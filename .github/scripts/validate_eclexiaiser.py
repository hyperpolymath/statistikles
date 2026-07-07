# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
# Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# Validates eclexiaiser.toml structure (called by dogfood-gate.yml).
import sys
import tomllib

with open("eclexiaiser.toml", "rb") as f:
    data = tomllib.load(f)

project = data.get("project", {})
if not project.get("name", "").strip():
    print("ERROR: project.name is required", file=sys.stderr)
    sys.exit(1)

functions = data.get("functions", [])
if not functions:
    print("ERROR: at least one [[functions]] entry is required", file=sys.stderr)
    sys.exit(1)

for fn in functions:
    if not fn.get("name", "").strip():
        print("ERROR: function name cannot be empty", file=sys.stderr)
        sys.exit(1)
    if not fn.get("source", "").strip():
        print(f'ERROR: function {fn["name"]} has no source path', file=sys.stderr)
        sys.exit(1)

print(f'Valid: {project["name"]} ({len(functions)} function(s))')
