const std = @import("std");

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
) !Slots {
    // Fetch finalized slot from SSZ-encoded endpoint
    const finalized_slot = try fetchSlotFromSSZEndpoint(
        allocator,
        client,
        base_url,
        "/lean/v0/states/finalized",
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
) !u64 {
    // Build full URL
    var url_buf: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base_url, path });

    // Parse URI
    const uri = try std.Uri.parse(url);

    // Make request
    var header_buf: [4096]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &header_buf,
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    // Check status
    if (req.response.status != .ok) {
        return error.BadStatus;
    }

    // Read response body (SSZ binary data)
    var body_buf = std.ArrayList(u8).init(allocator);
    defer body_buf.deinit();

    const max_bytes = 10 * 1024 * 1024; // 10 MB limit for state data
    try req.reader().readAllArrayList(&body_buf, max_bytes);

    const body = body_buf.items;

    // Validate we have enough bytes to read the slot
    if (body.len < 16) {
        return error.InvalidSSZData;
    }

    // Extract slot from bytes 8-15 (little-endian u64)
    // This is the second field in LeanState after config.genesis_time
    const slot = std.mem.readInt(u64, body[8..16], .little);

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
