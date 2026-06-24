<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# PROOF-NEEDS.md
## Current State

- **LOC**: ~11,900
- **Languages**: Julia, Agda, Idris2, Zig
- **Existing ABI proofs**: `src/abi/*.idr` (template-level)
- **Existing verification**: 3 Agda proof files in `proofs/StatistEase/`
  - `Inequalities.agda` — statistical inequalities
  - `RankIdentities.agda` — rank-based test identities
  - `TropicalSemiring.agda` — tropical semiring properties (mentions "no postulates" in comment, but grep found a match — needs audit)
- **Dangerous patterns**: Comment in TropicalSemiring.agda references postulates (may be a negation — "no postulates")

## What Needs Proving

### Tropical Semiring Audit (proofs/StatistEase/TropicalSemiring.agda)
- Verify the "no postulates" claim is still accurate
- Ensure semiring laws (associativity, commutativity, distributivity, identity) are all constructively proven

### Statistical Test Correctness (Julia core)
- Julia code implements statistical tests — the Agda proofs should correspond to these
- Prove: test implementations match their mathematical specifications
- Gap analysis: which Julia tests have Agda proofs and which do not?

### Bridge Correctness (src/bridge/)
- `typell_levels.jl`, `echidna_adapter.jl`, `verisimdb_schema.jl`, `aspasia_bridge.jl`, `betlang_bridge.jl`
- Prove: type-level bridges preserve the statistical properties proven in Agda

### Integration Correctness (src/integrations/)
- `smtlib_integration.jl` — SMT-LIB integration should produce valid SMT queries
- `quantum_integration.jl` — quantum probability calculations need mathematical proofs

### Additional Inequalities
- Extend `Inequalities.agda` to cover all statistical inequalities used in the Julia code
- Each inequality used at runtime should have a corresponding Agda proof

## Recommended Prover

- **Agda** (already in use — extend existing proof suite)
- **Lean4** alternative for the quantum probability proofs (Mathlib has probability theory)

## Priority

**MEDIUM** — Good existing proof coverage. Statistical correctness proofs are valuable but the tool is not security-critical. Focus on completing the gap analysis between Julia implementations and Agda proofs.

## Template ABI Cleanup (2026-03-29)

Template ABI removed -- was creating false impression of formal verification.
The removed files (Types.idr, Layout.idr, Foreign.idr) contained only RSR template
scaffolding with unresolved {{PROJECT}}/{{AUTHOR}} placeholders and no domain-specific proofs.
