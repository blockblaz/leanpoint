const std = @import("std");
const config_mod = @import("config.zig");
const lean_api = @import("lean_api.zig");
const server = @import("server.zig");
const state_mod = @import("state.zig");
const upstreams_mod = @import("upstreams.zig");
const upstreams_config_mod = @import("upstreams_config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try config_mod.load(allocator);
    defer config.deinit(allocator);

    var state = state_mod.AppState{};
    defer state.deinit(allocator);

    // Check if multi-upstream mode is enabled
    if (config.upstreams_config) |upstreams_path| {
        std.debug.print("Loading upstreams from: {s}\n", .{upstreams_path});
        var upstreams = upstreams_config_mod.loadFromJsonFile(allocator, upstreams_path) catch |err| {
            std.debug.print("Failed to load upstreams config: {s}\n", .{@errorName(err)});
            return err;
        };
        defer upstreams.deinit();

        std.debug.print("Loaded {d} upstreams\n", .{upstreams.upstreams.items.len});
        const poller_thread = try std.Thread.spawn(.{}, pollLoopMulti, .{ allocator, &config, &state, &upstreams });
        defer poller_thread.detach();

        try server.serve(allocator, &config, &state);
    } else {
        // Legacy single upstream mode
        const poller_thread = try std.Thread.spawn(.{}, pollLoop, .{ allocator, &config, &state });
        defer poller_thread.detach();

        try server.serve(allocator, &config, &state);
    }
}

fn pollLoop(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    if (@hasField(std.http.Client, "connect_timeout")) {
        client.connect_timeout = config.request_timeout_ms * std.time.ns_per_ms;
    }
    if (@hasField(std.http.Client, "read_timeout")) {
        client.read_timeout = config.request_timeout_ms * std.time.ns_per_ms;
    }

    while (true) {
        const start_ns = std.time.nanoTimestamp();
        const now_ms = std.time.milliTimestamp();

        const slots = lean_api.fetchSlots(
            allocator,
            &client,
            config.lean_api_base_url,
            config.lean_api_path,
        ) catch |err| {
            var msg_buf = std.ArrayList(u8).init(allocator);
            defer msg_buf.deinit();
            try msg_buf.writer().print("poll error: {s}", .{@errorName(err)});
            state.updateError(allocator, msg_buf.items, now_ms);
            std.time.sleep(config.poll_interval_ms * std.time.ns_per_ms);
            continue;
        };

        const end_ns = std.time.nanoTimestamp();
        const delta_ns = end_ns - start_ns;
        const delta_ms = @divTrunc(delta_ns, @as(i128, std.time.ns_per_ms));
        const latency_ms = @as(u64, @intCast(delta_ms));
        state.updateSuccess(allocator, slots.justified_slot, slots.finalized_slot, latency_ms, now_ms);

        std.time.sleep(config.poll_interval_ms * std.time.ns_per_ms);
    }
}

fn pollLoopMulti(
    allocator: std.mem.Allocator,
    config: *const config_mod.Config,
    state: *state_mod.AppState,
    upstreams: *upstreams_mod.UpstreamManager,
) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    if (@hasField(std.http.Client, "connect_timeout")) {
        client.connect_timeout = config.request_timeout_ms * std.time.ns_per_ms;
    }
    if (@hasField(std.http.Client, "read_timeout")) {
        client.read_timeout = config.request_timeout_ms * std.time.ns_per_ms;
    }

    while (true) {
        const start_ns = std.time.nanoTimestamp();
        const now_ms = std.time.milliTimestamp();

        // Poll all upstreams and get consensus
        const consensus_slots = upstreams.pollUpstreams(&client, now_ms);

        if (consensus_slots) |slots| {
            const end_ns = std.time.nanoTimestamp();
            const delta_ns = end_ns - start_ns;
            const delta_ms = @divTrunc(delta_ns, @as(i128, std.time.ns_per_ms));
            const latency_ms = @as(u64, @intCast(delta_ms));
            state.updateSuccess(allocator, slots.justified_slot, slots.finalized_slot, latency_ms, now_ms);
        } else {
            const error_msg = upstreams.getErrorSummary(allocator) catch "failed to get error summary";
            defer allocator.free(error_msg);
            state.updateError(allocator, error_msg, now_ms);
        }

        std.time.sleep(config.poll_interval_ms * std.time.ns_per_ms);
    }
}
