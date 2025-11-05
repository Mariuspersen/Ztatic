const std = @import("std");
const Logger = @import("logger.zig");
const config = @import("config.zon");

const linux = std.os.linux;
const posix = std.posix;
const RespondOptions = std.http.Server.Request.RespondOptions;
const Connection = std.net.Server.Connection;
const Address = std.net.Address;

fn hash(bytes: []const u8) u64 {
    var final: u64 = 0;
    for (bytes, 1..) |b, i| {
        const mul = @mulWithOverflow(b, i)[0];
        const res = @addWithOverflow(final, mul)[0];
        final = res;
    }
    return final;
}

fn genToken(addr: []const u8) ![32]u8 {
    var sha = std.crypto.hash.sha3.Sha3_256.init(.{});
    sha.update(addr);
    var final: [32]u8 = undefined;
    sha.final(&final);
    return final;
}

test "Generate Tokens" {
    genToken(address);
}

const address = Address.parseIp4(
    config.ip,
    config.port,
) catch |err| @compileError(err);

const options = Address.ListenOptions{
    .reuse_address = true,
};

pub fn main() !void {
    var server = try address.listen(options);
    defer server.deinit();

    var logger = try Logger.init();
    defer logger.deinit();

    logger.println("Listening at http://{s}:{d}", .{ config.ip, config.port });

    while (true) {
        const connection = server.accept() catch |e| {
            logger.print_error(e);
            continue;
        };
        defer connection.stream.close();

        var stream_reader_buf: [1024]u8 = undefined;
        var stream_writer_buf: [1024]u8 = undefined;

        var stream_reader = connection.stream.reader(&stream_reader_buf);
        var stream_writer = connection.stream.writer(&stream_writer_buf);

        var http_server = std.http.Server.init(
            stream_reader.interface(),
            &stream_writer.interface,
        );
        var request = http_server.receiveHead() catch |e| {
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
        const result = switch (hashid) {
            hash("/") => request.respond(
                @embedFile("assets/index.html"),
                .{
                    .extra_headers = &.{
                        .{ .name = "Token", .value = &try genToken(address_str) },
                    },
                },
            ),
            hash("/style.css") => request.respond(
                @embedFile("assets/style.css"),
                .{},
            ),
            hash("/script.js") => request.respond(
                @embedFile("assets/script.js"),
                .{
                    .extra_headers = &.{
                        .{ .name = "Content-Type", .value = "application/javascript" },
                    },
                },
            ),
            hash("/email_icon.svg") => request.respond(
                @embedFile("assets/email_icon.svg"),
                .{
                    .extra_headers = &.{
                        .{ .name = "Content-Type", .value = "image/svg+xml" },
                    },
                },
            ),
            hash("/favicon.ico") => request.respond(
                @embedFile("assets/favicon.ico"),
                .{
                    .extra_headers = &.{
                        .{ .name = "Content-Type", .value = "image/ico+xml" },
                    },
                },
            ),
            else => request.respond(
                @embedFile("assets/404.html"),
                .{ .status = .not_found },
            ),
        };

        result catch |e| {
            logger.print_error(e);
            continue;
        };

        logger.println("{d}: {s} => {s}", .{
            std.time.timestamp(), path, address_str,
        });
    }
}
