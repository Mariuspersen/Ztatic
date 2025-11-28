const std = @import("std");
const Index = @import("index");

const Config = @import("config");
const find_index = Index.slash_index;

const Settings = Config.settings;

pub fn main() !void {
    defer std.process.cleanExit();
    const file = try std.fs.cwd().createFile("src/switch.zig", .{});
    defer file.close();
    var buf: [1024]u8 = undefined;
    var w = file.writer(&buf);
    const writer = &w.interface;

    try writer.writeAll(
        \\const std = @import("std");
        \\const Hash = @import("hash");
        \\const hash = Hash.hash;
        \\
    );

    inline for (Settings.websites) |website| {
        const slashed = comptime find_index(website.repo);
        try writer.print(
            \\const @"{s}" = @import("website_switches/{s}.zig");
            \\
        , .{ slashed, slashed });
    }

    try writer.writeAll(
        \\
        \\pub fn sendResponse(hashid: u64, req: *std.http.Server.Request) !void {
        \\var h_it = req.iterateHeaders();
        \\while (h_it.next()) |h| {
        \\switch (hash(h.name)) {
        \\hash("Host") => {
        \\try switch(hash(h.value)) {
        \\
    );

    inline for (Settings.websites) |website| {
        const slashed = comptime find_index(website.repo);
        inline for (website.urls) |url| {
            try writer.print(
                \\hash("{s}"),
            , .{url});
        }
        try writer.print(
            \\ => @"{s}".sendResponse(hashid,req),
        , .{slashed});
    }

    try writer.writeAll(
        \\else => req.respond(
        \\@embedFile("404.html"),
        \\    .{ .status = .not_found },
        \\),
    );

    try writer.writeAll(
        \\};
        \\},
        \\else => continue,
        \\}
    );

    try writer.writeAll(
        \\}
        \\}
        \\
    );

    try writer.flush();
}
