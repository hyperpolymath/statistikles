# W1-1 · Neural boundary guardrail (P0) + hardening

**Model:** impl=opus · verify=opus · **Branch:** `fix/neural-boundary-guardrail`
**Priority: P0 — this is the product's raison d'être made real.**

## Context

The flagship guarantee — "no number is ever produced by the LLM" — is currently
**prompt-only** (`src/tools/chat.jl` SYSTEM_PROMPT ~lines 29-66) with zero output
validation. `chat.jl` (~114-119) prints assistant content verbatim; nothing checks
that numerals in the reply came from a tool result. Surrounding this are crash/robustness
gaps: unguarded tool-call JSON parsing, no HTTP timeout, silent-null unknown sub-types,
dropped `tools` on follow-up calls (no multi-step chaining), and `@assert`-based
resource assumptions.

## Requirements (implement in `src/tools/`)

**(a) NEW `src/tools/guardrail.jl`:**
- `collect_numbers(x)` — recursively harvest every numeric value from tool-result
  Dicts/Vectors/nested structures.
- `extract_numeric_tokens(text::String)` — find numeric literals in assistant prose
  (ints, decimals, scientific notation, percentages).
- `validate_numeric_provenance(text, tool_results, user_numbers; rtol=1e-6) -> (ok::Bool, orphans::Vector{String})`.
  A token is legitimate if it approx-matches (rtol) any harvested tool-result number,
  OR its ÷100 / ×100 variant matches (percent phrasing), OR it appears in the user's own
  input numbers, OR it is a small structural integer 0..12.

**(b) `chat.jl`:** record all tool results for the turn; after the final assistant
content, run the guardrail (parse user-message numbers as `user_numbers`). If orphans
exist AND tool calls happened: ONE retry asking the model to restate using only
tool-result numbers; if orphans persist, print the reply with a clear warning block
listing the unverified numbers. If the reply has numeric tokens but NO tool call was
made: same retry-once-then-warn with a "no symbolic computation was performed" message.
**Never silently rewrite model text — flag, never fabricate.**

**(c) `lmstudio.jl` `process_tool_calls`:** wrap the per-tool-call body (nested key
access + `JSON3.read` of arguments, ~lines 88-101) in try/catch; on failure push a
`role:"tool"` message with a clean `Dict("error"=>...)` so the model recovers. **Pass
the `tools` parameter on the follow-up call** (currently dropped ~line 104) and iterate
tool-call rounds in a bounded loop (max 5) until a reply has no tool_calls. Add HTTP
timeouts to `call_lm_studio` and the `chat.jl` HTTP call: `connect_timeout=10`,
`readtimeout=120`, `retry=false` (see `echidna_adapter.jl` for the existing pattern);
timeout → return the existing error-Dict shape.

**(d) `chat.jl` REPL while-loop:** try/catch around the turn body — print a concise
error and continue; one bad turn must never kill the session.

**(e) `executor.jl`:** clamp caller-supplied `n_reps`/`n_permutations` to ≤100_000 and
component counts `k` to ≤20 (return `Dict("error"=>...)` when exceeded); add a trailing
`else return Dict("error"=>"Unknown type '…' for <tool>")` to EVERY inner sub-type
dispatch (grep every inner if/elseif chain: t_test, time_series, information_theory,
survival_analysis, robust_stats, causal_inference, spatial_stats, advanced_modeling,
algebraic_stats, nonparametric_test, and any others); gate the `trace` backtrace field
in the catch-all behind ENV `STATISTIKLES_DEBUG` (default off), keeping a concise stable
error string.

**(f) tests — NEW `test/guardrail_test.jl`:** unit tests for the three guardrail
functions incl. a **clean fixture** (all numbers from tool results, with rounding/percent
variants) that passes and an **injected-fabrication fixture** that MUST be flagged; tests
for `process_tool_calls` recovery with malformed tool_call dicts (missing keys, non-JSON
arguments) — construct response Dicts directly, no HTTP; tests for clamps and
unknown-sub-type else-errors via `execute_tool`. Wire into `test/runtests.jl`.

## Acceptance criteria

- [ ] Guardrail flags an injected fabricated number and passes a clean reply (both tested).
- [ ] Malformed tool-call dicts recover instead of crashing (tested).
- [ ] Every inner sub-type dispatch has an `else`-error; clamps enforced (tested).
- [ ] HTTP calls have timeouts; follow-up call passes `tools`; loop is bounded.
- [ ] Full suite green locally (was 4404 tests) + the new tests.

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
in a WSL login shell (`wsl.exe -d Debian -u hyperpolymath -- bash -lc '…'`).

## Out of scope

Prompt-injection input delimiting (that is W2-7, which builds on this guardrail).
