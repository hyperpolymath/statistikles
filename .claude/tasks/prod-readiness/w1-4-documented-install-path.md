# W1-4 · Make the documented install path real

**Model:** impl=sonnet · verify=haiku · **Branch:** `fix/documented-install-path`

## Context

`QUICKSTART-USER.adoc` drives `just setup`/`just run`/`just deps`, but `setup` doesn't
exist, `run` prints "Run not configured yet" (`Justfile:347-349`), `deps`/`build` are
no-op echoes with TODOs. A new user following the documented quickstart cannot install
or run. Only the raw README `julia --project=.` path works. Four quickstarts diverge;
`docs/QUICKSTART.md` even clones a different repo.

## Requirements

**(a) Justfile** — real recipes wrapping the working commands:
`setup: julia --project=. -e 'using Pkg; Pkg.instantiate()'`; `deps:` alias/dependency
of setup; `build: julia --project=. -e 'using Pkg; Pkg.precompile()'`;
`run: julia --project=. -e 'using Statistikles; main()'`. Keep the test recipe correct.
If docs reference `stapeln-run`, either alias it to `run` or drop the reference — be
consistent.

**(b) Quickstarts** — replace remaining template placeholder content in
`QUICKSTART-USER.adoc` (token list ~line 4, "See README.adoc" body) with a real minimal
quickstart matching the new recipes; correct expected-output claims (check what
`src/Statistikles.jl` `main()` actually prints — don't promise unprinted strings).
`QUICKSTART-DEV.adoc`: replace `{{BUILD_CMD}}`/`{{TEST_CMD}}`/`{{LANG_STACK}}` with real
Julia commands; fix references to nonexistent `just setup-dev`/`panic-scan`/`flake.nix`/
`tests/` (tests live in `test/`). `QUICKSTART-MAINTAINER.adoc`: trim references to
missing recipes. `docs/QUICKSTART.md`: reconcile to statistikles or reduce to a pointer.
**One canonical, tested command story.**

**(c) `.tool-versions`:** add `julia` pinned to the CI minor (check `e2e.yml` — 1.10.x).

**(d) `README.adoc`:** fix the module-count claim (says 17; count `src/stats/*.jl` and
state the real number — audit found ~40).

**(e) NEW `.github/workflows/install-smoke.yml`:** ubuntu-latest; SHA-pinned
`actions/checkout` + `julia-actions/setup-julia` (1.10) matching repo pinning style;
install `just` (SHA-pinned action or apt); run `just setup && julia --project=. -e 'using Statistikles' && just --list`.
NO job-level `hashFiles()`/`secrets` conditionals — step-level only.

## Acceptance criteria

- [ ] Every recipe referenced by any quickstart exists in the Justfile (grep-verified).
- [ ] No `{{placeholders}}` remain in touched docs.
- [ ] install-smoke.yml is schema-valid and SHA-pinned.
- [ ] README module count matches reality.

## Local verification

In WSL: `sudo apt-get install -y just` (NOPASSWD sudo), then `just --list` in the repo
parses; grep that every quickstart-referenced recipe exists. Optionally `just setup`
under the Julia lock.

## Out of scope

Container/devcontainer install (W2-3); release (W2-1).
