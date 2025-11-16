const std = @import("std");
const tls = @import("tls");
const Logger = @import("logger.zig");
const Config = @import("config.zon");
const ComptimeAuth = @import("comptime_auth.zig");
const SwitchCodeGen = @import("switch.zig");
const Hash = @import("hash.zig");

const sendResponse = SwitchCodeGen.sendResponse;
const hash = Hash.hash;

const linux = std.os.linux;
const posix = std.posix;
const RespondOptions = std.http.Server.Request.RespondOptions;
const Connection = std.net.Server.Connection;
const Address = std.net.Address;

const address = Address.parseIp4(
    Config.ip,
    Config.port,
) catch |err| @compileError(err);

const options = Address.ListenOptions{
    .reuse_address = true,
    .kernel_backlog = 1,
};

pub fn main() !void {
    var alloc_buf: [16 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buf);
    const alloc = fba.allocator();

    var server = try address.listen(options);
    defer server.deinit();

    var logger = try Logger.init();
    defer logger.deinit();

    var auth = ComptimeAuth.init(
        alloc,
        @embedFile("certs/cert.pem"),
        @embedFile("certs/key.pem"),
    ) catch |e| {
        logger.print_error(e);
        return e;
    };
    defer auth.deinit(alloc);

    logger.println("Listening at https://{s}:{d}", .{ Config.ip, Config.port });
    logger.flush();

    while (true) {
        const connection = server.accept() catch |e| {
            logger.print_error(e);
            continue;
        };
        defer connection.stream.close();

        var upgraded = tls.serverFromStream(
            connection.stream,
            .{
                .auth = &auth,
            },
        ) catch |e| {
            logger.print_error(e);
            continue;
        };
        defer upgraded.close() catch |e| {
            logger.print_error(e);
        };

        var https_reader_buf: [16 * 1024]u8 = undefined;
        var https_writer_buf: [16 * 1024]u8 = undefined;
        var https_reader = upgraded.reader(&https_reader_buf);
        var https_writer = upgraded.writer(&https_writer_buf);

        var https_server = std.http.Server.init(
            &https_reader.interface,
            &https_writer.interface,
        );

        var request = https_server.receiveHead() catch |e| {
            logger.print_error(e);
            continue;
        };

        var it = std.mem.splitAny(u8, request.head.target, "?");
        const path = it.next() orelse request.head.target;

        logger.print("{d}: {s} => ", .{ std.time.timestamp(), path });
        connection.address.format(&logger.stdout_writer.interface) catch {};
        connection.address.format(&logger.filewriter.interface) catch {};
        logger.println("", .{});
        logger.flush();

        const hashid = hash(path);
        sendResponse(hashid, &request) catch |e| {
            logger.print_error(e);
            continue;
        };
    }
}
