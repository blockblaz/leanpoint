const std = @import("std");
const config_mod = @import("config.zig");
const lean_api = @import("lean_api.zig");
const server = @import("server.zig");
const state_mod = @import("state.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try config_mod.load(allocator);
    defer config.deinit(allocator);

    var state = state_mod.AppState{};
    defer state.deinit(allocator);

    const poller_thread = try std.Thread.spawn(.{}, pollLoop, .{ allocator, &config, &state });
    defer poller_thread.detach();

    try server.serve(allocator, &config, &state);
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
