# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           STATISTEASE                                       ║
# ║           Neurosymbolic Statistical Analysis Assistant                       ║
# ║                                                                              ║
# ║  CORE ARCHITECTURE: Neurosymbolic Bridge                                     ║
# ║  This system enforces a strict boundary between Neural Inference (LLM)        ║
# ║  and Symbolic Computation (Julia).                                           ║
# ║                                                                              ║
# ║  1. LLM (Neural): Handles user intent extraction and final interpretation.   ║
# ║  2. Julia (Symbolic): Performs ALL math, statistics, and data validation.     ║
# ║                                                                              ║
# ║  MANDATE: No statistical calculation may be performed by the LLM.            ║
# ║  Every number in the final report is audited by deterministic code.          ║
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

# --- SYMBOLIC KERNEL: Verified Statistical Methods ---
include("stats/descriptive.jl")      # Mean, Median, Variance, Skewness
include("stats/inferential.jl")      # T-Tests, ANOVA, Chi-Square
include("stats/correlation_regression.jl")
include("stats/nonparametric.jl")    # Mann-Whitney, Wilcoxon
include("stats/effect_sizes.jl")     # Cohen's d, Hedges' g
include("stats/power_analysis.jl")   # Sample size calculation
include("stats/bayesian.jl")         # Credible intervals, MCMC
include("stats/fuzzy_logic.jl")      # Imprecise data handling
include("stats/dempster_shafer.jl")  # Evidence theory integration
include("stats/causality.jl")        # DAGs and Structural Equation Modeling

# --- DATA STEWARDSHIP: Verification Pipeline ---
# Sequence is critical: Canonicalization must occur before any logic.
include("pipeline/canonicalization.jl")       # Epochs, precision, precedence
include("pipeline/dimensional_analysis.jl")   # SI unit consistency
include("pipeline/detection.jl")              # Automatic type discovery
include("pipeline/validation.jl")             # Schema enforcement
include("pipeline/cleansing.jl")              # Outlier and NaN handling
include("pipeline/normalization.jl")          # Z-scores, Min-Max scaling

# --- INTERFACE LAYER: LLM Integration ---
include("tools/definitions.jl")  # MCP / Function calling schemas
include("tools/executor.jl")     # Safe execution sandbox
include("tools/lmstudio.jl")     # Local LLM connectivity
include("tools/chat.jl")         # Interactive session management

export main, run_examples, statistical_assistant_chat

end # module
