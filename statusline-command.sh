#!/bin/bash

# Show staged/unstaged/ahead counts (S/U/A) after the branch
SHOW_GIT_COUNTS=false

# ANSI codes
RST=$'\033[0m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m'
BLUE=$'\033[34m' CYAN=$'\033[36m' ORANGE=$'\033[38;5;208m' GRAY=$'\033[90m' WHITE=$'\033[97m' LBLUE=$'\033[94m' TEAL=$'\033[38;5;80m' LABEL=$'\033[38;5;250m' AQUA=$'\033[38;2;45;251;251m' VIOLET=$'\033[38;2;176;38;255m'

# Requires jq; fail quietly with a hint instead of a broken status line
command -v jq > /dev/null || { printf 'statusline: jq not found'; exit 0; }

# Read the JSON input from stdin
input=$(cat)

# Per-session state (context delta baseline, running token total)
sd="$HOME/.claude/statusline-state"

# Skip optional git locks so the status line never blocks other git commands
export GIT_OPTIONAL_LOCKS=0

# One jq call; fields are pipe-separated (non-whitespace so empty fields survive), absent values become empty strings
IFS='|' read -r current_dir repo_name worktree model effort used_pct five five_reset seven seven_reset cost added removed tin tout cin ccr crd sid tpath cwsize < <(
    echo "$input" | jq -r '[
        (.workspace.current_dir // .cwd // ""),
        (.workspace.repo.name // ""),
        (.workspace.git_worktree // .worktree.name // ""),
        (.model.display_name // ""),
        (.effort.level // ""),
        (.context_window.used_percentage // ""),
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.five_hour.resets_at // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.rate_limits.seven_day.resets_at // ""),
        (.cost.total_cost_usd // ""),
        (.cost.total_lines_added // ""),
        (.cost.total_lines_removed // ""),
        (.context_window.total_input_tokens // ""),
        (.context_window.total_output_tokens // ""),
        (.context_window.current_usage.input_tokens // ""),
        (.context_window.current_usage.cache_creation_input_tokens // ""),
        (.context_window.current_usage.cache_read_input_tokens // ""),
        (.session_id // ""),
        (.transcript_path // ""),
        (.context_window.context_window_size // "")
    ] | map(tostring) | join("|")'
)

[ -z "$repo_name" ] && repo_name=$(basename "$current_dir")

g() { git -C "$current_dir" "$@" 2>/dev/null; }

branch="" staged=0 unstaged=0 ahead=0
if g rev-parse --git-dir > /dev/null; then
    branch=$(g branch --show-current)
    [ -z "$branch" ] && branch=$(g rev-parse --short HEAD)
    staged=$(g diff --cached --numstat | wc -l | tr -d ' ')
    # Unstaged = modified tracked files plus untracked files
    unstaged=$(( $(g diff --numstat | wc -l) + $(g ls-files --others --exclude-standard | wc -l) ))
    if g rev-parse --abbrev-ref '@{upstream}' > /dev/null; then
        ahead=$(g rev-list --count '@{upstream}..HEAD')
    else
        # No upstream: count commits ahead of the default branch (origin/HEAD, else master/main)
        base=$(g symbolic-ref -q --short refs/remotes/origin/HEAD)
        if [ -z "$base" ]; then
            for b in master main origin/master origin/main; do
                g rev-parse --verify -q "$b" > /dev/null && { base=$b; break; }
            done
        fi
        [ -n "$base" ] && ahead=$(g rev-list --count "$base..HEAD")
    fi
fi

SEP="${DIM} | ${RST}"

# Colorize a count: given color, or dim when the count is 0
count_seg() { # label count color
    local c="$3"
    [ "${2:-0}" -eq 0 ] && c="$GRAY"
    printf '%s%s: %s%s' "$c" "$1" "${2:-0}" "$RST"
}

# Time left until an epoch-seconds reset, e.g. 1h20m, 2d3h
until_reset() { # epoch
    local d=$(( $1 - $(date +%s) ))
    [ "$d" -le 0 ] && return
    if [ "$d" -ge 86400 ]; then printf '%dd%dh' $((d / 86400)) $((d % 86400 / 3600))
    elif [ "$d" -ge 3600 ]; then printf '%dh%dm' $((d / 3600)) $((d % 3600 / 60))
    else printf '%dm' $((d / 60)); fi
}

# Fill bar of N cells for a 0-100 value
bar() { # value
    local n=8 f i out=""
    f=$(( ($1 * n + 50) / 100 ))
    [ "$f" -gt "$n" ] && f=$n
    for ((i = 0; i < n; i++)); do
        if [ "$i" -lt "$f" ]; then out="$out"$'\xe2\x96\x88'; else out="$out"$'\xe2\x96\x91'; fi
    done
    printf '%s' "$out"
}

# Bar segment colored green <50, yellow 50-80, red >80 unless overridden
pct_seg() { # label value [reset_epoch] [suffix] [color override]
    local v c t=""
    v=$(printf '%.0f' "$2")
    if [ "$v" -gt 80 ]; then c="$RED"; elif [ "$v" -ge 50 ]; then c="$YELLOW"; else c="$GREEN"; fi
    [ -n "$5" ] && c="$5"
    [[ "$3" =~ ^[0-9]+$ ]] && t=$(until_reset "$3")
    printf '%s%s%s %s%s %s%%%s%s%s' "$LABEL" "$1" "$RST" "$c" "$(bar "$v")" "$v" "$RST" "$4" "${t:+$GRAY ($t)$RST}"
}

# Context color: green 0-20, yellow 20-50, red 50-80, violet 80-100 (20% is 200k on a 1M window)
ctx_color() { # percent
    local v
    v=$(printf '%.0f' "$1")
    if [ "$v" -ge 80 ]; then printf '%s' "$VIOLET"
    elif [ "$v" -ge 50 ]; then printf '%s' "$RED"
    elif [ "$v" -ge 20 ]; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"; fi
}

out="${LBLUE}${repo_name}${RST}"
[ -n "$branch" ] && out="$out${WHITE}:${RST}${CYAN}${branch}${RST}"
# Worktree is shown only when its name differs from the branch ("/" counts as "-")
[ -n "$worktree" ] && [ "$worktree" != "${branch//\//-}" ] && out="$out ${GRAY}(wt: ${worktree})${RST}"
[ "$SHOW_GIT_COUNTS" = true ] && [ -n "$branch" ] && out="$out${SEP}$(count_seg S "$staged" "$WHITE")${SEP}$(count_seg U "$unstaged" "$YELLOW")${SEP}$(count_seg A "$ahead" "$BLUE")"

# Compact token count: 842, 12.3k, 1.2M
fmt_tok() { # n
    awk -v n="$1" 'BEGIN { if (n >= 1e6) printf "%.1fM", n / 1e6; else if (n >= 1e3) printf "%.1fk", n / 1e3; else printf "%d", n }'
}

# Effort: cool (low) to hot (max)
case "$effort" in
    low) ec="$BLUE" ;;
    medium) ec="$CYAN" ;;
    high) ec="$YELLOW" ;;
    xhigh) ec="$ORANGE" ;;
    max) ec="$RED" ;;
    *) ec="" ;;
esac
me=""
[ -n "$model" ] && me="${AQUA}${model}${RST}"
[ -n "$effort" ] && me="${me:+$me/}${ec}${effort}${RST}"
[ -n "$me" ] && [ -n "$cwsize" ] && me="$me ${GRAY}($(fmt_tok "$cwsize" | sed 's/\.0//'))${RST}"
[ -n "$added$removed" ] && out="$out${SEP}${GREEN}+${added:-0}${RST} ${RED}-${removed:-0}${RST}"
[ -n "$me" ] && out="$out${SEP}$me"

ctx_delta=""
if [ -n "$sid$tin$tout" ] && [ -n "${sid//[^A-Za-z0-9_-]/}" ]; then
    # Context growth this prompt: statusline-hook.sh copies .latest to .baseline on each prompt submit
    sid=${sid//[^A-Za-z0-9_-]/}
    mkdir -p "$sd"
    printf '%s %s\n' "${tin:-0}" "${tout:-0}" > "$sd/$sid.latest"
    bin=0 bout=0
    [ -f "$sd/$sid.baseline" ] && read -r bin bout < "$sd/$sid.baseline"
    d=$(( ${tin:-0} + ${tout:-0} - ${bin:-0} - ${bout:-0} ))
    [ "$d" -lt 0 ] && d=0
    ctx_delta=" ${GRAY}(+$(fmt_tok "$d"))${RST}"
fi
[ -n "$used_pct" ] && out="$out${SEP}$(pct_seg Ctx "$used_pct" "" "$ctx_delta" "$(ctx_color "$used_pct")")"
[ -n "$five" ] && out="$out${SEP}$(pct_seg 5h "$five" "$five_reset")"
[ -n "$seven" ] && out="$out${SEP}$(pct_seg 7d "$seven" "$seven_reset")"

[ -n "$cost" ] && out="$out${SEP}${TEAL}$(printf '$%.2f' "$cost")${RST}"

# Session total tokens: new input + cache writes + output, summed per API call from the transcript.
# Incremental: the state file keeps "offset sum last_id last_total" so each render only parses appended lines.
if [ -n "$sid" ] && [ -f "$tpath" ]; then
    tf="$sd/$sid.total"
    off=0 sum=0 lid="" ltot=0
    [ -f "$tf" ] && read -r off sum lid ltot < "$tf"
    size=$(stat -c%s "$tpath" 2>/dev/null || stat -f%z "$tpath")
    [ "$size" -lt "${off:-0}" ] && off=0 sum=0 lid="" ltot=0
    if [ "$size" -gt "$off" ]; then
        chunk="$sd/$sid.chunk.$$"
        tail -c +$((off + 1)) "$tpath" > "$chunk"
        # Only consume complete lines; a trailing partial line is re-read next render
        partial=0
        [ "$(tail -c1 "$chunk" | od -An -c | tr -d ' ')" != '\n' ] && partial=$(tail -n1 "$chunk" | wc -c)
        done_bytes=$(( size - off - partial ))
        read -r add nlid nltot < <(head -c "$done_bytes" "$chunk" | jq -rs --arg last "$lid" --argjson lt "${ltot:-0}" '
            [.[] | select(.type == "assistant") | .message | select(.usage)
                | {id, t: ((.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.output_tokens // 0))}] as $m
            | ($m | group_by(.id) | map({id: .[0].id, t: (map(.t) | max)})) as $g
            | (($g | map(.t) | add // 0) - (if ($g | map(.id) | index($last)) != null then $lt else 0 end)) as $add
            | ($m | last | .id // $last) as $lid
            | [$add, ($lid // "-"), (if $m == [] then $lt else ($g | map(select(.id == $lid)) | .[0].t) end)] | join(" ")' 2>/dev/null)
        rm -f "$chunk"
        if [ -n "$nltot" ]; then
            sum=$(( ${sum:-0} + add )) off=$((off + done_bytes))
            [ "$nlid" = "-" ] && nlid=""
            lid="$nlid" ltot="$nltot"
            printf '%s %s %s %s\n' "$off" "$sum" "${lid:--}" "$ltot" > "$tf"
        fi
    fi
    [ "${lid:-}" = "-" ] && lid=""
    out="$out${SEP}${WHITE}$(fmt_tok "${sum:-0}")${RST}"
fi

# Cache hit rate of the last API call: cache reads / all input tokens
if [ -n "$crd" ]; then
    total=$(( ${cin:-0} + ${ccr:-0} + crd ))
    if [ "$total" -gt 0 ]; then
        hit=$(( (crd * 100 + total / 2) / total ))
        if [ "$hit" -ge 80 ]; then hc="$GREEN"; elif [ "$hit" -ge 50 ]; then hc="$YELLOW"; else hc="$RED"; fi
        out="$out${SEP}${LABEL}Hit${RST} ${hc}${hit}%${RST}"
    fi
fi

printf '%s' "$out"
