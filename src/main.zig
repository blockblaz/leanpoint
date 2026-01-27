const std = @import("std");
const config_mod = @import("config.zig");
const log = @import("log.zig");
const poller_mod = @import("poller.zig");
const server = @import("server.zig");
const state_mod = @import("state.zig");
const upstreams_mod = @import("upstreams.zig");
const upstreams_config_mod = @import("upstreams_config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize logging (default level: info)
    log.init(.info);

    var config = try config_mod.load(allocator);
    defer config.deinit(allocator);

    var state: state_mod.AppState = undefined;
    defer state.deinit(allocator);

    // Check if multi-upstream mode is enabled
    if (config.upstreams_config) |upstreams_path| {
        log.info("Loading upstreams from: {s}", .{upstreams_path});
        var upstreams = upstreams_config_mod.loadFromJsonFile(allocator, upstreams_path) catch |err| {
            log.err("Failed to load upstreams config: {s}", .{@errorName(err)});
            return err;
        };
        defer upstreams.deinit();

        state = state_mod.AppState.init(&upstreams);

        log.info("Loaded {d} upstreams", .{upstreams.upstreams.items.len});

        // Initialize poller
        var poller = poller_mod.Poller.init(allocator, &config, &state, &upstreams);
        defer poller.deinit();

        // Spawn poller thread
        const poller_thread = try std.Thread.spawn(.{}, pollerThreadFn, .{&poller});
        defer poller_thread.detach();

        try server.serve(allocator, &config, &state);
    } else {
        // Legacy single upstream mode
        log.info("Starting in single-upstream mode (legacy)", .{});
        state = state_mod.AppState.init(null);

        // Initialize poller
        var poller = poller_mod.Poller.init(allocator, &config, &state, null);
        defer poller.deinit();

        // Spawn poller thread
        const poller_thread = try std.Thread.spawn(.{}, pollerThreadFn, .{&poller});
        defer poller_thread.detach();

        try server.serve(allocator, &config, &state);
    }
}

/// Thread entry point for poller
fn pollerThreadFn(poller: *poller_mod.Poller) !void {
    poller.run() catch |err| {
        log.err("Poller crashed: {s}", .{@errorName(err)});
        return err;
    };
}
