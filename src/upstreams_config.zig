const std = @import("std");
const upstreams = @import("upstreams.zig");

/// Simple JSON configuration format for upstreams
/// Example:
/// {
///   "upstreams": [
///     {
///       "name": "zeam_0",
///       "url": "http://localhost:5052",
///       "path": "/status"
///     }
///   ]
/// }
pub fn loadFromJsonFile(allocator: std.mem.Allocator, file_path: []const u8) !upstreams.UpstreamManager {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    return try parseFromJson(allocator, content);
}

pub fn parseFromJson(allocator: std.mem.Allocator, json_content: []const u8) !upstreams.UpstreamManager {
    var manager = upstreams.UpstreamManager.init(allocator);
    errdefer manager.deinit();

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_content, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidFormat;

    const upstreams_array = root.object.get("upstreams") orelse return error.MissingUpstreams;
    if (upstreams_array != .array) return error.InvalidFormat;

    for (upstreams_array.array.items) |item| {
        if (item != .object) continue;
        const obj = item.object;

        const name = obj.get("name") orelse continue;
        const url = obj.get("url") orelse continue;
        const path_val = obj.get("path") orelse std.json.Value{ .string = "/status" };

        if (name != .string or url != .string or path_val != .string) continue;

        try manager.addUpstream(name.string, url.string, path_val.string);
    }

    return manager;
}

test "parse upstreams from JSON" {
    const json =
        \\{
        \\  "upstreams": [
        \\    {
        \\      "name": "zeam_0",
        \\      "url": "http://localhost:5052",
        \\      "path": "/status"
        \\    },
        \\    {
        \\      "name": "ream_0",
        \\      "url": "http://localhost:5053",
        \\      "path": "/status"
        \\    }
        \\  ]
        \\}
    ;

    var manager = try parseFromJson(std.testing.allocator, json);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 2), manager.upstreams.items.len);
    try std.testing.expectEqualStrings("zeam_0", manager.upstreams.items[0].name);
    try std.testing.expectEqualStrings("http://localhost:5052", manager.upstreams.items[0].base_url);
}
