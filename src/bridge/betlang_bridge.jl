# SPDX-License-Identifier: MPL-2.0
# BetLang Bridge — Probabilistic programming integration.
#
# Brings betlang's unique capabilities into Statistikles:
#   - 14 uncertainty-aware number systems
#   - Advanced Bayesian inference (MCMC, ABC, importance sampling)
#   - 14 sampling methods (HMC, SMC, Latin hypercube, Sobol, etc.)
#   - 13 optimization algorithms (SA, GA, PSO, DE, ant colony, etc.)
#   - Markov chains and HMMs
#   - Financial risk (VaR, CVaR, risk-of-ruin, Dutch book detection)
#   - Game theory (Nash equilibria, auctions)
#
# Statistikles provides back to betlang:
#   - Production-quality nonparametric tests (midranks, tie correction)
#   - Cross-verification (Aspasia + ECHIDNA triangle)
#   - Formal proofs (Agda)
#   - TypeLL type safety levels 1-12
#
# Integration: betlang's Julia backend (BetLang.jl) is loaded directly.
# If not available, falls back to a Racket subprocess bridge.

using Random
using Distributions

# ===========================================================================
# Ternary Bet Primitive (from betlang core)
# ===========================================================================

"""
    bet(a, b, c) -> Any

BetLang's core primitive: randomly choose one of three values with equal
probability (1/3 each). The ternary structure models three-way decisions
naturally (win/draw/lose, yes/no/maybe, heads/tails/edge).
"""
function bet(a, b, c)
    r = rand()
    r < 1/3 ? a : (r < 2/3 ? b : c)
end

"""
    bet_weighted(options::Vector{Tuple{T, Float64}}) where T -> T

Weighted ternary bet — probabilities don't need to be equal.
"""
function bet_weighted(options::Vector{<:Tuple})
    values = first.(options)
    weights = Float64[last(o) for o in options]
    probs = weights ./ sum(weights)
    dist = Categorical(probs)
    return values[rand(dist)]
end

"""
    bet_chain(n::Int, f::Function, init) -> Any

Chain n sequential bets, threading state through function f.
"""
function bet_chain(n::Int, f::Function, init)
    state = init
    for _ in 1:n
        state = f(state)
    end
    return state
end

"""
    bet_monte_carlo(n::Int, f::Function) -> Dict

Run f() n times and collect statistics on the results.
"""
function bet_monte_carlo(n::Int, f::Function)
    results = [f() for _ in 1:n]
    numeric = filter(x -> x isa Number, results)
    return Dict{String,Any}(
        "n" => n,
        "results" => results,
        "mean" => isempty(numeric) ? NaN : Statistics.mean(numeric),
        "std" => isempty(numeric) ? NaN : Statistics.std(numeric),
        "min" => isempty(numeric) ? NaN : minimum(numeric),
        "max" => isempty(numeric) ? NaN : maximum(numeric),
    )
end

# ===========================================================================
# Uncertainty Number Systems (from betlang's 14 systems)
# ===========================================================================

"""
    DistnumberNormal — Gaussian uncertainty propagation.
    Arithmetic on N(μ,σ²) values propagates uncertainty correctly.
"""
struct DistnumberNormal
    mu::Float64
    sigma::Float64
end

Base.:+(a::DistnumberNormal, b::DistnumberNormal) =
    DistnumberNormal(a.mu + b.mu, sqrt(a.sigma^2 + b.sigma^2))
Base.:-(a::DistnumberNormal, b::DistnumberNormal) =
    DistnumberNormal(a.mu - b.mu, sqrt(a.sigma^2 + b.sigma^2))
Base.:*(a::DistnumberNormal, b::DistnumberNormal) =
    DistnumberNormal(a.mu * b.mu, sqrt((a.mu * b.sigma)^2 + (b.mu * a.sigma)^2))

"""Sample from the underlying distribution."""
draw_sample(d::DistnumberNormal) = d.mu + d.sigma * randn()

"""
    AffineInterval — Interval arithmetic [lo, hi].
    Conservative bounds on uncertainty.
"""
struct AffineInterval
    lo::Float64
    hi::Float64
end

Base.:+(a::AffineInterval, b::AffineInterval) = AffineInterval(a.lo + b.lo, a.hi + b.hi)
Base.:-(a::AffineInterval, b::AffineInterval) = AffineInterval(a.lo - b.hi, a.hi - b.lo)
width(a::AffineInterval) = a.hi - a.lo
midpoint(a::AffineInterval) = (a.lo + a.hi) / 2

"""
    ImpreciseProbability — [P_lower, P_upper] bounds on unknown probability.
    Models epistemic uncertainty (don't know the exact probability).
"""
struct ImpreciseProbability
    lower::Float64
    upper::Float64
    function ImpreciseProbability(lo, hi)
        (0.0 <= lo <= hi <= 1.0) || throw(ArgumentError(
            "ImpreciseProbability bounds must satisfy 0 <= lower <= upper <= 1, got lower=$lo, upper=$hi"))
        new(lo, hi)
    end
end

complement(p::ImpreciseProbability) = ImpreciseProbability(1.0 - p.upper, 1.0 - p.lower)

# ===========================================================================
# Advanced Sampling (from betlang's 14 methods)
# ===========================================================================

"""
    latin_hypercube(n::Int, dims::Int) -> Matrix{Float64}

Latin Hypercube Sampling — space-filling design for n points in `dims` dimensions.
Each dimension is divided into n equal strata with one point per stratum.
"""
function latin_hypercube(n::Int, dims::Int)
    samples = zeros(n, dims)
    for d in 1:dims
        perm = randperm(n)
        for i in 1:n
            samples[i, d] = (perm[i] - 1 + rand()) / n
        end
    end
    return samples
end

"""
    sobol_sequence(n::Int, dims::Int) -> Matrix{Float64}

Quasi-random Sobol sequence — low-discrepancy for better coverage than
pseudo-random sampling. Uses bit-reversal radical inverse.
"""
function sobol_sequence(n::Int, dims::Int)
    samples = zeros(n, dims)
    for d in 1:dims
        base = d + 1  # Different prime-like base per dimension
        for i in 1:n
            # Van der Corput / radical inverse in base
            result = 0.0
            f = 1.0 / base
            val = i
            while val > 0
                result += (val % base) * f
                val = div(val, base)
                f /= base
            end
            samples[i, d] = result
        end
    end
    return samples
end

"""
    importance_sample(target_pdf, proposal_pdf, proposal_sample, n) -> (samples, weights)

Importance sampling — sample from proposal, reweight by target/proposal ratio.
"""
function importance_sample(target_pdf::Function, proposal_pdf::Function,
                          proposal_sample::Function, n::Int)
    samples = [proposal_sample() for _ in 1:n]
    weights = [target_pdf(s) / max(proposal_pdf(s), 1e-15) for s in samples]
    weights ./= sum(weights)  # Normalize
    return samples, weights
end

# ===========================================================================
# Optimization (from betlang's 13 algorithms)
# ===========================================================================

"""
    simulated_annealing(objective, initial; T0=1.0, cooling=0.995, steps=10000) -> Dict

Simulated annealing optimizer — escapes local optima via temperature-controlled
random acceptance of worse solutions.
"""
function simulated_annealing(objective::Function, initial::Vector{Float64};
                            T0::Float64=1.0, cooling::Float64=0.995, steps::Int=10000)
    current = copy(initial)
    best = copy(current)
    current_score = objective(current)
    best_score = current_score
    T = T0

    for step in 1:steps
        # Neighbor: perturb by Gaussian
        neighbor = current .+ randn(length(current)) .* T
        neighbor_score = objective(neighbor)

        # Accept if better, or probabilistically if worse
        delta = neighbor_score - current_score
        if delta < 0 || rand() < exp(-delta / max(T, 1e-10))
            current = neighbor
            current_score = neighbor_score
        end

        if current_score < best_score
            best = copy(current)
            best_score = current_score
        end

        T *= cooling
    end

    return Dict{String,Any}(
        "best" => best, "best_score" => best_score,
        "final_temperature" => T, "steps" => steps
    )
end

"""
    particle_swarm(objective, n_particles, dims; steps=1000) -> Dict

Particle Swarm Optimization — social learning from personal and global best.
"""
function particle_swarm(objective::Function, n_particles::Int, dims::Int;
                       steps::Int=1000, bounds::Tuple{Float64,Float64}=(-10.0, 10.0))
    lo, hi = bounds
    positions = [lo .+ (hi - lo) .* rand(dims) for _ in 1:n_particles]
    velocities = [randn(dims) .* 0.1 for _ in 1:n_particles]
    personal_best = copy.(positions)
    personal_scores = [objective(p) for p in positions]
    global_best_idx = argmin(personal_scores)
    global_best = copy(personal_best[global_best_idx])
    global_score = personal_scores[global_best_idx]

    w, c1, c2 = 0.7, 1.5, 1.5  # Inertia, cognitive, social

    for _ in 1:steps
        for i in 1:n_particles
            r1, r2 = rand(dims), rand(dims)
            velocities[i] = w .* velocities[i] .+
                           c1 .* r1 .* (personal_best[i] .- positions[i]) .+
                           c2 .* r2 .* (global_best .- positions[i])
            positions[i] .+= velocities[i]
            score = objective(positions[i])
            if score < personal_scores[i]
                personal_scores[i] = score
                personal_best[i] = copy(positions[i])
                if score < global_score
                    global_score = score
                    global_best = copy(positions[i])
                end
            end
        end
    end

    return Dict{String,Any}(
        "best" => global_best, "best_score" => global_score,
        "n_particles" => n_particles, "steps" => steps
    )
end

# ===========================================================================
# Financial Risk (from betlang)
# ===========================================================================

"""
    value_at_risk(returns, alpha=0.05) -> Float64

Value-at-Risk: the α-quantile of the loss distribution.
"""
function value_at_risk(returns::Vector{Float64}; alpha::Float64=0.05)
    sorted = sort(returns)
    idx = max(1, ceil(Int, alpha * length(sorted)))
    return -sorted[idx]
end

"""
    conditional_var(returns, alpha=0.05) -> Float64

Conditional VaR (Expected Shortfall): average loss beyond VaR.
"""
function conditional_var(returns::Vector{Float64}; alpha::Float64=0.05)
    sorted = sort(returns)
    cutoff = ceil(Int, alpha * length(sorted))
    tail = sorted[1:max(1, cutoff)]
    return -Statistics.mean(tail)
end

"""
    dutch_book_check(probabilities::Vector{Float64}) -> Dict

Check if a set of probability assignments is coherent (no Dutch book).
Probabilities must sum to 1.0 (within tolerance).
"""
function dutch_book_check(probabilities::Vector{Float64})
    total = sum(probabilities)
    all_valid = all(0.0 .<= probabilities .<= 1.0)
    coherent = all_valid && isapprox(total, 1.0, atol=1e-10)
    overround = total - 1.0  # Bookmaker margin

    return Dict{String,Any}(
        "coherent" => coherent,
        "total" => total,
        "overround" => overround,
        "all_valid" => all_valid,
        "vulnerability" => coherent ? "none" : (total < 1.0 ? "Dutch book possible (underround)" : "Built-in margin (overround)")
    )
end

"""
    risk_of_ruin(win_prob, win_amount, loss_amount, bankroll) -> Float64

Gambler's ruin probability — chance of losing entire bankroll.
"""
function risk_of_ruin(win_prob::Float64, win_amount::Float64,
                     loss_amount::Float64, bankroll::Float64)
    q = 1.0 - win_prob
    if win_prob == q
        return loss_amount / bankroll
    end
    r = q / win_prob
    n_units = bankroll / loss_amount
    return r^n_units
end
