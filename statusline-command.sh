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
        git_info="  $branch"

        # Check dirty status and diff stats
        untracked_count=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

        has_tracked_changes=false
        if ! git -c core.fileMode=false diff --quiet 2>/dev/null || ! git -c core.fileMode=false diff --cached --quiet 2>/dev/null; then
            has_tracked_changes=true
        fi

        if [[ "$has_tracked_changes" == false ]] && [[ "$untracked_count" -eq 0 ]]; then
            git_info="$git_info 󰗡"
        else
            git_info="$git_info 󰷉"
            # Get combined diff stats (unstaged + staged) for tracked files only
            diff_stats=$(git -c core.fileMode=false diff --shortstat 2>/dev/null)
            staged_stats=$(git -c core.fileMode=false diff --cached --shortstat 2>/dev/null)
            # Parse files changed, insertions, deletions from both
            files_w=$(echo "$diff_stats" | grep -oP '\d+(?= file)' || echo 0)
            files_s=$(echo "$staged_stats" | grep -oP '\d+(?= file)' || echo 0)
            adds_w=$(echo "$diff_stats" | grep -oP '\d+(?= insertion)' || echo 0)
            adds_s=$(echo "$staged_stats" | grep -oP '\d+(?= insertion)' || echo 0)
            dels_w=$(echo "$diff_stats" | grep -oP '\d+(?= deletion)' || echo 0)
            dels_s=$(echo "$staged_stats" | grep -oP '\d+(?= deletion)' || echo 0)
            total_files=$(( ${files_w:-0} + ${files_s:-0} ))
            total_adds=$(( ${adds_w:-0} + ${adds_s:-0} ))
            total_dels=$(( ${dels_w:-0} + ${dels_s:-0} ))
            diff_display=""
            [[ "$total_files" -gt 0 ]] && diff_display=" ${total_files}f"
            [[ "$total_adds" -gt 0 ]] && diff_display="${diff_display} +${total_adds}"
            [[ "$total_dels" -gt 0 ]] && diff_display="${diff_display} -${total_dels}"
            [[ "$untracked_count" -gt 0 ]] && diff_display="${diff_display} ?${untracked_count}"
            git_info="$git_info${diff_display}"
        fi

        # Check ahead/behind remote
        upstream=$(git -c core.fileMode=false rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
        if [ -n "$upstream" ]; then
            ahead=$(git -c core.fileMode=false rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
            behind=$(git -c core.fileMode=false rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
            if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
                git_info="$git_info"
                [[ "$ahead" -gt 0 ]] && git_info="$git_info ↑$ahead"
                [[ "$behind" -gt 0 ]] && git_info="$git_info ↓$behind"
            fi
        fi
    fi
fi

# Format numbers with K/M suffix
format_num() {
    local num=$1
    if [[ $num -ge 1000000 ]]; then
        printf "%.1fM" $(awk "BEGIN {printf \"%.1f\", $num / 1000000}")
    elif [[ $num -ge 1000 ]]; then
        echo "$((num / 1000))K"
    else
        echo "$num"
    fi
}

# Context window calculation from transcript (last API call usage)
context_info=""
transcript=$(echo "$input" | jq -r '.transcript_path // ""')
context_tokens=0
if [[ -n "$transcript" ]] && [[ -f "$transcript" ]]; then
    last_input=$(grep -oP '"input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | tail -1)
    last_cache_read=$(grep -oP '"cache_read_input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | tail -1)
    last_cache_create=$(grep -oP '"cache_creation_input_tokens":\K[0-9]+' "$transcript" 2>/dev/null | tail -1)
    context_tokens=$(( ${last_input:-0} + ${last_cache_read:-0} + ${last_cache_create:-0} ))
fi
if [[ "$context_tokens" -gt 0 ]]; then
    context_max=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
    pct_num=$((context_tokens * 100 / context_max))
    ctx_display=$(format_num $context_tokens)
    if [[ $pct_num -lt 50 ]]; then
        ctx_color=$'\033[32m'  # green
    elif [[ $pct_num -lt 80 ]]; then
        ctx_color=$'\033[33m'  # yellow
    else
        ctx_color=$'\033[31m'  # red
    fi
    reset=$'\033[0m'
    context_info=" 🧠 ${ctx_color}${ctx_display} ${pct_num}%${reset}"
fi

# Get API ping latency (cached for 60 seconds)
ping_info=""
ping_cache="/tmp/claude-api-ping"
ping_max_age=60
if [[ -f "$ping_cache" ]] && [[ $(($(date +%s) - $(stat -c %Y "$ping_cache" 2>/dev/null || echo 0))) -lt $ping_max_age ]]; then
    ping_ms=$(cat "$ping_cache")
else
    ping_time=$(curl -o /dev/null -s -w '%{time_connect}' https://api.anthropic.com --connect-timeout 2 2>/dev/null)
    if [[ -n "$ping_time" ]]; then
        ping_ms=$(awk "BEGIN {printf \"%.0f\", $ping_time * 1000}")
        echo "$ping_ms" > "$ping_cache"
    fi
fi
if [[ -n "$ping_ms" ]] && [[ "$ping_ms" -gt 0 ]]; then
    ping_info=" 󰛳 ${ping_ms}ms"
fi

# Output with colors
# Blue for dir, green for git, default for ping, context %
printf "\033[34m%s\033[0m\033[32m%s\033[0m%s%s" \
    "$dir_display" "$git_info" "$context_info" "$ping_info"
