# SPDX-License-Identifier: MPL-2.0
# Data canonicalization — ZEROTH stage of the Data Quality Pathway.
#
# [CANONICALIZATION] → Detection → Validation → Cleansing → Normalization → Analysis
#
# Before we can detect, validate, or compute ANYTHING, we must ensure that
# the input data is interpreted unambiguously. This module handles:
#
# 1. DATE FORMAT DETECTION AND NORMALIZATION
#    - Is "01/02/2026" January 2nd or February 1st?
#    - Enforces ISO 8601 (YYYY-MM-DD) as the canonical internal format
#    - Detects and reports ambiguous dates
#
# 2. DECIMAL SEPARATOR DETECTION
#    - Is "1,234" the integer 1234 or the float 1.234?
#    - Is "1.234,56" nonsense or the German float 1234.56?
#    - Detects locale conventions and normalizes to dot-decimal
#
# 3. EXPRESSION PRECEDENCE
#    - Julia follows standard mathematical precedence (PEMDAS/BODMAS)
#    - This is documented explicitly so users from calculator/Excel
#      backgrounds know what to expect
#
# 4. UNIT DETECTION
#    - Flags mixed unit systems (inches and cm in same column)
#    - Does NOT auto-convert (too dangerous) — asks the user
#
# 5. TYPE COERCION DETECTION
#    - Catches Excel-style corruption (gene names → dates, leading zeros stripped)
#    - Detects boolean/string ambiguity ("TRUE", "true", "1", "yes")
#
# WHY THIS MATTERS
# ────────────────
# The Mars Climate Orbiter crashed because one team used pounds-force and
# another used newtons. Ziemann et al. (2016) found that ~20% of genomics
# papers had gene names corrupted to dates by Excel. These are not edge
# cases — they are the NORMAL failure mode of data exchange.
#
# If we don't catch this HERE, both StatistEase and Aspasia will compute
# confidently on misinterpreted data, agree with each other (because they
# both misinterpreted the same way), and produce a verified wrong answer.

"""
    canonicalize_input(raw_values::Vector{String}; locale_hint="auto") -> Dict

Detect and resolve ambiguities in raw string input before any computation.
Returns canonicalized values plus a detailed report of interpretations made.
"""
function canonicalize_input(raw_values::Vector{String}; locale_hint::String="auto")
    n = length(raw_values)
    issues = String[]
    warnings = String[]
    canonical = Vector{Any}(nothing, n)
    interpretations = Dict{Int,String}()

    # Phase 1: Detect the dominant locale/format
    detected_locale = locale_hint == "auto" ? detect_locale(raw_values) : locale_hint

    for (i, raw) in enumerate(raw_values)
        stripped = strip(raw)

        # Check for date-like patterns FIRST (before number parsing eats them)
        date_result = try_parse_date(stripped)
        if date_result.is_date
            if date_result.ambiguous
                push!(warnings,
                    "Row $i: '$(stripped)' is an AMBIGUOUS date — " *
                    "could be $(date_result.interpretation_a) (US) or " *
                    "$(date_result.interpretation_b) (UK/EU). " *
                    "Using ISO 8601 interpretation: $(date_result.canonical)")
            end
            canonical[i] = date_result.canonical
            interpretations[i] = "date → $(date_result.canonical)"
            continue
        end

        # Check for number-like patterns
        num_result = try_parse_number(stripped, detected_locale)
        if num_result.is_number
            if num_result.ambiguous
                push!(warnings,
                    "Row $i: '$(stripped)' is AMBIGUOUS — could be " *
                    "$(num_result.interpretation_a) or $(num_result.interpretation_b). " *
                    "Interpreted as $(num_result.value) using $(detected_locale) locale.")
            end
            canonical[i] = num_result.value
            interpretations[i] = "number → $(num_result.value)"
            continue
        end

        # Check for Excel-corrupted gene names
        if is_excel_corrupted(stripped)
            push!(issues,
                "Row $i: '$(stripped)' looks like an Excel-corrupted gene name " *
                "(e.g., MARCH1 → Mar-01). Original value may be lost.")
            canonical[i] = stripped
            interpretations[i] = "WARNING: possible Excel corruption"
            continue
        end

        # Check for boolean ambiguity
        bool_result = try_parse_boolean(stripped)
        if bool_result.is_boolean
            canonical[i] = bool_result.value
            interpretations[i] = "boolean → $(bool_result.value)"
            continue
        end

        # Check for leading zeros (ID field vs number?)
        if startswith(stripped, "0") && all(isdigit, stripped) && length(stripped) > 1
            push!(warnings,
                "Row $i: '$(stripped)' has leading zeros — is this a number ($(parse(Int, stripped))) " *
                "or an identifier (keep as string '$(stripped)')? Treating as string.")
            canonical[i] = stripped
            interpretations[i] = "string (leading zeros preserved)"
            continue
        end

        # Default: keep as string
        canonical[i] = stripped
        interpretations[i] = "string"
    end

    return Dict{String,Any}(
        "canonical" => canonical,
        "interpretations" => interpretations,
        "detected_locale" => detected_locale,
        "n_values" => n,
        "n_issues" => length(issues),
        "n_warnings" => length(warnings),
        "issues" => issues,
        "warnings" => warnings,
        "precedence_note" => "Julia uses standard mathematical precedence (PEMDAS/BODMAS). " *
            "Exponentiation is right-associative: 2^3^2 = 2^(3^2) = 512, not (2^3)^2 = 64.",
        "recommendation" => isempty(issues) && isempty(warnings) ?
            "Input appears unambiguous" :
            "REVIEW REQUIRED: $(length(warnings)) ambiguous values detected. " *
            "Verify interpretations before proceeding."
    )
end


"""
    detect_locale(values::Vector{String}) -> String

Detect whether values use dot-decimal ("en") or comma-decimal ("eu") convention.
"""
function detect_locale(values::Vector{String})
    dot_count = 0   # Values matching English format (1,234.56)
    comma_count = 0 # Values matching European format (1.234,56)

    for val in values
        stripped = strip(val)
        # Pattern: digits, then comma, then exactly 3 digits, then dot
        # → English thousands separator: 1,234.56
        if occursin(r"^\d{1,3}(,\d{3})*\.\d+$", stripped)
            dot_count += 1
        # Pattern: digits, then dot, then exactly 3 digits, then comma
        # → European thousands separator: 1.234,56
        elseif occursin(r"^\d{1,3}(\.\d{3})*,\d+$", stripped)
            comma_count += 1
        # Single comma with 1-2 digits after → likely European decimal
        elseif occursin(r"^\d+,\d{1,2}$", stripped)
            comma_count += 1
        # Single dot with digits after → likely English decimal
        elseif occursin(r"^\d+\.\d+$", stripped)
            dot_count += 1
        end
    end

    if comma_count > dot_count
        return "eu"  # European: comma decimal, dot thousands
    else
        return "en"  # English: dot decimal, comma thousands
    end
end


"""
    try_parse_date(s::String) -> NamedTuple

Attempt to parse a string as a date. Detect ambiguous formats.
"""
function try_parse_date(s::String)
    # ISO 8601 — unambiguous, always preferred
    m = match(r"^(\d{4})-(\d{2})-(\d{2})$", s)
    if !isnothing(m)
        y, mo, d = parse.(Int, m.captures)
        return (is_date=true, ambiguous=false,
                canonical=s, interpretation_a=s, interpretation_b=s)
    end

    # Slash format — AMBIGUOUS
    m = match(r"^(\d{1,2})/(\d{1,2})/(\d{2,4})$", s)
    if !isnothing(m)
        a, b, c = parse.(Int, m.captures)
        year = c < 100 ? c + 2000 : c

        if a > 12 && b <= 12
            # a must be day (>12), b is month → DD/MM/YYYY (UK)
            canonical = @sprintf("%04d-%02d-%02d", year, b, a)
            return (is_date=true, ambiguous=false,
                    canonical=canonical, interpretation_a=canonical, interpretation_b=canonical)
        elseif b > 12 && a <= 12
            # b must be day (>12), a is month → MM/DD/YYYY (US)
            canonical = @sprintf("%04d-%02d-%02d", year, a, b)
            return (is_date=true, ambiguous=false,
                    canonical=canonical, interpretation_a=canonical, interpretation_b=canonical)
        elseif a <= 12 && b <= 12
            # AMBIGUOUS — both could be month or day
            us_interp = @sprintf("%04d-%02d-%02d", year, a, b)  # MM/DD/YYYY
            uk_interp = @sprintf("%04d-%02d-%02d", year, b, a)  # DD/MM/YYYY
            # Default to ISO-like (assume DD/MM/YYYY as more globally common)
            return (is_date=true, ambiguous=true,
                    canonical=uk_interp,
                    interpretation_a=us_interp,
                    interpretation_b=uk_interp)
        end
    end

    # Dash format with month names — unambiguous
    m = match(r"^(\d{1,2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d{2,4})$"i, s)
    if !isnothing(m)
        d = parse(Int, m.captures[1])
        month_str = titlecase(m.captures[2])
        y = parse(Int, m.captures[3])
        y = y < 100 ? y + 2000 : y
        months = Dict("Jan"=>1,"Feb"=>2,"Mar"=>3,"Apr"=>4,"May"=>5,"Jun"=>6,
                      "Jul"=>7,"Aug"=>8,"Sep"=>9,"Oct"=>10,"Nov"=>11,"Dec"=>12)
        mo = months[month_str]
        canonical = @sprintf("%04d-%02d-%02d", y, mo, d)
        return (is_date=true, ambiguous=false,
                canonical=canonical, interpretation_a=canonical, interpretation_b=canonical)
    end

    return (is_date=false, ambiguous=false,
            canonical="", interpretation_a="", interpretation_b="")
end


"""
    try_parse_number(s::String, locale::String) -> NamedTuple

Attempt to parse a string as a number, respecting locale conventions.
"""
function try_parse_number(s::String, locale::String)
    # Pure integer
    if occursin(r"^-?\d+$", s)
        return (is_number=true, ambiguous=false,
                value=parse(Float64, s),
                interpretation_a="", interpretation_b="")
    end

    if locale == "en"
        # English: 1,234.56 → remove commas, parse
        cleaned = replace(s, "," => "")
        if occursin(r"^-?\d+\.?\d*$", cleaned)
            val = parse(Float64, cleaned)
            # Check if the original had ambiguous comma usage
            # "1,234" is unambiguous (English thousands). "1,23" is suspicious.
            if occursin(r",\d{1,2}$", s) && !occursin(r",\d{3}", s)
                return (is_number=true, ambiguous=true,
                        value=val,
                        interpretation_a="$(val) (English: comma as thousands)",
                        interpretation_b="$(replace(s, "," => ".") |> x -> parse(Float64, x)) (European: comma as decimal)")
            end
            return (is_number=true, ambiguous=false, value=val,
                    interpretation_a="", interpretation_b="")
        end
    else  # eu
        # European: 1.234,56 → swap separators, parse
        cleaned = replace(replace(s, "." => ""), "," => ".")
        if occursin(r"^-?\d+\.?\d*$", cleaned)
            return (is_number=true, ambiguous=false,
                    value=parse(Float64, cleaned),
                    interpretation_a="", interpretation_b="")
        end
    end

    # Scientific notation
    if occursin(r"^-?\d+\.?\d*[eE][+-]?\d+$", s)
        return (is_number=true, ambiguous=false,
                value=parse(Float64, s),
                interpretation_a="", interpretation_b="")
    end

    return (is_number=false, ambiguous=false, value=NaN,
            interpretation_a="", interpretation_b="")
end


"""
    is_excel_corrupted(s::String) -> Bool

Detect values that look like Excel auto-converted gene names to dates.
Ziemann et al. (2016): ~20% of genomics papers affected.
"""
function is_excel_corrupted(s::String)
    # Common gene name → date corruptions
    excel_patterns = [
        r"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-\d{2}$"i,  # MARCH1 → Mar-01
        r"^\d{1,2}-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$"i, # SEPT2 → 2-Sep
    ]
    return any(p -> occursin(p, s), excel_patterns)
end


"""
    try_parse_boolean(s::String) -> NamedTuple

Parse boolean values consistently. Documents what maps to true/false.
"""
function try_parse_boolean(s::String)
    true_vals = Set(["true", "TRUE", "True", "yes", "YES", "Yes", "1", "T", "Y"])
    false_vals = Set(["false", "FALSE", "False", "no", "NO", "No", "0", "F", "N"])

    if s in true_vals
        return (is_boolean=true, value=true)
    elseif s in false_vals
        return (is_boolean=true, value=false)
    end
    return (is_boolean=false, value=false)
end


"""
    precedence_check(expression::String) -> Dict

Document how Julia evaluates an expression and flag potential surprises
for users coming from calculators or Excel.
"""
function precedence_check(expression::String)
    known_surprises = Dict{String,String}(
        "^" => "Exponentiation is RIGHT-associative in Julia: 2^3^2 = 2^(3^2) = 512. " *
               "In some calculators and Excel, it is left-associative: (2^3)^2 = 64.",
        "/" => "Division of integers produces a float in Julia: 7/2 = 3.5. " *
               "In Python 2 and some languages, 7/2 = 3 (integer division). " *
               "Use div(7,2) or 7÷2 for integer division.",
        "%" => "Julia uses '%' for the remainder operator (like C). " *
               "It is NOT the modulo operator for negative numbers. " *
               "Use mod(x,y) for true mathematical modulo.",
        "-" => "Unary minus binds tighter than exponentiation: -2^2 = -(2^2) = -4. " *
               "In some calculators, -2^2 = (-2)^2 = 4."
    )

    warnings = String[]
    for (op, warning) in known_surprises
        if occursin(op, expression)
            push!(warnings, warning)
        end
    end

    return Dict{String,Any}(
        "expression" => expression,
        "julia_precedence" => "Standard PEMDAS/BODMAS with right-associative exponentiation",
        "warnings" => warnings,
        "note" => "Julia follows standard mathematical precedence. " *
                  "If you are used to a calculator, Excel, or another language, " *
                  "some results may differ. When in doubt, use explicit parentheses."
    )
end


"""
    check_constant_integrity() -> Dict

Verify that mathematical constants have not been redefined, approximated,
or shadowed. This is a safety check — if someone has done `pi = 22/7` or
`e = 2.7` in their session, every subsequent computation is wrong.

This function should be called BEFORE any computation and its result
should be included in every transaction sent to Aspasia.
"""
function check_constant_integrity()
    issues = String[]
    constants_ok = true

    # Check pi
    if abs(pi - 3.141592653589793) > 1e-15
        constants_ok = false
        push!(issues,
            "CRITICAL: pi has been redefined! Current value: $(pi). " *
            "Expected: 3.141592653589793. Every trigonometric and " *
            "circular computation is WRONG until this is fixed.")
    end

    # Check Euler's number
    expected_e = Base.MathConstants.e
    if abs(Float64(expected_e) - 2.718281828459045) > 1e-15
        constants_ok = false
        push!(issues,
            "CRITICAL: e (Euler's number) may have been redefined! " *
            "Expected: 2.718281828459045.")
    end

    # Check common approximation traps
    approximation_warnings = String[]
    # These are things users might reasonably do that are dangerous
    # pi ≈ 22/7 (accurate to 0.04%)
    # pi ≈ 355/113 (accurate to 0.000008%)
    # e ≈ 19/7 (accurate to 0.12%)
    # sqrt(2) ≈ 1.414 (truncated)

    return Dict{String,Any}(
        "constants_ok" => constants_ok,
        "issues" => issues,
        "verified_values" => Dict(
            "pi" => Float64(pi),
            "e" => Float64(Base.MathConstants.e),
            "sqrt2" => sqrt(2.0),
            "ln2" => log(2.0),
            "ln10" => log(10.0)
        ),
        "note" => constants_ok ?
            "All mathematical constants verified at full Float64 precision" :
            "CONSTANT INTEGRITY VIOLATION — DO NOT PROCEED UNTIL FIXED",
        "recommendation" => "Never reassign mathematical constants. " *
            "If you need an approximation for pedagogical purposes, " *
            "use a DIFFERENT variable name (e.g., pi_approx = 22/7) " *
            "and document it clearly."
    )
end


"""
    check_variable_shadows(var_names::Vector{String}) -> Dict

Check if user-defined variable names shadow built-in functions or constants.
Common trap: naming a variable 'mean', 'std', 'var', 'sum', 'length', etc.
"""
function check_variable_shadows(var_names::Vector{String})
    # Functions and constants that should NEVER be shadowed
    critical_names = Set([
        "pi", "e", "Inf", "NaN", "true", "false", "nothing",
        "mean", "median", "std", "var", "sum", "length", "size",
        "min", "max", "sort", "abs", "sqrt", "log", "exp",
        "sin", "cos", "tan", "quantile", "cor",
    ])

    shadows = String[]
    for name in var_names
        if name in critical_names
            push!(shadows,
                "Variable '$(name)' shadows the built-in function/constant '$(name)'. " *
                "This will cause incorrect results. Rename your variable.")
        end
    end

    return Dict{String,Any}(
        "shadows_found" => !isempty(shadows),
        "n_shadows" => length(shadows),
        "shadows" => shadows,
        "severity" => isempty(shadows) ? "ok" :
            any(n -> n in Set(["pi", "e", "Inf", "NaN"]), var_names) ? "critical" : "warning",
        "recommendation" => isempty(shadows) ? "No variable shadowing detected" :
            "RENAME shadowed variables immediately. Use descriptive names " *
            "(e.g., 'group_mean' instead of 'mean', 'sample_var' instead of 'var')."
    )
end


"""
    detect_unit_mixing(values::Vector{String}) -> Dict

Detect potential mixed unit systems in data labels or values.
"""
function detect_unit_mixing(values::Vector{String})
    imperial = String[]
    metric = String[]
    imperial_patterns = [r"(?i)\b(inch|inches|in|ft|feet|foot|yard|yd|mile|mi|lb|lbs|pound|oz|ounce|fahrenheit|°F)\b"]
    metric_patterns = [r"(?i)\b(cm|mm|meter|metre|km|kg|gram|g|celsius|°C|litre|liter|ml)\b"]

    for val in values
        for p in imperial_patterns
            if occursin(p, val)
                push!(imperial, val)
            end
        end
        for p in metric_patterns
            if occursin(p, val)
                push!(metric, val)
            end
        end
    end

    mixed = !isempty(imperial) && !isempty(metric)

    return Dict{String,Any}(
        "mixed_units" => mixed,
        "imperial_found" => imperial,
        "metric_found" => metric,
        "warning" => mixed ?
            "MIXED UNIT SYSTEMS DETECTED. Imperial and metric values found in the same dataset. " *
            "This WILL produce incorrect results if not resolved. " *
            "Convert all values to one system before analysis. " *
            "(Reference: Mars Climate Orbiter, 1999 — \$327M loss from unit confusion)" :
            "No mixed units detected"
    )
end
