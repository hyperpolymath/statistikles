# W1-3 · Table-driven router tests + CI coverage

**Model:** impl=sonnet · verify=sonnet · **Branch:** `test/executor-router-coverage`

## Context

`src/tools/executor.jl` has ~75 dispatch arms but `execute_tool` is tested exactly once
(anova, `reference_validation_test.jl:103`). The string→function mapping and argument
coercion — the precise layer the LLM drives — is unverified for 74/75 tools; `lmstudio.jl`
has zero test references. Coverage is entirely unmeasured (no flag, no reporter, no gate)
across ~90 source files.

## Requirements

**(a) NEW `test/executor_router_test.jl`:** programmatically enumerate every registered
tool name from `src/tools/definitions.jl` (parse the definitions structure — do NOT
hand-copy the list); maintain a table of minimal valid arguments per tool; for each,
call `execute_tool(name, args)` and assert the result is a `Dict` NOT containing
`"error"`. Maintain an explicit skip-list with a reason string for tools genuinely
needing external services/files, and assert the skip-list stays small. For ≥5
high-traffic tools (t_test, descriptive_stats, correlation, regression, mann_whitney)
cross-check key numbers against the direct Julia function call (the anova pattern). **The
test must FAIL if a new tool is registered without a table entry or skip reason** — that
is the point. Wire into `runtests.jl`.

**(b) `.github/workflows/e2e.yml`:** switch to `Pkg.test(coverage=true)`; add a
SHA-pinned `julia-actions/julia-processcoverage` step; compute total % and echo to
`GITHUB_STEP_SUMMARY`; upload an lcov artifact. **INFORMATIONAL only** (no threshold
gate yet). Match existing SHA-pinning style (every action pinned by full commit SHA +
version comment).

**Sibling caution:** W1-1 adds `else`-error branches for unknown sub-types and clamps —
do NOT assert unknown sub-types return `nothing`, and use argument values within clamp
bounds.

## Acceptance criteria

- [ ] Every registered tool is exercised or explicitly skipped-with-reason (tested).
- [ ] ≥5 tools cross-checked vs direct calls.
- [ ] e2e.yml runs with coverage and reports a %; actions SHA-pinned.
- [ ] Full suite green + new test.

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
(WSL login shell). YAML: actionlint if available, else careful review.

## Out of scope

Enforcing a coverage threshold (informational first); extending ground-truth reference
values (W2-5).
