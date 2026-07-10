# W2-5 · Extend ground-truth reference validation to advanced modules

**Model:** impl=sonnet · verify=opus · **Branch:** `test/reference-validation-extension`

## Context

`test/reference_validation_test.jl` compares against hand-derived ground truth for only
~7 of ~40 stat modules (descriptive moments, Welch t, Pearson, OLS, ANOVA, Mann-Whitney,
Levene). The advanced surface (bayesian, survival, SEM, ML, meta-analysis, causality,
Kruskal-Wallis, chi-square, logistic/multiple regression, Kaplan-Meier) has only
`isa Dict`/`haskey` smoke tests — a wrong-but-deterministic number there is exactly the
failure the project exists to prevent.

## Requirements

1. Pick the highest-traffic advanced tools (suggested first tranche: Kruskal-Wallis,
   chi-square test of independence, multiple linear regression, logistic regression,
   Kaplan-Meier survival, fixed/random-effects meta-analysis). For each, derive
   **independent ground-truth** expected values — from a textbook worked example OR a
   second implementation (R / SciPy / Julia's own upstream packages) run **locally**.
   Python/R is fine for deriving constants (it is banned only in *repo code*); commit
   only the constants plus a comment citing the source/derivation.
2. Add assertions to `reference_validation_test.jl` (or a new
   `reference_validation_advanced_test.jl` wired into `runtests.jl`) checking key
   statistics to a stated tolerance (`isapprox`, atol/rtol documented per case).
3. Where a function's output disagrees with ground truth, that is a **real bug find** —
   report it clearly in the PR body (do NOT silently loosen tolerance to make it pass;
   if you must, open the failing case as an `@test_broken` with a comment and flag it).

## Acceptance criteria

- [ ] ≥6 advanced tools have hand-derived/second-implementation reference assertions.
- [ ] Every expected constant has a source comment (textbook page or tool+version).
- [ ] Full suite green (or documented `@test_broken` for genuine discrepancies found).

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
(WSL login shell). Derivation scripts may live in scratch, not the repo.

## Out of scope

Property-based tests (already strong); fixing discovered bugs beyond flagging them
(open follow-up work orders for real bugs found).
