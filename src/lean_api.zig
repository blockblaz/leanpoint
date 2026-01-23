const std = @import("std");

pub const Slots = struct {
    justified_slot: u64,
    finalized_slot: u64,
};

/// Fetch finalized and justified slots from lean node endpoints
/// The finalized endpoint returns SSZ-encoded state data
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
        "/lean/states/finalized",
    );

    // For now, use finalized slot as justified slot since /lean/states/justified returns 404
    // TODO: Find the correct endpoint for justified slot
    const justified_slot = finalized_slot;

    return Slots{
        .justified_slot = justified_slot,
        .finalized_slot = finalized_slot,
    };
}

/// Fetch slot from SSZ-encoded endpoint
/// The lean nodes return SSZ-encoded BeaconState data
/// The slot is the first field (first 8 bytes as little-endian u64)
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

    // SSZ-encoded BeaconState: slot is the first field (8 bytes, little-endian u64)
    if (body.len < 8) {
        return error.InvalidSSZData;
    }

    // Read first 8 bytes as little-endian u64
    const slot = std.mem.readInt(u64, body[0..8], .little);

    return slot;
}

test "parse SSZ slot from binary data" {
    // Simulate SSZ data where first 8 bytes represent slot
    var data: [8]u8 = undefined;
    std.mem.writeInt(u64, &data, 12345, .little);

    const slot = std.mem.readInt(u64, data[0..8], .little);
    try std.testing.expectEqual(@as(u64, 12345), slot);
}

test "parse SSZ slot with additional data" {
    // Simulate SSZ data with slot + other fields
    var data: [100]u8 = undefined;
    std.mem.writeInt(u64, data[0..8], 99999, .little);
    // Fill rest with dummy data
    @memset(data[8..], 0xFF);

    const slot = std.mem.readInt(u64, data[0..8], .little);
    try std.testing.expectEqual(@as(u64, 99999), slot);
}
