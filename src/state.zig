const std = @import("std");

pub const Snapshot = struct {
    justified_slot: u64,
    finalized_slot: u64,
    last_updated_ms: i64,
    last_success_ms: i64,
    last_latency_ms: u64,
    error_count: u64,
    last_error: ?[]u8,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        if (self.last_error) |err_msg| allocator.free(err_msg);
    }
};

pub const AppState = struct {
    mutex: std.Thread.Mutex = .{},
    justified_slot: u64 = 0,
    finalized_slot: u64 = 0,
    last_updated_ms: i64 = 0,
    last_success_ms: i64 = 0,
    last_latency_ms: u64 = 0,
    error_count: u64 = 0,
    last_error: ?[]u8 = null,

    pub fn deinit(self: *AppState, allocator: std.mem.Allocator) void {
        if (self.last_error) |msg| allocator.free(msg);
        self.last_error = null;
    }

    pub fn updateSuccess(
        self: *AppState,
        allocator: std.mem.Allocator,
        justified_slot: u64,
        finalized_slot: u64,
        latency_ms: u64,
        now_ms: i64,
    ) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.justified_slot = justified_slot;
        self.finalized_slot = finalized_slot;
        self.last_updated_ms = now_ms;
        self.last_success_ms = now_ms;
        self.last_latency_ms = latency_ms;
        if (self.last_error) |msg| allocator.free(msg);
        self.last_error = null;
    }

    pub fn updateError(
        self: *AppState,
        allocator: std.mem.Allocator,
        msg: []const u8,
        now_ms: i64,
    ) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.last_updated_ms = now_ms;
        self.error_count += 1;
        if (self.last_error) |old| allocator.free(old);
        self.last_error = allocator.dupe(u8, msg) catch null;
    }

    pub fn snapshot(self: *AppState, allocator: std.mem.Allocator) !Snapshot {
        self.mutex.lock();
        defer self.mutex.unlock();
        var err_copy: ?[]u8 = null;
        if (self.last_error) |msg| {
            err_copy = try allocator.dupe(u8, msg);
        }
        return Snapshot{
            .justified_slot = self.justified_slot,
            .finalized_slot = self.finalized_slot,
            .last_updated_ms = self.last_updated_ms,
            .last_success_ms = self.last_success_ms,
            .last_latency_ms = self.last_latency_ms,
            .error_count = self.error_count,
            .last_error = err_copy,
        };
    }
};

test "AppState updateSuccess" {
    var state = AppState{};
    defer state.deinit(std.testing.allocator);

    state.updateSuccess(std.testing.allocator, 100, 99, 50, 1000);

    try std.testing.expectEqual(@as(u64, 100), state.justified_slot);
    try std.testing.expectEqual(@as(u64, 99), state.finalized_slot);
    try std.testing.expectEqual(@as(i64, 1000), state.last_updated_ms);
    try std.testing.expectEqual(@as(i64, 1000), state.last_success_ms);
    try std.testing.expectEqual(@as(u64, 50), state.last_latency_ms);
    try std.testing.expectEqual(@as(u64, 0), state.error_count);
    try std.testing.expect(state.last_error == null);
}

test "AppState updateError" {
    var state = AppState{};
    defer state.deinit(std.testing.allocator);

    state.updateError(std.testing.allocator, "test error", 2000);

    try std.testing.expectEqual(@as(i64, 2000), state.last_updated_ms);
    try std.testing.expectEqual(@as(u64, 1), state.error_count);
    try std.testing.expect(state.last_error != null);
    if (state.last_error) |msg| {
        try std.testing.expectEqualStrings("test error", msg);
    }
}

test "AppState snapshot" {
    var state = AppState{};
    defer state.deinit(std.testing.allocator);

    state.updateSuccess(std.testing.allocator, 200, 199, 75, 3000);

    var snapshot = try state.snapshot(std.testing.allocator);
    defer snapshot.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u64, 200), snapshot.justified_slot);
    try std.testing.expectEqual(@as(u64, 199), snapshot.finalized_slot);
    try std.testing.expectEqual(@as(i64, 3000), snapshot.last_updated_ms);
    try std.testing.expectEqual(@as(i64, 3000), snapshot.last_success_ms);
    try std.testing.expectEqual(@as(u64, 75), snapshot.last_latency_ms);
}

test "AppState updateError clears previous error" {
    var state = AppState{};
    defer state.deinit(std.testing.allocator);

    state.updateError(std.testing.allocator, "first error", 1000);
    state.updateError(std.testing.allocator, "second error", 2000);

    try std.testing.expectEqual(@as(u64, 2), state.error_count);
    if (state.last_error) |msg| {
        try std.testing.expectEqualStrings("second error", msg);
    }
}

test "AppState updateSuccess clears error" {
    var state = AppState{};
    defer state.deinit(std.testing.allocator);

    state.updateError(std.testing.allocator, "error message", 1000);
    try std.testing.expectEqual(@as(u64, 1), state.error_count);

    state.updateSuccess(std.testing.allocator, 100, 99, 50, 2000);
    try std.testing.expect(state.last_error == null);
    try std.testing.expectEqual(@as(u64, 1), state.error_count); // error_count persists
}
