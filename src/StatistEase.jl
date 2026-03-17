# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

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
include("stats/nonparametric.jl")    # Mann-Whitney, Wilcoxon, PERMANOVA, Friedman, Cochran's Q
include("stats/effect_sizes.jl")     # Cohen's d, Hedges' g
include("stats/power_analysis.jl")   # Sample size calculation
include("stats/bayesian.jl")         # Credible intervals, MCMC
include("stats/fuzzy_logic.jl")      # Imprecise data handling
include("stats/dempster_shafer.jl")  # Evidence theory integration
include("stats/causality.jl")        # DAGs, SEM, IV, DiD, RDD
include("stats/assumptions.jl")      # Normality, Homoscedasticity
include("stats/estimation.jl")       # James-Stein, MLE
include("stats/measurement.jl")      # Reliability, Validity metrics
include("stats/sampling.jl")         # Sample size, Margin of Error
include("stats/reliability.jl")      # Cronbach's Alpha
include("stats/validity.jl")         # Content/Criterion validity
include("stats/qualitative.jl")      # Thematic saturation
include("stats/complexity.jl")       # Big O Analysis
include("stats/corrections.jl")      # P-value adjustments
include("stats/sem.jl")              # Path Analysis
include("stats/multivariate.jl")     # PCA
include("stats/resampling.jl")       # Bootstrapping
include("stats/timeseries.jl")       # Moving averages, ACF, DTW
include("stats/information_theory.jl") # Entropy, KL Divergence
include("stats/survival.jl")         # Kaplan-Meier, Log-Rank
include("stats/meta_analysis.jl")    # Effect synthesis
include("stats/robust.jl")           # Mahalanobis, Huber, RANSAC
include("stats/spatial.jl")          # Moran's I, GWR
include("stats/machine_learning.jl") # Splines, RF Proxy
include("stats/nlp.jl")              # Lexicon Sentiment, NMF
include("stats/advanced_regression.jl") # Mixed Effects, Ordinal Logistic
include("stats/signal_processing.jl")   # ICA
include("stats/bayesian_advanced.jl")   # EM Algorithm
include("stats/functional.jl")          # Functional PCA
include("stats/algebraic.jl")           # Binary, p-adic, Complex
include("stats/representations.jl")     # Compositional, Interval
include("stats/non_classical.jl")       # Choquet, Quantum, Tropical
include("stats/dynamic_structured.jl")  # Graphs, Fractals, Hurst
include("stats/unconventional.jl")      # Rough Sets, Imprecise
include("stats/pre_framework.jl")       # PRE Framework (Lambda, Tau, etc.)

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

export main, run_examples, statistical_assistant_chat,
       descriptive_stats, t_test_independent, pearson_correlation,
       simple_linear_regression, multiple_regression, logistic_regression, permanova,
       mle_fit, estimate_complexity, adjust_p_values, path_analysis,
       pca, bootstrap_ci, moving_average, autocorrelation, shannon_entropy, kl_divergence,
       kaplan_meier, log_rank_test, meta_analysis,
       friedman_test, cochrans_q, stuart_maxwell_test,
       mahalanobis_distance, huber_m_estimator, ransac_regression,
       instrumental_variables, difference_in_differences, regression_discontinuity,
       morans_i, gwr_basic, dynamic_time_warping,
       spline_regression, random_forest_proxy,
       lexicon_sentiment, topic_modeling_nmf,
       mixed_effects_intercept, ordinal_logistic_regression,
       independent_component_analysis, expectation_maximization_normal,
       functional_pca, mcnemar_test, padic_valuation, centered_log_ratio,
       interval_overlap_test, choquet_integral, tropical_dot_product,
       bell_test_chsh, degree_centrality, box_counting_dimension,
       hurst_exponent, rough_set_approximations, rough_membership,
       calculate_PRE_suite

end # module
