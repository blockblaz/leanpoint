const std = @import("std");

pub const Level = enum {
    debug,
    info,
    warn,
    err,

    pub fn fromInt(val: u8) Level {
        return switch (val) {
            0 => .debug,
            1 => .info,
            2 => .warn,
            3 => .err,
            else => .info,
        };
    }
};

var log_level: Level = .info;
var log_mutex: std.Thread.Mutex = .{};

pub fn init(level: Level) void {
    log_level = level;
}

pub fn setLevel(level: Level) void {
    log_mutex.lock();
    defer log_mutex.unlock();
    log_level = level;
}

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    log(.debug, fmt, args);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    log(.info, fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    log(.warn, fmt, args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    log(.err, fmt, args);
}

fn log(level: Level, comptime fmt: []const u8, args: anytype) void {
    log_mutex.lock();
    defer log_mutex.unlock();

    if (@intFromEnum(level) < @intFromEnum(log_level)) return;

    const timestamp = std.time.milliTimestamp();
    const level_str = switch (level) {
        .debug => "DEBUG",
        .info => "INFO ",
        .warn => "WARN ",
        .err => "ERROR",
    };

    // Format: [timestamp] LEVEL | message
    std.debug.print("[{d}] {s} | ", .{ timestamp, level_str });
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

test "log level filtering" {
    setLevel(.warn);

    // These shouldn't panic, just won't print
    debug("debug message", .{});
    info("info message", .{});

    // Reset for other tests
    setLevel(.info);
}

test "log formatting" {
    info("Test message with arg: {s}", .{"value"});
    warn("Warning with number: {d}", .{42});
    err("Error with multiple: {s} {d}", .{ "error", 123 });
}
