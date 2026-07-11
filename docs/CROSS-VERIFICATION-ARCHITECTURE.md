<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Cross-Verification Architecture

*Status: ASPIRATIONAL.* This document describes the target multi-repo
verification architecture. Only Layer 1 (Statistikles/Julia computation) and
a small experimental slice of Layer 3 (10 ℕ-level Agda lemmas, not statistical
identities over ℝ) exist today; Aspasia, ECHIDNA arbitration, VeriSimDB
persistence, and TypeLL levels 9-12 are design targets, not implemented
integrations. See the "Experimental surfaces" section of `README.adoc` for the
current, honest status of the FFI and proofs boundaries specifically.

## Three-Body Verification Triangle

```
           ECHIDNA (Formal Proofs)
          ╱   Agda, Lean 4, Z3   ╲
         ╱    Arbitrates disputes  ╲
        ╱                           ╲
Statistikles ◄─────────────────► Aspasia
  (Julia)    cross-verify via    (GNU Octave)
  Compute     JSON transactions   Audit
```

### Layer 1: Statistikles (Julia) — Computation
- All numerical computation happens in Julia's symbolic kernel
- Every result includes BLAKE3 hash for reproducibility
- Results written as JSON transactions for Aspasia

### Layer 2: Aspasia (GNU Octave + Prolog) — Audit
- Independent reimplementation using different BLAS/LAPACK
- Socratic engine: numerical, ontological, interpretation checks
- 6-step resolution ladder for disagreements (NIST StRD → Interval → Symbolic → Human)

### Layer 3: ECHIDNA (Rust + 48 provers) — Arbitration (planned; not wired up)
- Target: formal proofs of statistical identities via Agda/Lean 4. Today,
  `proofs/` has 10 Agda lemmas proven over ℕ as discrete proxies — not
  statistical identities over ℝ — and ECHIDNA dispatch from
  `src/bridge/echidna_adapter.jl` is not yet implemented (see
  `proofs/README.adoc`, "Integration with ECHIDNA (aspirational)")
- SMT verification of arithmetic properties via Z3/CVC5
- Trust levels 1-5 for every verified property

### Layer 4: VeriSimDB (Port 8096) — Persistence
- All results, audits, proofs persisted with VQL-UT queries
- 8 modalities: numerical, audit, proof, metadata, timeseries, graph, raw, config

### Layer 5: TypeLL (Levels 1-10) — Type Safety (L1-3 real; L9-10 target)
- From simple Float64 (L1) to a *target* of formally-proven epistemological
  types (L10) — L9-10 depend on the Layer 3 proof/verification pipeline above,
  which is not yet wired up, so no value in this codebase actually carries an
  L9/L10 guarantee yet
- Tropical semiring types at L7-8, verification provenance at L9-10 (target)
