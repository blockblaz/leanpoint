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
