# W2-6 · Structured logging + audit trail

**Model:** impl=sonnet · verify=sonnet · **Branch:** `feat/structured-observability`

## Context

Observability is limited to bare `println` (`lmstudio.jl:93` prints the symbolic-execute
breadcrumb; errors go to stdout). No `Logging` stdlib use, no request/trace IDs, no
timing, no persisted audit trail — despite the product marketing auditability. A VeriSimDB
persistence layer exists (`src/bridge/verisimdb_schema.jl`) but is never invoked from the
runtime path. **Depends on / coordinates with W1-1** (which restructures chat/executor).

## Requirements

1. Introduce `Logging`-based structured logging (`@info`/`@warn`/`@error`) across the
   runtime path (`src/tools/chat.jl`, `executor.jl`, `lmstudio.jl`), replacing ad-hoc
   `println`. Attach a **per-chat-turn correlation id** and a per-tool-call id; log for
   each tool call: tool name, an argument hash (not raw args — may contain user data),
   result summary (shape/keys, not full values), and duration.
2. Make verbosity configurable via ENV (`STATISTIKLES_LOG_LEVEL`, default `Info`), and
   keep the human-facing REPL output clean (logs to stderr / a logger, not interleaved
   with answers).
3. **Wire the dormant VeriSimDB audit path**: from `execute_tool` (or `process_tool_calls`),
   record an audit entry (turn id, tool, arg hash, result provenance) via
   `src/bridge/verisimdb_schema.jl`. If VeriSimDB requires a backend not available in
   tests, make persistence pluggable/no-op-by-default and unit-test the record
   construction — do not make the test suite depend on an external DB.
4. Tests: NEW `test/observability_test.jl` — assert log records carry a correlation id
   and tool metadata (capture with `Test.collect_test_logs`/`with_logger`); assert the
   audit-record constructor produces the expected shape. Wire into `runtests.jl`.

## Acceptance criteria

- [ ] Runtime path uses structured logging with correlation ids (tested via captured logs).
- [ ] REPL answers are not polluted by log lines.
- [ ] Audit-record construction is tested; persistence is pluggable/no-op-safe in CI.
- [ ] Full suite green + new test.

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
(WSL login shell).

## Out of scope

Standing up a real VeriSimDB backend; log shipping/telemetry infra.
