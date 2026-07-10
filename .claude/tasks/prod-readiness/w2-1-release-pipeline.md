# W2-1 · Release pipeline: JuliaRegistrator + TagBot + SBOM

**Model:** impl=opus · verify=opus · **Branch:** `feat/release-registrator-tagbot`

## Context

`.github/workflows/release.yml` is an unfilled template: the build job is
`echo "Build your artifacts here"` (~lines 27-29), artifact upload is commented out,
and the SLSA provenance job passes `base64-subjects: ""` which makes
slsa-github-generator **error on any `v*` tag push** — the release pipeline has never
produced a successful run (no tags exist yet). The user decided (2026-07-10, binding):
release via **JuliaRegistrator + TagBot** to the Julia General registry. Also required:
an SBOM actually published with releases (currently only a silent `|| echo` local
Justfile recipe).

## Requirements

1. **TagBot**: add `.github/workflows/TagBot.yml` using `JuliaRegistries/TagBot`
   (SHA-pinned + version comment, matching repo pinning style), triggered per TagBot
   docs (issue_comment from JuliaTagBot / workflow_dispatch). Configure `ssh: false`
   default token flow unless the repo requires otherwise.
2. **Registration path**: document — in a new `docs/RELEASING.adoc` — the exact
   maintainer flow: bump `version` in Project.toml → merge to main → comment
   `@JuliaRegistrator register` on the commit (or install the Registrator GitHub app) →
   General registry PR → TagBot cuts the GitHub release. Include first-registration
   caveats (AutoMerge requirements: [compat] completeness — `Statistics = "1"` was
   added in wave 1; name/UUID rules).
3. **release.yml rewrite**: on `v*` tags (which TagBot creates): build a source
   tarball artifact, generate an SPDX SBOM with `anchore/sbom-action` (syft,
   SHA-pinned), attach both to the GitHub release, and compute **real**
   `base64-subjects` (sha256sum of the artifacts, base64-encoded per
   slsa-github-generator docs) for the SLSA job — or, if you judge the SLSA job
   unsalvageable without binary artifacts, remove it and say so in the PR body with
   reasoning. Keep the existing git-cliff changelog step if present and functional.
4. Remove/replace all `TODO: Replace with your build commands` template residue in
   release.yml.
5. **Never** create or push a tag in this task. The pipeline must be inert until a
   maintainer registers a version.

## Acceptance criteria

- [ ] `actionlint`-clean (or careful manual YAML review if actionlint unavailable);
      every action SHA-pinned with version comment.
- [ ] No job-level `hashFiles()`/`secrets` conditionals (repo rule: step-level only).
- [ ] A dry validation of the SLSA subjects computation (run the shell snippet locally
      on a dummy file and show the output in the PR body), OR the job removed with
      justification.
- [ ] `docs/RELEASING.adoc` walks a maintainer end-to-end with zero external lookups.
- [ ] PR body includes a "first release checklist" (version bump, registrator comment,
      what to watch for in AutoMerge).

## Local verification

`actionlint` on changed workflows if available; otherwise line-by-line schema review.
Shell-test the sha256/base64 subjects snippet with a scratch file. No Julia needed.

## Out of scope

Actually registering the package; creating tags; container image releases.
