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
