# SPDX-License-Identifier: MPL-2.0
# Non-parametric tests — production-quality implementations with:
#   - Midranks (fractional ranks for ties)
#   - Tie correction factors
#   - Continuity correction
#   - Multi-factor PERMANOVA

using StatsBase: competerank, ordinalrank
using Distributions: Normal, Chisq, cdf
using Random: shuffle
using Statistics
using LinearAlgebra: inv

# ===========================================================================
# Ranking with midranks (fractional ranks for ties)
# ===========================================================================

"""
    midranks(x) -> Vector{Float64}

Compute fractional (averaged) ranks, correctly handling ties.
Ties receive the mean of the ranks they would occupy.
This is the standard ranking method for nonparametric tests.
"""
function midranks(x::AbstractVector)
    n = length(x)
    idx = sortperm(x)
    ranks = zeros(Float64, n)
    i = 1
    while i <= n
        j = i
        # Find extent of tie group
        while j <= n && x[idx[j]] == x[idx[i]]
            j += 1
        end
        # Assign average rank to all tied values
        avg_rank = (i + j - 1) / 2.0
        for k in i:(j-1)
            ranks[idx[k]] = avg_rank
        end
        i = j
    end
    return ranks
end

"""
    tie_correction(ranks) -> Float64

Compute the tie correction factor for use in variance adjustment.
Returns sum of (t^3 - t) for each group of t ties.
"""
function tie_correction(x::AbstractVector)
    counts = Dict{eltype(x), Int}()
    for v in x
        counts[v] = get(counts, v, 0) + 1
    end
    return sum(t^3 - t for (_, t) in counts if t > 1; init=0.0)
end

# ===========================================================================
# Mann-Whitney U test (Wilcoxon rank-sum)
# ===========================================================================

"""
    mann_whitney_u(group1, group2; alpha=0.05) -> Dict

Two-sample rank-sum test with midranks, tie correction, and continuity correction.
Equivalent to R's wilcox.test(x, y).
"""
function mann_whitney_u(group1::Vector{Float64}, group2::Vector{Float64}; alpha::Float64=0.05)
    n1, n2 = length(group1), length(group2)
    N = n1 + n2
    combined = vcat(group1, group2)

    # Midranks handle ties correctly
    ranks = midranks(combined)
    R1 = sum(ranks[1:n1])

    U1 = R1 - n1 * (n1 + 1) / 2
    U2 = n1 * n2 - U1
    U = min(U1, U2)

    mu_U = n1 * n2 / 2.0

    # Tie-corrected variance: σ² = (n1*n2 / 12) * (N + 1 - Σ(tᵢ³ - tᵢ) / (N*(N-1)))
    T = tie_correction(combined)
    sigma_U = sqrt(n1 * n2 / 12.0 * ((N + 1) - T / (N * (N - 1))))

    # Continuity correction: subtract 0.5 from |U - μ|
    z = (abs(U - mu_U) - 0.5) / sigma_U
    p_value = 2 * (1 - cdf(Normal(), abs(z)))

    return Dict{String,Any}(
        "U_statistic" => U, "U1" => U1, "U2" => U2,
        "z" => z, "p_value" => p_value, "significant" => p_value < alpha,
        "rank_biserial_r" => 1 - (2 * U) / (n1 * n2),
        "median_group1" => median(group1), "median_group2" => median(group2),
        "n1" => n1, "n2" => n2,
        "tie_correction" => T,
        "test_type" => "Mann-Whitney U test (Wilcoxon rank-sum, midranks + tie correction)"
    )
end

# ===========================================================================
# Wilcoxon signed-rank test
# ===========================================================================

"""
    wilcoxon_signed_rank(x, y; alpha=0.05) -> Dict

Paired test with midranks, tie correction, and continuity correction.
Equivalent to R's wilcox.test(x, y, paired=TRUE).
"""
function wilcoxon_signed_rank(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    diffs = x .- y
    diffs_nz = filter(!=(0.0), diffs)
    n = length(diffs_nz)

    if n == 0
        return Dict{String,Any}(
            "W_statistic" => 0.0, "p_value" => 1.0, "significant" => false,
            "n_nonzero" => 0, "test_type" => "Wilcoxon signed-rank test (no nonzero differences)"
        )
    end

    # Midranks of absolute differences
    abs_diffs = abs.(diffs_nz)
    ranks = midranks(abs_diffs)
    signed_ranks = sign.(diffs_nz) .* ranks

    W_plus = sum(r for r in signed_ranks if r > 0; init=0.0)
    W_minus = abs(sum(r for r in signed_ranks if r < 0; init=0.0))
    W = min(W_plus, W_minus)

    mu_W = n * (n + 1) / 4.0

    # Tie-corrected variance
    T = tie_correction(abs_diffs)
    sigma_W = sqrt(n * (n + 1) * (2n + 1) / 24.0 - T / 48.0)

    # Continuity correction
    z = (abs(W - mu_W) - 0.5) / sigma_W
    p_value = 2 * (1 - cdf(Normal(), abs(z)))

    return Dict{String,Any}(
        "W_statistic" => W, "W_plus" => W_plus, "W_minus" => W_minus,
        "z" => z, "p_value" => p_value, "significant" => p_value < alpha,
        "effect_size_r" => z / sqrt(n), "n_nonzero" => n,
        "tie_correction" => T,
        "test_type" => "Wilcoxon signed-rank test (midranks + tie correction)"
    )
end

# ===========================================================================
# Kruskal-Wallis H test
# ===========================================================================

"""
    kruskal_wallis(groups; alpha=0.05) -> Dict

k-sample test with midranks and tie correction.
Equivalent to R's kruskal.test().
"""
function kruskal_wallis(groups::Vector{Vector{Float64}}; alpha::Float64=0.05)
    k = length(groups)
    ns = length.(groups)
    N = sum(ns)
    combined = vcat(groups...)

    # Midranks
    ranks = midranks(combined)

    # Compute rank sums per group
    idx = 1
    rank_sums = Float64[]
    for g in groups
        n_g = length(g)
        push!(rank_sums, sum(ranks[idx:idx+n_g-1]))
        idx += n_g
    end

    # H statistic
    H = (12 / (N * (N + 1))) * sum(rank_sums .^ 2 ./ ns) - 3 * (N + 1)

    # Tie correction: H_corrected = H / (1 - Σ(tᵢ³ - tᵢ) / (N³ - N))
    T = tie_correction(combined)
    tie_factor = 1.0 - T / (N^3 - N)
    H_corrected = tie_factor > 0 ? H / tie_factor : H

    df = k - 1
    p_value = 1 - cdf(Chisq(df), H_corrected)

    return Dict{String,Any}(
        "H_statistic" => H_corrected, "H_uncorrected" => H,
        "df" => df, "p_value" => p_value,
        "significant" => p_value < alpha,
        "eta_squared_H" => (H_corrected - k + 1) / (N - k),
        "k_groups" => k, "N_total" => N,
        "group_medians" => median.(groups),
        "tie_correction" => T,
        "test_type" => "Kruskal-Wallis H test (midranks + tie correction)"
    )
end

# ===========================================================================
# Friedman test
# ===========================================================================

"""
    friedman_test(data; alpha=0.05) -> Dict

Non-parametric repeated-measures test with midranks within blocks.
Equivalent to R's friedman.test().
- `data`: Rows are blocks (subjects), columns are treatments.
"""
function friedman_test(data::Matrix{Float64}; alpha::Float64=0.05)
    n, k = size(data)
    n < 2 && return Dict("error" => "At least 2 blocks required")

    # Rank within each block using midranks
    ranks = zeros(n, k)
    for i in 1:n
        ranks[i, :] = midranks(data[i, :])
    end

    R = sum(ranks, dims=1)
    Q = (12 / (n * k * (k + 1))) * sum(R .^ 2) - 3 * n * (k + 1)
    df = k - 1
    p_val = 1 - cdf(Chisq(df), Q)

    return Dict{String, Any}(
        "Q_statistic" => Q, "df" => df, "p_value" => p_val,
        "significant" => p_val < alpha,
        "test_type" => "Friedman test (midranks within blocks)"
    )
end

# ===========================================================================
# Cochran's Q test
# ===========================================================================

"""
    cochrans_q(data; alpha=0.05) -> Dict

Extends McNemar test to k groups (binary outcomes).
- `data`: Rows are subjects, columns are treatments (0 or 1).
"""
function cochrans_q(data::Matrix{Int}; alpha::Float64=0.05)
    n, k = size(data)
    C = sum(data, dims=1)
    R = sum(data, dims=2)
    num = (k - 1) * (k * sum(C .^ 2) - sum(C)^2)
    den = k * sum(R) - sum(R .^ 2)
    Q = num / den
    df = k - 1
    p_val = 1 - cdf(Chisq(df), Q)

    return Dict{String, Any}(
        "Q_statistic" => Q, "df" => df, "p_value" => p_val,
        "significant" => p_val < alpha,
        "test_type" => "Cochran's Q Test"
    )
end

# ===========================================================================
# Stuart-Maxwell test
# ===========================================================================

"""
    stuart_maxwell_test(matrix; alpha=0.05) -> Dict

Extension of McNemar's test for k×k tables. Tests marginal homogeneity.
"""
function stuart_maxwell_test(matrix::Matrix{Int}; alpha::Float64=0.05)
    k = size(matrix, 1)
    require_square(matrix, "matrix")
    d = sum(matrix, dims=2)[:] .- sum(matrix, dims=1)[:]
    V = zeros(k, k)
    for i in 1:k, j in 1:k
        if i == j
            V[i, i] = sum(matrix[i, :]) + sum(matrix[:, i]) - 2 * matrix[i, i]
        else
            V[i, j] = -(matrix[i, j] + matrix[j, i])
        end
    end
    V_sub = V[1:k-1, 1:k-1]
    d_sub = d[1:k-1]
    chi2 = d_sub' * inv(V_sub) * d_sub
    df = k - 1
    p_val = 1 - cdf(Chisq(df), chi2)

    return Dict{String, Any}(
        "chi_squared" => chi2, "df" => df, "p_value" => p_val,
        "significant" => p_val < alpha,
        "test_type" => "Stuart-Maxwell Test"
    )
end

# ===========================================================================
# PERMANOVA — multi-factor support
# ===========================================================================

"""
    permanova(distance_matrix, group_labels; n_permutations=999, alpha=0.05) -> Dict

Single-factor PERMANOVA with permutation-based p-value.
Reference: Anderson (2001).
"""
function permanova(distance_matrix::Matrix{Float64},
                   group_labels::Vector;
                   n_permutations::Int=999,
                   alpha::Float64=0.05)
    N = size(distance_matrix, 1)
    require_dims_match(distance_matrix, N, "distance_matrix")
    require_length(group_labels, N, "group_labels")

    unique_groups = unique(group_labels)
    k = length(unique_groups)
    require_at_least(k, 2, "number of distinct groups")

    D2 = distance_matrix .^ 2
    SS_T = sum(D2) / (2 * N)

    function compute_SS_W(labels)
        ss = 0.0
        for g in unique_groups
            idx = findall(==(g), labels)
            n_g = length(idx)
            group_sum = 0.0
            for i in idx, j in idx
                group_sum += D2[i, j]
            end
            ss += group_sum / (2 * n_g)
        end
        return ss
    end

    SS_W = compute_SS_W(group_labels)
    SS_A = SS_T - SS_W
    df_A = k - 1
    df_W = N - k
    F_observed = (SS_A / df_A) / (SS_W / df_W)
    R2 = SS_A / SS_T

    n_extreme = 0
    for _ in 1:n_permutations
        perm_labels = shuffle(group_labels)
        perm_SS_W = compute_SS_W(perm_labels)
        perm_SS_A = SS_T - perm_SS_W
        perm_F = (perm_SS_A / df_A) / (perm_SS_W / df_W)
        if perm_F >= F_observed
            n_extreme += 1
        end
    end

    p_value = (n_extreme + 1) / (n_permutations + 1)

    group_sizes = Dict{String,Int}(string(g) => count(==(g), group_labels) for g in unique_groups)

    return Dict{String,Any}(
        "pseudo_F" => F_observed,
        "df_between" => df_A, "df_within" => df_W,
        "SS_between" => SS_A, "SS_within" => SS_W, "SS_total" => SS_T,
        "partial_R2" => R2, "p_value" => p_value,
        "significant" => p_value < alpha,
        "n_permutations" => n_permutations, "n_groups" => k, "N_total" => N,
        "group_sizes" => group_sizes,
        "test_type" => "PERMANOVA (Permutational Multivariate Analysis of Variance)"
    )
end

"""
    permanova_multi(distance_matrix, factors; n_permutations=999, alpha=0.05) -> Dict

Multi-factor sequential PERMANOVA (Type I SS), supporting models like
`group + run` comparable to R's adonis2(dist ~ group + run).

Each factor is tested sequentially: factor 1 first, then factor 2 after
removing factor 1's effect, etc.

- `factors`: Vector of named factors, e.g. [("group", labels_g), ("run", labels_r)]
"""
function permanova_multi(distance_matrix::Matrix{Float64},
                         factors::Vector{Tuple{String, Vector}};
                         n_permutations::Int=999,
                         alpha::Float64=0.05)
    N = size(distance_matrix, 1)
    require_dims_match(distance_matrix, N, "distance_matrix")

    D2 = distance_matrix .^ 2
    SS_T = sum(D2) / (2 * N)

    results = Dict{String,Any}[]
    residual_labels = nothing  # For sequential testing

    SS_explained = 0.0

    for (fname, flabels) in factors
        require_length(flabels, N, "factor '$fname' labels")

        unique_levels = unique(flabels)
        k = length(unique_levels)

        # Compute SS_W for this factor
        SS_W_f = 0.0
        for g in unique_levels
            idx = findall(==(g), flabels)
            n_g = length(idx)
            group_sum = 0.0
            for i in idx, j in idx
                group_sum += D2[i, j]
            end
            SS_W_f += group_sum / (2 * n_g)
        end

        SS_A_f = SS_T - SS_W_f - SS_explained  # Sequential: remove prior factors
        df_f = k - 1
        df_resid = N - k
        MS_A = SS_A_f / df_f
        MS_W = (SS_T - SS_explained - SS_A_f) / df_resid
        F_obs = MS_W > 0 ? MS_A / MS_W : 0.0
        R2_f = SS_A_f / SS_T

        # Permutation test for this factor
        n_extreme = 0
        for _ in 1:n_permutations
            perm_labels = shuffle(flabels)
            perm_SS_W = 0.0
            for g in unique_levels
                idx = findall(==(g), perm_labels)
                n_g = length(idx)
                gs = 0.0
                for i in idx, j in idx
                    gs += D2[i, j]
                end
                perm_SS_W += gs / (2 * n_g)
            end
            perm_SS_A = SS_T - perm_SS_W - SS_explained
            perm_F = df_resid > 0 && (SS_T - SS_explained - perm_SS_A) > 0 ?
                     (perm_SS_A / df_f) / ((SS_T - SS_explained - perm_SS_A) / df_resid) : 0.0
            if perm_F >= F_obs
                n_extreme += 1
            end
        end
        p_val = (n_extreme + 1) / (n_permutations + 1)

        push!(results, Dict{String,Any}(
            "factor" => fname,
            "pseudo_F" => F_obs, "df" => df_f,
            "SS" => SS_A_f, "R2" => R2_f,
            "p_value" => p_val, "significant" => p_val < alpha
        ))

        SS_explained += SS_A_f
    end

    return Dict{String,Any}(
        "factors" => results,
        "SS_total" => SS_T,
        "SS_residual" => SS_T - SS_explained,
        "R2_total" => SS_explained / SS_T,
        "N_total" => N,
        "n_permutations" => n_permutations,
        "test_type" => "Sequential PERMANOVA (Type I, multi-factor)"
    )
end

# ===========================================================================
# Fisher's Exact Test (2×2)
# ===========================================================================

"""
    fisher_exact_test(a, b, c, d; alpha=0.05) -> Dict

FISHER'S EXACT TEST for 2×2 contingency tables.
Uses hypergeometric distribution — valid for ALL sample sizes including small n.

    |       | Col1 | Col2 |
    |-------|------|------|
    | Row1  |  a   |  b   |
    | Row2  |  c   |  d   |
"""
function fisher_exact_test(a::Int, b::Int, c::Int, d::Int; alpha::Float64=0.05)
    n = a + b + c + d
    r1 = a + b  # Row 1 total
    c1 = a + c  # Col 1 total

    # P(X = k) under hypergeometric distribution
    function hyper_prob(k)
        # Binomial coefficients via log-factorial for numerical stability
        function log_fact(n)
            n <= 1 && return 0.0
            return sum(log(i) for i in 2:n)
        end
        function log_binom(n, k)
            (k < 0 || k > n) && return -Inf
            return log_fact(n) - log_fact(k) - log_fact(n - k)
        end
        return exp(log_binom(c1, k) + log_binom(n - c1, r1 - k) - log_binom(n, r1))
    end

    p_observed = hyper_prob(a)

    # Two-sided: sum probabilities of all tables as extreme or more extreme
    k_min = max(0, r1 - (n - c1))
    k_max = min(r1, c1)

    p_value = 0.0
    for k in k_min:k_max
        p_k = hyper_prob(k)
        if p_k <= p_observed + 1e-12  # As extreme or more
            p_value += p_k
        end
    end
    p_value = min(1.0, p_value)

    # Odds ratio
    odds_ratio = (b == 0 || c == 0) ? Inf : (a * d) / (b * c)

    return Dict{String,Any}(
        "p_value" => p_value,
        "odds_ratio" => odds_ratio,
        "significant" => p_value < alpha,
        "table" => [a b; c d],
        "test_type" => "Fisher's exact test (two-sided)"
    )
end

# ===========================================================================
# Dunn's Test (post-hoc for Kruskal-Wallis)
# ===========================================================================

"""
    dunn_test(groups; alpha=0.05, correction="bonferroni") -> Dict

DUNN'S TEST: Pairwise post-hoc comparisons following a significant Kruskal-Wallis.
Uses midranks and applies multiple comparison correction.
"""
function dunn_test(groups::Vector{Vector{Float64}}; alpha::Float64=0.05, correction::String="bonferroni")
    k = length(groups)
    ns = length.(groups)
    N = sum(ns)
    combined = vcat(groups...)
    ranks = midranks(combined)

    # Mean rank per group
    idx = 1
    mean_ranks = Float64[]
    for g in groups
        n_g = length(g)
        push!(mean_ranks, Statistics.mean(ranks[idx:idx+n_g-1]))
        idx += n_g
    end

    # Tie correction for variance
    T = tie_correction(combined)
    sigma2 = (N * (N + 1) / 12.0 - T / (12.0 * (N - 1)))

    # Pairwise comparisons
    n_comparisons = k * (k - 1) ÷ 2
    comparisons = Dict{String,Any}[]
    raw_p_values = Float64[]

    for i in 1:k, j in (i+1):k
        z = (mean_ranks[i] - mean_ranks[j]) / sqrt(sigma2 * (1.0 / ns[i] + 1.0 / ns[j]))
        p_raw = 2 * (1 - cdf(Normal(), abs(z)))
        push!(raw_p_values, p_raw)
        push!(comparisons, Dict{String,Any}(
            "group_i" => i, "group_j" => j,
            "mean_rank_i" => mean_ranks[i], "mean_rank_j" => mean_ranks[j],
            "z" => z, "p_raw" => p_raw
        ))
    end

    # Apply correction
    adjusted = if correction == "bonferroni"
        min.(1.0, raw_p_values .* n_comparisons)
    elseif correction == "holm"
        sorted_idx = sortperm(raw_p_values)
        adj = zeros(length(raw_p_values))
        for (rank, orig_idx) in enumerate(sorted_idx)
            adj[orig_idx] = min(1.0, raw_p_values[orig_idx] * (n_comparisons - rank + 1))
        end
        # Enforce monotonicity
        for i in 2:length(sorted_idx)
            adj[sorted_idx[i]] = max(adj[sorted_idx[i]], adj[sorted_idx[i-1]])
        end
        adj
    else
        raw_p_values  # No correction
    end

    for (i, comp) in enumerate(comparisons)
        comp["p_adjusted"] = adjusted[i]
        comp["significant"] = adjusted[i] < alpha
    end

    return Dict{String,Any}(
        "comparisons" => comparisons,
        "n_comparisons" => n_comparisons,
        "correction" => correction,
        "test_type" => "Dunn's test (post-hoc pairwise, $correction correction)"
    )
end

# ===========================================================================
# Kolmogorov-Smirnov 2-Sample Test
# ===========================================================================

"""
    ks_2sample(x, y; alpha=0.05) -> Dict

KOLMOGOROV-SMIRNOV 2-SAMPLE TEST: Tests whether two samples come from the
same continuous distribution. Distribution-free — no assumptions about shape.
"""
function ks_2sample(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n1 = length(x)
    n2 = length(y)
    combined = sort(vcat(x, y))

    # Empirical CDFs
    D_max = 0.0
    for val in combined
        ecdf1 = count(<=(val), x) / n1
        ecdf2 = count(<=(val), y) / n2
        D_max = max(D_max, abs(ecdf1 - ecdf2))
    end

    # Asymptotic p-value via Kolmogorov distribution approximation
    n_eff = sqrt(n1 * n2 / (n1 + n2))
    lambda = (n_eff + 0.12 + 0.11 / n_eff) * D_max

    # Marsaglia et al. approximation for P(K > lambda)
    p_value = 2.0 * sum((-1)^(k-1) * exp(-2 * k^2 * lambda^2) for k in 1:100)
    p_value = clamp(p_value, 0.0, 1.0)

    return Dict{String,Any}(
        "D_statistic" => D_max,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "n1" => n1, "n2" => n2,
        "test_type" => "Kolmogorov-Smirnov two-sample test"
    )
end
