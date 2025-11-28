const std = @import("std");
const Config = @import("build.zig.zon");
const Index = @import("src/index.zig");

const find_index = Index.slash_index;

pub fn build(b: *std.Build) !void {
    //std.fs.cwd().deleteFile(config.switch_path) catch {};
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_opts = .{ .target = target, .optimize = optimize };
    const tls_module = b.dependency("tls", dep_opts).module("tls");

    const hash_mod = b.createModule(.{
        .root_source_file = b.path("src/hash.zig"),
        .target = target,
    });

    const index_mod = b.createModule(.{
        .root_source_file = b.path("src/index.zig"),
        .target = target,
    });

    const config = b.addModule("config", .{
        .root_source_file = b.path("build.zig.zon"),
    });

    const switchgen_website = b.addExecutable(.{
        .name = "switch_gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_website_switch.zig"),
            .target = b.graph.host,
        }),
    });

    switchgen_website.root_module.addImport("config", config);
    switchgen_website.root_module.addImport("hash", hash_mod);
    switchgen_website.root_module.addImport("index", index_mod);

    const switchgen_host = b.addExecutable(.{
        .name = "switch_gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_host_switch.zig"),
            .target = b.graph.host,
        }),
    });

    switchgen_host.root_module.addImport("config", config);
    switchgen_host.root_module.addImport("hash", hash_mod);
    switchgen_host.root_module.addImport("index", index_mod);

    var runs = std.ArrayList(?*std.Build.Step.Run).initCapacity(b.allocator, Config.settings.websites.len) catch @panic("OOM");

    inline for (Config.settings.websites) |website| {
        const slashed = comptime find_index(website.repo);
        try runs.append(b.allocator, if (std.fs.cwd().access("src/assets/" ++ slashed, .{})) null else |_| b.addSystemCommand(&.{
            "git",
            "clone",
            "--recurse-submodules",
            website.repo,
            "src/assets/" ++ slashed,
        }));
    }

    const switchgen_website_run = b.addRunArtifact(switchgen_website);
    for (runs.items) |run| if (run) |r| {
        switchgen_website_run.step.dependOn(&r.step);
    };

    const switchgen_host_run = b.addRunArtifact(switchgen_host);
    switchgen_host_run.step.dependOn(&switchgen_website_run.step);

    const exe = b.addExecutable(.{
        .name = "webserver",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });
    exe.root_module.addImport("config", config);
    exe.root_module.addImport("tls", tls_module);
    exe.root_module.addImport("hash", hash_mod);
    exe.step.dependOn(&switchgen_website_run.step);
    exe.step.dependOn(&switchgen_host_run.step);

    inline for (Config.settings.websites) |website| {
        const slashed = comptime find_index(website.repo);
        const fmt_run = b.addFmt(.{ .paths = &.{"src/website_switches/" ++ slashed ++ ".zig"} });
        fmt_run.step.dependOn(&switchgen_website_run.step);
        b.getInstallStep().dependOn(&fmt_run.step);
    }

    const fmt_run = b.addFmt(.{ .paths = &.{"src/switch.zig"} });
    fmt_run.step.dependOn(&switchgen_host_run.step);
    b.getInstallStep().dependOn(&fmt_run.step);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const clean_step = b.step("clean", "Clean up logs and generated files");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(Config.settings.log_folder_name)).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("src/website_switches")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("src/assets")).step);
}
