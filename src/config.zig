const std = @import("std");

pub const Config = struct {
    bind_address: []const u8,
    bind_port: u16,
    lean_api_base_url: []const u8,
    lean_api_path: []const u8,
    poll_interval_ms: u64,
    request_timeout_ms: u64,
    stale_after_ms: u64,
    static_dir: ?[]const u8,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.bind_address);
        allocator.free(self.lean_api_base_url);
        allocator.free(self.lean_api_path);
        if (self.static_dir) |dir| allocator.free(dir);
    }
};

pub fn load(allocator: std.mem.Allocator) !Config {
    const defaults = Defaults{};
    var bind_address = try allocator.dupe(u8, defaults.bind_address);
    var bind_port: u16 = defaults.bind_port;
    var lean_api_base_url = try allocator.dupe(u8, defaults.lean_api_base_url);
    var lean_api_path = try allocator.dupe(u8, defaults.lean_api_path);
    var poll_interval_ms: u64 = defaults.poll_interval_ms;
    var request_timeout_ms: u64 = defaults.request_timeout_ms;
    var stale_after_ms: u64 = defaults.stale_after_ms;
    var static_dir: ?[]const u8 = null;

    if (try getEnvOwned(allocator, "LEANPOINT_BIND_ADDR")) |val| {
        allocator.free(bind_address);
        bind_address = val;
    }
    if (try getEnvOwned(allocator, "LEANPOINT_BIND_PORT")) |val| {
        bind_port = try parseU16(val);
        allocator.free(val);
    }
    if (try getEnvOwned(allocator, "LEANPOINT_LEAN_URL")) |val| {
        allocator.free(lean_api_base_url);
        lean_api_base_url = val;
    }
    if (try getEnvOwned(allocator, "LEANPOINT_LEAN_PATH")) |val| {
        allocator.free(lean_api_path);
        lean_api_path = val;
    }
    if (try getEnvOwned(allocator, "LEANPOINT_POLL_MS")) |val| {
        poll_interval_ms = try parseU64(val);
        allocator.free(val);
    }
    if (try getEnvOwned(allocator, "LEANPOINT_TIMEOUT_MS")) |val| {
        request_timeout_ms = try parseU64(val);
        allocator.free(val);
    }
    if (try getEnvOwned(allocator, "LEANPOINT_STALE_MS")) |val| {
        stale_after_ms = try parseU64(val);
        allocator.free(val);
    }
    if (try getEnvOwned(allocator, "LEANPOINT_STATIC_DIR")) |val| {
        static_dir = val;
    }

    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--bind")) {
            const value = try needArg(&args, "--bind");
            allocator.free(bind_address);
            bind_address = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, arg, "--port")) {
            const value = try needArg(&args, "--port");
            bind_port = try parseU16(value);
        } else if (std.mem.eql(u8, arg, "--lean-url")) {
            const value = try needArg(&args, "--lean-url");
            allocator.free(lean_api_base_url);
            lean_api_base_url = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, arg, "--lean-path")) {
            const value = try needArg(&args, "--lean-path");
            allocator.free(lean_api_path);
            lean_api_path = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, arg, "--poll-ms")) {
            const value = try needArg(&args, "--poll-ms");
            poll_interval_ms = try parseU64(value);
        } else if (std.mem.eql(u8, arg, "--timeout-ms")) {
            const value = try needArg(&args, "--timeout-ms");
            request_timeout_ms = try parseU64(value);
        } else if (std.mem.eql(u8, arg, "--stale-ms")) {
            const value = try needArg(&args, "--stale-ms");
            stale_after_ms = try parseU64(value);
        } else if (std.mem.eql(u8, arg, "--static-dir")) {
            const value = try needArg(&args, "--static-dir");
            if (static_dir) |dir| allocator.free(dir);
            static_dir = try allocator.dupe(u8, value);
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            printUsage();
            return error.InvalidArgument;
        }
    }

    if (!std.mem.startsWith(u8, lean_api_path, "/")) {
        const prefixed = try std.fmt.allocPrint(allocator, "/{s}", .{lean_api_path});
        allocator.free(lean_api_path);
        lean_api_path = prefixed;
    }

    return Config{
        .bind_address = bind_address,
        .bind_port = bind_port,
        .lean_api_base_url = lean_api_base_url,
        .lean_api_path = lean_api_path,
        .poll_interval_ms = poll_interval_ms,
        .request_timeout_ms = request_timeout_ms,
        .stale_after_ms = stale_after_ms,
        .static_dir = static_dir,
    };
}

const Defaults = struct {
    bind_address: []const u8 = "0.0.0.0",
    bind_port: u16 = 5555,
    lean_api_base_url: []const u8 = "http://127.0.0.1:5052",
    lean_api_path: []const u8 = "/status",
    poll_interval_ms: u64 = 10_000,
    request_timeout_ms: u64 = 5_000,
    stale_after_ms: u64 = 30_000,
};

fn getEnvOwned(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

fn parseU64(value: []const u8) !u64 {
    return std.fmt.parseInt(u64, value, 10);
}

fn parseU16(value: []const u8) !u16 {
    return std.fmt.parseInt(u16, value, 10);
}

fn needArg(args: *std.process.ArgIterator, flag: []const u8) ![]const u8 {
    if (args.next()) |val| return val;
    std.debug.print("Missing value for {s}\n", .{flag});
    return error.MissingArgument;
}

fn printUsage() void {
    std.debug.print(
        \\leanpoint checkpoint status service
        \\
        \\Usage:
        \\  leanpoint [options]
        \\
        \\Options:
        \\  --bind <addr>         Bind address (default 0.0.0.0)
        \\  --port <port>         Bind port (default 5555)
        \\  --lean-url <url>      LeanEthereum base URL
        \\  --lean-path <path>    LeanEthereum path (default /status)
        \\  --poll-ms <ms>        Poll interval in milliseconds
        \\  --timeout-ms <ms>     Request timeout in milliseconds
        \\  --stale-ms <ms>       Stale threshold in milliseconds
        \\  --static-dir <dir>    Optional static frontend directory
        \\  --help                Show this help
        \\
        \\Env vars:
        \\  LEANPOINT_BIND_ADDR, LEANPOINT_BIND_PORT, LEANPOINT_LEAN_URL,
        \\  LEANPOINT_LEAN_PATH, LEANPOINT_POLL_MS, LEANPOINT_TIMEOUT_MS,
        \\  LEANPOINT_STALE_MS, LEANPOINT_STATIC_DIR
        \\
    , .{});
}
