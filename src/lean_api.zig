const std = @import("std");
const log = @import("log.zig");

pub const Slots = struct {
    justified_slot: u64,
    finalized_slot: u64,
};

/// Fetch finalized and justified slots from lean node endpoints
/// The finalized endpoint returns SSZ-encoded LeanState data
pub fn fetchSlots(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    base_url: []const u8,
    _: []const u8, // path parameter not used anymore
    out_state_ssz: *?[]u8,
) !Slots {
    // Fetch finalized slot from SSZ-encoded endpoint
    const finalized_slot = try fetchSlotFromSSZEndpoint(
        allocator,
        client,
        base_url,
        "/lean/v0/states/finalized",
        out_state_ssz,
    );

    // For now, use finalized slot as justified slot since /lean/v0/states/justified returns 404
    // TODO: Find the correct endpoint for justified slot
    const justified_slot = finalized_slot;

    return Slots{
        .justified_slot = justified_slot,
        .finalized_slot = finalized_slot,
    };
}

/// Fetch slot from SSZ-encoded endpoint
/// The lean nodes return SSZ-encoded LeanState data in this structure:
///   - config.genesis_time: u64 (8 bytes, offset 0-7)
///   - slot: u64 (8 bytes, offset 8-15)
///   - latest_block_header: LeanBlockHeader (112 bytes, offset 16-127)
///     - slot: u64 (8 bytes)
///     - proposer_index: u64 (8 bytes)
///     - parent_root: [32]u8 (32 bytes)
///     - state_root: [32]u8 (32 bytes)
///     - body_root: [32]u8 (32 bytes)
///   - latest_justified: Checkpoint (40 bytes, offset 128-167)
///   - latest_finalized: Checkpoint (40 bytes, offset 168-207)
///   - Then offsets for variable-length fields...
///
/// We extract the slot directly from bytes 8-15 (little-endian u64)
fn fetchSlotFromSSZEndpoint(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    base_url: []const u8,
    path: []const u8,
    out_state_ssz: *?[]u8,
) !u64 {
    // Build full URL
    var url_buf: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base_url, path });

    // Parse URI
    const uri = try std.Uri.parse(url);

    // Make request with Accept: application/octet-stream header
    // Force connection closure to prevent stale connection reuse (EndOfStream errors)
    var header_buf: [4096]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &header_buf,
        .extra_headers = &.{
            .{ .name = "accept", .value = "application/octet-stream" },
            .{ .name = "connection", .value = "close" },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    // Check status
    if (req.response.status != .ok) {
        log.warn("Bad status from {s}: {any}", .{ url, req.response.status });
        return error.BadStatus;
    }

    // Read response body
    var body_buf = std.ArrayList(u8).init(allocator);
    errdefer body_buf.deinit();

    // Optimize buffer size based on endpoint
    // Finalized/justified states are typically 1-2MB in SSZ format
    // Other endpoints (health, metrics) are much smaller
    const max_bytes: usize = if (std.mem.indexOf(u8, path, "states") != null)
        2 * 1024 * 1024 // 2MB for state endpoints
    else
        64 * 1024; // 64KB for other endpoints

    try req.reader().readAllArrayList(&body_buf, max_bytes);

    const body = body_buf.items;

    // Validate we have enough bytes to read the slot
    if (body.len < 16) {
        log.err("Response too short for SSZ state (need 16 bytes, got {d}) from {s}", .{ body.len, url });
        return error.InvalidSSZData;
    }

    // Check if response looks like text/JSON/metrics instead of binary SSZ
    // SSZ binary data should have non-printable bytes in the first 64 bytes
    var text_byte_count: usize = 0;
    const check_len = @min(body.len, 64);
    for (body[0..check_len]) |byte| {
        // Count printable ASCII characters
        if ((byte >= 32 and byte <= 126) or byte == '\n' or byte == '\r' or byte == '\t') {
            text_byte_count += 1;
        }
    }

    // If more than 90% of bytes are printable text, it's probably not SSZ
    if (text_byte_count * 100 / check_len > 90) {
        const preview = body[0..@min(body.len, 100)];
        log.err("Response from {s} appears to be text, not SSZ binary. First 100 bytes: {s}", .{ url, preview });
        return error.UnexpectedTextResponse;
    }

    // Extract slot from bytes 8-15 (little-endian u64)
    // This is the second field in LeanState after config.genesis_time
    const genesis_time = std.mem.readInt(u64, body[0..8], .little);
    const slot = std.mem.readInt(u64, body[8..16], .little);

    // Validate slot is reasonable (not astronomically large due to misinterpreting text as binary)
    // A reasonable upper bound: 1 billion slots (would take ~300 years at 12s per slot)
    const max_reasonable_slot: u64 = 1_000_000_000;
    if (slot > max_reasonable_slot) {
        // This is likely text being interpreted as a number
        const bytes_as_text = body[8..16];
        var is_ascii = true;
        for (bytes_as_text) |byte| {
            if (byte < 32 or byte > 126) {
                is_ascii = false;
                break;
            }
        }
        if (is_ascii) {
            log.err("Invalid slot value {d} from {s}. Bytes 8-15 as ASCII: '{s}'. This suggests text/metrics response instead of SSZ", .{ slot, url, bytes_as_text });
            return error.InvalidSlotValue;
        }
    }

    // Validate genesis time is reasonable (Unix timestamp between 2020 and 2050)
    const min_genesis: u64 = 1577836800; // 2020-01-01
    const max_genesis: u64 = 2524608000; // 2050-01-01
    if (genesis_time < min_genesis or genesis_time > max_genesis) {
        log.warn("Unusual genesis_time {d} from {s} (expected Unix timestamp between 2020-2050)", .{ genesis_time, url });
    }

    log.debug("Successfully fetched slot {d} from {s}", .{ slot, url });

    // Transfer ownership of the full SSZ payload to the caller.
    out_state_ssz.* = try body_buf.toOwnedSlice();

    return slot;
}

test "extract slot from ssz bytes" {
    // Simulate SSZ LeanState data
    var data: [300]u8 = undefined;
    @memset(&data, 0);

    // config.genesis_time at offset 0-7
    std.mem.writeInt(u64, data[0..8], 1234567890, .little);

    // slot at offset 8-15
    std.mem.writeInt(u64, data[8..16], 42, .little);

    // Read back the slot
    const slot = std.mem.readInt(u64, data[8..16], .little);
    try std.testing.expectEqual(@as(u64, 42), slot);
}
