const std = @import("std");
const config = @import("config.zon");
const Writer = std.io.Writer;

const Self = @This();

logfile: std.fs.File,

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

    return .{
        .logfile = try std.fs.cwd().createFile(name_buf[0..name_writer.end], .{}),
    };
}

pub fn print_error(self: *Self, err: anyerror) void {
    const ts = std.time.timestamp();
    const en = @errorName(err);
    const fmt = "{d}: ERROR: {s}\n";
    const args = .{ ts, en };
    const writers = [_]std.fs.File{ self.logfile, std.fs.File.stderr() };
    for (writers) |f| {
        var buf: [1024]u8 = undefined;
        var w = f.writer(&buf);
        const out = &w.interface;

        out.print(fmt,args) catch {};
        out.flush() catch {};
    }
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
    const writers = [_]std.fs.File{ self.logfile, std.fs.File.stdout() };
    for (writers) |f| {
        var buf: [1024]u8 = undefined;
        var w = f.writer(&buf);
        const out = &w.interface;

        out.print(fmt,args) catch |e| self.print_error(e);
        out.flush() catch |e| self.print_error(e);
    }
}

pub fn deinit(self: *Self) void {
    self.stdout.flush() catch {};
    self.stderr.flush() catch {};
    self.logger.flush() catch {};
    self.logfile.close();
}
