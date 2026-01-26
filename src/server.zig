const std = @import("std");
const config_mod = @import("config.zig");
const state_mod = @import("state.zig");
const metrics_mod = @import("metrics.zig");

pub fn serve(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
) !void {
    const address = try std.net.Address.parseIp4(config.bind_address, config.bind_port);
    var net_server = try address.listen(.{ .reuse_address = true });
    defer net_server.deinit();
    std.debug.print("Listening on {s}:{d}\n", .{ config.bind_address, config.bind_port });

    while (true) {
        var conn = try net_server.accept();
        defer conn.stream.close();
        var read_buffer: [16 * 1024]u8 = undefined;
        var http_server = std.http.Server.init(conn, &read_buffer);

        while (true) {
            var req = http_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => break,
                error.HttpRequestTruncated,
                error.HttpHeadersOversize,
                error.HttpHeadersInvalid,
                error.HttpHeadersUnreadable,
                => break,
            };
            try handleRequest(allocator, config, state, &req);
        }
    }
}

fn handleRequest(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
    req: *std.http.Server.Request,
) !void {
    if (req.head.method != .GET) {
        try respondText(req, .method_not_allowed, "Method not allowed\n", "text/plain");
        return;
    }

    const target = req.head.target;
    const path = splitPath(target);

    if (std.mem.eql(u8, path, "/status")) {
        try handleStatus(allocator, config, state, req);
        return;
    }
    if (std.mem.eql(u8, path, "/metrics")) {
        try handleMetrics(allocator, state, req);
        return;
    }
    if (std.mem.eql(u8, path, "/healthz")) {
        try handleHealthz(allocator, config, state, req);
        return;
    }
    if (std.mem.eql(u8, path, "/api/upstreams")) {
        try handleApiUpstreams(allocator, config, state, req);
        return;
    }

    if (config.static_dir) |static_dir| {
        if (try handleStatic(allocator, static_dir, path, req)) return;
    }

    try respondText(req, .not_found, "Not found\n", "text/plain");
}

fn handleStatus(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
    req: *std.http.Server.Request,
) !void {
    var snapshot = try state.snapshot(allocator);
    defer snapshot.deinit(allocator);

    const now_ms = std.time.milliTimestamp();
    const stale = snapshot.last_success_ms == 0 or
        (now_ms - snapshot.last_success_ms) > @as(i64, @intCast(config.stale_after_ms));

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var last_error_json: ?[]const u8 = null;
    defer if (last_error_json) |value| allocator.free(value);
    if (snapshot.last_error) |msg| {
        last_error_json = try jsonString(allocator, msg);
    }

    const writer = buffer.writer();
    try writer.print(
        \\{{"justified_slot":{d},"finalized_slot":{d},"last_updated_ms":{d},"last_success_ms":{d},"stale":{s},"error_count":{d},"last_error":{s}}}
    , .{
        snapshot.justified_slot,
        snapshot.finalized_slot,
        snapshot.last_updated_ms,
        snapshot.last_success_ms,
        if (stale) "true" else "false",
        snapshot.error_count,
        last_error_json orelse "null",
    });

    try respondText(req, .ok, buffer.items, "application/json");
}

fn handleMetrics(
    allocator: std.mem.Allocator,
    state: *state_mod.AppState,
    req: *std.http.Server.Request,
) !void {
    var snapshot = try state.snapshot(allocator);
    defer snapshot.deinit(allocator);

    const body = try metrics_mod.format(allocator, snapshot);
    defer allocator.free(body);
    try respondText(req, .ok, body, "text/plain; version=0.0.4");
}

fn handleHealthz(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
    req: *std.http.Server.Request,
) !void {
    var snapshot = try state.snapshot(allocator);
    defer snapshot.deinit(allocator);

    const now_ms = std.time.milliTimestamp();
    const stale = snapshot.last_success_ms == 0 or
        (now_ms - snapshot.last_success_ms) > @as(i64, @intCast(config.stale_after_ms));

    if (stale) {
        try respondText(req, .service_unavailable, "stale\n", "text/plain");
    } else {
        try respondText(req, .ok, "ok\n", "text/plain");
    }
}

fn handleApiUpstreams(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
    req: *std.http.Server.Request,
) !void {
    _ = config;

    // Get upstreams data from state
    const upstreams_data = try state.getUpstreamsData(allocator);
    defer {
        var data = upstreams_data;
        data.deinit(allocator);
    }

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    const writer = buffer.writer();

    // Start JSON response
    try writer.writeAll("{\"upstreams\":[");

    // Write each upstream
    for (upstreams_data.upstreams, 0..) |upstream, i| {
        if (i > 0) try writer.writeAll(",");

        const name_json = try jsonString(allocator, upstream.name);
        defer allocator.free(name_json);
        const url_json = try jsonString(allocator, upstream.url);
        defer allocator.free(url_json);
        const path_json = try jsonString(allocator, upstream.path);
        defer allocator.free(path_json);

        var last_error_json: ?[]const u8 = null;
        defer if (last_error_json) |value| allocator.free(value);
        if (upstream.last_error) |msg| {
            last_error_json = try jsonString(allocator, msg);
        }

        try writer.print(
            \\{{"name":{s},"url":{s},"path":{s},"healthy":{s},"last_success_ms":{s},"error_count":{d},"last_error":{s},"last_justified_slot":{s},"last_finalized_slot":{s}}}
        , .{
            name_json,
            url_json,
            path_json,
            if (upstream.healthy) "true" else "false",
            if (upstream.last_success_ms) |ms| blk: {
                var num_buf: [32]u8 = undefined;
                const num_str = try std.fmt.bufPrint(&num_buf, "{d}", .{ms});
                break :blk num_str;
            } else "null",
            upstream.error_count,
            last_error_json orelse "null",
            if (upstream.last_justified_slot) |slot|
            blk: {
                var num_buf: [32]u8 = undefined;
                const num_str = try std.fmt.bufPrint(&num_buf, "{d}", .{slot});
                break :blk num_str;
            } else "null",
            if (upstream.last_finalized_slot) |slot|
            blk: {
                var num_buf: [32]u8 = undefined;
                const num_str = try std.fmt.bufPrint(&num_buf, "{d}", .{slot});
                break :blk num_str;
            } else "null",
        });
    }

    // Write consensus info
    try writer.print(
        \\],"consensus":{{"total_upstreams":{d},"responding_upstreams":{d},"consensus_threshold":50,"has_consensus":{s}}}}}
    , .{
        upstreams_data.consensus.total_upstreams,
        upstreams_data.consensus.responding_upstreams,
        if (upstreams_data.consensus.has_consensus) "true" else "false",
    });

    try respondText(req, .ok, buffer.items, "application/json");
}

fn handleStatic(
    allocator: std.mem.Allocator,
    static_dir: []const u8,
    path: []const u8,
    req: *std.http.Server.Request,
) !bool {
    var relative_path = path;
    if (std.mem.eql(u8, relative_path, "/")) {
        relative_path = "/index.html";
    }
    if (std.mem.startsWith(u8, relative_path, "/")) {
        relative_path = relative_path[1..];
    }
    if (std.mem.indexOf(u8, relative_path, "..") != null) {
        try respondText(req, .bad_request, "invalid path\n", "text/plain");
        return true;
    }

    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ static_dir, relative_path });
    defer allocator.free(file_path);

    var file = std.fs.cwd().openFile(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 8 * 1024 * 1024);
    defer allocator.free(data);

    const content_type = guessContentType(file_path);
    try respondText(req, .ok, data, content_type);
    return true;
}

fn splitPath(target: []const u8) []const u8 {
    var iter = std.mem.splitScalar(u8, target, '?');
    return iter.next() orelse target;
}

fn respondText(
    req: *std.http.Server.Request,
    status: std.http.Status,
    body: []const u8,
    content_type: []const u8,
) !void {
    const headers = [_]std.http.Header{
        .{ .name = "content-type", .value = content_type },
    };
    try req.respond(body, .{
        .status = status,
        .extra_headers = &headers,
    });
}

fn jsonString(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();
    const writer = buffer.writer();
    try std.json.stringify(input, .{}, writer);
    return buffer.toOwnedSlice();
}

fn guessContentType(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".html")) return "text/html";
    if (std.mem.eql(u8, ext, ".js")) return "application/javascript";
    if (std.mem.eql(u8, ext, ".css")) return "text/css";
    if (std.mem.eql(u8, ext, ".json")) return "application/json";
    if (std.mem.eql(u8, ext, ".png")) return "image/png";
    if (std.mem.eql(u8, ext, ".svg")) return "image/svg+xml";
    if (std.mem.eql(u8, ext, ".ico")) return "image/x-icon";
    return "application/octet-stream";
}

test "splitPath removes query string" {
    try std.testing.expectEqualStrings("/status", splitPath("/status?foo=bar"));
    try std.testing.expectEqualStrings("/metrics", splitPath("/metrics"));
    try std.testing.expectEqualStrings("/", splitPath("/?query=value"));
}

test "guessContentType" {
    try std.testing.expectEqualStrings("text/html", guessContentType("index.html"));
    try std.testing.expectEqualStrings("application/javascript", guessContentType("script.js"));
    try std.testing.expectEqualStrings("text/css", guessContentType("style.css"));
    try std.testing.expectEqualStrings("application/json", guessContentType("data.json"));
    try std.testing.expectEqualStrings("image/png", guessContentType("image.png"));
    try std.testing.expectEqualStrings("image/svg+xml", guessContentType("icon.svg"));
    try std.testing.expectEqualStrings("image/x-icon", guessContentType("favicon.ico"));
    try std.testing.expectEqualStrings("application/octet-stream", guessContentType("file.bin"));
    try std.testing.expectEqualStrings("application/octet-stream", guessContentType("no_extension"));
}

test "jsonString escapes special characters" {
    const input = "test \"quoted\" string\nwith newline";
    const output = try jsonString(std.testing.allocator, input);
    defer std.testing.allocator.free(output);

    // Should be properly escaped JSON string
    try std.testing.expect(std.mem.indexOf(u8, output, "\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\\n") != null);
}
