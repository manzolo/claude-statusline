#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Use max of API's used_percentage and token-based calculation.
# api_pct reflects Claude Code's internal compaction threshold (excludes output tokens).
# Token calculation adds output tokens to predict next-turn context fill.
# Taking the max ensures we never under-report.
used=""
api_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_t=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_c=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_r=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
output_t=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
total=$((input_t + cache_c + cache_r + output_t))

calc_pct=""
if [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null && [ "$total" -gt 0 ]; then
    calc_pct=$((total * 100 / ctx_size))
fi

if [ -n "$api_pct" ] && [ -n "$calc_pct" ]; then
    if [ "$api_pct" -gt "$calc_pct" ]; then
        used=$api_pct
    else
        used=$calc_pct
    fi
elif [ -n "$api_pct" ]; then
    used=$api_pct
elif [ -n "$calc_pct" ]; then
    used=$calc_pct
fi

# Directory: folder name only
dir=$(basename "$cwd")

# Model: shorten "Claude Opus 4.6" -> "Opus 4.6"
short_model=$(echo "$model" | sed 's/^Claude //')

# Git branch
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Context bar
ctx=""
if [ -n "$used" ]; then
    pct=$used
    # 5-segment bar
    filled=$((pct / 20))
    empty=$((5 - filled))
    bar=""
    i=0; while [ $i -lt $filled ]; do bar="${bar}▰"; i=$((i+1)); done
    i=0; while [ $i -lt $empty ];  do bar="${bar}▱"; i=$((i+1)); done
    # color: green <50, yellow <80, red >=80
    if [ "$pct" -ge 80 ]; then
        color="\033[31m"
    elif [ "$pct" -ge 50 ]; then
        color="\033[33m"
    else
        color="\033[32m"
    fi
    # Token counts in K format (derived from pct to stay consistent with displayed percentage)
    token_info=""
    if [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
        total_k=$(( (ctx_size + 500) / 1000 ))
        used_k=$(( (ctx_size * pct / 100 + 500) / 1000 ))
        token_info=" ${used_k}K/${total_k}K"
    fi
    ctx=" \033[90m│\033[0m 🧠 ${color}${bar} ${pct}%${token_info}\033[0m"
fi

# Git branch + dirty
branch_info=""
if [ -n "$branch" ]; then
    dirty_count=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    dirty=""
    if [ "$dirty_count" -gt 0 ]; then
        dirty=" \033[33m*${dirty_count}\033[0m"
    fi
    branch_info=" \033[90m│\033[0m \033[35m🌿 ${branch}\033[0m${dirty}"
fi

# Docker containers
docker_info=""
if command -v docker >/dev/null 2>&1; then
    running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    if [ "$running" -gt 0 ]; then
        docker_info=" \033[90m│\033[0m 🐳 \033[36mcontainers:${running}\033[0m"
    fi
fi

# Output: model, context, dir, git, docker
printf "\033[36m🤖 %b\033[0m%b \033[90m│\033[0m \033[34m📁 %b\033[0m%b%b" \
    "$short_model" "$ctx" "$dir" "$branch_info" "$docker_info"
