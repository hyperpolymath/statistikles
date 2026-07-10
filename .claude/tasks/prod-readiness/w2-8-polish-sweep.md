# W2-8 · Polish sweep (mechanical P2 cleanup)

**Model:** impl=haiku · verify=haiku · **Branch:** `chore/polish-sweep`

## Context

A batch of low-risk P2 items from the audit. Each is small and mechanical. Skip any that
a wave-1 PR already resolved (check `git log`/the file before editing) and note skips in
the PR body. **Purely mechanical — introduce no behavior change beyond what's listed.**

## Requirements (do each; verify the file first)

1. **Undefined-stat sentinels → null+reason**: if not already handled by W1-2, ensure
   `harmonic_mean`, `cv`, `geometric_mean` return `nothing` + a `"note"` on undefined
   input (grep `src/stats` for these).
2. **`.tool-versions`**: add `julia 1.10.x` (match CI) if W1-4 didn't.
3. **`Project.toml` [compat]**: add `Statistics = "1"` and, for AutoMerge quiet,
   `Dates`/`LinearAlgebra`/`Printf`/`Random`/`UUIDs = "1"` if not present.
4. **README module count**: if W1-4 didn't fix it, correct "17 modules" to the real
   `src/stats/*.jl` count.
5. **SHA-pin version comments**: normalize inconsistent annotations (same checkout SHA
   commented `# v7.0.0` in one workflow and `# v4` in another) to the true tag across
   `.github/workflows/*`.
6. **Template banners**: remove any remaining "delete before publishing" banners in
   `CODE_OF_CONDUCT.md` / `docs/AI_INSTALLATION_GUIDE.adoc` (W1-8/#33 did SECURITY.md +
   security.txt; check these two).
7. **`build.zig`** dead refs (`include/statistikles.h`, `bench/bench.zig`): if W1-6
   didn't remove them, do so.
8. **Duplicate CODEOWNERS / dead `tests/`**: if #33 didn't fully resolve, keep one
   `.github/CODEOWNERS`, remove dead entries.

## Explicitly DO NOT

- Touch `.gitlab-ci.yml` or `deny.toml` (flagged as scaffolding but carry load-bearing
  policy claims — a separate decision; note as recommended follow-up in the PR body).
- Delete `generated/` again (#33 handled it).
- Make any behavioral/statistical change beyond the null-sentinel item.

## Acceptance criteria

- [ ] Each item done OR explicitly noted as already-resolved-by-a-prior-PR.
- [ ] No `{{placeholder}}`/template banner remains in touched files.
- [ ] Full suite green (if any `src/` touched) — else N/A stated.

## Local verification

If `src/` touched: `flock /tmp/statistikles-julia.lock -c '… Pkg.test()'`. Otherwise grep
confirmations per item.

## Out of scope

`.gitlab-ci.yml`/`deny.toml` decision; anything requiring judgment beyond the list.
