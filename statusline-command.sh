#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current working directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
cd "$cwd" 2>/dev/null || cd ~

# Format directory display
dir="$cwd"
if [[ "$dir" == "$HOME" ]]; then
    dir_display="󰚡 ~"
elif [[ "$dir" == "$HOME"/* ]]; then
    dir_display="~/${dir#$HOME/}"
else
    dir_display="$dir"
fi

# Get git information
git_info=""
if git -c core.fileMode=false rev-parse --git-dir &>/dev/null; then
    branch=$(git -c core.fileMode=false branch --show-current 2>/dev/null | head -n1)
    if [ -n "$branch" ]; then
        git_info=" $branch"
        if git -c core.fileMode=false diff --quiet 2>/dev/null && git -c core.fileMode=false diff --cached --quiet 2>/dev/null; then
            git_info="$git_info 󰗡"
        else
            git_info="$git_info 󰷉"
        fi
    fi
fi

# Format numbers with K/M suffix
format_num() {
    local num=$1
    if [[ $num -ge 1000000 ]]; then
        printf "%.1fM" "$(echo "scale=1; $num / 1000000" | bc)"
    elif [[ $num -ge 1000 ]]; then
        echo "$((num / 1000))K"
    else
        echo "$num"
    fi
}

# Extract token usage from transcript file
transcript=$(echo "$input" | jq -r '.transcript_path // ""')

token_info=""
if [[ -n "$transcript" ]] && [[ -f "$transcript" ]]; then
    # Sum tokens from transcript - separate all types
    tokens_input=$(grep -oP '"input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | awk '{s+=$1} END {print s+0}')
    tokens_output=$(grep -oP '"output_tokens":\K[0-9]+' "$transcript" 2>/dev/null | awk '{s+=$1} END {print s+0}')
    cache_write=$(grep -oP '"cache_creation_input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | awk '{s+=$1} END {print s+0}')
    cache_read=$(grep -oP '"cache_read_input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | awk '{s+=$1} END {print s+0}')

    # Build token display: 󰾂 in/out 󰆓 write/read
    if [[ "$tokens_input" -gt 0 ]] || [[ "$tokens_output" -gt 0 ]] || [[ "$cache_write" -gt 0 ]] || [[ "$cache_read" -gt 0 ]]; then
        in_display=$(format_num $tokens_input)
        out_display=$(format_num $tokens_output)
        write_display=$(format_num $cache_write)
        read_display=$(format_num $cache_read)
        token_info=" 󰾂 ${in_display}↑${out_display}↓ 󰆓 ${write_display}↑${read_display}↓"
    fi
fi

# Get ccusage data (context %)
ccusage_info=""
ccusage_output=$(echo "$input" | npx --yes ccusage@latest statusline 2>/dev/null)

if [[ -n "$ccusage_output" ]]; then
    # Extract context info: "🧠 XX,XXX (XX%)" - get the percentage
    context_pct=$(echo "$ccusage_output" | grep -oP '🧠\s+[\d,]+\s+\(\K\d+%' | head -1)

    if [[ -n "$context_pct" ]]; then
        # Color context based on percentage
        pct_num=${context_pct%\%}
        if [[ $pct_num -lt 50 ]]; then
            ctx_color=$'\033[32m'  # green
        elif [[ $pct_num -lt 80 ]]; then
            ctx_color=$'\033[33m'  # yellow
        else
            ctx_color=$'\033[31m'  # red
        fi
        reset=$'\033[0m'
        ccusage_info=" 🧠 ${ctx_color}${context_pct}${reset}"
    fi
fi

# Calculate billing week cost
get_billing_week_start() {
    local ref_epoch=1765234800  # Dec 8, 2025 23:00 UTC
    local now_epoch=$(date +%s)
    local week_seconds=$((7 * 24 * 60 * 60))
    local diff=$((now_epoch - ref_epoch))
    if [[ $diff -lt 0 ]]; then
        local weeks_back=$(( (-diff + week_seconds - 1) / week_seconds ))
        echo $((ref_epoch - (weeks_back * week_seconds)))
    else
        local weeks_since=$((diff / week_seconds))
        echo $((ref_epoch + (weeks_since * week_seconds) - week_seconds))
    fi
}

weekly_cost=0
projects_dir="$HOME/.claude/projects"
cache_file="/tmp/claude-weekly-cost-cache"
cache_max_age=300

if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $cache_max_age ]]; then
    weekly_cost=$(cat "$cache_file")
else
    if [[ -d "$projects_dir" ]]; then
        billing_start=$(get_billing_week_start)
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                f_input=$(grep -oP '"input_tokens":\K[0-9]+' "$file" 2>/dev/null | awk '{s+=$1} END {print s+0}')
                f_output=$(grep -oP '"output_tokens":\K[0-9]+' "$file" 2>/dev/null | awk '{s+=$1} END {print s+0}')
                f_cache_create=$(grep -oP '"cache_creation_input_tokens":\K[0-9]+' "$file" 2>/dev/null | awk '{s+=$1} END {print s+0}')
                f_cache_read=$(grep -oP '"cache_read_input_tokens":\K[0-9]+' "$file" 2>/dev/null | awk '{s+=$1} END {print s+0}')
                file_cost=$(echo "scale=6; ($f_input * 0.000015) + ($f_output * 0.000075) + ($f_cache_create * 0.00001875) + ($f_cache_read * 0.000001875)" | bc)
                weekly_cost=$(echo "scale=6; $weekly_cost + $file_cost" | bc)
            fi
        done < <(find "$projects_dir" -name "*.jsonl" -newermt "@$billing_start" -print0 2>/dev/null)
    fi
    echo "$weekly_cost" > "$cache_file"
fi

weekly_info=""
if (( $(echo "$weekly_cost > 0" | bc -l) )); then
    if (( $(echo "$weekly_cost >= 1" | bc -l) )); then
        weekly_display=$(printf "\$%.2f" "$weekly_cost")
    else
        weekly_cents=$(echo "$weekly_cost * 100" | bc)
        weekly_display=$(printf "%.0f¢" "$weekly_cents")
    fi
    weekly_info=" 󰃭 ${weekly_display}/wk"
fi

# Get session cost from Claude Code
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_info=""
if (( $(echo "$session_cost > 0" | bc -l) )); then
    if (( $(echo "$session_cost >= 1" | bc -l) )); then
        cost_display=$(printf "$%.2f" "$session_cost")
    else
        cents=$(echo "$session_cost * 100" | bc)
        cost_display=$(printf "%.0f¢" "$cents")
    fi
    cost_info=" 󰄬 ${cost_display}"
fi

# Output with colors
# Blue for dir, default for git, cyan for tokens, yellow for cost, green for weekly, then ccusage info
printf "\033[34m%s\033[0m%s\033[36m%s\033[0m\033[33m%s\033[0m\033[32m%s\033[0m%s" \
    "$dir_display" "$git_info" "$token_info" "$cost_info" "$weekly_info" "$ccusage_info"
