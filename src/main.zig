const std = @import("std");
const tls = @import("tls");
const Logger = @import("logger.zig");
const Config = @import("config");
const ComptimeAuth = @import("comptime_auth.zig");
const SwitchCodeGen = @import("switch.zig");
const Hash = @import("hash");

const sendResponse = SwitchCodeGen.sendResponse;
const hash = Hash.hash;

const linux = std.os.linux;
const posix = std.posix;
const RespondOptions = std.http.Server.Request.RespondOptions;
const Connection = std.net.Server.Connection;
const Address = std.net.Address;

const Settings = Config.settings;

const address = Address.parseIp4(
    Settings.ip,
    Settings.port,
) catch |err| @compileError(err);

const options = Address.ListenOptions{
    .reuse_address = true,
};

pub fn main() !void {
    var alloc_buf: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buf);
    const alloc = fba.allocator();

    var server = try address.listen(options);
    defer server.deinit();

    var logger = try Logger.init(alloc);
    defer logger.deinit(alloc);

    var auth = try ComptimeAuth.init(
        alloc,
        @embedFile("certs/cert.pem"),
        @embedFile("certs/key.pem"),
    );
    defer auth.deinit(alloc);

    logger.println("Listening at https://{s}:{d}", .{ Settings.ip, Settings.port });
    logger.flush();

    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();

        var upgraded = try tls.serverFromStream(
            connection.stream,
            .{
                .auth = &auth,
            },
        );

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
        var address_writer = std.io.Writer.fixed(&address_buf);
        try connection.address.format(&address_writer);
        const index = std.mem.lastIndexOf(u8, &address_buf, ":") orelse return error.AddressNotHaveAColon;
        const address_str = address_buf[0..index];

        try SwitchCodeGen.sendResponse(hashed_path, &request);
        try upgraded.close();

        logger.println("{d}: {s} => {s}", .{
            std.time.timestamp(),
            path,
            address_str,
        });
        logger.flush();
    }
}
