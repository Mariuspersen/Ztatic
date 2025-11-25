const std = @import("std");
const config = @import("src/config.zon");

pub fn build(b: *std.Build) void {
    std.fs.cwd().deleteFile(config.switch_path) catch {};
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_opts = .{ .target = target, .optimize = optimize };
    const tls_module = b.dependency("tls", dep_opts).module("tls");

    const hash_mod = b.createModule(.{
        .root_source_file = b.path("src/hash.zig"),
        .target = target,
    });

    const switchgen = b.addExecutable(.{
        .name = "switch_gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_switch.zig"),
            .target = b.graph.host,
        }),
    });

    switchgen.root_module.addAnonymousImport("config", .{
        .root_source_file = b.path("src/config.zon"),
    });
    switchgen.root_module.addImport("hash", hash_mod);

    var runs = std.ArrayList(?*std.Build.Step.Run).initCapacity(b.allocator, config.websites.len) catch @panic("OOM");
    runs.deinit(b.allocator);

    inline for (config.websites) |website| {
        const run = if (std.fs.cwd().access("src/" ++ website.repo, .{})) null else |_| b.addSystemCommand(&.{
            "git",
            "clone",
            "--recurse-submodules",
            website.repo,
            "src/" ++ website.repo,
        });
        runs.appendAssumeCapacity(run);
    }

    const git = if (std.fs.cwd().access("src/assets", .{})) null else |_| b.addSystemCommand(&.{
        "git",
        "clone",
        "--recurse-submodules",
        config.websites[0].repo,
        "src/assets",
    });

    const switchgen_step = b.addRunArtifact(switchgen);
    for (runs.items) |run| if(run) |r| {
        switchgen_step.step.dependOn(&r.step);
    };
    if (git) |g| {
        switchgen_step.step.dependOn(&g.step);
    }

    const slash_idx = if (std.mem.lastIndexOf(u8, config.websites[0].repo, "/")) |i| i + 1 else 0;

    const exe = b.addExecutable(.{
        .name = config.websites[0].repo[slash_idx..],
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });
    exe.root_module.addImport("tls", tls_module);
    exe.step.dependOn(&switchgen_step.step);

    const fmt_run = b.addFmt(.{ .paths = &.{config.switch_path} });
    fmt_run.step.dependOn(&switchgen_step.step);
    b.getInstallStep().dependOn(&fmt_run.step);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const clean_step = b.step("clean", "Clean up logfiles");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(config.log_folder_name)).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}
