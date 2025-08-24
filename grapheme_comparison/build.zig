const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zg dependency
    const zg_dep = b.dependency("zg", .{
        // .cjk = false, // Enable CJK support for better testing
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "grapheme_example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import zg modules
    exe.root_module.addImport("code_point", zg_dep.module("code_point"));
    exe.root_module.addImport("Graphemes", zg_dep.module("Graphemes"));
    exe.root_module.addImport("DisplayWidth", zg_dep.module("DisplayWidth"));

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
