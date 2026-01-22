const std = @import("std");

pub const Slots = struct {
    justified_slot: u64,
    finalized_slot: u64,
};

/// Fetch finalized and justified slots from separate endpoints
pub fn fetchSlots(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    base_url: []const u8,
    _: []const u8, // path parameter not used anymore
) !Slots {
    // Fetch finalized slot
    const finalized_slot = try fetchSlotFromEndpoint(
        allocator,
        client,
        base_url,
        "/lean/states/finalized",
    );

    // Fetch justified slot
    const justified_slot = try fetchSlotFromEndpoint(
        allocator,
        client,
        base_url,
        "/lean/states/justified",
    );

    return Slots{
        .justified_slot = justified_slot,
        .finalized_slot = finalized_slot,
    };
}

fn fetchSlotFromEndpoint(
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

    // Read response body
    var body_buf = std.ArrayList(u8).init(allocator);
    defer body_buf.deinit();

    const max_bytes = 1024 * 1024; // 1 MB limit
    try req.reader().readAllArrayList(&body_buf, max_bytes);

    // Parse JSON - expecting just a number
    const body = body_buf.items;
    
    // Try to parse as direct number first
    const slot = std.fmt.parseInt(u64, std.mem.trim(u8, body, " \t\n\r\""), 10) catch {
        // If that fails, try parsing as JSON object with "slot" field
        const parsed = try std.json.parseFromSlice(
            struct { slot: u64 },
            allocator,
            body,
            .{},
        );
        defer parsed.deinit();
        return parsed.value.slot;
    };

    return slot;
}

test "parse slot from plain number" {
    const body = "12345";
    const slot = try std.fmt.parseInt(u64, std.mem.trim(u8, body, " \t\n\r\""), 10);
    try std.testing.expectEqual(@as(u64, 12345), slot);
}

test "parse slot from quoted number" {
    const body = "\"12345\"";
    const slot = try std.fmt.parseInt(u64, std.mem.trim(u8, body, " \t\n\r\""), 10);
    try std.testing.expectEqual(@as(u64, 12345), slot);
}
