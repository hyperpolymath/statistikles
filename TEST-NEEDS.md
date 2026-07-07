<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# TEST-NEEDS: statistease

## CRG Grade: C — ACHIEVED 2026-04-04

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 65 | Julia: 30+ stats modules (descriptive, inferential, bayesian, SEM, timeseries, survival, etc.), pipeline, output, integrations, bridge (Idris2 template ABI removed 2026-03-29; Zig FFI remains) |
| **Unit tests** | 478 | All in single runtests.jl -- comprehensive @test/@testset coverage |
| **E2E tests** | yes | test/e2e_test.jl -- full descriptive pipeline, error handling (empty/NaN), combined descriptive+inferential |
| **Property tests** | yes | test/property_test.jl -- invariants (constant arrays, sort-invariance, power-mean ordering, p-value/correlation bounds) |
| **Integration tests** | 0 | No dedicated tests for the 8 claimed external integrations |
| **Benchmarks** | yes | benches/benchmarks.jl (BenchmarkTools; descriptive_stats at 3 scales + batch scenario) |
| **Agda proofs** | 3 files | proofs/StatistEase/ (Inequalities, RankIdentities, TropicalSemiring) |

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
- **478 tests is solid unit coverage** -- best among all scanned repos
- **Single test file for 65 modules** -- should be split for maintainability
- **0 integration tests despite 8 claimed integrations** -- integration claims unverified
- **ffi/zig comments reference deleted src/abi/Foreign.idr** -- the Idris2 template
  ABI was removed 2026-03-29 but the Zig FFI still cites it; either wire the Zig
  layer to something real or retire it

## Priority: P2 (MEDIUM) -- unit tests are decent; integration tests are the main gap

## FAKE-FUZZ ALERT — RESOLVED 2026-07-07

- `tests/fuzz/placeholder.txt` (scorecard placeholder inherited from
  rsr-template-repo, no real fuzz coverage) was removed on 2026-07-07
- A real fuzz harness remains open work (see rsr-template-repo/tests/fuzz/README.adoc)
