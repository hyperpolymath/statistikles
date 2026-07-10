# W1-2 · Degenerate-input guards + `@assert`→`ArgumentError`

**Model:** impl=sonnet · verify=opus · **Branch:** `fix/stats-degenerate-inputs`

## Context

The compute core is correct on the happy path and reference-validated, but degenerate
inputs leak `NaN`/`Inf` verbatim to the user — violating the finiteness + JSON-
serialisability contract and the "nothing fabricated" guarantee. Separately, ~26
validation `@assert` sites across ~13 modules are the sole guard on user/LLM data;
Julia documents `@assert` as disable-able, so mismatched-length/out-of-range inputs
could proceed to `BoundsError` or silently-wrong numbers.

## Requirements

**(a) Degenerate guards** (`src/stats/*.jl`): skewness requires n≥3; kurtosis n≥4;
pearson/regression guard zero denominators (`den>0`, `ss_tot>0`, `(1-r^2)>0`); t-tests
guard `se==0` and `n<2`; zero-variance groups. Follow the guard patterns already in
`spearman`/`one_way_anova`. On a degenerate case return `nothing` (JSON null) for that
field plus, where the Dict shape allows, a short `"note"` explaining why — never
NaN/Inf. Also convert misleading sentinels `harmonic_mean=0.0`, `cv=Inf`,
`geometric_mean=NaN` to `nothing`+note.

**(b) Replace validation `@assert`s** that guard user/LLM data with
`throw(ArgumentError("…"))` carrying a precise message (grep `@assert` under `src/`;
known sites include `correlation_regression.jl:17,54,206`, `descriptive.jl:132`,
`information_theory.jl:26`, `representations.jl:15`, `bridge/typell_levels.jl:59`). Add
NEW `src/stats/validation.jl` with small helpers (`require_equal_length`,
`require_nonempty`, `require_positive`, `require_probability`, …) and use them. Keep
`@assert` only for true internal invariants.

**(c) tests — NEW `test/degenerate_input_test.jl`:** n=1/2/3 vectors, constant vectors,
zero-variance two-group cases; assert no `NaN`/`Inf` anywhere in returned Dicts (reuse
the serialisability walk from `e2e_test.jl`); `@test_throws ArgumentError` for the
converted validations. Wire into `runtests.jl`.

**NOTE:** `descriptive_stats`' `outlier_fences` was already fixed to a `Vector` (PR #31,
merged). Do not touch it.

## Acceptance criteria

- [ ] No core stat function returns NaN/Inf on degenerate input (tested).
- [ ] Converted validations throw `ArgumentError` (tested).
- [ ] Full suite green + new tests.

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
(WSL login shell). Sibling W1-1 also adds guards; if both are unmerged and overlap on a
file, note it — do not duplicate.

## Out of scope

The guardrail/provenance layer (W1-1); reference-value coverage (W2-5).
