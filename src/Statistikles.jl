# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           STATISTIKLES                                       ║
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

module Statistikles

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

# --- CROSS-VERIFICATION & PERSISTENCE ---
include("bridge/aspasia_bridge.jl")    # Aspasia (Octave) cross-verification bridge
include("bridge/verisimdb_schema.jl")  # VeriSimDB persistence (port 8096)
include("bridge/echidna_adapter.jl")   # ECHIDNA formal proof dispatch
include("bridge/betlang_bridge.jl")   # BetLang probabilistic programming integration
include("bridge/typell_levels.jl")     # TypeLL levels 1-12 statistical types

# --- JULIA ECOSYSTEM INTEGRATIONS ---
include("integrations/axiom_integration.jl")    # Axiom.jl property verification
include("integrations/smtlib_integration.jl")   # SMTLib.jl exact arithmetic
include("integrations/causals_integration.jl")  # Causals.jl causal DAGs + Bradford Hill
include("integrations/bowtie_integration.jl")   # BowtieRisk.jl barrier modeling
include("integrations/zeroprob_integration.jl") # ZeroProb.jl zero-inflated models
include("integrations/quantum_integration.jl")  # QuantumCircuit.jl Bell tests

# --- INTERFACE LAYER: LLM Integration ---
include("tools/definitions.jl")  # MCP / Function calling schemas
include("tools/executor.jl")     # Safe execution sandbox
include("tools/lmstudio.jl")     # Local LLM connectivity
include("tools/guardrail.jl")    # Neural-boundary numeric provenance enforcement
include("tools/chat.jl")         # Interactive session management

export main, run_examples, statistical_assistant_chat,
       # Descriptive
       descriptive_stats, power_mean, weighted_stats, frequency_table,
       # Inferential
       t_test_independent, one_way_anova, pearson_correlation,
       simple_linear_regression, multiple_regression, logistic_regression,
       partial_correlation, grubbs_test, spearman_correlation,
       # Multivariate
       manova_oneway,
       # Nonparametric
       mann_whitney_u, wilcoxon_signed_rank, kruskal_wallis,
       friedman_test, cochrans_q, stuart_maxwell_test,
       permanova, permanova_multi, midranks, tie_correction,
       fisher_exact_test, dunn_test, ks_2sample,
       # Effect sizes & power
       mle_fit, estimate_complexity, adjust_p_values,
       # Bayesian & estimation
       path_analysis, pca, bootstrap_ci,
       # Time series & signal
       moving_average, autocorrelation, dynamic_time_warping,
       independent_component_analysis,
       # Information theory
       shannon_entropy, kl_divergence,
       # Survival
       kaplan_meier, log_rank_test,
       # Meta-analysis
       meta_analysis,
       # Robust
       mahalanobis_distance, huber_m_estimator, ransac_regression,
       # Causal
       instrumental_variables, difference_in_differences, regression_discontinuity,
       # Spatial
       morans_i, gwr_basic,
       # ML proxy
       spline_regression, random_forest_proxy,
       # NLP
       lexicon_sentiment, topic_modeling_nmf,
       # Advanced regression
       mixed_effects_intercept, ordinal_logistic_regression,
       expectation_maximization_normal, functional_pca,
       # Algebraic: p-adic, complex, modular
       mcnemar_test, padic_valuation, complex_circular_normality,
       modular_stats, gcd_stats,
       # Compositional & interval
       centered_log_ratio, interval_overlap_test,
       # Non-classical: tropical, Choquet, quantum
       choquet_integral, tropical_dot_product, tropical_mean,
       tropical_matrix_multiply, tropical_eigenvalue,
       bell_test_chsh,
       # Graph & fractal
       degree_centrality, box_counting_dimension, hurst_exponent,
       # Rough sets
       rough_set_approximations, rough_membership,
       # PRE framework
       calculate_PRE_suite,
       # Reliability & agreement
       icc, bland_altman,
       # Normality
       anderson_darling,
       # Corrections
       adjust_p_values,
       # Cross-verification bridge
       write_transaction, read_audit, list_pending_audits,
       cross_verify_summary, init_bridge,
       # VeriSimDB persistence
       store_result, query_results, store_audit, store_proof,
       # ECHIDNA proofs
       check_echidna_health, proof_coverage_report,
       verify_all_statistical_identities, StatProofObligation,
       # TypeLL levels 1-12
       Probability, EffectSize, DistributionType, HypothesisSpec,
       TestResult, ConfidenceInterval,
       TropicalValue, PadicValue, ModularInt,
       VerifiedResult, ProvenResult, KnowledgeState,
       AuditSession, new_audit_session, advance,
       # BetLang integration
       bet, bet_weighted, bet_chain, bet_monte_carlo,
       DistnumberNormal, AffineInterval, ImpreciseProbability,
       width, midpoint, complement,
       latin_hypercube, sobol_sequence, importance_sample,
       simulated_annealing, particle_swarm,
       value_at_risk, conditional_var, dutch_book_check, risk_of_ruin,
       # Axiom.jl integration
       statistical_property_audit, verify_pvalue_bounds, verify_effect_size_label,
       # SMTLib.jl integration
       smt_verify_dutch_book, smt_verify_mean_inequality, smt_verify_correction_monotone,
       # Causals.jl integration
       bet_chain_to_dag, bradford_hill_checklist, confounding_check,
       # BowtieRisk.jl integration
       bowtie_from_bets, monte_carlo_bowtie,
       # ZeroProb.jl integration
       zero_inflated_bet, zero_inflated_model, rare_event_probability,
       # QuantumCircuit.jl integration
       simulate_bell_experiment, quantum_random_walk

end # module
