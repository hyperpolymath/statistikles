# W1-5 · Pin the compute half + prune Dependabot + real threat model

**Model:** impl=sonnet · verify=sonnet · **Branch:** `fix/supply-chain-pinning`

## Context

The Julia layer that produces every number has **no `Manifest.toml`** committed and
Dependabot lists ecosystems (mix/npm/pip/nix) that don't exist here (Julia is unsupported
by Dependabot). The trusted numeric layer is neither pinned nor vuln-monitored, and
`docs/THREAT-MODEL.md` falsely claims "lockfiles committed" and is otherwise generic
STRIDE boilerplate that never models the neurosymbolic or FFI boundary.

## Requirements

**(a)** Generate `Manifest.toml` with the SAME Julia minor as CI (1.10) —
`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.instantiate()"'`.
Remove the `Manifest.toml` ignore line from `.gitignore` and commit the manifest.
Read `e2e.yml` to confirm nothing deletes the manifest (Pkg.instantiate honours a
committed manifest by default — no workflow change needed).

**(b)** `.github/dependabot.yml`: verify each listed ecosystem against the tree; remove
dead entries; keep `github-actions` (and any genuinely present). Note in the PR body
that Julia has no Dependabot ecosystem and the committed Manifest + CI instantiate is the
compensating control.

**(c)** `docs/THREAT-MODEL.md`: add a section modelling the actual **neurosymbolic
boundary** — LLM numeric fabrication (mitigated by the W1-1 guardrail), prompt injection
via user data (W2-7), tool mis-routing, silent-null sub-types — and the **FFI/C-ABI
boundary** (memory safety, unvalidated inputs crossing the ABI). Fix false/boilerplate
claims: references to Cargo.lock/deno.lock that don't exist, the nonexistent
`scorecard-enforcer.yml`, and the "lockfiles committed" row (now true only for
Manifest.toml). Keep the existing STRIDE structure — surgical edits, not a rewrite.

## Acceptance criteria

- [ ] `Manifest.toml` tracked & committed; `.gitignore` no longer excludes it.
- [ ] dependabot.yml lists only ecosystems that exist.
- [ ] THREAT-MODEL models the neural + FFI boundaries; no false lockfile/workflow refs.
- [ ] Governance CI still green on the PR.

## Local verification

`flock … Pkg.instantiate()` produced a Manifest that `git status` shows staged; grep
THREAT-MODEL for the removed false claims.

## Out of scope

SBOM publishing (W2-1); making the FFI real.
