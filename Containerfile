# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Containerfile for Statistikles
# Build: podman build -t statistikles:latest -f Containerfile .
# Run:   podman run --rm -it statistikles:latest
# Seal:  selur seal statistikles:latest
#
# Statistikles is a pure Julia package with no compiled binary artifact (see
# "Build from Source" in QUICKSTART-MAINTAINER.adoc) — the `julia` executable
# itself is the runtime, so there is nothing a separate build stage could
# hand off that the runtime doesn't also need. A single stage on the official
# Julia image is therefore correct here, not a shortcut. Chainguard ships no
# Julia package, so the org-default Wolfi/static base (docs/AI-CONVENTIONS.md)
# does not apply to this stack.

# docker.io/library/julia:1.10 == Julia 1.10.11 (Debian trixie), matching the
# `julia_version` pinned in the committed Manifest.toml and .tool-versions.
FROM docker.io/library/julia:1.10@sha256:12477d07306333f0c59c04274196432a3834f8c44a0a10585de659fbf8ab0e54

# Non-root runtime user
RUN useradd --create-home --uid 1000 --shell /bin/bash statistikles
WORKDIR /app
COPY --chown=statistikles:statistikles . .
USER statistikles
ENV JULIA_DEPOT_PATH=/home/statistikles/.julia

# Resolve the committed Manifest.toml exactly (no re-resolution) and
# precompile so the entrypoint starts promptly.
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# `main()` (src/tools/chat.jl) prints the startup banner, then tries to reach
# an LM Studio-compatible endpoint (STATISTIKLES_LM_URL, default
# http://localhost:1234/v1). With no LLM endpoint reachable from the
# container it prints "Cannot connect..." and runs the offline
# `run_examples()` demo instead, then exits 0 — it does not hang waiting for
# input. Run with `--network=host` to reach a host-side LM Studio at the
# default address for the interactive chat session instead. NOTE: setting
# STATISTIKLES_LM_URL at `docker/podman run` time has no effect — Julia's
# Pkg.precompile() above already baked the default URL into the package's
# precompile cache; to change it, set STATISTIKLES_LM_URL as an image build
# ENV before the RUN Pkg.precompile() line and rebuild.
ENTRYPOINT ["julia", "--project=/app", "-e", "using Statistikles; main()"]
