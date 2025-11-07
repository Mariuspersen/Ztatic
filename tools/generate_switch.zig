const std = @import("std");

const hash = @import("hash").hash;

pub fn main() !void {
    defer std.process.cleanExit();
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const file = try std.fs.cwd().createFile("src/switch.zig", .{});
    defer file.close();
    var buf: [1024]u8 = undefined;
    var w= file.writer(&buf);
    const writer = &w.interface;

    try writer.writeAll(
        \\const std = @import("std");
        \\const hash = @import("hash.zig").hash;
    );

    try writer.writeAll(\\
    \\pub fn sendResponse(hashid: u64, req: *std.http.Server.Request) !void {
    \\return switch(hashid) {
    \\
    );

    var dir = try std.fs.cwd().openDir("src/assets", .{.iterate = true});
    var walker = try dir.walk(std.heap.page_allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .directory) continue;
        const extension = std.fs.path.extension(entry.path);

        const name = try std.heap.page_allocator.alloc(u8, std.mem.replacementSize(u8, entry.path, "\\", "/"));
        defer std.heap.page_allocator.free(name);
        _ = std.mem.replace(u8, entry.path, "\\", "/", name);

        if (std.mem.indexOf(u8, name, ".git")) |_| continue;

        const hashed_ext = hash(extension);
        const hashed_name = hash(name);
        switch (hashed_name) {
            hash("404.html"), hash("index.html") => continue,
            else => {} 
        }

        const extra_header = switch (hashed_ext) {
            hash(".js") => 
            \\.extra_headers = &.{
            \\.{ .name = "Content-Type", .value = "application/javascript" },
            \\},
            \\
            ,
            hash(".svg") => 
            \\.extra_headers = &.{
            \\.{ .name = "Content-Type", .value = "image/svg+xml" },
            \\},
            \\
            ,
            hash(".ico") => 
            \\.extra_headers = &.{
            \\.{ .name = "Content-Type", .value = "image/ico" },
            \\},
            \\
            ,
            hash(".png") => 
            \\.extra_headers = &.{
            \\.{ .name = "Content-Type", .value = "image/png" },
            \\},
            \\
            ,
            else => "",
        };
        try writer.print(
        \\hash("/{s}") => req.respond(
        \\@embedFile("assets/{s}"),
        \\.{{{s}}},
        \\),
        \\
        , .{name, name, extra_header});
    }
    try writer.writeAll(
        \\hash("/") => req.respond(
        \\@embedFile("assets/index.html"),
        \\.{},
        \\),
        \\else => req.respond(
        \\@embedFile("assets/404.html"),
        \\.{ .status = .not_found },
        \\),
        \\};
        \\}
    );
    
    try writer.flush();
}