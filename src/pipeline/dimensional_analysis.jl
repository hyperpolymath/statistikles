# SPDX-License-Identifier: MPL-2.0
# Dimensional analysis — ensuring physical quantities are used correctly.
#
# WHY THIS MATTERS
# ────────────────
# You cannot add meters to seconds. You cannot take the mean of a column
# that mixes temperatures and pressures. Dimensional analysis catches these
# errors BEFORE computation, not after.
#
# This is the same principle that caught the Mars Climate Orbiter error
# (pound-force vs newtons, 1999) and that catches unit errors in physics
# homework. Statistical software usually ignores dimensions entirely —
# it will happily compute the mean of [3 kg, 5 m, 7 seconds] and tell you
# the answer is 5.0 (dimensionless), which is meaningless.
#
# APPROACH
# ────────
# We represent dimensions as exponent vectors over base SI units:
#   [length, mass, time, temperature, current, amount, luminosity]
#
# Example: velocity = m/s = [1, 0, -1, 0, 0, 0, 0]
# Example: force = kg·m/s² = [1, 1, -2, 0, 0, 0, 0]
# Example: energy = kg·m²/s² = [2, 1, -2, 0, 0, 0, 0]
#
# Dimensionless quantities (ratios, counts, proportions) = [0,0,0,0,0,0,0]
#
# Rules:
# - Addition/subtraction: dimensions MUST match
# - Multiplication: dimensions ADD
# - Division: dimensions SUBTRACT
# - Exponentiation: dimensions MULTIPLY by exponent
# - Statistical functions (mean, sd, etc.): all values must have same dimension
# - Correlation/regression: units are tracked through the computation

# Dimension vector: [length, mass, time, temperature, current, amount, luminosity]
const DIM_NAMES = ["length", "mass", "time", "temperature", "current", "amount", "luminosity"]

"""
    Dimension

Represents the physical dimension of a quantity as SI base unit exponents.
"""
struct Dimension
    exponents::Vector{Int}  # 7 elements: L, M, T, Θ, I, N, J
    label::String           # Human-readable label (e.g., "m/s", "kg")
end

# Common dimensions
const DIMENSIONLESS = Dimension(zeros(Int, 7), "dimensionless")
const LENGTH = Dimension([1,0,0,0,0,0,0], "m")
const MASS = Dimension([0,1,0,0,0,0,0], "kg")
const TIME = Dimension([0,0,1,0,0,0,0], "s")
const TEMPERATURE = Dimension([0,0,0,1,0,0,0], "K")
const VELOCITY = Dimension([1,0,-1,0,0,0,0], "m/s")
const ACCELERATION = Dimension([1,0,-2,0,0,0,0], "m/s²")
const FORCE = Dimension([1,1,-2,0,0,0,0], "N")
const ENERGY = Dimension([2,1,-2,0,0,0,0], "J")
const PRESSURE = Dimension([-1,1,-2,0,0,0,0], "Pa")
const FREQUENCY = Dimension([0,0,-1,0,0,0,0], "Hz")

"""
    dimensions_compatible(a::Dimension, b::Dimension) -> Bool

Check if two dimensions are compatible for addition/subtraction.
"""
dimensions_compatible(a::Dimension, b::Dimension) = a.exponents == b.exponents

"""
    detect_dimension(unit_string::String) -> Dimension

Parse a unit string into its dimensional representation.
"""
function detect_dimension(unit_string::String)
    s = strip(lowercase(unit_string))

    # Direct SI unit mapping
    unit_map = Dict(
        # Length
        "m" => LENGTH, "meter" => LENGTH, "metre" => LENGTH, "meters" => LENGTH,
        "cm" => LENGTH, "mm" => LENGTH, "km" => LENGTH,
        "in" => LENGTH, "inch" => LENGTH, "inches" => LENGTH,
        "ft" => LENGTH, "feet" => LENGTH, "foot" => LENGTH,
        "yd" => LENGTH, "yard" => LENGTH, "yards" => LENGTH,
        "mi" => LENGTH, "mile" => LENGTH, "miles" => LENGTH,
        # Mass
        "kg" => MASS, "g" => MASS, "gram" => MASS, "grams" => MASS,
        "lb" => MASS, "lbs" => MASS, "pound" => MASS, "pounds" => MASS,
        "oz" => MASS, "ounce" => MASS, "ounces" => MASS,
        # Time
        "s" => TIME, "sec" => TIME, "second" => TIME, "seconds" => TIME,
        "min" => TIME, "minute" => TIME, "minutes" => TIME,
        "h" => TIME, "hr" => TIME, "hour" => TIME, "hours" => TIME,
        "day" => TIME, "days" => TIME,
        "year" => TIME, "years" => TIME, "yr" => TIME,
        # Temperature
        "k" => TEMPERATURE, "kelvin" => TEMPERATURE,
        "c" => TEMPERATURE, "celsius" => TEMPERATURE, "°c" => TEMPERATURE,
        "f" => TEMPERATURE, "fahrenheit" => TEMPERATURE, "°f" => TEMPERATURE,
        # Dimensionless
        "%" => DIMENSIONLESS, "percent" => DIMENSIONLESS,
        "ratio" => DIMENSIONLESS, "proportion" => DIMENSIONLESS,
        "count" => DIMENSIONLESS, "n" => DIMENSIONLESS,
    )

    if haskey(unit_map, s)
        return unit_map[s]
    end

    return Dimension(zeros(Int, 7), "unknown ($unit_string)")
end

"""
    check_dimensional_consistency(values::Vector{Float64},
                                  units::Vector{String}) -> Dict

Verify that all values in a dataset have compatible dimensions.
This MUST pass before any statistical computation.
"""
function check_dimensional_consistency(values::Vector{Float64},
                                       units::Vector{String})
    n = length(values)
    if length(units) != n
        return Dict{String,Any}("error" => "Values and units vectors must have same length")
    end

    dimensions = [detect_dimension(u) for u in units]
    issues = String[]

    # Check that all dimensions are the same
    reference = dimensions[1]
    for i in 2:n
        if !dimensions_compatible(reference, dimensions[i])
            push!(issues,
                "Row $i: '$(units[i])' ($(dim_to_string(dimensions[i]))) " *
                "is incompatible with row 1: '$(units[1])' ($(dim_to_string(reference))). " *
                "Cannot compute statistics across different physical dimensions.")
        end
    end

    # Check for mixed unit systems within compatible dimensions
    # (e.g., some values in cm, others in inches — same dimension, different scales)
    unit_set = Set(lowercase.(strip.(units)))
    if length(unit_set) > 1 && isempty(issues)
        push!(issues,
            "Multiple unit representations found: $(join(unit_set, ", ")). " *
            "All values must be converted to the same unit before computation. " *
            "Dimensions are compatible but SCALES may differ.")
    end

    consistent = isempty(issues)

    return Dict{String,Any}(
        "consistent" => consistent,
        "reference_dimension" => dim_to_string(reference),
        "n_values" => n,
        "issues" => issues,
        "dimension_vector" => reference.exponents,
        "recommendation" => consistent ?
            "All values have compatible dimensions — computation may proceed" :
            "STOP: Dimensional inconsistency detected. Fix units before computing.",
        "note" => "Statistical functions (mean, sd, correlation, etc.) require " *
                  "all input values to have the same physical dimension. " *
                  "A mean of [3 kg, 5 m, 7 s] is meaningless."
    )
end

"""
    track_dimensions_through_computation(input_dim::Dimension,
                                          operation::String) -> Dimension

Track how dimensions transform through statistical operations.
"""
function track_dimensions_through_computation(input_dim::Dimension,
                                               operation::String)
    op = lowercase(operation)

    if op in ["mean", "median", "mode", "min", "max", "sum",
              "q1", "q3", "percentile", "trimmed_mean"]
        # Same dimension as input
        return input_dim
    elseif op in ["variance", "mean_squared_error"]
        # Dimension squared
        return Dimension(input_dim.exponents .* 2,
                        "($(input_dim.label))²")
    elseif op in ["std_dev", "standard_error", "sem", "mad",
                  "range", "iqr"]
        # Same dimension as input
        return input_dim
    elseif op in ["coefficient_of_variation", "z_score",
                  "correlation", "r_squared", "eta_squared",
                  "cohens_d", "t_statistic", "f_statistic",
                  "chi_square", "p_value", "skewness", "kurtosis"]
        # Dimensionless (ratio of same-dimension quantities)
        return DIMENSIONLESS
    elseif op == "regression_slope"
        # Slope has dimensions of y/x — need both to compute
        return Dimension(zeros(Int, 7), "y_dim / x_dim")
    elseif op == "regression_intercept"
        # Intercept has dimensions of y
        return input_dim
    else
        return Dimension(zeros(Int, 7), "unknown ($(operation))")
    end
end

"""
    dim_to_string(d::Dimension) -> String

Convert a dimension to a human-readable string.
"""
function dim_to_string(d::Dimension)
    if all(d.exponents .== 0)
        return "dimensionless"
    end

    parts = String[]
    for (i, exp) in enumerate(d.exponents)
        if exp != 0
            name = DIM_NAMES[i]
            if exp == 1
                push!(parts, name)
            else
                push!(parts, "$(name)^$(exp)")
            end
        end
    end
    return join(parts, "·")
end

"""
    dimensional_report(values::Vector{Float64}, units::Vector{String},
                       operations::Vector{String}) -> Dict

Generate a complete dimensional analysis report for a planned computation.
Shows what dimensions each intermediate result will have.
"""
function dimensional_report(values::Vector{Float64}, units::Vector{String},
                            operations::Vector{String})
    # First check consistency
    consistency = check_dimensional_consistency(values, units)
    if !consistency["consistent"]
        return Dict{String,Any}(
            "can_proceed" => false,
            "consistency" => consistency,
            "note" => "Cannot perform dimensional analysis — input dimensions are inconsistent"
        )
    end

    input_dim = detect_dimension(units[1])
    results = Dict{String,String}[]

    for op in operations
        output_dim = track_dimensions_through_computation(input_dim, op)
        push!(results, Dict(
            "operation" => op,
            "input_dimension" => dim_to_string(input_dim),
            "output_dimension" => dim_to_string(output_dim)
        ))
    end

    return Dict{String,Any}(
        "can_proceed" => true,
        "input_dimension" => dim_to_string(input_dim),
        "operations" => results,
        "consistency" => consistency,
        "note" => "All operations are dimensionally valid. " *
                  "Results carry the dimensions shown above."
    )
end
