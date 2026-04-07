#!/bin/bash
# Source: https://github.com/daniel3303/ClaudeCodeStatusLine
# Single line: Model | usage | effort | cwd@branch | 5h | 7d

set -f

input=$(cat)
if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ANSI colors (default 16-color palette)
green='\033[32m'
yellow='\033[33m'
red='\033[31m'
blue='\033[34m'
cyan='\033[36m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}|${reset} "

usage_color() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then echo "$red"
    elif [ "$pct" -ge 70 ]; then echo "$yellow"
    else echo "$green"
    fi
}

format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.0fM\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

# Extract all fields in one jq call
eval "$(echo "$input" | jq -r '
    @sh "model_name=\(.model.display_name // "Claude")",
    @sh "size=\(.context_window.context_window_size // 200000)",
    @sh "input_tokens=\(.context_window.current_usage.input_tokens // 0)",
    @sh "cache_create=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
    @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // 0)",
    @sh "cwd=\(.cwd // "")",
    @sh "five_hour_pct=\(.rate_limits.five_hour.used_percentage // "")",
    @sh "five_hour_reset=\(.rate_limits.five_hour.resets_at // "")",
    @sh "seven_day_pct=\(.rate_limits.seven_day.used_percentage // "")",
    @sh "seven_day_reset=\(.rate_limits.seven_day.resets_at // "")"
')"

[ "$size" -eq 0 ] 2>/dev/null && size=200000
current=$(( input_tokens + cache_create + cache_read ))

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

# Strip "(1M context)" etc from model name
model_name="${model_name%% (*}"

# Reasoning effort
claude_config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
effort_level="medium"
if [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ]; then
    effort_level="$CLAUDE_CODE_EFFORT_LEVEL"
elif [ -f "$claude_config_dir/settings.json" ]; then
    effort_val=$(jq -r '.effortLevel // empty' "$claude_config_dir/settings.json" 2>/dev/null)
    [ -n "$effort_val" ] && effort_level="$effort_val"
fi

# ===== Build output =====
line1=""
line2=""

# Model
line1+="${blue}${model_name}${reset}"

# Effort
line1+=" "
case "$effort_level" in
    low)    line1+="${dim}${effort_level}${reset}" ;;
    medium) line1+="${yellow}med${reset}" ;;
    max)    line1+="${red}${effort_level}${reset}" ;;
    *)      line1+="${green}${effort_level}${reset}" ;;
esac

# Token usage
used_color=$(usage_color "$pct_used")
line1+="${sep}${used_color}$(format_tokens $current)/$(format_tokens $size) (${pct_used}%)${reset}"

# Rate limits (builtin only)
format_epoch() {
    local epoch="$1" fmt="$2"
    [ -z "$epoch" ] || [ "$epoch" = "null" ] && return
    date -d "@$epoch" +"$fmt" 2>/dev/null || date -j -r "$epoch" +"$fmt" 2>/dev/null
}

if [ -n "$five_hour_pct" ]; then
    pct=$(printf "%.0f" "$five_hour_pct")
    line1+="${sep}$(usage_color "$pct")${pct}%${reset}"
    rt=$(format_epoch "$five_hour_reset" "%H:%M")
    [ -n "$rt" ] && line1+=" ${dim} 5h@${rt}${reset}"
fi

if [ -n "$seven_day_pct" ]; then
    pct=$(printf "%.0f" "$seven_day_pct")
    line1+="${sep}$(usage_color "$pct")${pct}%${reset}"
    rt=$(format_epoch "$seven_day_reset" "%e" | sed -E "s/^ *//; s/^(1[123])$/\1th/; s/^([0-9]*1)$/\1st/; s/^([0-9]*2)$/\1nd/; s/^([0-9]*3)$/\1rd/; s/^([0-9]+)$/\1th/")
    rt+=", $(format_epoch "$seven_day_reset" "%H:%M")"
    [ -n "$rt" ] && line1+=" ${dim} 7d@${rt}${reset}"
fi

# Working directory + git
if [ -n "$cwd" ]; then
    display_dir="${cwd##*/}"
    line2+="${cyan}${display_dir}${reset}"
    git_branch=$(git -C "${cwd}" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$git_branch" ]; then
        line2+="${dim}@${reset}${green}${git_branch}${reset}"
        git_stat=$(git -C "${cwd}" diff --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END {if (a+d>0) printf "+%d -%d", a, d}')
        if [ -n "$git_stat" ]; then
            line2+=" ${dim}(${reset}${green}${git_stat%% *}${reset} ${red}${git_stat##* }${reset}${dim})${reset}"
        fi
    fi
fi



# Output: line 1 always, line 2 if there's content
if [ -n "$line2" ]; then
    printf "%b\n%b" "$line1" "$line2"
else
    printf "%b" "$line1"
fi
