# SPDX-License-Identifier: MPL-2.0
# Data type detection — first stage of the Data Quality Pathway.
#
# Raw Input → [DETECTION] → Validation → Cleansing → Normalization → Analysis
#
# This module identifies what kind of data we're working with before
# any statistical computation begins.

"""
    detect_data_type(values::Vector) -> Dict

Detect the measurement level and type of a data vector.
Returns scale type (nominal, ordinal, interval, ratio), suggested tests,
and data quality indicators.
"""
function detect_data_type(values::Vector)
    n = length(values)
    n_missing = count(ismissing, values)
    clean = filter(!ismissing, values)

    # Try numeric
    numeric_vals = Float64[]
    for v in clean
        if v isa Number
            push!(numeric_vals, Float64(v))
        elseif v isa AbstractString
            parsed = tryparse(Float64, v)
            !isnothing(parsed) && push!(numeric_vals, parsed)
        end
    end

    is_numeric = length(numeric_vals) > 0.8 * length(clean)

    if is_numeric && !isempty(numeric_vals)
        n_unique = length(unique(numeric_vals))
        all_int = all(x -> x == floor(x), numeric_vals)

        # Heuristic scale detection
        scale = if n_unique <= 2
            "binary"
        elseif n_unique <= 7 && all_int
            "ordinal_likely"
        elseif all(x -> x >= 0, numeric_vals)
            "ratio"
        else
            "interval"
        end

        return Dict{String,Any}(
            "data_type" => "numeric",
            "scale" => scale,
            "n" => n, "n_missing" => n_missing,
            "n_unique" => n_unique,
            "all_integer" => all_int,
            "range" => (minimum(numeric_vals), maximum(numeric_vals)),
            "suggested_tests" => scale == "binary" ?
                ["chi_square", "proportion_test", "logistic_regression"] :
                scale == "ordinal_likely" ?
                ["mann_whitney", "kruskal_wallis", "spearman"] :
                ["t_test", "anova", "pearson", "regression"]
        )
    else
        # Categorical
        str_vals = String.(clean)
        n_unique = length(unique(str_vals))

        return Dict{String,Any}(
            "data_type" => "categorical",
            "scale" => n_unique <= 2 ? "binary" : "nominal",
            "n" => n, "n_missing" => n_missing,
            "n_unique" => n_unique,
            "categories" => sort(unique(str_vals)),
            "suggested_tests" => ["chi_square", "frequency_analysis", "cohens_kappa"]
        )
    end
end

"""
    detect_file_format(path::String) -> Dict

Detect the format and structure of a data file.
"""
function detect_file_format(path::String)
    !isfile(path) && return Dict{String,Any}("error" => "File not found: $path")

    ext = lowercase(splitext(path)[2])
    size_bytes = filesize(path)

    format = if ext in [".csv", ".tsv"]
        "delimited"
    elseif ext == ".json"
        "json"
    elseif ext in [".xlsx", ".xls"]
        "spreadsheet"
    elseif ext in [".sav", ".sas7bdat", ".dta"]
        "statistical_package"
    else
        "unknown"
    end

    # For delimited files, detect delimiter and header
    if format == "delimited"
        first_lines = readlines(path; keep=false)
        n_lines = length(first_lines)
        first_line = n_lines > 0 ? first_lines[1] : ""

        n_commas = count(',', first_line)
        n_tabs = count('\t', first_line)
        delimiter = n_tabs > n_commas ? "tab" : "comma"

        has_header = !all(c -> tryparse(Float64, c) !== nothing,
                         split(first_line, delimiter == "tab" ? '\t' : ','))

        return Dict{String,Any}(
            "format" => format, "extension" => ext,
            "delimiter" => delimiter, "has_header" => has_header,
            "n_rows_estimate" => n_lines - (has_header ? 1 : 0),
            "size_bytes" => size_bytes
        )
    end

    return Dict{String,Any}(
        "format" => format, "extension" => ext,
        "size_bytes" => size_bytes
    )
end
