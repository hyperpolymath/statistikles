#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# validate-actions-lock.sh — actions.lock must MATCH the workflows it locks.
#
# WHY THIS EXISTS
# ---------------
# This repo declares its action surface twice: once in the workflows (`uses:`),
# once in `.github/workflows/actions.lock`. Nothing kept the two in step, and
# GitHub refuses the RUN (not the file) when they drift, so the failure is
# invisible to every YAML parser while the board shows nothing at all.
#
# Measured in this repository, twice:
#
#   1. 2026-09-25 — `chore(deps): bump github/codeql-action from 4.38.0 to
#      4.38.1` (dependabot) rewrote both `uses:` lines in `codeql.yml` and did
#      not touch the lock. CodeQL Security Analysis has been a
#      `startup_failure` with zero jobs ever since, annotated:
#         Invalid lockfile: .github/workflows/actions.lock#L1 —
#         "The lockfile could not be validated. Regenerate it by running
#          `gh actions-lock`."
#      The lock still listed `github/codeql-action@v4.38.0`; the workflow says
#      `@v4.38.1`. That was the whole defect.
#   2. 2026-09-21 — `fix(ci): reconcile actions.lock so the lockfile validates`
#      (63b7ab7 / 1715d4f) was the same repair, done by hand, after the same
#      class of drift. It recurred four days later, which is why this is a gate
#      and not a note.
#
# WHY IT DOES NOT NEED `gh actions-lock`
# --------------------------------------
# The tool resolves refs to commits; it does not decide coverage. GitHub's own
# coverage rule is visible in the refusals this repo has already collected: a
# ref pinned to a full 40-hex commit is immutable and needs no lock entry, and
# every other ref (tag or branch) must be in the lock. The `zz-m5` probe, which
# pinned the standards reusable by SHA and had no lock section, started fine;
# `zz-pages-perms-probe`, which pinned `actions/checkout@v7.0.1` and
# `actions/upload-pages-artifact@v5.0.0` with no lock section, was refused ten
# runs out of ten (run 36177415819: "The actions … are not allowed … because
# all actions must be from a repository owned by hyperpolymath, created by
# GitHub, verified in the GitHub Marketplace, or match one of the patterns
# …"). That is the rule this checker mirrors, and it mirrors it WITHOUT the
# network: `gh actions-lock` could not be installed in the environment that
# wrote this (its release asset download EOFs), and a gate that needs a working
# third-party download to tell you the lock is stale is not a backstop.
#
# WHAT IT CHECKS (and what it deliberately does not)
# --------------------------------------------------
#   FAIL  lock section exists and disagrees with the file        (case 1 above)
#   FAIL  the lock has a section for a workflow file that no longer exists
#         (a deleted workflow left in the lock is the same drift, inverted)
#   FAIL  a locked ref has no `dependencies:` entry, or its entry's `ref:`
#         disagrees with the key, or it has no `commit: 'sha1-<40 hex>'`
#   WARN  a file uses a tag/branch ref and has NO lock section. Not a failure:
#         the org's refusal path here has been observed but is not documented
#         by GitHub, and the estate's own gate treats an absent lock as a
#         warning until it can be regenerated. It is still printed, because
#         silence is what this repo keeps writing postmortems about.
#   NOT   resolving refs → commits (that is `gh actions-lock`'s job, run by the
#         governance reusable), or deciding whether a ref is ALLOWED.
#
# Usage: .githooks/validate-actions-lock.sh [workflow-dir] [lockfile]
#   defaults: .github/workflows/ and .github/workflows/actions.lock

set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

DIR="${1:-.github/workflows}"
LOCK="${2:-$DIR/actions.lock}"

if [ ! -f "$LOCK" ]; then
  echo "validate-actions-lock: no lockfile at $LOCK — nothing to verify"
  echo "  (the estate's gate treats a repo without a lock as red only while"
  echo "   unpinned refs remain; see check-actions-lock-gate.sh)"
  exit 0
fi

files=$(find "$DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
if [ -z "$files" ]; then
  echo "validate-actions-lock: no workflow files in $DIR" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- parse lock
cat > "$tmp/parse.awk" <<'AWK'
# Records emitted from actions.lock:
#   SECTION   <workflow-path>
#   REF       <workflow-path> <ref>        locked refs, lowercased
#   DEP       <ref>                        dependency keys, lowercased
#   DEPREF    <ref> <ref-field>            the tag/branch the key stands for
#   DEPCOMMIT <ref> <commit-field>
BEGIN { mode = 0; dep = ""; section = "" }
/^[[:space:]]*#/               { next }
/^workflows:[[:space:]]*$/     { mode = 1; next }
/^dependencies:[[:space:]]*$/  { mode = 2; next }
/^[^[:space:]]/                { mode = 0 }
mode == 1 && /^[[:space:]][[:space:]][[:space:]][[:space:]][^[:space:]]/ {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    sub(/:.*/, "", line)
    gsub(/["'\'']/, "", line)
    section = line
    print "SECTION\t" section
    next
}
mode == 1 && /^[[:space:]]+-[[:space:]]/ {
    ref = $0
    sub(/^[[:space:]]+-[[:space:]]*/, "", ref)
    gsub(/["'\'']/, "", ref)
    print "REF\t" section "\t" tolower(ref)
    next
}
mode == 2 && /^[[:space:]][[:space:]][[:space:]][[:space:]][^[:space:]]/ {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    sub(/:.*/, "", line)
    gsub(/["'\'']/, "", line)
    dep = tolower(line)
    print "DEP\t" dep
    next
}
mode == 2 && dep != "" && /^[[:space:]]+ref:/ {
    line = $0
    sub(/^[[:space:]]+ref:[[:space:]]*/, "", line)
    gsub(/["'\'']/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    print "DEPREF\t" dep "\t" tolower(line)
    next
}
mode == 2 && dep != "" && /^[[:space:]]+commit:/ {
    line = $0
    sub(/^[[:space:]]+commit:[[:space:]]*/, "", line)
    gsub(/["'\'']/, "", line)
    print "DEPCOMMIT\t" dep "\t" line
}
AWK
awk -f "$tmp/parse.awk" "$LOCK" > "$tmp/lock.tsv"

awk -F'\t' '$1 == "SECTION" { print $2 }'            "$tmp/lock.tsv" | sort -u > "$tmp/sectionkeys.txt"
awk -F'\t' '$1 == "REF"     { print $2 "\t" $3 }'    "$tmp/lock.tsv" | sort -u > "$tmp/sections.tsv"
awk -F'\t' '$1 == "DEP"     { print $2 }'            "$tmp/lock.tsv" | sort -u > "$tmp/deps.txt"
awk -F'\t' '$1 == "DEPREF"  { print $2 "\t" $3 }'    "$tmp/lock.tsv" > "$tmp/deprefs.tsv"
awk -F'\t' '$1 == "DEPCOMMIT" { print $2 "\t" $3 }'  "$tmp/lock.tsv" > "$tmp/depcommits.tsv"

# ---------------------------------------------------- refs a workflow needs
# A `uses:` ref needs a lock entry unless it is local, a container, dynamic, or
# pinned to a full 40-hex commit (immutable by construction).
workflow_refs() {
  sed -nE 's/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*([^[:space:]#]+).*/\2/p' "$1" |
  while IFS= read -r ref; do
    case "$ref" in
      ./*|docker://*|'$'*) continue ;;
      *@*) ;;
      *) continue ;;
    esac
    target="${ref%@*}"
    rev="${ref##*@}"
    if [[ "$rev" =~ ^[0-9a-f]{40}$ ]]; then continue; fi
    owner="${target%%/*}"
    rest="${target#*/}"
    repo="${rest%%/*}"
    printf '%s/%s@%s\n' "${owner,,}" "${repo,,}" "${rev,,}"
  done
}

fails=0
warns=0

for f in $files; do
  refs=$(workflow_refs "$f" | sort -u)
  key="${f#./}"
  if ! grep -qxF "$key" "$tmp/sectionkeys.txt"; then
    if [ -n "$refs" ]; then
      warns=$((warns + 1))
      echo "WARN: $key uses tag/branch refs but has no section in $(basename "$LOCK"):"
      # shellcheck disable=SC2086
      printf '        %s\n' $refs
      echo "      (SHA-pinned refs need no entry; these are what the lock is for)"
    fi
    continue
  fi

  section=$(awk -F'\t' -v k="$key" '$1 == k { print $2 }' "$tmp/sections.tsv" | sort -u)
  if [ "$refs" != "$section" ]; then
    fails=$((fails + 1))
    echo "FAIL: $key and $(basename "$LOCK") disagree — GitHub refuses the RUN, not the file"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      printf '%s\n' "$refs" | grep -qxF "$r" || echo "        lock lists it, the workflow does not: $r"
    done <<EOF
$section
EOF
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      printf '%s\n' "$section" | grep -qxF "$r" || echo "        workflow uses it, the lock does not: $r"
    done <<EOF
$refs
EOF
  fi
done

# ------------------------------------------- sections for files that are gone
while IFS= read -r key; do
  [ -n "$key" ] || continue
  if [ ! -f "$key" ]; then
    fails=$((fails + 1))
    echo "FAIL: $(basename "$LOCK") has a section for $key, which does not exist"
    echo "        dangling section (regenerate the lock, or restore the file)"
  fi
done < "$tmp/sectionkeys.txt"

# ------------------------------------------ locked refs must resolve in-lock
while IFS=$'\t' read -r key ref; do
  [ -n "$ref" ] || continue
  if ! grep -qxF "$ref" "$tmp/deps.txt"; then
    fails=$((fails + 1))
    echo "FAIL: $key locks '$ref' with no 'dependencies:' entry — the lock cannot resolve it"
    continue
  fi
  slashrev="${ref##*@}"
  if ! [[ "$slashrev" =~ ^[0-9a-f]{40}$ ]]; then
    depref=$(awk -F'\t' -v r="$ref" '$1 == r { print $2 }' "$tmp/deprefs.tsv" | head -1)
    if [ "$depref" != "$slashrev" ]; then
      fails=$((fails + 1))
      echo "FAIL: dependency '$ref' declares ref '${depref:-none}' — it must be '$slashrev'"
    fi
  fi
  commit=$(awk -F'\t' -v r="$ref" '$1 == r { print $2 }' "$tmp/depcommits.tsv" | head -1)
  if ! [[ "$commit" =~ ^sha1-[0-9a-f]{40}$ ]]; then
    fails=$((fails + 1))
    echo "FAIL: dependency '$ref' has no well-formed commit (want sha1-<40 hex>, got '${commit:-none}')"
  fi
done < "$tmp/sections.tsv"

if [ "$fails" -gt 0 ]; then
  echo
  echo "validate-actions-lock: $fails problem(s) — regenerate with 'gh actions-lock'"
  echo "and commit actions.lock in the SAME commit as the 'uses:' change."
  exit 1
fi

nfiles=$(wc -l < "$tmp/sectionkeys.txt" | tr -d ' ')
nrefs=$(wc -l < "$tmp/sections.tsv" | tr -d ' ')
echo "validate-actions-lock: all $nfiles locked workflow file(s) match ($nrefs refs resolve), $warns unlocked"
