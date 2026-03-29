<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
# Cross-Verification Architecture

## Three-Body Verification Triangle

```
           ECHIDNA (Formal Proofs)
          ╱   Agda, Lean 4, Z3   ╲
         ╱    Arbitrates disputes  ╲
        ╱                           ╲
StatistEase ◄─────────────────► Aspasia
  (Julia)    cross-verify via    (GNU Octave)
  Compute     JSON transactions   Audit
```

### Layer 1: StatistEase (Julia) — Computation
- All numerical computation happens in Julia's symbolic kernel
- Every result includes BLAKE3 hash for reproducibility
- Results written as JSON transactions for Aspasia

### Layer 2: Aspasia (GNU Octave + Prolog) — Audit
- Independent reimplementation using different BLAS/LAPACK
- Socratic engine: numerical, ontological, interpretation checks
- 6-step resolution ladder for disagreements (NIST StRD → Interval → Symbolic → Human)

### Layer 3: ECHIDNA (Rust + 48 provers) — Arbitration
- Formal proofs of statistical identities via Agda/Lean 4
- SMT verification of arithmetic properties via Z3/CVC5
- Trust levels 1-5 for every verified property

### Layer 4: VeriSimDB (Port 8096) — Persistence
- All results, audits, proofs persisted with VQL-UT queries
- 8 modalities: numerical, audit, proof, metadata, timeseries, graph, raw, config

### Layer 5: TypeLL (Levels 1-10) — Type Safety
- From simple Float64 (L1) to formally-proven epistemological types (L10)
- Tropical semiring types at L7-8, verification provenance at L9-10
