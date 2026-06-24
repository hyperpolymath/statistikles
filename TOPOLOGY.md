<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
<!-- TOPOLOGY.md — StatistEase architecture map and completion dashboard -->
<!-- Last updated: 2026-02-20 -->

# StatistEase — Project Topology

## System Architecture

```
                    ┌──────────────────────────────────┐
                    │         USER (natural language)   │
                    │   "Is there a significant diff?"  │
                    └──────────────┬───────────────────┘
                                   │
                    ═══════════════╪═══════════════════  NEURAL LAYER
                                   ▼
                    ┌──────────────────────────────────┐
                    │         LM STUDIO (LOCAL LLM)    │
                    │  ┌────────┐  ┌────────────────┐  │
                    │  │ NLU    │  │ Tool Selection  │  │
                    │  │ (parse)│  │ (function call) │  │
                    │  └────────┘  └───────┬────────┘  │
                    └──────────────────────┼───────────┘
                                           │ tool_call JSON
                    ═══════════════════════╪═══════════  BOUNDARY
                          MOLLOCK GATE     │              (executor.jl)
                          ⚠️ No neural     │
                          numbers pass ⚠️  │
                    ═══════════════════════╪═══════════  SYMBOLIC LAYER
                                           ▼
                    ┌──────────────────────────────────┐
                    │      JULIA COMPUTATION ENGINE     │
                    │                                    │
                    │  ┌─────────────┐ ┌─────────────┐ │
                    │  │ PIPELINE    │ │ STATISTICS   │ │
                    │  │             │ │              │ │
                    │  │ Detection   │ │ Descriptive  │ │
                    │  │ Validation  │ │ Inferential  │ │
                    │  │ Cleansing   │ │ Correlation  │ │
                    │  │ Normaliz.   │ │ Nonparam.    │ │
                    │  └──────┬──────┘ │ Effect Size  │ │
                    │         │        │ Power        │ │
                    │         ▼        │ Bayesian     │ │
                    │  ┌─────────────┐ │ Fuzzy/DS     │ │
                    │  │ OUTPUT      │ │ Causality    │ │
                    │  │             │ │ Estimation   │ │
                    │  │ Tables      │ │ Reliability  │ │
                    │  │ Graphs      │ │ Validity     │ │
                    │  │ CSV/JSON    │ │ Measurement  │ │
                    │  │ Reports     │ │ Qualitative  │ │
                    │  └─────────────┘ │ Assumptions  │ │
                    │                  │ Sampling     │ │
                    │                  └─────────────┘ │
                    └──────────────────────────────────┘
                                   │
                    ═══════════════╪═══════════════════  VERIFICATION
                                   ▼                     (PLANNED)
                    ┌──────────────────────────────────┐
                    │     ADVERSARIAL VERIFICATION      │
                    │                                    │
                    │  ┌──────────┐  ┌───────────────┐ │
                    │  │ Socratic │  │ Neurosymbolic │ │
                    │  │ SLM      │  │ Auditor       │ │
                    │  │ (indep.) │  │ (OpenCyc/DPL) │ │
                    │  └────┬─────┘  └───────┬───────┘ │
                    │       │                │          │
                    │       ▼                ▼          │
                    │  ┌──────────────────────────────┐│
                    │  │ echidna (GraphQL proofs)     ││
                    │  │ explain / prove / demonstrate ││
                    │  └──────────────────────────────┘│
                    └──────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE ARCHITECTURE
  Julia computation engine          ██████████ 100%    17 statistical modules
  LM Studio integration             ██████████ 100%    25+ tools, function calling
  Neural-symbolic boundary           ██████████ 100%    executor.jl gate with MOLLOCK rule
  System prompt governance           ██████████ 100%    Hard "never compute" instructions

DATA QUALITY PATHWAY
  Detection (type/format)            ██████████ 100%    Scale detection + file format
  Validation (range/integrity)       ██████████ 100%    Range, variance, infinity checks
  Cleansing (outliers/missing)       ██████████ 100%    IQR/z-score, imputation, dedup
  Normalization (transform/NF)       ██████████ 100%    Z-score, min-max, log, 1NF-3NF

OUTPUT
  Terminal tables (Unicode)          ██████████ 100%    Box-drawing, alignment, formatting
  ASCII graphs                       ██████████ 100%    Histogram, boxplot, scatter, bar
  Data export (CSV/JSON)             ██████████ 100%    Pretty JSON, flat CSV
  Report generation                  ██████████ 100%    Multi-section text reports

VERIFICATION (PLANNED)
  explain_that (mathematical)        ░░░░░░░░░░   0%    Trace to mathematical proofs
  prove_that (formal)                ░░░░░░░░░░   0%    echidna GraphQL integration
  demonstrate_that (visual)          ░░░░░░░░░░   0%    R/Julia walkthrough generation
  annotate_that (detailed)           ░░░░░░░░░░   0%    Code + mathematical working
  verify_that (adversarial)          ░░░░░░░░░░   0%    Neurosymbolic SLM auditor

INFRASTRUCTURE
  RSR template compliance            ██████████ 100%    All RSR files present
  Tests                              ░░░░░░░░░░   0%    Not yet written
  CI/CD                              ░░░░░░░░░░   0%    Workflows present, not configured

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ██████░░░░  60%    Core complete, verification planned
```

## Key Dependencies

```
LM Studio (local) ──► StatistEase ──► Julia stdlib (Statistics, LinearAlgebra)
                          │                │
                          │                ├── Distributions.jl
                          │                ├── StatsBase.jl
                          │                ├── DataFrames.jl
                          │                └── HTTP.jl / JSON3.jl
                          │
                          ▼ (planned)
                     echidna (GraphQL) ──► Formal proof verification
                     adversarial SLM ───► Independent neurosymbolic audit
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
