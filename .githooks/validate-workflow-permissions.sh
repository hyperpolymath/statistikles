#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# validate-workflow-permissions.sh — deploy/OIDC credentials must be granted
# per JOB, never workflow-wide.
#
# WHY THIS EXISTS
# ---------------
# `pages.yml` granted `pages: write` and `id-token: write` at WORKFLOW level
# (SonarCloud MAJOR, issue #66). Every job in the file inherited them, including
# `build` — the job that compiles checked-out source inside a container. A build
# step has no use for either scope, so the file handed a compiler-run token the
# right to publish to Pages and to mint an OIDC token.
#
# OIDC is the reason this is a gate and not a style nit. An `id-token` is a JWT
# minted by GitHub and exchanged for short-lived credentials in OTHER systems:
# it is the one scope in a workflow whose blast radius leaves the repository.
# `pages: write` publishes the site, i.e. it writes to a surface users read.
# Neither is a scope a job should inherit because a NEIGHBOURING job needed it.
#
# The fix is structural, and GitHub's semantics do the work: a job-level
# `permissions:` block does not extend the workflow-level map, it REPLACES it
# for that job. A read-only workflow floor plus per-job grants is therefore both
# the least-privilege shape and the easiest one to audit — the deploy job names
# its two scopes, and nothing else in the file can hold them.
#
# WHY IT GATES ONLY THOSE TWO SCOPES
# ----------------------------------
# `security-events: write` and `issues: write` appear at workflow level in this
# repo on purpose (the wrapper callers raise the floor for the reusable they
# call). They are deliberately NOT flagged: a gate that fires on accepted
# practice gets muted, and a muted gate is the thing this repo keeps writing
# postmortems about. `write-all` IS flagged at any level — it is the same defect
# with a wider net and there is never a reason to need it here.
#
# SCOPE — stated, not implied:
#   * Checked: the workflow-level `permissions:` map (or scalar), and any
#     `write-all` anywhere in the file.
#   * NOT checked: whether a job that deploys declares the scopes it needs. A
#     missing floor fails loudly at runtime (the deploy step errors and names
#     the permission), so there is nothing silent to catch.
#   * NOT checked: `uses:` pins, `on:` triggers, YAML validity — those belong to
#     validate-workflow-yaml.sh and validate-actions-lock.sh.
#
# Usage: .githooks/validate-workflow-permissions.sh [workflow-file-or-dir ...]
#   With no arguments, every .github/workflows/*.yml{,yaml} in the repo.

set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "validate-workflow-permissions: python3 not found — cannot verify workflows" >&2
  exit 1
fi

python3 - "$@" <<'PY'
import glob, os, sys

try:
    import yaml
except ImportError:
    print("validate-workflow-permissions: PyYAML not installed — cannot verify workflows",
          file=sys.stderr)
    print("  (the container/runner image must provide python3 + PyYAML, as the",
          "sibling validate-workflow-yaml.sh already requires)", file=sys.stderr)
    sys.exit(1)

DEPLOY_SCOPES = ("pages", "id-token")

def expand(path):
    """Return a non-directory path in a list, or the sorted ``.yml`` and
    ``.yaml`` entries directly inside a directory."""
    if os.path.isdir(path):
        return sorted(glob.glob(os.path.join(path, "*.yml")) +
                      glob.glob(os.path.join(path, "*.yaml")))
    return [path]

paths = sys.argv[1:]
if paths:
    files = [f for p in paths for f in expand(p)]
else:
    files = sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml"))

if not files:
    print("validate-workflow-permissions: no workflow files found", file=sys.stderr)
    sys.exit(1)

findings = []
for f in files:
    try:
        doc = yaml.safe_load(open(f))
    except Exception as e:
        # Unparseable is another gate's finding, not a pass here. Report it so
        # this check can never be vacuously green on a file it never read.
        findings.append((f, "<file does not parse>", str(e).splitlines()[0]))
        continue
    if not isinstance(doc, dict):
        findings.append((f, "top level", "not a mapping — cannot evaluate permissions"))
        continue

    top = doc.get("permissions")

    # `permissions: write-all` (scalar) grants every scope, these two included.
    if isinstance(top, str) and top.strip().lower() == "write-all":
        findings.append((f, "workflow", "permissions: write-all — grants every write scope, "
                                        "including pages/id-token"))
    elif isinstance(top, dict):
        for scope, level in top.items():
            if scope in DEPLOY_SCOPES and str(level).lower() == "write":
                findings.append((f, f"workflow-level {scope}: write",
                                 "deploy/OIDC credential is workflow-wide — every job in the file "
                                 "can mint it or publish with it"))

    for job_name, job in (doc.get("jobs") or {}).items():
        if not isinstance(job, dict):
            continue
        perms = job.get("permissions")
        if isinstance(perms, str) and perms.strip().lower() == "write-all":
            findings.append((f, f"job {job_name}", "permissions: write-all — name the scopes "
                                                   "this job actually needs"))

print(f"validate-workflow-permissions: examined {len(files)} workflow file(s) "
      f"for workflow-wide {('/'.join(DEPLOY_SCOPES))} grants")

if findings:
    print()
    print("ERROR: deploy/OIDC credentials granted wider than a single job:")
    print()
    for f, where, why in findings:
        print(f"  {f}")
        print(f"      at {where}: {why}")
    print()
    print("Fix — floor read-only at the top, raise it inside the one job that needs it:")
    print()
    print("    permissions:")
    print("      contents: read          # workflow floor, read-only")
    print("    jobs:")
    print("      deploy:")
    print("        permissions:          # REPLACES the floor for this job")
    print("          pages: write")
    print("          id-token: write")
    print()
    print("See issue #66. If a file genuinely needs one of these scopes workflow-wide,")
    print("the answer is still a job-level grant — the job that needs it names it.")
    sys.exit(1)

print("validate-workflow-permissions: no workflow-wide deploy/OIDC grants — PASS")
PY
