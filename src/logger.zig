const std = @import("std");
const config = @import("config.zon");
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

var filewriter_buf: [1024]u8 = undefined;

logfile: std.fs.File,
writer: std.fs.File.Writer,

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

    const file = try std.fs.cwd().createFile(name_buf[0..name_writer.end], .{});
    const writer = file.writer(&filewriter_buf);

    return .{
        .logfile = file,
        .writer = writer,
    };
}

pub fn print_error(self: *Self, err: anyerror) void {
    var stderr_buf: [1024]u8 = undefined;
    var stderr = File.stdout().writer(&stderr_buf);
    const writers = [_]*Writer{&self.writer.interface, &stderr.interface};

    const ts = std.time.timestamp();
    const en = @errorName(err);
    const fmt = "{d}: ERROR: {s}" ++ newline;
    const args = .{ ts, en };
    
    self.print_to_writer_slice(&writers, fmt, args);
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout = File.stdout().writer(&stdout_buf);
    const writers = [_]*Writer{&self.writer.interface, &stdout.interface};
    self.print_to_writer_slice(&writers, fmt, args);
}

pub fn println(self: *Self, comptime fmt: []const u8, args: anytype) void {
    self.print(fmt ++ newline, args);
}

fn print_to_writer_slice(_: *Self, writers: []const *Writer, comptime fmt: []const u8, args: anytype) void {
    for (writers) |writer| {
        writer.print(fmt,args) catch {};
        writer.flush() catch {};
    }
}

pub fn deinit(self: *Self) void {
    self.logfile.close();
}
