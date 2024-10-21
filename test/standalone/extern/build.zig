const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    if (b.graph.host.result.os.tag == .windows and b.graph.host.result.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/16959
        return;
    }

    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject(.{
        .name = "exports",
        .root_source_file = b.path("exports.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const shared = b.addSharedLibrary(.{
        .name = "shared",
        .target = b.graph.host,
        .optimize = optimize,
        .link_libc = true,
    });
    if (b.graph.host.result.abi == .msvc) shared.defineCMacro("API", "__declspec(dllexport)");
    shared.addCSourceFile(.{ .file = b.path("shared.c"), .flags = &.{} });
    const test_exe = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
    });
    test_exe.addObject(obj);
    test_exe.linkLibrary(shared);

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
