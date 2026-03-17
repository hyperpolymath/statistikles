# SPDX-License-Identifier: PMPL-1.0-or-later

# Complexity Analysis — Empirical Algorithmic Profiling.
#
# This module performs empirical time-complexity analysis by measuring 
# execution time across multiple scales and fitting a complexity model.

"""
    estimate_complexity(f::Function, input_gen::Function; n_range=[10, 100, 1000], trials=3) -> Dict

EMPIRICAL BIG O: Measures the growth rate of a function.
- `f`: The function to profile (e.g., sort).
- `input_gen`: A function that generates an input for size N.
- `n_range`: Vector of input sizes to test.
"""
function estimate_complexity(f::Function, input_gen::Function; 
                             n_range::Vector{Int}=[100, 500, 1000, 2000, 5000], 
                             trials::Int=5)
    times = Float64[]
    
    for n in n_range
        t_sum = 0.0
        for _ in 1:trials
            input = input_gen(n)
            # Warm up / Compile
            f(input_gen(max(1, div(n, 10)))) 
            
            t = @elapsed f(input)
            t_sum += t
        end
        push!(times, t_sum / trials)
    end
    
    # Fit power law: T(n) = a * n^b  => log(T) = log(a) + b * log(n)
    log_n = log.(n_range)
    log_t = log.(max.(times, 1e-10))
    
    # Linear regression on log-log data
    # y = beta0 + beta1 * x
    mx, my = mean(log_n), mean(log_t)
    beta1 = sum((log_n .- mx) .* (log_t .- my)) / sum((log_n .- mx).^2)
    beta0 = my - beta1 * mx
    
    exponent = beta1
    
    # Classify Big O
    complexity_class = if exponent < 0.1
        "O(1) - Constant"
    elseif exponent < 0.8
        "O(log n) - Logarithmic"
    elseif exponent < 1.2
        "O(n) - Linear"
    elseif exponent < 1.4
        "O(n log n) - Linearithmic"
    elseif exponent < 2.3
        "O(n^2) - Quadratic"
    elseif exponent < 3.3
        "O(n^3) - Cubic"
    else
        "O(2^n) - Exponential"
    end
    
    return Dict{String,Any}(
        "complexity_class" => complexity_class,
        "empirical_exponent" => exponent,
        "n_tested" => n_range,
        "avg_times" => times,
        "r_squared" => cor(log_n, log_t)^2
    )
end
