#!/bin/bash
# Custom status line for Claude Code
# Shows: conversation context % | tokens | model | git repo:branch [dirty]
#
# NOTE: This shows CONVERSATION context only (your messages + Claude's responses).
#       It does NOT include system prompt, tools, agents, skills, or memory files.
#       Use /context command to see TOTAL context usage including all overhead.
#
# Claude Code passes JSON via stdin with structure:
#   .model.display_name - model name
#   .context_window.total_input_tokens - input tokens used
#   .context_window.total_output_tokens - output tokens used
#   .context_window.context_window_size - max context window
#   .cost.total_cost_usd - session cost in USD
#   .output_style.name - active output style (e.g., "explanatory")

# Color thresholds
# Session cost in USD: green <= COST_GREEN_MAX, yellow <= COST_YELLOW_MAX, red above
COST_GREEN_MAX=5
COST_YELLOW_MAX=15
# Context usage in %: green < CTX_GREEN_MAX, yellow < CTX_YELLOW_MAX, red above
CTX_GREEN_MAX=50
CTX_YELLOW_MAX=75

# Read JSON from stdin (Claude Code pipes this to us)
input=$(cat)

output=""

# Helper: format large numbers (1500 -> 1.5k, 150000 -> 150k)
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        printf "%.1fM" "$(echo "scale=1; $num / 1000000" | bc)"
    elif [ "$num" -ge 1000 ]; then
        printf "%.1fk" "$(echo "scale=1; $num / 1000" | bc)"
    else
        echo "$num"
    fi
}

# Colors
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
cyan="\033[36m"
reset="\033[0m"

# Parse context usage from JSON using jq
if command -v jq &>/dev/null && [ -n "$input" ]; then
    input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
    output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
    context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
    model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

    # Calculate percentage and total tokens if we have valid numbers
    if [ "$context_size" -gt 0 ] 2>/dev/null; then
        total_tokens=$((input_tokens + output_tokens))

        # Context % based on INPUT tokens only (aligned with /context command)
        percent=$((input_tokens * 100 / context_size))

        # Color coding based on CTX_* thresholds
        if [ "$percent" -lt "$CTX_GREEN_MAX" ]; then
            pct_color="$green"
        elif [ "$percent" -lt "$CTX_YELLOW_MAX" ]; then
            pct_color="$yellow"
        else
            pct_color="$red"
        fi

        # Show conversation context % and total tokens consumed
        # "Chat ctx" makes it clear this is conversation only, not total context (use /context for that)
        total_formatted=$(format_tokens "$total_tokens")
        output="Chat ctx: ${pct_color}${percent}%${reset} | ${cyan}${total_formatted}${reset} total tokens"
    fi

    # Parse session cost
    cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

    # Add cost segment if > 0
    if [ "$(echo "$cost_usd > 0" | bc 2>/dev/null)" = "1" ]; then
        # Color coding based on COST_* thresholds
        if [ "$(echo "$cost_usd <= $COST_GREEN_MAX" | bc)" = "1" ]; then
            cost_color="$green"
        elif [ "$(echo "$cost_usd <= $COST_YELLOW_MAX" | bc)" = "1" ]; then
            cost_color="$yellow"
        else
            cost_color="$red"
        fi

        # Format: <$0.01 for tiny, $X.XX otherwise
        if [ "$(echo "$cost_usd < 0.01" | bc)" = "1" ]; then
            cost_display="<\$0.01"
        else
            cost_display=$(printf "$%.2f" "$cost_usd")
        fi

        if [ -n "$output" ]; then
            output="${output} | ${cost_color}${cost_display}${reset}"
        else
            output="${cost_color}${cost_display}${reset}"
        fi
    fi

    # Parse output style
    style_name=$(echo "$input" | jq -r '.output_style.name // "default"')

    # Add model name (with optional style indicator)
    if [ -n "$model" ] && [ "$model" != "unknown" ] && [ "$model" != "null" ]; then
        model_segment="${model}"

        # Append output style in brackets if non-default
        if [ -n "$style_name" ] && [ "$style_name" != "default" ] && [ "$style_name" != "null" ]; then
            model_segment="${model_segment} ${cyan}[${style_name}]${reset}"
        fi

        if [ -n "$output" ]; then
            output="${output} | ${model_segment}"
        else
            output="${model_segment}"
        fi
    fi
fi

# Git repo name, branch, and dirty indicator
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
    branch=$(git branch --show-current 2>/dev/null)

    # Check for uncommitted changes (dirty state)
    dirty=""
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        dirty=" ${yellow}●${reset}"  # Yellow dot for dirty
    fi

    # Check for untracked files
    if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        dirty=" ${red}●${reset}"  # Red dot if untracked files exist
    fi

    if [ -n "$repo_name" ]; then
        if [ -n "$output" ]; then
            output="${output} | "
        fi
        output="${output}${repo_name}"
        if [ -n "$branch" ]; then
            output="${output}:${branch}"
        fi
        output="${output}${dirty}"
    fi
fi

# Use echo -e to interpret color codes
echo -e "$output"
