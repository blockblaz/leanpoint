const std = @import("std");
const lean_api = @import("lean_api.zig");

pub const Upstream = struct {
    name: []const u8,
    base_url: []const u8,
    path: []const u8,
    // Track upstream health
    last_slots: ?lean_api.Slots,
    last_success_ms: i64,
    error_count: u64,
    last_error: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, base_url: []const u8, path: []const u8) !Upstream {
        return Upstream{
            .name = try allocator.dupe(u8, name),
            .base_url = try allocator.dupe(u8, base_url),
            .path = try allocator.dupe(u8, path),
            .last_slots = null,
            .last_success_ms = 0,
            .error_count = 0,
            .last_error = null,
        };
    }

    pub fn deinit(self: *Upstream, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.base_url);
        allocator.free(self.path);
        if (self.last_error) |err| allocator.free(err);
    }
};

pub const UpstreamManager = struct {
    upstreams: std.ArrayList(Upstream),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UpstreamManager {
        return UpstreamManager{
            .upstreams = std.ArrayList(Upstream).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UpstreamManager) void {
        for (self.upstreams.items) |*upstream| {
            upstream.deinit(self.allocator);
        }
        self.upstreams.deinit();
    }

    pub fn addUpstream(self: *UpstreamManager, name: []const u8, base_url: []const u8, path: []const u8) !void {
        const upstream = try Upstream.init(self.allocator, name, base_url, path);
        try self.upstreams.append(upstream);
    }

    /// Poll all upstreams and return consensus slots if 50%+ agree
    pub fn pollUpstreams(
        self: *UpstreamManager,
        client: *std.http.Client,
        now_ms: i64,
    ) ?lean_api.Slots {
        if (self.upstreams.items.len == 0) return null;

        var slot_counts = std.AutoHashMap(u128, u32).init(self.allocator);
        defer slot_counts.deinit();

        var successful_polls: u32 = 0;

        // Poll each upstream
        for (self.upstreams.items) |*upstream| {
            const slots = lean_api.fetchSlots(
                self.allocator,
                client,
                upstream.base_url,
                upstream.path,
            ) catch |err| {
                upstream.error_count += 1;
                if (upstream.last_error) |old_err| self.allocator.free(old_err);
                upstream.last_error = std.fmt.allocPrint(
                    self.allocator,
                    "poll error: {s}",
                    .{@errorName(err)},
                ) catch null;
                continue;
            };

            // Update upstream state
            upstream.last_slots = slots;
            upstream.last_success_ms = now_ms;

            // Create a unique key for this slot combination
            const slot_key: u128 = (@as(u128, slots.justified_slot) << 64) | @as(u128, slots.finalized_slot);
            const count = slot_counts.get(slot_key) orelse 0;
            slot_counts.put(slot_key, count + 1) catch continue;

            successful_polls += 1;
        }

        if (successful_polls == 0) return null;

        // Find consensus (50%+ agreement)
        const required_votes = (successful_polls + 1) / 2; // Ceiling division

        var iter = slot_counts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* >= required_votes) {
                const slot_key = entry.key_ptr.*;
                return lean_api.Slots{
                    .justified_slot = @truncate(slot_key >> 64),
                    .finalized_slot = @truncate(slot_key & 0xFFFFFFFFFFFFFFFF),
                };
            }
        }

        return null; // No consensus reached
    }
};

test "upstream manager basic operations" {
    var manager = UpstreamManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.addUpstream("test1", "http://localhost:5052", "/status");
    try manager.addUpstream("test2", "http://localhost:5053", "/status");

    try std.testing.expectEqual(@as(usize, 2), manager.upstreams.items.len);
}
