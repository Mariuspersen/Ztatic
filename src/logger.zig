const std = @import("std");
const config = @import("config.zon");

const Self = @This();

stdout: *std.Io.Writer = undefined,
stdout_buf: [1024]u8 = undefined,
stdout_writer: std.fs.File.Writer = undefined,
stderr: *std.Io.Writer = undefined,
stderr_writer: std.fs.File.Writer = undefined,
stderr_buf: [1024]u8 = undefined,
logger: *std.Io.Writer = undefined,
logfile: std.fs.File,
logfile_writer: std.fs.File.Writer = undefined,
logfile_writer_buf: [1024]u8 = undefined,

pub fn init() !Self {
    var name_buf: [1024]u8 = undefined;
    var name_writer = std.Io.Writer.fixed(&name_buf);
    try name_writer.print("{s}{s}{d}-{s}.log", .{
        config.log_folder_name,
        std.fs.path.sep_str,
        std.time.timestamp(),
        config.executable_name,
    });
    try name_writer.flush();

    std.fs.cwd().makeDir(config.log_folder_name) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    var self: Self = .{
        .logfile = try std.fs.cwd().createFile(name_buf[0..name_writer.end], .{}),
    };
    self.stdout_writer = std.fs.File.stdout().writer(&self.stdout_buf);
    self.stderr_writer = std.fs.File.stdout().writer(&self.stderr_buf);
    self.stdout = &self.stdout_writer.interface;
    self.stderr = &self.stderr_writer.interface;
    self.logfile_writer = self.logfile.writer(&self.logfile_writer_buf);
    self.logger = &self.logfile_writer.interface;
    return self;
}

pub fn print_error(self: *Self, err: anyerror) void {
    const ts = std.time.timestamp();
    const en = @errorName(err);
    const fmt = "{d}: ERROR: {s}\n";
    const err_fmt = "{d}: ERROR: Unable to print error {s}\n";
    const args = .{ ts, en };
    self.stderr.print(fmt, args) catch {
        self.logger.print(err_fmt, args) catch {};
    };
    self.logger.print(fmt, args) catch {
        self.stderr.print(err_fmt, args) catch {};
    };
    self.flush_error() catch {};
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
    self.logger.print(fmt, args) catch |e| self.print_error(e);
    self.stdout.print(fmt, args) catch |e| self.print_error(e);
}

pub fn log_request(self: *Self, address: *const std.net.Address, path: []const u8) void {
    const ts = std.time.timestamp();
    const fmt = "{d}: {s} => ";
    const args = .{
        ts, path,
    };
    self.logger.print(fmt, args) catch |e| self.print_error(e);
    self.stdout.print(fmt, args) catch |e| self.print_error(e);
    address.format(self.logger) catch |e| self.print_error(e);
    address.format(self.stdout) catch |e| self.print_error(e);
    self.logger.writeAll(config.newline) catch |e| self.print_error(e);
    self.stdout.writeAll(config.newline) catch |e| self.print_error(e);
    self.flush();
}

fn flush_error(self: *Self) !void {
    try self.logger.flush();
    try self.stderr.flush();
}

pub fn flush(self: *Self) void {
    self.logger.flush() catch |e| self.print_error(e);
    self.stdout.flush() catch |e| self.print_error(e);
}

pub fn deinit(self: *Self) void {
    self.stdout.flush() catch {};
    self.stderr.flush() catch {};
    self.logger.flush() catch {};
    self.logfile.close();
}
