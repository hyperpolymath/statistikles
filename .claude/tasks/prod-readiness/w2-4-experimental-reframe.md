# W2-4 · Experimental reframe: FFI + formal-proofs documentation

**Model:** impl=sonnet · verify=sonnet · **Branch:** `docs/experimental-reframe`

## Context

The audit found the Zig FFI and Agda proofs are aspirational: FFI ops are placeholders
calling no Julia code, the "Idris2 ABI + generated header" pipeline in `ABI-FFI-README.md`
doesn't exist, and the Agda proofs cover ℕ-lemmas, not the ℝ/Float64 statistical theorems
the docs imply. **User decision (binding): reframe both as EXPERIMENTAL** repo-wide.
W1-6 and W1-7 already made both compile + CI-check with honest *inline* labels; this task
is the docs/positioning sweep. **Depends on W1-6 and W1-7 being merged (or branch from
their state).**

## Requirements

1. Inventory every claim: grep `README.adoc`, `EXPLAINME.adoc`, `ABI-FFI-README.md`,
   `PROOF-NEEDS.md`, `proofs/README.adoc`, `docs/**`, `.machine_readable/**`,
   `RSR_OUTLINE.adoc`, quickstarts for: "formally verified", "formally proven",
   "proof-backed", "Idris2 ABI", "Level 10", "verified by Agda", "production-ready"
   (in FFI/proof context), and any text asserting the C-ABI exposes the stats core.
2. Rewrite each hit to the honest state with consistent vocabulary:
   - FFI: "**Experimental** — compiles and is CI-tested, but entry points are
     placeholders not yet backed by the Julia core; the Idris2 ABI layer is design-only."
   - Proofs: "**Experimental** — small ℕ-level lemmas type-checked by `agda --safe` in
     CI; the statistical theorems over ℝ remain open targets."
3. Add ONE canonical "Experimental surfaces" section to `README.adoc` (short, under the
   architecture section) describing both boundaries and linking the detailed docs; other
   docs reference it rather than re-asserting.
4. `.machine_readable` a2ml manifests (e.g. NEUROSYM.a2ml, META.a2ml): align any
   proof/FFI maturity fields so machine-readable claims don't exceed human-readable ones.
   Keep a2ml syntax valid (the "Validate A2ML manifests" CI job checks these).
5. Do NOT weaken the Julia core's tested/reference-validated claims (true). Do NOT delete
   PROOF-NEEDS.md — label it "open targets".

## Acceptance criteria

- [ ] `git grep -in "formally verified\|formally proven"` returns only accurate
      proofs/-internal descriptions or explicit "not yet / target" phrasing.
- [ ] No doc asserts the C-ABI reaches the stats core.
- [ ] README has the single canonical "Experimental surfaces" section; others link it.
- [ ] A2ML validation CI job passes; PR body lists every file with before→after.

## Local verification

The acceptance-criteria grep; re-run any manifest validator (`just` validate recipe or
rely on CI).

## Out of scope

Making FFI real / proofs over ℝ (user-deferred); code changes beyond comment-text.
