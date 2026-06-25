#!/bin/bash

# Read JSON input
input=$(cat)

# Extract data
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
user=$(whoami)
host=$(hostname -s)
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Colors (bright for dark background)
RESET="\033[0m"
WHITE="\033[97m"
BRIGHT_CYAN="\033[96m"
BRIGHT_GREEN="\033[92m"
BRIGHT_YELLOW="\033[93m"
DIM="\033[38;5;244m"

# Format numbers with K suffix
format_num() {
    local n=$1
    if [ "$n" -ge 1000 ]; then
        printf "%.1fK" "$(echo "scale=1; $n/1000" | bc)"
    else
        printf "%d" "$n"
    fi
}

# Line 1: user@host | directory | git
line1="${DIM}${user}@${host}${RESET} ${BRIGHT_CYAN}${cwd}${RESET}"

# Git info
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    cd "$cwd" 2>/dev/null || true
    branch=$(git -c core.useBuiltinFSMonitor=false rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if git -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null && \
           git -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
            line1+=" ${BRIGHT_GREEN}${branch}${RESET}"
        else
            line1+=" ${BRIGHT_YELLOW}±${branch}${RESET}"
        fi
    fi
fi

# Line 2: ccusage output
line2=$(echo "$input" | bun x ccusage statusline --visual-burn-rate emoji 2>/dev/null || echo "")

# Line 3: tokens | context window size
line3=""
if [ "$input_tokens" != "null" ] || [ "$output_tokens" != "null" ]; then
    in_fmt=$(format_num "${input_tokens:-0}")
    out_fmt=$(format_num "${output_tokens:-0}")
    line3+="${DIM}input:${in_fmt} output:${out_fmt}${RESET}"
fi

# Output
printf "%b\n%b\n%b" "$line1" "$line2" "$line3"
