// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// STATISTIKLES Integration Tests
//
// These tests exercise the Zig FFI through the SAME `Handle`/`Result` types the
// implementation exports — imported from the root module (`build.zig` wires
// `src/main.zig` in as the `statistikles` module) rather than re-declared here,
// so the tests and the library can never drift out of sync on the ABI.

const std = @import("std");
const testing = std.testing;

const sk = @import("statistikles");
const Handle = sk.Handle;
const Result = sk.Result;

//==============================================================================
// Lifecycle Tests
//==============================================================================

test "create and destroy handle" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    try testing.expect(@intFromPtr(handle) != 0);
}

test "handle is initialized" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    const initialized = sk.statistikles_is_initialized(handle);
    try testing.expectEqual(@as(u32, 1), initialized);
}

test "null handle is not initialized" {
    const initialized = sk.statistikles_is_initialized(null);
    try testing.expectEqual(@as(u32, 0), initialized);
}

//==============================================================================
// Operation Tests
//==============================================================================

test "process with valid handle" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    try testing.expectEqual(Result.ok, sk.statistikles_process(handle, 42));
}

test "process with null handle returns error" {
    try testing.expectEqual(Result.null_pointer, sk.statistikles_process(null, 42));
}

//==============================================================================
// String Tests
//==============================================================================

test "get string result" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    const str = sk.statistikles_get_string(handle);
    defer if (str) |s| sk.statistikles_free_string(s);

    try testing.expect(str != null);
}

test "get string with null handle" {
    const str = sk.statistikles_get_string(null);
    try testing.expect(str == null);
}

//==============================================================================
// Error Handling Tests
//==============================================================================

test "last error after null handle operation" {
    _ = sk.statistikles_process(null, 0);

    const err = sk.statistikles_last_error();
    try testing.expect(err != null);

    if (err) |e| {
        const err_str = std.mem.span(e);
        try testing.expect(err_str.len > 0);
    }
}

test "no error after successful operation" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    try testing.expectEqual(Result.ok, sk.statistikles_process(handle, 0));

    // A successful operation clears the last error.
    try testing.expect(sk.statistikles_last_error() == null);
}

//==============================================================================
// Version Tests
//==============================================================================

test "version string is not empty" {
    const ver = sk.statistikles_version();
    const ver_str = std.mem.span(ver);

    try testing.expect(ver_str.len > 0);
}

test "version string is semantic version format" {
    const ver = sk.statistikles_version();
    const ver_str = std.mem.span(ver);

    // Should be in format X.Y.Z
    try testing.expect(std.mem.count(u8, ver_str, ".") >= 1);
}

test "abi version is monotonic and nonzero" {
    try testing.expect(sk.statistikles_abi_version() >= 1);
}

//==============================================================================
// Memory Safety Tests
//==============================================================================

test "multiple handles are independent" {
    const h1 = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(h1);

    const h2 = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(h2);

    try testing.expect(h1 != h2);

    // Operations on h1 should not affect h2.
    try testing.expectEqual(Result.ok, sk.statistikles_process(h1, 1));
    try testing.expectEqual(Result.ok, sk.statistikles_process(h2, 2));
}

test "double free is a safe error, not UB" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;

    // First free succeeds.
    try testing.expectEqual(Result.ok, sk.statistikles_free(handle));
    // Second free on the same (now dangling) pointer must be rejected with an
    // error code — a safe no-op, not a second destroy() / undefined behaviour.
    try testing.expectEqual(Result.invalid_param, sk.statistikles_free(handle));
}

test "operations on a freed handle are rejected" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    try testing.expectEqual(Result.ok, sk.statistikles_free(handle));

    try testing.expectEqual(Result.invalid_param, sk.statistikles_process(handle, 0));
    try testing.expectEqual(@as(u32, 0), sk.statistikles_is_initialized(handle));
}

test "free null is a safe no-op" {
    // Must not crash; reported as null_pointer, never a destroy().
    try testing.expectEqual(Result.null_pointer, sk.statistikles_free(null));
}

//==============================================================================
// Thread Safety Tests
//==============================================================================

test "concurrent operations" {
    const handle = sk.statistikles_init() orelse return error.InitFailed;
    defer _ = sk.statistikles_free(handle);

    const ThreadContext = struct {
        h: *Handle,
        id: u32,
    };

    const thread_fn = struct {
        fn run(ctx: ThreadContext) void {
            _ = sk.statistikles_process(ctx.h, ctx.id);
        }
    }.run;

    var threads: [4]std.Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, thread_fn, .{
            ThreadContext{ .h = handle, .id = @intCast(i) },
        });
    }

    for (threads) |thread| {
        thread.join();
    }
}
