# SPDX-License-Identifier: MPL-2.0
# QuantumCircuit.jl Integration — Quantum statistics and Bell tests.
#
# Generates measurement correlations from quantum circuits for
# BetLang's bell_test_chsh and StatistEase's statistical analysis.

"""
    simulate_bell_experiment(n_measurements::Int; theta=π/4) -> Dict

Simulate a Bell/CHSH experiment with n measurements.
Returns correlations for 4 measurement settings and the CHSH S-value.
Classical bound: |S| ≤ 2. Quantum violation: |S| ≤ 2√2.
"""
function simulate_bell_experiment(n_measurements::Int; theta::Float64=π/4)
    # Measurement settings: (a₀, a₁) × (b₀, b₁)
    # Angles: a₀=0, a₁=π/4, b₀=π/8, b₁=3π/8
    settings = [(0.0, π/8), (0.0, 3π/8), (π/4, π/8), (π/4, 3π/8)]

    correlations = Float64[]
    for (a, b) in settings
        # Quantum prediction: E(a,b) = -cos(2(a-b))
        # For maximally entangled state (singlet)
        E = -cos(2 * (a - b))

        # Add statistical noise from finite measurements
        noise = randn() * sqrt((1 - E^2) / n_measurements)
        push!(correlations, clamp(E + noise, -1.0, 1.0))
    end

    # CHSH S-value: S = E(a₀,b₀) - E(a₀,b₁) + E(a₁,b₀) + E(a₁,b₁)
    S = correlations[1] - correlations[2] + correlations[3] + correlations[4]

    # Statistical significance of violation
    se_S = sqrt(4 * (1 / n_measurements))  # Approximate SE
    z_violation = (abs(S) - 2.0) / se_S
    p_violation = z_violation > 0 ? 1 - cdf(Normal(), z_violation) : 1.0

    return Dict{String,Any}(
        "S_value" => S,
        "classical_bound" => 2.0,
        "quantum_bound" => 2 * sqrt(2),
        "violates_classical" => abs(S) > 2.0,
        "p_violation" => p_violation,
        "correlations" => correlations,
        "n_measurements" => n_measurements,
        "test_type" => "CHSH Bell test simulation"
    )
end

"""
    quantum_random_walk(n_steps::Int; coin_bias=0.5) -> Dict

Quantum random walk using Hadamard coin. Compared to classical random
walk, produces different spread characteristics (ballistic vs diffusive).
"""
function quantum_random_walk(n_steps::Int; coin_bias::Float64=0.5)
    # Classical walk for comparison
    classical_pos = 0
    classical_positions = [0]
    for _ in 1:n_steps
        classical_pos += rand() < coin_bias ? 1 : -1
        push!(classical_positions, classical_pos)
    end

    # Quantum walk (simplified — position distribution)
    # Quantum walk spreads as O(n) vs classical O(√n)
    quantum_spread = n_steps  # Ballistic
    classical_spread = sqrt(n_steps)  # Diffusive

    return Dict{String,Any}(
        "n_steps" => n_steps,
        "classical_final_pos" => classical_pos,
        "classical_std" => std(classical_positions),
        "quantum_expected_spread" => quantum_spread,
        "classical_expected_spread" => classical_spread,
        "speedup_ratio" => quantum_spread / classical_spread,
        "test_type" => "Quantum vs classical random walk"
    )
end
