# W1-6 · Make the Zig FFI compile + memory-safety fixes + CI

**Model:** impl=opus · verify=sonnet · **Branch:** `fix/zig-ffi-compiles`

## Context

The FFI does not compile: `ffi/zig/src/main.zig` (~42-67) declares `Handle` as
`opaque {}` yet gives it fields and `allocator.create(Handle)`s it (both hard Zig
compile errors); `ffi/zig/test/integration_test.zig` has its own conflicting `Handle`.
No workflow runs `zig build`, so every check is green while the FFI is broken.
**User decision: the FFI is EXPERIMENTAL** — make it compile and CI-check; do NOT wire it
to the Julia core or build the (nonexistent) Idris2 ABI.

⚠ **Zig version:** the setup environment installed Zig **0.16.0**, which has breaking std
changes (Io writer/reader redesign). If the code targets ≤0.14, fetch a matching older
tarball into `/home/hyperpolymath/zig/` and use its binary. State the version you built
against in the PR.

## Requirements

**(a)** `main.zig`: make `Handle` a real struct (internal), exported across the C ABI as
an opaque pointer (idiomatic for the Zig version you use). Fix the double-free /
use-after-free the audit flagged — add a liveness/magic flag checked in
`statistikles_free` and `statistikles_process`; freeing twice must be a safe no-op
returning an error code, not UB. Fix the `statistikles_last_error` string-ownership leak
(stable storage owned by the handle or a static buffer — document the ownership rule in a
comment). Add `export fn statistikles_abi_version() callconv(.C) u32` returning a
monotonic ABI number alongside the existing version string.

**(b)** `test/integration_test.zig`: use the ONE shared `Handle` (import from the root
module — restructure `build.zig` test wiring if needed); make the double-free test assert
the safe-error behaviour instead of "should not crash".

**(c)** `build.zig`: remove or satisfy references to missing `include/statistikles.h` and
`bench/bench.zig` (audit says both are referenced but absent — prefer removing dead steps
unless trivially satisfiable).

**(d)** NEW `.github/workflows/zig.yml`: SHA-pinned checkout + a pinned Zig setup action
(e.g. `mlugg/setup-zig` by full SHA) matching the version you built against; run
`zig build test` in `ffi/zig`. Match repo SHA-pinning style.

**(e)** HONESTY: the exported ops are placeholders not backed by the Julia core. Keep a
clear comment block saying so + mention it in the PR body. Do NOT invent a Julia bridge.
(The doc-level reframe is W2-4.)

## Acceptance criteria

- [ ] `zig build test` passes locally (state the Zig version).
- [ ] Double-free is a safe error, not UB (tested); no `last_error` leak.
- [ ] `zig.yml` green on the PR; SHA-pinned.
- [ ] No commented-out/dead references remain in `build.zig`.

## Local verification

WSL login shell: `cd <repo>/ffi/zig && zig build test` (zig on PATH in login shell, or
full path `/home/hyperpolymath/zig/zig-x86_64-linux-<ver>/zig`).

## Out of scope

Real Julia-backed FFI semantics; the Idris2 ABI; doc reframe (W2-4).
