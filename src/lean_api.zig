const std = @import("std");

pub const Slots = struct {
    justified_slot: u64,
    finalized_slot: u64,
};

pub fn fetchSlots(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    base_url: []const u8,
    path: []const u8,
) !Slots {
    const full_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base_url, path });
    defer allocator.free(full_url);

    const uri = try std.Uri.parse(full_url);
    var header_buffer: [8 * 1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &header_buffer,
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }

    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);

    return parseSlotsFromJson(allocator, body);
}

pub fn parseSlotsFromJson(allocator: std.mem.Allocator, body: []const u8) !Slots {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();
    const root = parsed.value;

    if (try parseTopLevel(root)) |slots| return slots;
    if (try parseDataObject(root)) |slots| return slots;

    return error.UnexpectedResponse;
}

fn parseTopLevel(root: std.json.Value) !?Slots {
    if (root != .object) return null;
    const obj = root.object;
    const justified_val = obj.get("justified_slot") orelse return null;
    const finalized_val = obj.get("finalized_slot") orelse return null;
    return Slots{
        .justified_slot = try parseJsonU64(justified_val),
        .finalized_slot = try parseJsonU64(finalized_val),
    };
}

fn parseDataObject(root: std.json.Value) !?Slots {
    if (root != .object) return null;
    const obj = root.object;
    const data_val = obj.get("data") orelse return null;
    if (data_val != .object) return null;
    const data_obj = data_val.object;

    if (data_obj.get("justified_slot")) |justified_val| {
        if (data_obj.get("finalized_slot")) |finalized_val| {
            return Slots{
                .justified_slot = try parseJsonU64(justified_val),
                .finalized_slot = try parseJsonU64(finalized_val),
            };
        }
    }

    const justified_obj = data_obj.get("justified") orelse return null;
    const finalized_obj = data_obj.get("finalized") orelse return null;
    if (justified_obj != .object or finalized_obj != .object) return null;

    const justified_slot_val = justified_obj.object.get("slot") orelse return null;
    const finalized_slot_val = finalized_obj.object.get("slot") orelse return null;

    return Slots{
        .justified_slot = try parseJsonU64(justified_slot_val),
        .finalized_slot = try parseJsonU64(finalized_slot_val),
    };
}

fn parseJsonU64(value: std.json.Value) !u64 {
    return switch (value) {
        .integer => |i| if (i < 0) error.InvalidValue else @as(u64, @intCast(i)),
        .string => |s| std.fmt.parseInt(u64, s, 10),
        else => error.InvalidValue,
    };
}

test "parseSlotsFromJson supports top-level fields" {
    const input =
        \\{"justified_slot":123,"finalized_slot":"120"}
    ;
    const slots = try parseSlotsFromJson(std.testing.allocator, input);
    try std.testing.expectEqual(@as(u64, 123), slots.justified_slot);
    try std.testing.expectEqual(@as(u64, 120), slots.finalized_slot);
}

test "parseSlotsFromJson supports data.justified.slot" {
    const input =
        \\{"data":{"justified":{"slot":"64"},"finalized":{"slot":32}}}
    ;
    const slots = try parseSlotsFromJson(std.testing.allocator, input);
    try std.testing.expectEqual(@as(u64, 64), slots.justified_slot);
    try std.testing.expectEqual(@as(u64, 32), slots.finalized_slot);
}
