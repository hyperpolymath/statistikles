#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# validate-workflow-yaml.sh — every .github/workflows/*.yml must PARSE.
#
# WHY THIS EXISTS
# ---------------
# A malformed workflow is not a red check. GitHub Actions rejects it at PARSE
# time, which produces zero jobs and NO CHECK RUN AT ALL — the gate silently
# ceases to exist while the board still reads green. `gh pr checks` shows
# nothing wrong. The only visible tell is that `gh run list` starts printing the
# workflow's PATH instead of its NAME.
#
# This repo has hit that twice in one day, from the same cause both times: a
# sweep that appends `actions: read` after every `permissions:` line. Four
# workflows declare permissions in the SCALAR form —
#
#     permissions: read-all
#
# — and hanging a mapping key under a scalar is invalid YAML:
#
#     permissions: read-all
#       actions: read        # "mapping values are not allowed here"
#
# It was fixed in PR #64 and reintroduced by PR #68, because the sweep matched
# `permissions:` as TEXT rather than as a YAML node. The insertion is redundant
# regardless: `read-all` already grants every read scope, `actions: read`
# included.
#
# So this check is deliberately dumb and total: parse every workflow, fail on
# any that does not. It cannot be satisfied by a sweep that only looks at text.
#
# MEASURED 2026-09-25 — three more ways a file "parses" and is still rejected:
#
#   1. DUPLICATE KEYS. `release.yml` carried `contents: read` and
#      `contents: write` in the same `permissions:` map (the read line was
#      appended by the #98 sweep on top of an existing write line). GitHub
#      answers "Invalid workflow file: (Line: 199, Col: 7): 'contents' is
#      already defined" and produces a `failure` run with zero jobs, no log and
#      no check run. yaml.safe_load resolves the duplicate and reports SUCCESS,
#      so the parse check alone cannot see it — the node tree can.
#   2. NO `on:` KEY. `zz-m3-no-on.yml` was the deliberate probe for this; the
#      answer GitHub gave is "No event triggers defined in `on`" — again a
#      0-job `failure` and no check run, on every push, forever.
#   3. `timeout-minutes` ON A REUSABLE-WORKFLOW CALL JOB. Also rejected before
#      any job is created (this one is in the estate's canonical parser,
#      standards@092deda tools/policy/check-workflows-parse.sh).
#
# The first two are measured in this repository's own history, not imported
# theory, so the local backstop now reads for them too.

set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "validate-workflow-yaml: python3 not found — cannot verify workflows" >&2
  exit 1
fi

python3 - "$@" <<'PY'
import glob, sys

try:
    import yaml
    from yaml.nodes import MappingNode, SequenceNode
except ImportError:
    print("validate-workflow-yaml: PyYAML not installed — cannot verify workflows",
          file=sys.stderr)
    sys.exit(1)


def duplicate_keys(node, path=""):
    """Keys repeated at the same mapping level, as (dotted path, line) pairs.

    Only the composed node tree can see these: `yaml.safe_load` keeps the LAST
    duplicate and reports success, which is why a duplicate-key file passes
    every ordinary parser and linter while GitHub refuses to run it."""
    found = []
    if isinstance(node, MappingNode):
        seen = set()
        for key_node, value_node in node.value:
            key = key_node.value
            here = f"{path}.{key}" if path else str(key)
            if key in seen:
                found.append((here, key_node.start_mark.line + 1))
            seen.add(key)
            found.extend(duplicate_keys(value_node, here))
    elif isinstance(node, SequenceNode):
        for index, item in enumerate(node.value):
            found.extend(duplicate_keys(item, f"{path}[{index}]"))
    return found


files = sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml"))
if not files:
    print("validate-workflow-yaml: no workflow files found", file=sys.stderr)
    sys.exit(1)

bad = []
for f in files:
    with open(f, encoding="utf-8") as handle:
        source = handle.read()
    try:
        doc = yaml.safe_load(source)
        tree = yaml.compose(source)
    except Exception as e:
        bad.append((f, str(e).splitlines()[0]))
        continue
    # A workflow that parses but has no jobs is equally inert.
    if not isinstance(doc, dict) or not doc.get("jobs"):
        bad.append((f, "parses but declares no jobs — would run nothing"))
        continue
    # GitHub: "Invalid workflow file: (Line: N, Col: M): 'key' is already defined"
    for where, line in duplicate_keys(tree):
        bad.append((f, f"duplicate key '{where.split('.')[-1]}' at line {line} — "
                       f"GitHub rejects the whole file at parse time"))
    # GitHub: "No event triggers defined in `on`"
    # PyYAML implements YAML 1.1, where a bare `on:` key is the BOOLEAN True —
    # so `doc.get("on")` is None for every correct workflow in this repo. Look
    # for the string key first (quoted `"on":`), then the 1.1 boolean spelling.
    triggers = doc["on"] if "on" in doc else doc.get(True)
    if not triggers:
        bad.append((f, "declares no event trigger (`on:`) — GitHub rejects the "
                       "whole file at parse time"))
    # GitHub: a reusable-workflow call job cannot declare timeout-minutes.
    for name, job in (doc.get("jobs") or {}).items():
        if isinstance(job, dict) and "uses" in job and "timeout-minutes" in job:
            bad.append((f, f"job '{name}' calls a reusable workflow and also "
                           f"declares timeout-minutes — GitHub rejects the run "
                           f"before creating any jobs"))

if bad:
    print("ERROR: unparseable or inert workflow(s) — these produce NO check run,")
    print("       not a red X, so CI would look green while the gate is dead:\n")
    for f, err in bad:
        print(f"  {f}\n      {err}")
    print("\nIf this is `actions: read` under `permissions: read-all`, delete the")
    print("added line: `read-all` already grants every read scope.")
    print("If it is a duplicate key, delete the line that duplicates an existing")
    print("key in the same mapping — a duplicate is a parse error, not an override.")
    sys.exit(1)

print(f"validate-workflow-yaml: all {len(files)} workflows parse, declare jobs,")
print("                        carry an `on:` trigger and have no duplicate keys")
PY
