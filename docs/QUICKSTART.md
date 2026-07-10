<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Quickstart

The canonical quickstart guides live at the repository root:

- [QUICKSTART-USER.adoc](../QUICKSTART-USER.adoc) — install and run in 5 minutes
- [QUICKSTART-DEV.adoc](../QUICKSTART-DEV.adoc) — clone, build, test, PR
- [QUICKSTART-MAINTAINER.adoc](../QUICKSTART-MAINTAINER.adoc) — packaging and deployment

The short version:

```bash
git clone https://github.com/hyperpolymath/statistikles.git
cd statistikles
just setup    # julia --project=. -e 'using Pkg; Pkg.instantiate()'
just run      # julia --project=. -e 'using Statistikles; main()'
just test     # julia --project=. test/runtests.jl
```

Requires [Julia](https://julialang.org/downloads/) 1.10+ and
[just](https://github.com/casey/just). See the
[README](../README.adoc) for the full feature overview.
