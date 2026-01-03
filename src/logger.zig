const std = @import("std");
const Config = @import("config");
const Writer = std.io.Writer;
const File = std.fs.File;

const builtin = @import("builtin");
const native_os = builtin.target.os.tag;
pub const newline_windows = "\r\n";
pub const newline_posix = "\n";
pub const newline = switch (native_os) {
    .windows, .uefi => newline_windows,
    else => newline_posix,
};

const Self = @This();
const Settings = Config.settings;

logfile: File,
logfile_buf: []u8,
logfile_writer: File.Writer,
stdout: File,
stdout_buf: []u8,
stdout_writer: File.Writer,
stderr: File,
stderr_buf: []u8,
stderr_writer: File.Writer,

pub fn init(alloc: std.mem.Allocator) !Self {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    const basename = std.fs.path.basename(args[0]);

    var name_writer = std.Io.Writer.Allocating.init(alloc);
    defer name_writer.deinit();

    try name_writer.writer.print("{s}{s}{d}-{s}.log", .{
        Settings.log_folder_name,
        std.fs.path.sep_str,
        std.time.timestamp(),
        basename,
    });
    try name_writer.writer.flush();

    std.fs.cwd().makeDir(Settings.log_folder_name) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    const logfile = try std.fs.cwd().createFile(name_writer.written(), .{});
    const logfile_buf = try alloc.alloc(u8, 1024);
    const logfile_writer = logfile.writer(logfile_buf);

    const stdout = File.stdout();
    const stdout_buf = try alloc.alloc(u8, 1024);
    const stdout_writer = stdout.writer(stdout_buf);

    const stderr = File.stderr();
    const stderr_buf = try alloc.alloc(u8, 1024);
    const stderr_writer = stderr.writer(stderr_buf);

    return .{
        .logfile = logfile,
        .logfile_buf = logfile_buf,
        .logfile_writer = logfile_writer,
        .stdout = stdout,
        .stdout_buf = stdout_buf,
        .stdout_writer = stdout_writer,
        .stderr = stderr,
        .stderr_buf = stderr_buf,
        .stderr_writer = stderr_writer,
    };
}

pub fn print_error(self: *Self, err: anyerror) !void {
    const writers = [_]*Writer{
        &self.logfile_writer.interface,
        &self.stderr_writer.interface,
    };

    const ts = std.time.timestamp();
    const en = @errorName(err);
    const fmt = "{d}: ERROR: {s}" ++ newline;
    const args = .{ ts, en };

    try self.print_to_writer_slice(&writers, fmt, args);
    try self.flush_writers(&writers);
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    const writers = [_]*Writer{
        &self.logfile_writer.interface,
        &self.stdout_writer.interface,
    };
    try self.print_to_writer_slice(&writers, fmt, args);
}

pub fn println(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    try self.print(fmt ++ newline, args);
}

fn print_to_writer_slice(_: *Self, writers: []const *Writer, comptime fmt: []const u8, args: anytype) !void {
    for (writers) |writer| {
        try writer.print(fmt, args);
    }
}

pub fn flush(self: *Self) !void {
    const writers = [_]*Writer{
        &self.logfile_writer.interface,
        &self.stdout_writer.interface,
    };
    try self.flush_writers(&writers);
}

fn flush_writers(_: *Self, writers: []const *Writer) !void {
    for (writers) |writer| try writer.flush();
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.logfile_buf);
    alloc.free(self.stdout_buf);
    alloc.free(self.stderr_buf);
    self.logfile.close();
}
