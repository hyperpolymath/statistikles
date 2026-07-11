// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// STATISTIKLES FFI Build Configuration
//
// Built and CI-checked against Zig 0.13.0.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library (.so, .dylib, .dll). The version must be passed here so the
    // versioned-filename fields are computed at creation time (setting
    // `lib.version` afterwards leaves them null and crashes installArtifact).
    const lib = b.addSharedLibrary(.{
        .name = "statistikles",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    // The FFI uses std.heap.c_allocator (malloc/free) so it interops with C
    // consumers and `statistikles_free_string`; that requires libc.
    lib.linkLibC();

    // Static library (.a)
    const lib_static = b.addStaticLibrary(.{
        .name = "statistikles",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_static.linkLibC();

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(lib_static);

    // Unit tests (main.zig's own test blocks)
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_tests.linkLibC();

    const run_lib_tests = b.addRunArtifact(lib_tests);

    // Integration tests. Import src/main.zig as the `statistikles` module so the
    // tests exercise the SAME Handle/Result types the library exports (one
    // shared definition, no re-declared opaque types that can drift).
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.root_module.addAnonymousImport("statistikles", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.linkLibC();

    const run_integration_tests = b.addRunArtifact(integration_tests);

    // `zig build test` runs BOTH the unit and integration tests.
    const test_step = b.step("test", "Run library + integration tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    // Keep a dedicated integration-only step for convenience.
    const integration_test_step = b.step("test-integration", "Run integration tests only");
    integration_test_step.dependOn(&run_integration_tests.step);

    // Documentation
    const docs = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    docs.linkLibC();

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);
}
