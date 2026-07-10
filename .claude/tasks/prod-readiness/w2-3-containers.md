# W2-3 · Runnable Containerfile + devcontainer

**Model:** impl=sonnet · verify=sonnet · **Branch:** `feat/containers-runnable`

## Context

Neither container surface yields a runnable app. `Containerfile` (repo root): the
build-deps section (~lines 12-16) and build commands (~21-25) are fully commented out,
no artifact is copied into the runtime stage (~30-35), the base is `chainguard/static`
(static-binary base — unusable for Julia), and ENTRYPOINT is commented out (~41).
`.devcontainer/devcontainer.json` installs git/just/nickel features but **no Julia**,
and its postCreateCommand ran the no-op `just deps` stub (wave-1 PR 4/8 made `just`
recipes real — coordinate). There is also `.devcontainer/Containerfile`.

## Requirements

1. **Containerfile**: multi-stage or single-stage image based on the official
   `docker.io/julia:1.10` image (pin by digest for reproducibility; add version
   comment). Copy the project, run
   `julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'` at build
   time, set `ENTRYPOINT ["julia", "--project=/app", "-e", "using Statistikles; main()"]`
   (verify the actual entry function in `src/Statistikles.jl` first). Respect the
   committed Manifest.toml (wave-1 PR 5/8) if present. Non-root runtime user.
2. **devcontainer.json**: add Julia via the community devcontainer feature
   (`ghcr.io/julialang/devcontainer-features/julia` — verify current id) pinned to 1.10,
   or base the devcontainer on the julia image; make postCreate run the real
   `just setup` (or `julia --project=. -e 'using Pkg; Pkg.instantiate()'` directly if
   just isn't guaranteed). Keep existing features that are real.
3. **CI**: new `.github/workflows/container-build.yml` that builds the Containerfile
   with podman or docker (`docker build .` on ubuntu-latest is simplest) on PRs
   touching Containerfile/Project.toml/Manifest.toml/src — build only, no push, no
   registry login. SHA-pin actions; step-level conditionals only.
4. Reconcile QUICKSTART "Option 2" container instructions with the now-real image
   (exact `podman build`/`podman run` commands that work).

## Acceptance criteria

- [ ] `docker build .` (or podman) completes locally, and
      `docker run <img>` reaches the Statistikles entrypoint (interactive REPL may
      just print its banner and wait — that counts; document expected behavior).
- [ ] Devcontainer JSON is schema-valid; postCreate references only real commands.
- [ ] CI build job green on the PR.
- [ ] No commented-out template blocks remain in either Containerfile.

## Local verification

`docker build`/`podman build` if a container runtime is available (state which);
otherwise rely on the new CI job and say so. JSON-validate devcontainer.json.

## Out of scope

Publishing images to a registry; multi-arch builds; guix (separate task W2-2).
