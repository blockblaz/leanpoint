const std = @import("std");
const state = @import("state.zig");

pub fn format(
    allocator: std.mem.Allocator,
    snapshot: state.Snapshot,
) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();
    const writer = buffer.writer();

    try writer.print(
        \\# HELP leanpoint_justified_slot Latest justified slot.
        \\# TYPE leanpoint_justified_slot gauge
        \\leanpoint_justified_slot {d}
        \\# HELP leanpoint_finalized_slot Latest finalized slot.
        \\# TYPE leanpoint_finalized_slot gauge
        \\leanpoint_finalized_slot {d}
        \\# HELP leanpoint_last_success_timestamp_ms Last successful poll time (ms since epoch).
        \\# TYPE leanpoint_last_success_timestamp_ms gauge
        \\leanpoint_last_success_timestamp_ms {d}
        \\# HELP leanpoint_last_updated_timestamp_ms Last update time (ms since epoch).
        \\# TYPE leanpoint_last_updated_timestamp_ms gauge
        \\leanpoint_last_updated_timestamp_ms {d}
        \\# HELP leanpoint_last_latency_ms Last poll latency in milliseconds.
        \\# TYPE leanpoint_last_latency_ms gauge
        \\leanpoint_last_latency_ms {d}
        \\# HELP leanpoint_error_total Total poll errors.
        \\# TYPE leanpoint_error_total counter
        \\leanpoint_error_total {d}
        \\
    , .{
        snapshot.justified_slot,
        snapshot.finalized_slot,
        snapshot.last_success_ms,
        snapshot.last_updated_ms,
        snapshot.last_latency_ms,
        snapshot.error_count,
    });

    return buffer.toOwnedSlice();
}

test "metrics format" {
    const snapshot = state.Snapshot{
        .justified_slot = 12345,
        .finalized_slot = 12344,
        .last_success_ms = 1705852800000,
        .last_updated_ms = 1705852800000,
        .last_latency_ms = 45,
        .error_count = 0,
        .last_error = null,
    };

    const output = try format(std.testing.allocator, snapshot);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_justified_slot 12345") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_finalized_slot 12344") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_last_latency_ms 45") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_error_total 0") != null);
}

test "metrics format with high values" {
    const snapshot = state.Snapshot{
        .justified_slot = 999999999,
        .finalized_slot = 999999998,
        .last_success_ms = 9999999999999,
        .last_updated_ms = 9999999999999,
        .last_latency_ms = 9999,
        .error_count = 12345,
        .last_error = null,
    };

    const output = try format(std.testing.allocator, snapshot);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_justified_slot 999999999") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "leanpoint_error_total 12345") != null);
}
