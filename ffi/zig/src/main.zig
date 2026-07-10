// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// STATISTIKLES FFI Implementation
//
// This module defines the C-compatible FFI surface for statistikles.
//
// STATUS — EXPERIMENTAL: this FFI locks the C ABI and is CI-checked so it
// cannot silently break, but the exported operations are PLACEHOLDERS. They
// validate their arguments and enforce handle liveness, yet they are NOT
// backed by the Julia statistical core, and there is (deliberately) no Idris2
// ABI wired up. Making these ops do real statistics is out of scope here; the
// documentation reframe lives in work order W2-4.
//

const std = @import("std");

// Version information (keep in sync with project)
const VERSION = "0.1.0";
const BUILD_INFO = "STATISTIKLES built with Zig " ++ @import("builtin").zig_version_string;

/// Monotonic C-ABI version. Bump on any breaking change to the exported
/// function signatures / struct layouts below. Independent of the semantic
/// VERSION string above (which tracks the library release).
const ABI_VERSION: u32 = 1;

/// Liveness cookie stored at the head of every live `Handle`.
const HANDLE_MAGIC: u32 = 0x57A7_1C1E;
/// Poison written over the cookie just before a handle's memory is released,
/// so that a second free / an operation on the dangling pointer is detected
/// instead of invoking undefined behaviour.
const HANDLE_FREED: u32 = 0xDEAD_F8EE;

/// Thread-local last-error storage.
///
/// OWNERSHIP RULE: every error message is a program-lifetime string literal
/// (static storage). `statistikles_last_error` therefore hands the caller a
/// borrowed pointer that the caller MUST NOT free. It stays valid until the
/// next FFI call on the same thread updates or clears the error. Storing only
/// static pointers (never a heap dup) is what keeps this leak-free.
threadlocal var last_error: ?[*:0]const u8 = null;

/// Set the last error message (must be a string literal / static storage).
fn setError(msg: [*:0]const u8) void {
    last_error = msg;
}

/// Clear the last error.
fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types
//==============================================================================

/// Result codes.
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
};

/// Library handle.
///
/// Internally a real struct; across the C ABI it is only ever handed out and
/// taken back as an opaque `*Handle` pointer, so C consumers cannot see or
/// depend on its layout. The leading `magic` cookie is checked on every entry
/// point that dereferences a handle (see `checkLive`) to make use-after-free
/// and double-free safe, reported errors rather than undefined behaviour.
pub const Handle = struct {
    magic: u32,
    allocator: std.mem.Allocator,
    initialized: bool,
};

/// Validate a handle pointer. Returns the typed pointer only if it points at a
/// live handle (cookie intact), otherwise null.
///
/// Note: on an already-freed pointer this reads the poisoned cookie in the
/// still-mapped `c_allocator` block. That read is what the liveness cookie is
/// *for*; libc keeps small freed blocks mapped, so it is safe in practice and
/// lets a double-free return an error code instead of corrupting the heap.
fn checkLive(handle: ?*Handle) ?*Handle {
    const h = handle orelse return null;
    if (h.magic != HANDLE_MAGIC) return null;
    return h;
}

//==============================================================================
// Library Lifecycle
//==============================================================================

/// Initialize the library. Returns a handle, or null on failure.
pub export fn statistikles_init() ?*Handle {
    const allocator = std.heap.c_allocator;

    const handle = allocator.create(Handle) catch {
        setError("Failed to allocate handle");
        return null;
    };

    handle.* = .{
        .magic = HANDLE_MAGIC,
        .allocator = allocator,
        .initialized = true,
    };

    clearError();
    return handle;
}

/// Free the library handle.
///
/// Safe against double-free: freeing an already-freed handle is a no-op that
/// returns `.invalid_param` (never a second `destroy`). Returns `.null_pointer`
/// for a null handle and `.ok` on success.
pub export fn statistikles_free(handle: ?*Handle) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    if (h.magic != HANDLE_MAGIC) {
        setError("Handle already freed or invalid");
        return .invalid_param;
    }

    const allocator = h.allocator;

    // Poison the cookie BEFORE releasing so a subsequent free/operation on this
    // (now dangling) pointer is detected rather than double-freeing.
    h.magic = HANDLE_FREED;
    h.initialized = false;

    allocator.destroy(h);
    clearError();
    return .ok;
}

//==============================================================================
// Core Operations
//
// EXPERIMENTAL PLACEHOLDERS: the operations below validate arguments and handle
// liveness correctly, but perform no real statistics — they are NOT backed by
// the Julia core. Present only to fix the C ABI surface under CI.
//==============================================================================

/// Process data (placeholder operation).
pub export fn statistikles_process(handle: ?*Handle, input: u32) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    if (h.magic != HANDLE_MAGIC) {
        setError("Handle already freed or invalid");
        return .invalid_param;
    }

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    _ = input;

    clearError();
    return .ok;
}

//==============================================================================
// String Operations
//==============================================================================

/// Get a string result (placeholder).
/// Caller must free the returned string with `statistikles_free_string`.
pub export fn statistikles_get_string(handle: ?*Handle) ?[*:0]const u8 {
    const h = handle orelse {
        setError("Null handle");
        return null;
    };

    if (h.magic != HANDLE_MAGIC) {
        setError("Handle already freed or invalid");
        return null;
    }

    if (!h.initialized) {
        setError("Handle not initialized");
        return null;
    }

    const result = h.allocator.dupeZ(u8, "Example result") catch {
        setError("Failed to allocate string");
        return null;
    };

    clearError();
    return result.ptr;
}

/// Free a string allocated by the library.
pub export fn statistikles_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.c_allocator;

    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Array/Buffer Operations
//==============================================================================

/// Process an array of data (placeholder).
pub export fn statistikles_process_array(
    handle: ?*Handle,
    buffer: ?[*]const u8,
    len: u32,
) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    if (h.magic != HANDLE_MAGIC) {
        setError("Handle already freed or invalid");
        return .invalid_param;
    }

    const buf = buffer orelse {
        setError("Null buffer");
        return .null_pointer;
    };

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    const data = buf[0..len];
    _ = data;

    clearError();
    return .ok;
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message, or null if none.
///
/// Ownership: STATIC storage (a string literal). The caller MUST NOT free the
/// returned pointer; it stays valid until the next FFI call on this thread
/// updates or clears the error.
pub export fn statistikles_last_error() ?[*:0]const u8 {
    return last_error;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library (semantic) version string.
pub export fn statistikles_version() [*:0]const u8 {
    return VERSION;
}

/// Get the monotonic C-ABI version number.
pub export fn statistikles_abi_version() callconv(.C) u32 {
    return ABI_VERSION;
}

/// Get build information.
pub export fn statistikles_build_info() [*:0]const u8 {
    return BUILD_INFO;
}

//==============================================================================
// Callback Support
//==============================================================================

/// Callback function type (C ABI).
pub const Callback = *const fn (u64, u32) callconv(.C) u32;

/// Register a callback (placeholder — the callback is validated but not stored).
pub export fn statistikles_register_callback(
    handle: ?*Handle,
    callback: ?Callback,
) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    if (h.magic != HANDLE_MAGIC) {
        setError("Handle already freed or invalid");
        return .invalid_param;
    }

    const cb = callback orelse {
        setError("Null callback");
        return .null_pointer;
    };

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    _ = cb;

    clearError();
    return .ok;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Check if handle is live and initialized (0 = no, 1 = yes).
pub export fn statistikles_is_initialized(handle: ?*Handle) u32 {
    const h = checkLive(handle) orelse return 0;
    return if (h.initialized) 1 else 0;
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle" {
    const handle = statistikles_init() orelse return error.InitFailed;
    defer _ = statistikles_free(handle);

    try std.testing.expect(statistikles_is_initialized(handle) == 1);
}

test "double free is a safe error, not UB" {
    const handle = statistikles_init() orelse return error.InitFailed;

    try std.testing.expectEqual(Result.ok, statistikles_free(handle));
    // Second free must be rejected, not a second destroy().
    try std.testing.expectEqual(Result.invalid_param, statistikles_free(handle));
}

test "operation on freed handle is rejected" {
    const handle = statistikles_init() orelse return error.InitFailed;
    try std.testing.expectEqual(Result.ok, statistikles_free(handle));

    try std.testing.expectEqual(Result.invalid_param, statistikles_process(handle, 0));
    try std.testing.expect(statistikles_is_initialized(handle) == 0);
}

test "error handling" {
    const result = statistikles_process(null, 0);
    try std.testing.expectEqual(Result.null_pointer, result);

    const err = statistikles_last_error();
    try std.testing.expect(err != null);
}

test "last_error is static and stable (no leak, no free)" {
    _ = statistikles_process(null, 0);
    const a = statistikles_last_error() orelse return error.NoError;
    const b = statistikles_last_error() orelse return error.NoError;
    // Same static pointer each call — nothing was allocated, nothing to free.
    try std.testing.expect(a == b);
}

test "version" {
    const ver = statistikles_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}

test "abi version is nonzero" {
    try std.testing.expect(statistikles_abi_version() >= 1);
}
