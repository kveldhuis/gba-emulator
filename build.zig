const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gba-emu",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize, .link_libc = true }),
    });

    exe.root_module.linkSystemLibrary("SDL3", .{ .preferred_link_mode = .dynamic });

    b.installArtifact(exe);

    // Dit maakt "zig build run" mogelijk
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the emulator");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_test = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_test.step);
}
