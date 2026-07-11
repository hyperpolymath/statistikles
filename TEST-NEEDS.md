<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# TEST-NEEDS: statistikles

## CRG Grade: C — ACHIEVED 2026-04-04

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 67 | Julia: 41 stats modules (descriptive, inferential, bayesian, SEM, timeseries, survival, etc.), pipeline, output, integrations, bridge (Idris2 template ABI removed 2026-03-29; Zig FFI remains) |
| **Unit tests** | 693 | @test assertions across runtests.jl + 7 wired suites (e2e, property, reference-validation ×2, degenerate-input, guardrail, executor-router) -- comprehensive @test/@testset coverage (E2E & property also broken out below) |
| **E2E tests** | yes | test/e2e_test.jl -- full descriptive pipeline, error handling (empty/NaN), combined descriptive+inferential |
| **Property tests** | yes | test/property_test.jl -- invariants (constant arrays, sort-invariance, power-mean ordering, p-value/correlation bounds) |
| **Integration tests** | 0 | No dedicated tests for the 8 claimed external integrations |
| **Benchmarks** | yes | benches/benchmarks.jl (BenchmarkTools; descriptive_stats at 3 scales + batch scenario) |
| **Agda proofs** | 3 files | proofs/Statistikles/ (Inequalities, RankIdentities, TropicalSemiring) |

## What's Missing

### P2P Tests
- [ ] No tests for VeriSimDB integration (claimed: port 8096)
- [ ] No tests for pipeline module orchestrating multiple stats modules
- [ ] No tests for TypeLL level integration

### E2E Tests
- [x] Full statistical analysis pipeline from data input to output report (test/e2e_test.jl)
- [ ] No test for integration with external data sources

### Aspect Tests
- [ ] **Security**: No input sanitization tests for user-provided data
- [ ] **Performance**: No performance tests despite being a computation-heavy stats library
- [ ] **Concurrency**: No parallel computation tests (Julia supports multi-threading)
- [x] **Error handling**: empty / single-element / NaN-containing / all-NaN datasets covered in test/e2e_test.jl

### Benchmarks Needed
- [x] benches/benchmarks.jl exists (BenchmarkTools; descriptive_stats at three scales + batch)
- [ ] Descriptive stats throughput at larger scales (10M/100M datapoints)
- [ ] Bayesian MCMC convergence timing
- [ ] SEM fitting performance
- [ ] Time series forecasting latency
- [ ] Memory usage for large datasets

### Self-Tests
- [ ] No self-diagnostic mode

## FLAGGED ISSUES
- **693 @test assertions is solid coverage** -- best among all scanned repos
- **Single test file for 65 modules** -- RESOLVED 2026-07-11: the suite is split
  across runtests.jl + 7 wired files (e2e, property, reference-validation ×2,
  degenerate-input, guardrail, executor-router)
- **0 integration tests despite 8 claimed integrations** -- integration claims unverified
- **ffi/zig comments reference deleted src/abi/Foreign.idr** -- RESOLVED (#38, #48):
  the Foreign.idr references were removed; the Zig FFI now compiles with a
  `zig build test` CI job and is documented as an EXPERIMENTAL placeholder surface
  (entry points are not yet backed by the Julia core)

## Priority: P2 (MEDIUM) -- unit tests are decent; integration tests are the main gap

## FAKE-FUZZ ALERT — RESOLVED 2026-07-07

- `tests/fuzz/placeholder.txt` (scorecard placeholder inherited from
  rsr-template-repo, no real fuzz coverage) was removed on 2026-07-07
- A real fuzz harness remains open work (see rsr-template-repo/tests/fuzz/README.adoc)
