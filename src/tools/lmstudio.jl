# SPDX-License-Identifier: MPL-2.0
# LM Studio server interface.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  HARD NOTICE: NEURAL-SYMBOLIC BOUNDARY                                │
# │                                                                        │
# │  This module handles communication with the LLM (neural component).   │
# │  The LLM's role is EXCLUSIVELY:                                       │
# │  1. Parsing natural language input                                     │
# │  2. Deciding which statistical tool to invoke                          │
# │  3. Interpreting symbolic results in plain language                    │
# │                                                                        │
# │  The LLM NEVER computes statistics. If you see a number in the        │
# │  LLM's response that didn't come from a tool call, it is a            │
# │  MOLLOCK — a plausible-sounding fabrication. Trust only tool results.  │
# └─────────────────────────────────────────────────────────────────────────┘

# Configuration — override via environment variables
const BASE_URL = get(ENV, "STATISTEASE_LM_URL", "http://localhost:1234/v1")
const API_KEY = get(ENV, "STATISTEASE_API_KEY", "lm-studio")
const MODEL = get(ENV, "STATISTEASE_MODEL", "lmstudio-community/qwen2.5-7b-instruct")

const HEADERS = [
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer $API_KEY"
]

"""
    call_lm_studio(messages, tools; stream) -> Dict

Send a chat completion request to LM Studio.
Uses untyped Dict to avoid Julia method dispatch issues with JSON-parsed dicts.
"""
function call_lm_studio(messages, tools=nothing; stream::Bool=false)
    payload = Dict{String,Any}(
        "model" => MODEL,
        "messages" => messages,
        "temperature" => 0.7,
        "max_tokens" => 4000
    )

    if !isnothing(tools)
        payload["tools"] = tools
    end

    if stream
        payload["stream"] = true
    end

    body = Vector{UInt8}(JSON3.write(payload))

    try
        resp = HTTP.request("POST", "$BASE_URL/chat/completions", HEADERS, body;
                           status_exception=false)
        if resp.status == 200
            return JSON3.read(String(resp.body), Dict{String,Any})
        else
            return Dict{String,Any}("error" => "HTTP $(resp.status): $(String(resp.body))")
        end
    catch e
        return Dict{String,Any}("error" => "Connection failed: $(string(e))")
    end
end

"""
    process_tool_calls(response, messages) -> Union{Dict, Nothing}

Process tool calls from the LLM response. Executes symbolic functions
and returns results to the LLM for interpretation.
"""
function process_tool_calls(response, messages)
    if !haskey(response, "choices") || isempty(response["choices"])
        return nothing
    end

    choice = response["choices"][1]
    message = choice["message"]

    if haskey(message, "tool_calls") && !isnothing(message["tool_calls"]) && !isempty(message["tool_calls"])
        # Add assistant's tool call request
        push!(messages, Dict{String,Any}(
            "role" => "assistant",
            "tool_calls" => message["tool_calls"]
        ))

        # Execute each tool call (symbolic computation)
        for tool_call in message["tool_calls"]
            fn_name = tool_call["function"]["name"]
            args_str = tool_call["function"]["arguments"]
            args = JSON3.read(args_str, Dict{String,Any})

            println("\n  [symbolic] executing: $fn_name")
            result = execute_tool(fn_name, args)

            push!(messages, Dict{String,Any}(
                "role" => "tool",
                "content" => JSON3.write(result),
                "tool_call_id" => tool_call["id"]
            ))
        end

        # Get final response (LLM interprets the symbolic results)
        return call_lm_studio(messages)
    end

    return response
end
