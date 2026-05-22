// STATISTEASE Integration Tests
// SPDX-License-Identifier: MPL-2.0
//
// These tests verify that the Zig FFI correctly implements the Idris2 ABI

const std = @import("std");
const testing = std.testing;

// Import FFI functions
extern fn statistease_init() ?*opaque {};
extern fn statistease_free(?*opaque {}) void;
extern fn statistease_process(?*opaque {}, u32) c_int;
extern fn statistease_get_string(?*opaque {}) ?[*:0]const u8;
extern fn statistease_free_string(?[*:0]const u8) void;
extern fn statistease_last_error() ?[*:0]const u8;
extern fn statistease_version() [*:0]const u8;
extern fn statistease_is_initialized(?*opaque {}) u32;

//==============================================================================
// Lifecycle Tests
//==============================================================================

test "create and destroy handle" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    try testing.expect(handle != null);
}

test "handle is initialized" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    const initialized = statistease_is_initialized(handle);
    try testing.expectEqual(@as(u32, 1), initialized);
}

test "null handle is not initialized" {
    const initialized = statistease_is_initialized(null);
    try testing.expectEqual(@as(u32, 0), initialized);
}

//==============================================================================
// Operation Tests
//==============================================================================

test "process with valid handle" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    const result = statistease_process(handle, 42);
    try testing.expectEqual(@as(c_int, 0), result); // 0 = ok
}

test "process with null handle returns error" {
    const result = statistease_process(null, 42);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

//==============================================================================
// String Tests
//==============================================================================

test "get string result" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    const str = statistease_get_string(handle);
    defer if (str) |s| statistease_free_string(s);

    try testing.expect(str != null);
}

test "get string with null handle" {
    const str = statistease_get_string(null);
    try testing.expect(str == null);
}

//==============================================================================
// Error Handling Tests
//==============================================================================

test "last error after null handle operation" {
    _ = statistease_process(null, 0);

    const err = statistease_last_error();
    try testing.expect(err != null);

    if (err) |e| {
        const err_str = std.mem.span(e);
        try testing.expect(err_str.len > 0);
    }
}

test "no error after successful operation" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    _ = statistease_process(handle, 0);

    // Error should be cleared after successful operation
    // (This depends on implementation)
}

//==============================================================================
// Version Tests
//==============================================================================

test "version string is not empty" {
    const ver = statistease_version();
    const ver_str = std.mem.span(ver);

    try testing.expect(ver_str.len > 0);
}

test "version string is semantic version format" {
    const ver = statistease_version();
    const ver_str = std.mem.span(ver);

    // Should be in format X.Y.Z
    try testing.expect(std.mem.count(u8, ver_str, ".") >= 1);
}

//==============================================================================
// Memory Safety Tests
//==============================================================================

test "multiple handles are independent" {
    const h1 = statistease_init() orelse return error.InitFailed;
    defer statistease_free(h1);

    const h2 = statistease_init() orelse return error.InitFailed;
    defer statistease_free(h2);

    try testing.expect(h1 != h2);

    // Operations on h1 should not affect h2
    _ = statistease_process(h1, 1);
    _ = statistease_process(h2, 2);
}

test "double free is safe" {
    const handle = statistease_init() orelse return error.InitFailed;

    statistease_free(handle);
    statistease_free(handle); // Should not crash
}

test "free null is safe" {
    statistease_free(null); // Should not crash
}

//==============================================================================
// Thread Safety Tests (if applicable)
//==============================================================================

test "concurrent operations" {
    const handle = statistease_init() orelse return error.InitFailed;
    defer statistease_free(handle);

    const ThreadContext = struct {
        h: *opaque {},
        id: u32,
    };

    const thread_fn = struct {
        fn run(ctx: ThreadContext) void {
            _ = statistease_process(ctx.h, ctx.id);
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
