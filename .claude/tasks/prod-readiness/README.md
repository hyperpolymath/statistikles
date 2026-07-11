<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
-->
# Production-Readiness — Execution Pack

Self-contained work orders from the 2026-07-10 ten-dimension production-readiness
audit of statistikles. Each file is a standalone brief runnable by a fresh Claude
session with **no dependency on the originating conversation**, with a recommended
model (**Opus / Sonnet / Haiku**) for implementation and for adversarial verification.

- **Wave 1** = "basically running & functioning acceptably" (the P0 guarantee + the
  crash/robustness/coverage/install fixes). Do these **first**.
- **Wave 2** = everything beyond that (release engineering, packaging, honesty
  reframes, deeper test coverage, observability, polish).

All of wave 1 and most of wave 2 are now **merged to `main`**. Only two work orders
remain open: **W2-6 (observability)** and **W2-7 (prompt-injection delimiting)**.

## How to run

**One task, any session:**
> "Execute the work order in `.claude/tasks/prod-readiness/w1-1-neural-guardrail.md`.
>  Use the model it names; follow the execution contract in the README."

**A whole wave as a fleet (Claude Code, budget permitting):**
> `Workflow({ name: "prod-readiness" })` — the runner reads this folder, routes each
>  task to its model, and does implement → adversarial-verify → open-PR. See
>  `.claude/workflows/prod-readiness.js`.

## Model routing

### Wave 1 — basic functioning (do first, in order)

**Status (2026-07-11):** all eight wave-1 packages are **MERGED** to `main`.

| # | Task | Branch | Impl | Verify | Status |
|---|------|--------|------|--------|--------|
| 1 | [Neural boundary guardrail (**P0**)](w1-1-neural-guardrail.md) | `fix/neural-boundary-guardrail` | **opus** | **opus** | ✅ #37 |
| 2 | [Degenerate-input guards + `@assert`→`ArgumentError`](w1-2-stats-degenerate-inputs.md) | `fix/stats-degenerate-inputs` | sonnet | opus | ✅ #40 |
| 3 | [Table-driven router tests + CI coverage](w1-3-executor-router-coverage.md) | `test/executor-router-coverage` | sonnet | sonnet | ✅ #41 |
| 4 | [Real install path (Justfile, quickstarts, smoke CI)](w1-4-documented-install-path.md) | `fix/documented-install-path` | sonnet | haiku | ✅ #34 |
| 5 | [Pin compute half + prune Dependabot + threat model](w1-5-supply-chain-pinning.md) | `fix/supply-chain-pinning` | sonnet | sonnet | ✅ #35 |
| 6 | [Make Zig FFI compile + `zig build test` CI](w1-6-zig-ffi-compiles.md) | `fix/zig-ffi-compiles` | **opus** | sonnet | ✅ #38 |
| 7 | [Type-checking Agda proofs + `agda --safe` CI](w1-7-agda-proofs-ci.md) | `fix/agda-proofs-ci` | **opus** | sonnet | ✅ #42 |
| 8 | Hygiene / security-templates | `chore/hygiene-security-templates` | haiku | haiku | ✅ #33 |

### Wave 2 — beyond basic functioning

**Status (2026-07-11):** six of eight merged; **W2-6** and **W2-7** remain **OPEN**. A
dedicated chi-square correctness review (Yates-clamp fix + ground-truth tests) also
landed as **#47**, outside the original wave plan.

| # | Task | Branch | Impl | Verify | Status |
|---|------|--------|------|--------|--------|
| 1 | [Release: JuliaRegistrator + TagBot + SBOM](w2-1-release-pipeline.md) | `feat/release-registrator-tagbot` | **opus** | **opus** | ✅ #43 |
| 2 | [Buildable guix.scm](w2-2-guix-package.md) | `feat/guix-real-package` | **opus** | sonnet | ✅ #39 |
| 3 | [Runnable Containerfile + devcontainer](w2-3-containers.md) | `feat/containers-runnable` | sonnet | sonnet | ✅ #44 |
| 4 | [Experimental reframe: FFI + proofs docs](w2-4-experimental-reframe.md) | `docs/experimental-reframe` | sonnet | sonnet | ✅ #48 |
| 5 | [Extend ground-truth reference validation](w2-5-reference-validation.md) | `test/reference-validation-extension` | sonnet | **opus** | ✅ #46 |
| 6 | [Structured logging + audit trail](w2-6-observability.md) | `feat/structured-observability` | sonnet | sonnet | **OPEN** |
| 7 | [Prompt-injection delimiting](w2-7-prompt-injection.md) | `fix/prompt-injection-delimiting` | sonnet | haiku | **OPEN** |
| 8 | [Polish sweep](w2-8-polish-sweep.md) | `chore/polish-sweep` | haiku | haiku | ✅ #45 |

**Routing rationale.** Opus for design-sensitive, safety-critical, or niche-toolchain
work (the guarantee guardrail, release engineering, Guix, Zig/Agda, statistical
ground-truth). Sonnet for well-specified implementation. Haiku for mechanical sweeps.
Verification is adversarial — the verifier tries to *refute* the implementation against
the work order's acceptance criteria — and is deliberately assigned the model that
should be able to follow the spec: if the verify-model can't confirm it, the spec or
the code isn't done.

## Decisions of record (user-approved 2026-07-10 — do not relitigate)

1. **Release = JuliaRegistrator + TagBot** (General registry), not artifact-only.
2. **FFI (Zig/C-ABI) and Agda proofs are EXPERIMENTAL** — make them compile & CI-check
   (wave 1), reframe docs (wave 2); do NOT invest in the Idris2 ABI or proofs-over-ℝ yet.
3. **guix.scm gets made real** (buildable), not deleted — governance has a "Guix primary"
   policy check.
4. **Merge gate is active**: the Base ruleset requires the "E2E — Julia Test Suite"
   status check. A PR cannot merge red.

## Verified toolchain facts (WSL Debian, set up 2026-07-10)

- **Julia 1.10.11** via juliaup; on PATH only in a **login shell** (`bash -lc`).
  Baseline `Pkg.test()` = **4404 tests green** (Full 424 / E2E 145 / Property 3800 /
  Reference 35). ALWAYS serialize Julia runs: `flock /tmp/statistikles-julia.lock -c '…'`
  (16 GB RAM ceiling). Warm depot exists; `instantiate+precompile` ≈ 1m46s, test ≈ 36s
  after precompile.
- **Zig 0.16.0** tarball at `/home/hyperpolymath/zig/zig-x86_64-linux-0.16.0/zig`
  (also `~/.local/bin/zig` in login shells). ⚠ 0.15+/0.16 has breaking std changes
  (Io writer/reader redesign) — if the repo's Zig targets ≤0.14, fetch an older
  tarball into the same dir.
- **Agda 2.6.4.3 + agda-stdlib 2.1** (apt); stdlib wired via `~/.agda/libraries` +
  `~/.agda/defaults`. ⚠ stdlib 2.1 renamed some modules vs 1.x — expect import tweaks.

## Execution contract (every task)

- Branch from up-to-date `origin/main` using the named branch. If a wave-1 prerequisite
  is unmerged and you touch the same files, branch from that branch and say so in the PR.
- Commits SSH-signed (environment is pre-configured). End messages with the
  `Co-Authored-By` trailer for your model.
- Run the work order's **Local verification** before pushing; on 16 GB RAM, wrap Julia
  in `flock /tmp/statistikles-julia.lock`. Never claim verification you didn't run.
- Diffs surgical; match surrounding style. GitHub Actions **SHA-pinned** with a version
  comment. Never job-level `hashFiles()`/`secrets` conditionals (silent startup_failure)
  — step-level only.
- **Do not open GitHub issues** and **do not merge/delete/force-push.** Open exactly one
  PR to `main` per task, titled per the work order; body = what changed & why (file
  refs) + verification run & result + anything skipped. Stop there.
- Python is banned in repo code (governance-enforced). Deriving test constants with
  Python/R locally is fine; only the constants + a derivation note enter the repo.
