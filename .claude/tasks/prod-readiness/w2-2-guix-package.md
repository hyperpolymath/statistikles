# W2-2 · Make guix.scm a real, buildable package

**Model:** impl=opus · verify=sonnet · **Branch:** `feat/guix-real-package`

## Context

`guix.scm` is a template placeholder: synopsis is literally `{{PROJECT_PURPOSE}}`
(~line 67), native-inputs/inputs are empty (~lines 54-65), and the build/check phases
are deleted (~lines 45-53) — the only "build" copies README.adoc into share/doc. It is
not a buildable package, yet governance CI runs a "Guix primary / Nix fallback policy"
check and docs claim reproducible builds. User decision (binding): **fill it to
actually build**, do not delete.

## Requirements

1. Rewrite `guix.scm` as a real package for a Julia project: `julia` in inputs
   (Guix has a `julia` package and a `julia-build-system` — evaluate whether
   `julia-build-system` fits a project-with-Manifest layout, or use
   `copy-build-system`/`gnu-build-system` with explicit phases that (a) copy the
   project, (b) run `julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'`
   where sandbox network policy allows, or vendor via the committed Manifest.toml —
   document which strategy you chose and why in comments).
   Note Guix builds are network-isolated: if full dependency instantiation inside the
   build sandbox is not feasible, the honest scope is a package that installs the
   source tree + a launcher script and *checks* `julia -e 'using Pkg; Pkg.status()'`
   syntax-level integrity. State the limitation in a comment header — do NOT fake a
   check phase that doesn't verify anything.
2. Real `synopsis` and `description` (from README: neurosymbolic statistical analysis
   assistant — Julia computes, LLMs route). License field must match repo (MPL-2.0).
   Fill `home-page` with the GitHub URL.
3. Replace every remaining `{{...}}` placeholder in the file.
4. Verify: `guix build -f guix.scm` in a Guix environment if available; otherwise at
   minimum `guile -c '(load "guix.scm")'`-style syntax validation or
   `guix repl`-less S-expression parse check (balanced parens, valid module refs
   verified against the Guix manual), stated honestly in the PR.
5. Check `.guix-channel` at repo root for consistency with the new package
   (channel metadata must not reference missing directories).

## Acceptance criteria

- [ ] No `{{placeholders}}` remain in guix.scm.
- [ ] Package form is syntactically valid Scheme (paren-balanced, evaluable).
- [ ] Build strategy is honest — no deleted-phase-pretending-to-build; limitations
      documented in comments.
- [ ] Governance "Guix primary / Nix fallback policy" CI check still passes on the PR.
- [ ] PR body states exactly what level of build verification was possible.

## Local verification

If `guix` is installed: `guix build -f guix.scm` (or `--dry-run`). Otherwise: Scheme
syntax validation + cross-check every symbol against Guix package/module names via
web search of the Guix manual. Never claim a build you didn't run.

## Out of scope

Nix flakes; publishing to a channel; CI job running guix (note as follow-up if valuable).
