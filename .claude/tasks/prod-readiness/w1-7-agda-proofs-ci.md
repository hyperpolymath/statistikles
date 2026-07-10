# W1-7 · Type-checking Agda proofs + `agda --safe` CI + honest catalogue

**Model:** impl=opus · verify=sonnet · **Branch:** `fix/agda-proofs-ci`

## Context

`proofs/README.adoc` claims "Verified by Agda's type checker — no postulates," but no
workflow runs Agda, ≥2 of the 3 files likely don't type-check (missing `_|>_` import; a
helper type mismatch), all proofs quantify over ℕ while claims/computation are over
ℝ/Float64, and the catalogue labels trivial lemmas as statistical theorems (e.g.
"Bonferroni" = `x ≤ x+Σ`, "tie-correction" = `a≤b → a²≤b²`, "mean-ordering" = `≤-trans`).
**User decision: proofs are EXPERIMENTAL** — make them compile & CI-check and relabel
honestly; do NOT restate over ℝ.

⚠ **Toolchain:** setup installed **Agda 2.6.4.3 + agda-stdlib 2.1**, wired via
`~/.agda/libraries` + `~/.agda/defaults`. stdlib 2.1 renamed some modules vs 1.x —
expect import tweaks.

## Requirements

**(a)** Fix compile errors so ALL modules under `proofs/` pass `agda --safe` (do not
weaken `--safe`). Resolve import paths against stdlib 2.1.

**(b)** `proofs/README.adoc`: relabel every catalogue entry to the lemma **actually
proven** (precise statement), keep the aspirational statistical theorem in a separate
clearly-marked "target (pending)" column/note, and add an explicit scope statement that
current proofs quantify over ℕ, not the Float64 the runtime uses. Honesty fix — do not
delete proofs, do not restate over reals here.

**(c)** NEW `.github/workflows/agda.yml`: ubuntu-latest; install agda + agda-stdlib
(apt); configure the stdlib library file; run `agda --safe` on every module under
`proofs/` (glob or explicit list with a guard that FAILS if a new `.agda` file isn't
checked). SHA-pin any actions; match repo pinning style.

**(d)** If a governance/grep workflow scans for `sorry`/`postulate` but skips `proofs/`,
extend it to cover `proofs/` (check `.github/workflows` and extend surgically).

## Acceptance criteria

- [ ] `agda --safe` passes on every `proofs/**/*.agda` locally.
- [ ] README catalogue states the real lemma per entry + a ℕ-scope disclaimer.
- [ ] `agda.yml` green on the PR; fails if a new proof file is unchecked.

## Local verification

WSL login shell: `cd <repo>/proofs && agda --safe <each Module>.agda` (stdlib resolves via
`~/.agda/defaults`). First run is slow while stdlib interfaces build.

## Out of scope

Proofs over ℝ; new theorems; the Julia↔Agda correspondence (deferred by user decision).
Broader doc reframe is W2-4.
