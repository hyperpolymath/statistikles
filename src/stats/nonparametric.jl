# SPDX-License-Identifier: PMPL-1.0-or-later
# Non-parametric tests — symbolic computation only.

function mann_whitney_u(group1::Vector{Float64}, group2::Vector{Float64}; alpha::Float64=0.05)
    n1, n2 = length(group1), length(group2)
    combined = vcat(group1, group2)
    ranks = ordinalrank(combined)
    R1 = sum(ranks[1:n1])
    U1 = R1 - n1 * (n1 + 1) / 2
    U2 = n1 * n2 - U1
    U = min(U1, U2)
    mu_U = n1 * n2 / 2
    sigma_U = sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
    z = (U - mu_U) / sigma_U
    p_value = 2 * (1 - cdf(Normal(), abs(z)))

    return Dict{String,Any}(
        "U_statistic" => U, "U1" => U1, "U2" => U2,
        "z" => z, "p_value" => p_value, "significant" => p_value < alpha,
        "rank_biserial_r" => 1 - (2 * U) / (n1 * n2),
        "median_group1" => median(group1), "median_group2" => median(group2),
        "n1" => n1, "n2" => n2,
        "test_type" => "Mann-Whitney U test (Wilcoxon rank-sum)"
    )
end

function wilcoxon_signed_rank(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    diffs = x .- y
    diffs_nz = filter(!=(0.0), diffs)
    n = length(diffs_nz)
    ranks = ordinalrank(abs.(diffs_nz))
    signed_ranks = sign.(diffs_nz) .* ranks
    W_plus = sum(r for r in signed_ranks if r > 0)
    W_minus = abs(sum(r for r in signed_ranks if r < 0))
    W = min(W_plus, W_minus)
    mu_W = n * (n + 1) / 4
    sigma_W = sqrt(n * (n + 1) * (2n + 1) / 24)
    z = (W - mu_W) / sigma_W
    p_value = 2 * (1 - cdf(Normal(), abs(z)))

    return Dict{String,Any}(
        "W_statistic" => W, "W_plus" => W_plus, "W_minus" => W_minus,
        "z" => z, "p_value" => p_value, "significant" => p_value < alpha,
        "effect_size_r" => z / sqrt(n), "n_nonzero" => n,
        "test_type" => "Wilcoxon signed-rank test"
    )
end

function kruskal_wallis(groups::Vector{Vector{Float64}}; alpha::Float64=0.05)
    k = length(groups)
    ns = length.(groups)
    N = sum(ns)
    combined = vcat(groups...)
    ranks = ordinalrank(combined)
    idx = 1
    rank_sums = Float64[]
    for g in groups
        n_g = length(g)
        push!(rank_sums, sum(ranks[idx:idx+n_g-1]))
        idx += n_g
    end
    H = (12 / (N * (N + 1))) * sum(rank_sums .^ 2 ./ ns) - 3 * (N + 1)
    df = k - 1
    p_value = 1 - cdf(Chisq(df), H)

    return Dict{String,Any}(
        "H_statistic" => H, "df" => df, "p_value" => p_value,
        "significant" => p_value < alpha,
        "eta_squared_H" => (H - k + 1) / (N - k),
        "k_groups" => k, "N_total" => N,
        "group_medians" => median.(groups),
        "test_type" => "Kruskal-Wallis H test"
    )
end

"""
    friedman_test(data::Matrix{Float64}; alpha=0.05) -> Dict

FRIEDMAN TEST: Non-parametric version of repeated-measures ANOVA.
- `data`: Rows are blocks (subjects), columns are treatments.
"""
function friedman_test(data::Matrix{Float64}; alpha::Float64=0.05)
    n, k = size(data)
    n < 2 && return Dict("error" => "At least 2 blocks required")
    
    # Rank within each block
    ranks = zeros(n, k)
    for i in 1:n
        ranks[i, :] = ordinalrank(data[i, :])
    end
    
    # Sum of ranks for each treatment
    R = sum(ranks, dims=1)
    
    # Chi-squared statistic
    Q = (12 / (n * k * (k + 1))) * sum(R .^ 2) - 3 * n * (k + 1)
    df = k - 1
    p_val = 1 - cdf(Chisq(df), Q)
    
    return Dict{String, Any}(
        "Q_statistic" => Q, "df" => df, "p_value" => p_val,
        "significant" => p_val < alpha,
        "test_type" => "Friedman Test"
    )
end

"""
    cochrans_q(data::Matrix{Int}; alpha=0.05) -> Dict

COCHRAN'S Q TEST: Extends McNemar test to k groups (binary outcomes).
- `data`: Rows are subjects, columns are treatments (0 or 1).
"""
function cochrans_q(data::Matrix{Int}; alpha::Float64=0.05)
    n, k = size(data)
    
    C = sum(data, dims=1)  # Successes per treatment
    R = sum(data, dims=2)  # Successes per subject
    
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

"""
    stuart_maxwell_test(contingency_matrix::Matrix{Int}; alpha=0.05) -> Dict

STUART-MAXWELL TEST: Extension of McNemar's test for k x k tables.
Tests marginal homogeneity in matched-pair data.
"""
function stuart_maxwell_test(matrix::Matrix{Int}; alpha::Float64=0.05)
    k = size(matrix, 1)
    @assert size(matrix, 1) == size(matrix, 2) "Matrix must be square"
    
    # Differences in marginal sums
    d = sum(matrix, dims=2)[:] .- sum(matrix, dims=1)[:]
    
    # Variance-covariance matrix of d
    V = zeros(k, k)
    for i in 1:k, j in 1:k
        if i == j
            V[i, i] = sum(matrix[i, :]) + sum(matrix[:, i]) - 2 * matrix[i, i]
        else
            V[i, j] = -(matrix[i, j] + matrix[j, i])
        end
    end
    
    # Use first k-1 rows/cols to avoid singularity
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

"""
    permanova(distance_matrix, group_labels; n_permutations=999, alpha=0.05) -> Dict

PERMANOVA (Permutational Multivariate Analysis of Variance).
Tests whether the centroids of groups differ in multivariate space
using a distance matrix and permutation-based significance testing.

- INPUT: A symmetric distance matrix (e.g. Euclidean, Bray-Curtis) and
  a vector of group labels indicating which group each observation belongs to.
- METHOD: Partitions total sum-of-squares of the distance matrix into
  within-group and between-group components, computes a pseudo-F statistic,
  then estimates p-value by permuting group labels.
- ASSUMPTIONS: Does NOT assume multivariate normality. Sensitive to
  differences in multivariate dispersion between groups (consider
  a test of homogeneity of dispersions as a companion check).
- EFFECT SIZE: Reports partial R² (proportion of variance explained by grouping).
- OUTPUT: Pseudo-F statistic, permutation p-value, partial R², group sizes.

Reference: Anderson, M.J. (2001). "A new method for non-parametric
multivariate analysis of variance." Austral Ecology, 26, 32–46.
"""
function permanova(distance_matrix::Matrix{Float64},
                   group_labels::Vector;
                   n_permutations::Int=999,
                   alpha::Float64=0.05)
    N = size(distance_matrix, 1)
    @assert size(distance_matrix) == (N, N) "Distance matrix must be square"
    @assert length(group_labels) == N "Group labels must match matrix dimension"

    unique_groups = unique(group_labels)
    k = length(unique_groups)
    @assert k >= 2 "At least two groups are required"

    # --- Compute sums-of-squares from the distance matrix ---
    # Following Anderson (2001): SS = (1/n) * sum of squared distances
    # We use the squared distance matrix throughout.
    D2 = distance_matrix .^ 2

    # Total sum-of-squares: (1/N) * sum of all squared distances / 2
    # (dividing by 2 because the matrix is symmetric and we'd double-count)
    SS_T = sum(D2) / (2 * N)

    # Within-group sum-of-squares
    SS_W = 0.0
    group_sizes = Dict{eltype(group_labels), Int}()
    for g in unique_groups
        idx = findall(==(g), group_labels)
        n_g = length(idx)
        group_sizes[g] = n_g
        # Sum of squared distances within group g, divided by group size
        for i in idx
            for j in idx
                SS_W += D2[i, j]
            end
        end
    end
    SS_W /= 2  # Symmetric matrix correction
    # Normalize: divide each group's contribution by its size
    SS_W_normalized = 0.0
    for g in unique_groups
        idx = findall(==(g), group_labels)
        n_g = length(idx)
        group_sum = 0.0
        for i in idx
            for j in idx
                group_sum += D2[i, j]
            end
        end
        SS_W_normalized += group_sum / (2 * n_g)
    end

    SS_A = SS_T - SS_W_normalized  # Between-group (among) SS

    # Degrees of freedom
    df_A = k - 1
    df_W = N - k

    # Pseudo-F statistic
    MS_A = SS_A / df_A
    MS_W = SS_W_normalized / df_W
    F_observed = MS_A / MS_W

    # Partial R² (proportion of variance explained)
    R2 = SS_A / SS_T

    # --- Permutation test ---
    # Count how many permuted F-statistics are >= the observed F.
    n_extreme = 0
    for _ in 1:n_permutations
        perm_labels = shuffle(group_labels)
        perm_SS_W = 0.0
        for g in unique_groups
            idx = findall(==(g), perm_labels)
            n_g = length(idx)
            group_sum = 0.0
            for i in idx
                for j in idx
                    group_sum += D2[i, j]
                end
            end
            perm_SS_W += group_sum / (2 * n_g)
        end
        perm_SS_A = SS_T - perm_SS_W
        perm_F = (perm_SS_A / df_A) / (perm_SS_W / df_W)
        if perm_F >= F_observed
            n_extreme += 1
        end
    end

    # P-value: proportion of permutations with F >= observed F
    # +1 in numerator and denominator accounts for the observed statistic itself
    p_value = (n_extreme + 1) / (n_permutations + 1)

    return Dict{String,Any}(
        "pseudo_F" => F_observed,
        "df_between" => df_A,
        "df_within" => df_W,
        "SS_between" => SS_A,
        "SS_within" => SS_W_normalized,
        "SS_total" => SS_T,
        "partial_R2" => R2,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "n_permutations" => n_permutations,
        "n_groups" => k,
        "N_total" => N,
        "group_sizes" => Dict{String,Int}(string(g) => group_sizes[g] for g in unique_groups),
        "test_type" => "PERMANOVA (Permutational Multivariate Analysis of Variance)"
    )
end
