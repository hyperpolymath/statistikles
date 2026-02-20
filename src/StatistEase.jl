# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           STATISTEASE                                       ║
# ║           Neurosymbolic Statistical Analysis Assistant                       ║
# ║                                                                              ║
# ║  DESIGN PRINCIPLE: This system uses a neurosymbolic architecture where       ║
# ║  a Large Language Model (LLM) handles ONLY natural language understanding    ║
# ║  and interpretation. ALL mathematical and statistical computations are        ║
# ║  performed by verified symbolic Julia functions.                             ║
# ║                                                                              ║
# ║  ┌─────────────────────────────────────────────────────────────────────┐     ║
# ║  │  WARNING: NEURAL COMPUTATION OF STATISTICS IS UNRELIABLE           │     ║
# ║  │                                                                     │     ║
# ║  │  LLMs are known to:                                                │     ║
# ║  │  • Hallucinate p-values, effect sizes, and test statistics         │     ║
# ║  │  • Misapply statistical formulas                                    │     ║
# ║  │  • Invent plausible but incorrect numerical results                │     ║
# ║  │  • Confuse statistical test assumptions and applicability          │     ║
# ║  │                                                                     │     ║
# ║  │  EVERY number produced by this system comes from deterministic,    │     ║
# ║  │  auditable Julia code — NEVER from neural inference.               │     ║
# ║  │  The LLM is a ROUTER and INTERPRETER, not a calculator.           │     ║
# ║  └─────────────────────────────────────────────────────────────────────┘     ║
# ║                                                                              ║
# ║  Data Quality Pathway:                                                       ║
# ║  Raw Input → CANONICALIZATION → Detection → Validation → Cleansing →        ║
# ║  Normalization → Analysis → Result Validation → Output → Interpretation     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

module StatistEase

using Statistics
using LinearAlgebra
using Distributions
using DataFrames
using StatsBase
using CSV
using HTTP
using JSON3
using Dates
using Printf
using Random
using UUIDs

# Statistical computation modules
include("stats/descriptive.jl")
include("stats/inferential.jl")
include("stats/correlation_regression.jl")
include("stats/nonparametric.jl")
include("stats/effect_sizes.jl")
include("stats/power_analysis.jl")
include("stats/bayesian.jl")
include("stats/fuzzy_logic.jl")
include("stats/dempster_shafer.jl")
include("stats/causality.jl")
include("stats/estimation.jl")
include("stats/reliability.jl")
include("stats/validity.jl")
include("stats/measurement.jl")
include("stats/qualitative.jl")
include("stats/assumptions.jl")
include("stats/sampling.jl")

# Data pipeline (order matters — canonicalization FIRST)
include("pipeline/canonicalization.jl")       # ZEROTH: dates, decimals, constants, precedence
include("pipeline/dimensional_analysis.jl")   # FIRST: physical dimension consistency
include("pipeline/detection.jl")
include("pipeline/validation.jl")
include("pipeline/cleansing.jl")
include("pipeline/normalization.jl")

# Output
include("output/tables.jl")
include("output/graphs.jl")
include("output/export.jl")

# LM Studio interface
include("tools/definitions.jl")
include("tools/executor.jl")
include("tools/lmstudio.jl")
include("tools/chat.jl")

export main, run_examples, statistical_assistant_chat

end # module
