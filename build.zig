const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "templateEngineTest",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const ParserTest = b.addTest(.{
        .root_source_file = b.path("src/template.zig"),
        .error_tracing = true,
        .target = target,
        .optimize = optimize,
    });
    const utilsTest = b.addTest(.{
        .root_source_file = b.path("src/httpUtils.zig"),
        .error_tracing = true,
        .target = target,
        .optimize = optimize,
    });

    const r_parserTest = b.addRunArtifact(ParserTest);
    const r_utilsTest = b.addRunArtifact(utilsTest);

    const test_step = b.step("test", "run tests");

    test_step.dependOn(&r_parserTest.step);
    test_step.dependOn(&r_utilsTest.step);
}
