const std = @import("std");
const tls = @import("tls");
const Config = @import("config");
const SwitchCodeGen = @import("switch.zig");

const Io = std.Io;
const net = Io.net;
const EpochSeconds = std.time.epoch.EpochSeconds;

const sendResponse = SwitchCodeGen.sendResponse;
pub const hash = std.hash.Crc32.hash;

const Settings = Config.settings;

const address = net.IpAddress.parseIp4(
    Settings.ip,
    Settings.port,
) catch |err| @compileError(err);

const options = net.IpAddress.ListenOptions{
    .reuse_address = true,
};

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.smp_allocator;

    var threaded = std.Io.Threaded.init(
        alloc,
        .{ .environ = init.minimal.environ },
    );
    defer threaded.deinit();
    const io = threaded.io();
    var group = std.Io.Group.init;
    defer group.cancel(io);

    var server = try address.listen(io, options);
    defer server.deinit(io);

    var auth = try tls.config.CertKeyPair.fromSlice(
        alloc,
        io,
        @embedFile("certs/cert.pem"),
        @embedFile("certs/key.pem"),
    );
    defer auth.deinit(alloc);

    const stdout_buf = try alloc.alloc(u8, 1024);
    defer alloc.free(stdout_buf);
    var stdout_writer = Io.File.stdout().writer(io, stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("Listening at https://{s}:{d}\n", .{ Settings.ip, Settings.port });
    try stdout.flush();

    while (server.accept(io)) |s| {
        try group.concurrent(io, handleWithTimeout, .{ io, s, stdout, &auth });
    } else |e| {
        var stderr_buf: [1024]u8 = undefined;
        if (io.lockStderr(&stderr_buf, null)) |lstderr| {
            lstderr.file_writer.interface.print(
                "ERROR: When accepting connection -> {any}\n",
                .{e},
            ) catch {};
        } else |_| {}
    }
}

fn handleWithTimeout(
    io: Io,
    s: net.Stream,
    w: *Io.Writer,
    auth: *tls.config.CertKeyPair,
) void {
    var timeout = io.concurrent(
        Io.sleep,
        .{ io, .fromSeconds(5), .real },
    ) catch |e| {
        printError(io, e);
        return;
    };
    var conn = io.concurrent(
        handleConnection,
        .{ io, s, w, auth },
    ) catch |e| {
        printError(io, e);
        return;
    };
    _ = io.select(.{ &timeout, &conn }) catch |e| {
        printError(io, e);
        return;
    };
}

fn handleConnection(
    io: Io,
    s: net.Stream,
    w: *Io.Writer,
    auth: *tls.config.CertKeyPair,
) !void {
    defer s.close(io);
    const rand = std.Random.IoSource{ .io = io };
    const ts = try std.Io.Clock.real.now(io);
    var upgraded = try tls.serverFromStream(
        io,
        s,
        .{
            .auth = auth,
            .now = ts,
            .rng = rand.interface(),
        },
    );
    defer upgraded.close() catch |e| printError(io, e);

    var https_reader_buf: [16 * 1024]u8 = undefined;
    var https_writer_buf: [16 * 1024]u8 = undefined;
    var https_reader = upgraded.reader(&https_reader_buf);
    var https_writer = upgraded.writer(&https_writer_buf);

    var https_server = std.http.Server.init(
        &https_reader.interface,
        &https_writer.interface,
    );

    var request = try https_server.receiveHead();

    var it = std.mem.splitAny(u8, request.head.target, "?");
    const path = it.next() orelse request.head.target;
    const hashed_path = hash(path);

    var address_buf: [1024]u8 = undefined;
    var address_writer = std.Io.Writer.fixed(&address_buf);
    try s.socket.address.format(&address_writer);
    const index = std.mem.lastIndexOf(u8, &address_buf, ":") orelse return error.AddressNotHaveAColon;
    const address_str = address_buf[0..index];

    try SwitchCodeGen.sendResponse(hashed_path, &request);

    try printDateTime(ts, w);
    try w.print(": {s} => {s}\n", .{
        path,
        address_str,
    });
    try w.flush();
}

fn printError(io: Io, e: anyerror) void {
    var buffer: [64]u8 = undefined;
    var lstderr = io.lockStderr(&buffer, null) catch return;
    lstderr.file_writer.interface.print("ERROR: {any}\n", .{e}) catch return;
}

fn printDateTime(ts: Io.Timestamp, w: *Io.Writer) !void {
    const es = EpochSeconds{ .secs = @intCast(ts.toSeconds()) };
    const ed = es.getEpochDay();
    const yd = ed.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    try w.print("{d:02}:{d:02}:{d:02} - {d:02} {s} {d:04}", .{
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
        md.day_index,
        @tagName(md.month),
        yd.year,
    });
}