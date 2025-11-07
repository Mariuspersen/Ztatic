const std = @import("std");
const config = @import("src/config.zon");

pub fn build(b: *std.Build) void {
    std.fs.cwd().deleteFile("src/switch.zig") catch {};
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    switchgen.root_module.addImport("hash", hash_mod);

    const switchgen_step = b.addRunArtifact(switchgen);

    const exe = b.addExecutable(.{
        .name = config.executable_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
            },
        }),
    });

    exe.step.dependOn(&switchgen_step.step);

    const fmt_run = b.addFmt(.{ .paths = &.{"src/switch.zig"} });
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
}


