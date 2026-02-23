const std = @import("std");
const Config = @import("config");
const Index = @import("index");

const hash = std.hash.Crc32.hash;
const find_index = Index.slash_index;

const Settings = Config.settings;

pub fn main(init: std.process.Init) !void {
    defer std.process.cleanExit(init.io);

    std.Io.Dir.cwd().createDir(init.io, "src/website_switches/", .default_file) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    inline for (Settings.websites) |website| {
        try generate_switch(init.io, website.repo);
    }
}

fn generate_switch(io: std.Io, comptime repo: []const u8) !void {
    const slashed = comptime find_index(repo);
    const file = try std.Io.Dir.cwd().createFile(io, "src/website_switches/" ++ slashed ++ ".zig", .{});
    defer file.close(io);
    var buf: [1024]u8 = undefined;
    var w = file.writer(io, &buf);
    const writer = &w.interface;

    try writer.writeAll(
        \\const std = @import("std");
        \\const hash = std.hash.Crc32.hash;
        \\
    );

    try writer.writeAll(
        \\
        \\pub fn sendResponse(hashid: u64, req: *std.http.Server.Request) !void {
        \\@setEvalBranchQuota(100000);
        \\return switch(hashid) {
        \\
    );

    var dir = try std.Io.Dir.cwd().openDir(io, "src/assets/" ++ slashed, .{ .iterate = true });
    var walker = try dir.walk(std.heap.page_allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory) continue;
        const extension = std.fs.path.extension(entry.path);

        const name = try std.heap.page_allocator.alloc(
            u8,
            std.mem.replacementSize(u8, entry.path, "\\", "/"),
        );
        defer std.heap.page_allocator.free(name);

        _ = std.mem.replace(
            u8,
            entry.path,
            "\\",
            "/",
            name,
        );

        if (std.mem.indexOf(u8, name, ".git")) |_| continue;

        const hashed_ext = hash(extension);
        const hashed_name = hash(name);
        switch (hashed_name) {
            hash("404.html"), hash("index.html") => continue,
            else => {},
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
        if (std.mem.endsWith(u8, entry.path, ".html")) {
            const idx = std.mem.lastIndexOf(u8, name, ".");
            if (idx) |i| {
                try writer.print(
                    \\hash("/{s}"),
                , .{name[0..i]});
            }
        }
        try writer.print(
            \\hash("/{s}") => req.respond(
            \\@embedFile("../assets/{s}/{s}"),
            \\.{{{s}}},
            \\),
            \\
        , .{ name, slashed, name, extra_header });
    }
    try writer.print(
        \\hash("/") => req.respond(
        \\@embedFile("../assets/{s}/index.html"),
        \\.{{}},
        \\),
        \\else => req.respond(
        \\@embedFile("../404.html"),
        \\.{{ .status = .not_found }},
        \\),
        \\}};
        \\}}
    , .{slashed});

    try writer.flush();
}
