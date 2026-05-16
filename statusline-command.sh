#!/bin/sh
# Claude Code statusline — single jq call + cached git/docker checks

# --- color constants (pre-expanded; safe with printf '%s') ---
ESC=$(printf '\033')
C_RESET="${ESC}[0m"
C_DIM="${ESC}[90m"
C_RED="${ESC}[31m"
C_GREEN="${ESC}[32m"
C_YELLOW="${ESC}[33m"
C_BLUE="${ESC}[34m"
C_MAGENTA="${ESC}[35m"
C_CYAN="${ESC}[36m"
SEP=" ${C_DIM}│${C_RESET} "
TAB=$(printf '\t')

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
    printf '%s🤖 (install jq)%s' "$C_RED" "$C_RESET"
    exit 0
fi

# --- single jq invocation, one field per line ---
fields=$(printf '%s' "$input" | jq -r '
    .cwd // "",
    (.model.display_name // ""),
    (.context_window.context_window_size // 0 | floor),
    (.context_window.used_percentage // 0 | floor),
    (.context_window.current_usage.input_tokens // 0 | floor),
    (.context_window.current_usage.cache_creation_input_tokens // 0 | floor),
    (.context_window.current_usage.cache_read_input_tokens // 0 | floor),
    (.context_window.current_usage.output_tokens // 0 | floor)
' 2>/dev/null)

{
    IFS= read -r cwd
    IFS= read -r model
    IFS= read -r ctx_size
    IFS= read -r api_pct
    IFS= read -r input_t
    IFS= read -r cache_c
    IFS= read -r cache_r
    IFS= read -r output_t
} <<EOF
$fields
EOF

: "${ctx_size:=0}" "${api_pct:=0}"
: "${input_t:=0}" "${cache_c:=0}" "${cache_r:=0}" "${output_t:=0}"

# --- context % normalized to auto-compact threshold ---
# Claude Code auto-compacts at ~80% of context_window_size; the raw window is
# never fully usable. We display the percentage *toward compaction*, so the
# bar reaches 100% right when /compact would fire. Override the threshold
# (in % of context_window_size) via CSL_COMPACT_THRESHOLD.
COMPACT_THRESHOLD=${CSL_COMPACT_THRESHOLD:-80}

# Raw % of full window (max of API value and token-based estimate, since
# the API's used_percentage excludes output_tokens).
total=$((input_t + cache_c + cache_r + output_t))
raw_calc=0
if [ "$ctx_size" -gt 0 ] && [ "$total" -gt 0 ]; then
    raw_calc=$((total * 100 / ctx_size))
fi
if [ "$api_pct" -gt "$raw_calc" ]; then
    raw_pct=$api_pct
else
    raw_pct=$raw_calc
fi

# Normalize against compaction threshold, clamp at 100.
if [ "$COMPACT_THRESHOLD" -gt 0 ]; then
    used=$((raw_pct * 100 / COMPACT_THRESHOLD))
    [ "$used" -gt 100 ] && used=100
else
    used=$raw_pct
fi

# --- cache helpers (TTL = 3s) ---
CACHE_TTL=3
cache_dir="/tmp/claude-statusline-$(id -u 2>/dev/null || echo 0)"
mkdir -p "$cache_dir" 2>/dev/null || cache_dir=""

file_age() {
    { [ -n "$cache_dir" ] && [ -f "$1" ]; } || { echo 99999; return; }
    now=$(date +%s)
    mtime=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
    echo $((now - mtime))
}

cwd_hash=$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)
git_cache="$cache_dir/git-$cwd_hash"
docker_cache="$cache_dir/docker"

# --- git info (cached) ---
branch=""; dirty_count=0; ahead=0; behind=0
if [ -n "$cwd" ]; then
    if [ "$(file_age "$git_cache")" -lt "$CACHE_TTL" ]; then
        {
            IFS= read -r branch
            IFS= read -r dirty_count
            IFS= read -r ahead
            IFS= read -r behind
        } < "$git_cache"
    elif git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        dirty_count=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        ab=$(git -C "$cwd" rev-list --left-right --count @{u}...HEAD 2>/dev/null)
        if [ -n "$ab" ]; then
            behind=${ab%%${TAB}*}
            ahead=${ab##*${TAB}}
        fi
        [ -n "$cache_dir" ] && printf '%s\n%s\n%s\n%s\n' \
            "$branch" "$dirty_count" "$ahead" "$behind" > "$git_cache" 2>/dev/null
    fi
fi
: "${dirty_count:=0}" "${ahead:=0}" "${behind:=0}"

# --- docker info (cached) ---
docker_running=0
if [ "$(file_age "$docker_cache")" -lt "$CACHE_TTL" ]; then
    docker_running=$(cat "$docker_cache" 2>/dev/null)
elif command -v docker >/dev/null 2>&1; then
    docker_running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    [ -n "$cache_dir" ] && printf '%s' "$docker_running" > "$docker_cache" 2>/dev/null
fi
: "${docker_running:=0}"

# --- render ---
short_model=$(printf '%s' "$model" | sed 's/^Claude //')
dir=$(basename "$cwd" 2>/dev/null)

ctx=""
if [ "$ctx_size" -gt 0 ]; then
    pct=$used
    filled=$((pct / 20))
    [ "$filled" -gt 5 ] && filled=5
    [ "$filled" -lt 0 ] && filled=0
    empty=$((5 - filled))
    bar=""
    i=0; while [ $i -lt $filled ]; do bar="${bar}▰"; i=$((i+1)); done
    i=0; while [ $i -lt $empty  ]; do bar="${bar}▱"; i=$((i+1)); done
    if   [ "$pct" -ge 80 ]; then color=$C_RED
    elif [ "$pct" -ge 50 ]; then color=$C_YELLOW
    else                         color=$C_GREEN
    fi
    # Token display uses real counts and the raw window size; the bar % is
    # normalized to compaction so 100% ≠ ctx_size by design.
    total_k=$(( (ctx_size + 500) / 1000 ))
    used_k=$(( (total + 500) / 1000 ))
    ctx="${SEP}🧠 ${color}${bar} ${pct}% ${used_k}K/${total_k}K${C_RESET}"
fi

branch_info=""
if [ -n "$branch" ]; then
    extras=""
    [ "$dirty_count" -gt 0 ] && extras="${extras} ${C_YELLOW}*${dirty_count}${C_RESET}"
    [ "$ahead"       -gt 0 ] && extras="${extras} ${C_GREEN}↑${ahead}${C_RESET}"
    [ "$behind"      -gt 0 ] && extras="${extras} ${C_RED}↓${behind}${C_RESET}"
    branch_info="${SEP}${C_MAGENTA}🌿 ${branch}${C_RESET}${extras}"
fi

docker_info=""
if [ "$docker_running" -gt 0 ]; then
    docker_info="${SEP}🐳 ${C_CYAN}containers:${docker_running}${C_RESET}"
fi

printf '%s🤖 %s%s%s%s%s📁 %s%s%s%s' \
    "$C_CYAN" "$short_model" "$C_RESET" \
    "$ctx" "$SEP" \
    "$C_BLUE" "$dir" "$C_RESET" \
    "$branch_info" "$docker_info"
