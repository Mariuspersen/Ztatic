const std = @import("std");
const tls = @import("tls");
const Logger = @import("logger.zig");
const config = @import("config.zon");

const sendResponse = @import("switch.zig").sendResponse;
const hash = @import("hash.zig").hash;
const bundle = @import("hash.zig").addCertsFromSlice;

const comptime_auth = @import("comptime_auth.zig");

const linux = std.os.linux;
const posix = std.posix;
const RespondOptions = std.http.Server.Request.RespondOptions;
const Connection = std.net.Server.Connection;
const Address = std.net.Address;

fn genToken(addr: []const u8) ![32]u8 {
    var sha = std.crypto.hash.sha3.Sha3_256.init(.{});
    sha.update(addr);
    var final: [32]u8 = undefined;
    sha.final(&final);
    return final;
}

const address = Address.parseIp4(
    config.ip,
    config.port,
) catch |err| @compileError(err);

const options = Address.ListenOptions{
    .reuse_address = true,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var server = try address.listen(options);
    defer server.deinit();

    var logger = try Logger.init();
    defer logger.deinit();

    var dir = std.fs.cwd().openDir("src/certs", .{}) catch |e| {
        logger.print_error(e);
        return e;
    };
    defer dir.close();

    var auth = comptime_auth.init(
        alloc,
        @embedFile("certs/localhost_ec/cert.pem"),
        @embedFile("certs/localhost_ec/key.pem"),
    ) catch |e| {
        logger.print_error(e);
        return e;
    };
    defer auth.deinit(alloc);

    logger.println("Listening at http://{s}:{d}", .{ config.ip, config.port });

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

        var address_buf: [1024]u8 = undefined;
        var address_writer = std.io.Writer.fixed(&address_buf);
        connection.address.format(&address_writer) catch |e| {
            logger.print_error(e);
            continue;
        };
        const index = std.mem.lastIndexOf(u8, &address_buf, ":") orelse {
            logger.print_error(error.AddressNotHaveAColon);
            continue;
        };
        const address_str = address_buf[0..index];

        var it = std.mem.splitAny(u8, request.head.target, "?");
        const path = it.next() orelse request.head.target;

        const hashid = hash(path);
        const result = sendResponse(hashid, &request);

        result catch |e| {
            logger.print_error(e);
            continue;
        };

        logger.println("{d}: {s} => {s}", .{
            std.time.timestamp(), path, address_str,
        });
    }
}
