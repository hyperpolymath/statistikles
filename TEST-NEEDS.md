<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# TEST-NEEDS: statistease

## CRG Grade: C — ACHIEVED 2026-04-04

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 68 | Julia: 30+ stats modules (descriptive, inferential, bayesian, SEM, timeseries, survival, etc.), pipeline, output, integrations, bridge + 3 Idris2 ABI |
| **Unit tests** | 478 | All in single runtests.jl -- comprehensive @test/@testset coverage |
| **Integration tests** | 0 | No dedicated integration tests |
| **E2E tests** | 0 | None |
| **Benchmarks** | 0 | benches/.gitkeep only -- EMPTY |
| **Agda proofs** | 10 | (per memory notes) |

## What's Missing

### P2P Tests
- [ ] No tests for VeriSimDB integration (claimed: port 8096)
- [ ] No tests for pipeline module orchestrating multiple stats modules
- [ ] No tests for TypeLL level integration

### E2E Tests
- [ ] No test running a full statistical analysis pipeline from data input to output report
- [ ] No test for integration with external data sources

### Aspect Tests
- [ ] **Security**: No input sanitization tests for user-provided data
- [ ] **Performance**: No performance tests despite being a computation-heavy stats library
- [ ] **Concurrency**: No parallel computation tests (Julia supports multi-threading)
- [ ] **Error handling**: No tests for NaN/Inf propagation, degenerate datasets, empty inputs

### Benchmarks Needed (CRITICAL)
- [ ] **benches/.gitkeep is EMPTY** -- claimed benchmarks DO NOT EXIST
- [ ] Descriptive stats throughput (1M/10M/100M datapoints)
- [ ] Bayesian MCMC convergence timing
- [ ] SEM fitting performance
- [ ] Time series forecasting latency
- [ ] Memory usage for large datasets

### Self-Tests
- [ ] No self-diagnostic mode

## FLAGGED ISSUES
- **478 tests is solid unit coverage** -- best among all scanned repos
- **benches/.gitkeep = phantom benchmarks** -- no actual benchmarks exist despite this being a performance-critical stats library
- **Single test file for 68 modules** -- should be split for maintainability
- **0 integration tests despite 8 claimed integrations** -- integration claims unverified

## Priority: P2 (MEDIUM) -- unit tests are decent, but benchmarks and integrations are critical gaps

## FAKE-FUZZ ALERT

- `tests/fuzz/placeholder.txt` is a scorecard placeholder inherited from rsr-template-repo — it does NOT provide real fuzz testing
- Replace with an actual fuzz harness (see rsr-template-repo/tests/fuzz/README.adoc) or remove the file
- Priority: P2 — creates false impression of fuzz coverage
