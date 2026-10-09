#!/bin/bash
# Claude Code status line. Needs jq, python3, and a Nerd Font in your terminal.
# Settings live in ~/.claude/statusline.conf (see statusline.conf.example); nothing here needs editing.

# ---- Defaults (override any of these in the config file) -------------------------------------------------------
STATUSLINE_THEME=sorbet     # sorbet | ember | sunset | ocean | forest | grape | mono
STATUSLINE_LAYOUT=compact   # compact: one line, shrinks to fit | wrap: usage on line 1, repo and diff on line 2 | full: never shrinks
STATUSLINE_BG=dark          # dark | light (terminal background)
STATUSLINE_MARGIN=6         # columns kept free at the right edge when fitting
BAR_WIDTH=10                # cells in a full-size usage bar (4 to 20)
CTX_PILL=false              # true wraps the Ctx label, bar and percent in one pill (a pill within a pill)
CTX_LABEL=Ctx               # the label before the Ctx bar, e.g. C
PILLS=false                 # true puts every segment in a pill (repo, git counts, diff, model, Ctx, 5h, 7d, cost, tokens) with no separators
LIMIT_PILL=false            # true wraps the 5h and 7d label, bar, percent and reset time in a pill, no separator between pills
BILLING=auto                # auto | plan | api: api hides 5h/7d and puts the cost in a colored pill
GROWTH_SHOW=percent         # tokens | percent | both: the number in the growth pill
GROWTH_COLOR_BY=percent     # percent | tokens: percent scales the 8 color steps to the context window
SHOW_GIT_COUNTS=false       # true adds staged / unstaged / ahead counts after the branch
SHOW_DIFF=true SHOW_COST=true SHOW_TOKENS=true SHOW_CACHE=true
COST_STYLE=auto             # auto | pill | text: auto is a pill for api billing, plain text for a plan
COST_STEPS="5 25 50 100 200 500 1000 2500"   # cents at which the cost pill steps to the next color
GIT_TTL=5                   # seconds a git result is cached

conf="${STATUSLINE_CONF:-$HOME/.claude/statusline.conf}"
[ -f "$conf" ] && . "$conf" 2>/dev/null

# Fall back to the default for any value that is not valid, so a typo cannot break the line
case "$STATUSLINE_THEME" in sorbet|ember|sunset|ocean|forest|grape|mono) ;; *) STATUSLINE_THEME=sorbet ;; esac
case "$STATUSLINE_LAYOUT" in compact|wrap|full) ;; *) STATUSLINE_LAYOUT=compact ;; esac
case "$STATUSLINE_BG" in dark|light) ;; *) STATUSLINE_BG=dark ;; esac
case "$BILLING" in auto|plan|api) ;; *) BILLING=auto ;; esac
case "$COST_STYLE" in auto|pill|text) ;; *) COST_STYLE=auto ;; esac
case "$GROWTH_SHOW" in tokens|percent|both) ;; *) GROWTH_SHOW=percent ;; esac
case "$GROWTH_COLOR_BY" in percent|tokens) ;; *) GROWTH_COLOR_BY=percent ;; esac
case "$STATUSLINE_MARGIN" in ''|*[!0-9]*) STATUSLINE_MARGIN=6 ;; esac
case "$CTX_PILL" in true|false) ;; *) CTX_PILL=false ;; esac
case "$LIMIT_PILL" in true|false) ;; *) LIMIT_PILL=false ;; esac
case "$PILLS" in true|false) ;; *) PILLS=false ;; esac
[ "$PILLS" = true ] && CTX_PILL=true LIMIT_PILL=true
case "$BAR_WIDTH" in ''|*[!0-9]*) BAR_WIDTH=10 ;; esac
[ "$BAR_WIDTH" -lt 4 ] && BAR_WIDTH=4; [ "$BAR_WIDTH" -gt 20 ] && BAR_WIDTH=20
bw2=6; [ "$BAR_WIDTH" -le 6 ] && bw2=$((BAR_WIDTH - 1))   # the shorter stage stays shorter than the full bar

# ---- Themes -----------------------------------------------------------------------------------------------------
ESC=$'\033'
RST="${ESC}[0m" DIM="${ESC}[2m"
c256() { printf '%s[38;5;%sm' "$ESC" "$1"; }
# T_GROW: 8 growth steps light to heavy; T_OFF: below the first step; T_INK: text on a filled pill;
# T_INSET: background of the cache inset; T_HIT: cache text for 80%+, 50%+, below
case "$STATUSLINE_THEME" in
    ember)
        T_GROW=(151 187 223 222 215 209 203 196) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(150 222 203)
        C_REPO=$(c256 216) C_BRANCH=$(c256 180) C_COLON=$(c256 250) C_MODEL=$(c256 222)
        C_ADD=$(c256 150) C_REM=$(c256 203) C_COST=$(c256 215) C_TOK=$(c256 255) C_LABEL=$(c256 250) C_DIM=$(c256 244) ;;
    sunset)
        T_GROW=(157 193 229 222 216 210 204 198) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(157 222 204)
        C_REPO=$(c256 223) C_BRANCH=$(c256 216) C_COLON=$(c256 250) C_MODEL=$(c256 210)
        C_ADD=$(c256 186) C_REM=$(c256 204) C_COST=$(c256 222) C_TOK=$(c256 255) C_LABEL=$(c256 250) C_DIM=$(c256 244) ;;
    ocean)
        T_GROW=(84 120 156 192 222 216 210 203) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(84 222 203)
        C_REPO=$(c256 117) C_BRANCH=$(c256 80) C_COLON=$(c256 250) C_MODEL=$(c256 159)
        C_ADD=$(c256 79) C_REM=$(c256 210) C_COST=$(c256 80) C_TOK=$(c256 255) C_LABEL=$(c256 250) C_DIM=$(c256 244) ;;
    forest)
        T_GROW=(114 150 156 192 228 215 209 196) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(114 221 196)
        C_REPO=$(c256 150) C_BRANCH=$(c256 114) C_COLON=$(c256 250) C_MODEL=$(c256 192)
        C_ADD=$(c256 114) C_REM=$(c256 209) C_COST=$(c256 150) C_TOK=$(c256 255) C_LABEL=$(c256 250) C_DIM=$(c256 244) ;;
    grape)
        T_GROW=(120 156 192 228 222 216 210 204) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(120 222 204)
        C_REPO=$(c256 183) C_BRANCH=$(c256 177) C_COLON=$(c256 250) C_MODEL=$(c256 219)
        C_ADD=$(c256 156) C_REM=$(c256 204) C_COST=$(c256 177) C_TOK=$(c256 255) C_LABEL=$(c256 250) C_DIM=$(c256 244) ;;
    mono)  # grayscale: additions bright, removals dim
        T_GROW=(108 143 186 222 216 210 174 167) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(108 186 167)
        C_REPO=$(c256 255) C_BRANCH=$(c256 250) C_COLON=$(c256 244) C_MODEL=$(c256 255)
        C_ADD=$(c256 252) C_REM=$(c256 245) C_COST=$(c256 252) C_TOK=$(c256 255) C_LABEL=$(c256 248) C_DIM=$(c256 242) ;;
    *)  # sorbet: soft pastel, mint to coral pill
        T_GROW=(78 114 150 186 221 215 209 203) T_OFF=240 T_INK=234 T_INSET=236 T_HIT=(78 221 203)
        C_REPO="${ESC}[94m" C_BRANCH="${ESC}[36m" C_COLON="${ESC}[97m" C_MODEL="${ESC}[38;2;45;251;251m"
        C_ADD="${ESC}[32m" C_REM="${ESC}[31m" C_COST="${ESC}[38;5;80m" C_TOK="${ESC}[97m" C_LABEL="${ESC}[38;5;250m" C_DIM="${ESC}[90m" ;;
esac
if [ "$STATUSLINE_BG" = light ]; then   # darker text and a pale inset for a light terminal
    T_INSET=254 T_HIT=(28 130 160)
    C_REPO=$(c256 25) C_BRANCH=$(c256 30) C_COLON=$(c256 240) C_MODEL=$(c256 31)
    C_ADD=$(c256 28) C_REM=$(c256 124) C_COST=$(c256 30) C_TOK=$(c256 235) C_LABEL=$(c256 240) C_DIM=$(c256 244)
fi
C_YELLOW="${ESC}[33m" C_RED="${ESC}[31m" C_BLUE="${ESC}[34m" C_GREEN="${ESC}[32m"
SEP="${DIM} | ${RST}"
[ "$PILLS" = true ] && SEP=" "
LCAP=$'\xee\x82\xb6' RCAP=$'\xee\x82\xb4' BOLT=$'\xef\x83\xa7'

# ---- Environment ------------------------------------------------------------------------------------------------
command -v jq > /dev/null || { printf 'statusline: jq not found'; exit 0; }

# ${#var} must count characters, not bytes: make sure a UTF-8 locale is active
_t=$'\xc3\xa9'
if [ "${#_t}" -ne 1 ]; then
    export LC_ALL=en_US.UTF-8
    _t=$'\xc3\xa9'
    [ "${#_t}" -ne 1 ] && export LC_ALL=C.UTF-8
fi

input=$(cat)
sd="$HOME/.claude/statusline-state"   # per-session state, pruned by the hook after 14 days
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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
# A new session reports no usage until its first response: show Ctx as 0% instead of hiding it
[ -z "$used_pct" ] && used_pct=0
now=$(date +%s)

# ---- Plan or API billing ----------------------------------------------------------------------------------------
# Rate limits are account-wide, but a new session does not report them until its first response. Remember the last
# values and reuse any whose reset time has not passed. A marker outside the pruned state dir records that this
# account has ever reported limits, which is how "auto" tells a plan from straight API keys.
rl="$sd/ratelimits" seen="$HOME/.claude/statusline-seen-limits"
if [ -n "$five$seven" ]; then
    mkdir -p "$sd"
    printf '%s|%s|%s|%s\n' "$five" "$five_reset" "$seven" "$seven_reset" > "$rl"
    [ -f "$seen" ] || : > "$seen"
elif [ -f "$rl" ]; then
    IFS='|' read -r c5 c5r c7 c7r < "$rl"
    [[ "$c5r" =~ ^[0-9]+$ ]] && [ "$c5r" -gt "$now" ] && [ -n "$c5" ] && five=$c5 five_reset=$c5r
    [[ "$c7r" =~ ^[0-9]+$ ]] && [ "$c7r" -gt "$now" ] && [ -n "$c7" ] && seven=$c7 seven_reset=$c7r
fi
api=false
case "$BILLING" in
    api) api=true ;;
    auto) [ -z "$five$seven" ] && [ ! -f "$seen" ] && api=true ;;
esac
[ "$api" = true ] && five="" seven=""

# ---- Git (cached) -----------------------------------------------------------------------------------------------
g() { git -C "$current_dir" "$@" 2>/dev/null; }
branch="" staged=0 unstaged=0 ahead=0
gcache="$sd/git.$(printf '%s' "$current_dir" | cksum | cut -d' ' -f1)"
if [ -f "$gcache" ]; then
    IFS='|' read -r gts branch staged unstaged ahead < "$gcache"
    [ $(( now - ${gts:-0} )) -ge "$GIT_TTL" ] && branch="" gts=""
fi
if [ -z "$branch" ] && [ -z "$gts" ]; then
    if g rev-parse --git-dir > /dev/null; then
        branch=$(g branch --show-current)
        [ -z "$branch" ] && branch=$(g rev-parse --short HEAD)
        if [ "$SHOW_GIT_COUNTS" = true ]; then
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
    fi
    mkdir -p "$sd"
    printf '%s|%s|%s|%s|%s\n' "$now" "$branch" "$staged" "$unstaged" "$ahead" > "$gcache"
fi

# ---- Helpers ----------------------------------------------------------------------------------------------------
# Compact token count: 842, 12.3k, 1.2M
fmt_tok() { # n
    local n=$1
    if [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n / 1000000)) $((n % 1000000 / 100000))
    elif [ "$n" -ge 1000 ]; then printf '%d.%dk' $((n / 1000)) $((n % 1000 / 100))
    else printf '%d' "$n"; fi
}

# Time left until an epoch-seconds reset, e.g. 1h20m, 2d3h
_t=""
until_reset() { # epoch -> $_t
    local d=$(( $1 - now ))
    _t=""
    [ "$d" -le 0 ] && return
    if [ "$d" -ge 86400 ]; then _t="$((d / 86400))d$((d % 86400 / 3600))h"
    elif [ "$d" -ge 3600 ]; then _t="$((d / 3600))h$((d % 3600 / 60))m"
    else _t="$((d / 60))m"; fi
}

# Visible width of a string: escape codes removed, characters counted (Nerd Font glyphs count as one cell)
vis=0
measure() { # strip one escape sequence at a time: a global extglob replace is pathologically slow on long strings in bash 3.2
    local s=$1 rest
    while [[ $s == *"${ESC}["* ]]; do
        rest=${s#*"${ESC}["}; rest=${rest#*m}; s=${s%%"${ESC}["*}$rest
    done
    vis=${#s}
}

# A filled pill with rounded caps
pill() { # fill text -> $_o
    _o="${ESC}[38;5;$1m${LCAP}${ESC}[48;5;$1m${ESC}[38;5;${T_INK}m$2${RST}${ESC}[38;5;$1m${RCAP}${RST}"
}

# Label, bar, percent (and optional text) in one pill; the bar and percent keep their own colors, so every reset in them re-applies the background
pill_bar() { # label bar [extra text in the label color] -> $_o
    local ib="${ESC}[48;5;${T_INSET}m" ic="${ESC}[38;5;${T_INSET}m"
    _o="${ic}${LCAP}${ib}${C_LABEL}$1 ${2//$RST/$RST$ib}${3:+ ${C_LABEL}$3}${RST}${ic}${RCAP}${RST}"
}

# Already-colored text in the same pill
pill_text() { # text -> $_o
    local ib="${ESC}[48;5;${T_INSET}m" ic="${ESC}[38;5;${T_INSET}m"
    _o="${ic}${LCAP}${ib}${1//$RST/$RST$ib}${RST}${ic}${RCAP}${RST}"
}

# Step of a value against ascending thresholds: 0 .. number of thresholds
_step=0
step_of() { # value thresholds... -> $_step
    local v=$1 t; shift
    _step=0
    for t in "$@"; do [ "$v" -ge "$t" ] && _step=$((_step+1)); done
}

# "3.54" -> 354 (cents), tolerant of "7.148909" and "12"
_cents=0
to_cents() { # -> $_cents
    local i=${1%%.*} f=""
    [[ "$1" == *.* ]] && f=${1#*.}
    f="${f}00"; _cents=$(( 10#${i:-0} * 100 + 10#${f:0:2} ))
}

# "3.54" -> 3540000 (millionths of a dollar); anything else (e.g. jq's "1e-05") counts as 0
_micro=0
to_micro() { # -> $_micro
    _micro=0
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]] || return
    local i=${1%%.*} f=""
    [[ "$1" == *.* ]] && f=${1#*.}
    f="${f}000000"; _micro=$(( 10#$i * 1000000 + 10#${f:0:6} ))
}

# ---- Bars: one python call renders every bar at every width a shrink stage might need ---------------------------
bars=()
if [ -n "$used_pct$five$seven" ]; then
    # System python on purpose: a pyenv shim on PATH adds ~200 ms per run
    py=/usr/bin/python3; [ -x "$py" ] || py=python3
    n=0
    while IFS= read -r line; do bars[n]=$line; n=$((n+1)); done < <("$py" "$here/statusline-ctxbar.py" --theme "$STATUSLINE_THEME" --bg "$STATUSLINE_BG" \
        --widths $BAR_WIDTH,$bw2,3 "${used_pct:+$(printf '%.0f' "$used_pct")}" "${five:+$(printf '%.0f' "$five")}" "${seven:+$(printf '%.0f' "$seven")}" 2>/dev/null)
fi
# bars[w*3 + k]: w = 0 full, 1 shorter, 2 minimal; k = 0 Ctx, 1 5h, 2 7d
_bar=""
bar_for() { _bar=${bars[$(( $2 * 3 + $1 ))]}; }  # k width-index

# Plain bar segment (python missing): green <50, yellow 50-80, red >80
plain_bar() { # label value
    local v n=8 f i out="" col
    v=$(printf '%.0f' "$2"); f=$(( (v * n + 50) / 100 )); [ "$f" -gt "$n" ] && f=$n
    if [ "$v" -gt 80 ]; then col="$C_RED"; elif [ "$v" -ge 50 ]; then col="$C_YELLOW"; else col="$C_GREEN"; fi
    for ((i = 0; i < n; i++)); do
        if [ "$i" -lt "$f" ]; then out="$out"$'\xe2\x96\x88'; else out="$out"$'\xe2\x96\x91'; fi
    done
    _o="${C_LABEL}$1${RST} ${col}${out} ${v}%${RST}"
}

# ---- Growth pill and cache inset --------------------------------------------------------------------------------
pill_growth="" pill_full=""
if [ -n "$sid$tin$tout" ] && [ -n "${sid//[^A-Za-z0-9_-]/}" ]; then
    # Context growth this prompt: statusline-hook.sh copies .latest to .baseline on each prompt submit
    sid=${sid//[^A-Za-z0-9_-]/}
    mkdir -p "$sd"
    printf '%s %s %s\n' "${tin:-0}" "${tout:-0}" "$cost" > "$sd/$sid.latest"
    bin=0 bout=0 bcost=""
    [ -f "$sd/$sid.baseline" ] && read -r bin bout bcost < "$sd/$sid.baseline"
    # Cost added this prompt, in cents; a baseline from before cost tracking has no third field, so no delta
    cost_delta=""
    if [ -n "$cost" ] && [ -n "$bcost" ]; then
        to_micro "$cost"; cm=$_micro; to_micro "$bcost"
        dm=$(( cm - _micro )); [ "$dm" -lt 0 ] && dm=0
        dm=$(( (dm + 5000) / 10000 ))
        printf -v cost_delta '+$%d.%02d' $((dm / 100)) $((dm % 100))
    fi
    d=$(( ${tin:-0} + ${tout:-0} - ${bin:-0} - ${bout:-0} ))
    [ "$d" -lt 0 ] && d=0
    # 8 color steps, light to heavy: tenths of a percent of the window, or fixed token counts
    if [ "$GROWTH_COLOR_BY" = percent ] && [ "${cwsize:-0}" -gt 0 ]; then
        step_of $(( d * 1000 / cwsize )) 5 10 20 40 75 125 200 350
    else
        step_of "$d" 1000 2000 4000 8000 15000 25000 40000 70000
    fi
    st=$_step
    gc=($T_OFF ${T_GROW[*]})
    gtxt=$(fmt_tok "$d")
    if [ "$GROWTH_SHOW" != tokens ] && [ "${cwsize:-0}" -gt 0 ]; then
        pm=$(( d * 1000 / cwsize )); ptxt=$(printf '%d.%d%%' $((pm / 10)) $((pm % 10)))
        if [ "$GROWTH_SHOW" = both ]; then gtxt="$gtxt $ptxt"; else gtxt=$ptxt; fi
    fi
    # Cache hit rate (cache reads / all input tokens); the lowest value since the last prompt is kept, so a cold call stays visible
    hit=""
    if [ -n "$crd" ]; then
        total=$(( ${cin:-0} + ${ccr:-0} + crd ))
        [ "$total" -gt 0 ] && hit=$(( (crd * 100 + total / 2) / total ))
    fi
    if [ -n "$hit" ]; then
        hmin=100
        [ -f "$sd/$sid.hitmin" ] && read -r hmin < "$sd/$sid.hitmin"
        case "$hmin" in ''|*[!0-9]*) hmin=100 ;; esac
        [ "$hit" -lt "$hmin" ] && hmin=$hit
        printf '%s\n' "$hmin" > "$sd/$sid.hitmin"
        hit=$hmin
    fi
    gcol=${gc[$st]}
    pill_growth=" ${ESC}[38;5;${gcol}m${LCAP}${ESC}[48;5;${gcol}m${ESC}[38;5;${T_INK}m+${gtxt}${RST}${ESC}[38;5;${gcol}m${RCAP}${RST}"
    pill_full=$pill_growth
    if [ -n "$hit" ] && [ "$SHOW_CACHE" = true ]; then
        if [ "$hit" -ge 80 ]; then hc=${T_HIT[0]}; elif [ "$hit" -ge 50 ]; then hc=${T_HIT[1]}; else hc=${T_HIT[2]}; fi
        # growth pill, then an inset (padded) with a bolt and the hit rate in its own color
        pill_full=" ${ESC}[38;5;${gcol}m${LCAP}${ESC}[48;5;${gcol}m${ESC}[38;5;${T_INK}m+${gtxt}${ESC}[38;5;${gcol}m${ESC}[48;5;${T_INSET}m${RCAP} ${ESC}[38;5;${hc}m${BOLT} ${hit}%${RST}${ESC}[38;5;${T_INSET}m${RCAP}${RST}"
    fi
fi

# ---- Session total tokens (incremental transcript parse) -------------------------------------------------------
# New input + cache writes + output, summed per API call. The state file keeps "offset sum last_id last_total",
# so each render only parses appended lines.
tok_total=""
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
    tok_total=$(fmt_tok "${sum:-0}")
fi

# ---- Segments, built for a given shrink stage -------------------------------------------------------------------
# Effort: the theme's secondary range, green (low) to red (max); darker greens to reds on a light terminal
case "$effort" in
    low) ei=0 ;; medium) ei=2 ;; high) ei=4 ;; xhigh) ei=6 ;; max) ei=7 ;; *) ei="" ;;
esac
ec=""
if [ -n "$ei" ]; then
    if [ "$STATUSLINE_BG" = light ]; then le=(28 28 64 64 136 136 166 124); ec=$(c256 "${le[$ei]}")
    else ec=$(c256 "${T_GROW[$ei]}"); fi
fi
winsz=""
[ -n "$cwsize" ] && { winsz=$(fmt_tok "$cwsize"); winsz=${winsz/.0k/k}; winsz=${winsz/.0M/M}; }

# What each shrink stage removes (stage 0 = everything; each stage keeps the earlier removals):
#   1 shorter bars   2 reset times and window size   3 token total   4 cache inset, cost delta   5 7d   6 diff
#   7 5h             8 minimal bars, model name only 9 worktree name  10 cost (plan billing)  11 model
# Repo, Ctx and the growth pill are never dropped.
MAXSTAGE=11
stage_vars() { # stage
    bw=0 show_reset=1 show_win=1 show_tok=1 show_cache_in=1 show_7d=1 show_diff=1 show_5h=1 show_eff=1 show_wt=1 show_cost=1 show_cost_delta=1 show_model=1
    [ "$1" -ge 1 ] && bw=1
    [ "$1" -ge 2 ] && show_reset=0 show_win=0
    [ "$1" -ge 3 ] && show_tok=0
    [ "$1" -ge 4 ] && show_cache_in=0 show_cost_delta=0
    [ "$1" -ge 5 ] && show_7d=0
    [ "$1" -ge 6 ] && show_diff=0
    [ "$1" -ge 7 ] && show_5h=0
    [ "$1" -ge 8 ] && bw=2 show_eff=0
    [ "$1" -ge 9 ] && show_wt=0
    [ "$1" -ge 10 ] && [ "$api" != true ] && show_cost=0
    [ "$1" -ge 11 ] && show_model=0
}

# Segment builders set $_o instead of printing, so the shrink loop forks nothing
_o=""
limit_seg() { # label k value reset
    _o=""
    local rt=""
    if [ "$show_reset" = 1 ] && [[ "$4" =~ ^[0-9]+$ ]]; then until_reset "$4"; rt=$_t; fi
    if [ -n "${bars[0]}" ]; then
        bar_for "$2" "$bw"
        if [ "$LIMIT_PILL" = true ]; then pill_bar "$1" "$_bar" "$rt"; return; fi
        _o="${C_LABEL}$1${RST} $_bar"
    else plain_bar "$1" "$3"; fi
    [ -n "$rt" ] && _o="$_o${C_DIM} ($rt)${RST}"
}

git_seg() {
    _o="${C_REPO}${repo_name}${RST}"
    [ -n "$branch" ] && _o="$_o${C_COLON}:${RST}${C_BRANCH}${branch}${RST}"
    # Worktree is shown only when its name differs from the branch ("/" counts as "-")
    [ "$show_wt" = 1 ] && [ -n "$worktree" ] && [ "$worktree" != "${branch//\//-}" ] && _o="$_o ${C_DIM}(wt: ${worktree})${RST}"
    [ "$PILLS" = true ] && pill_text "$_o"
    if [ "$SHOW_GIT_COUNTS" = true ] && [ -n "$branch" ]; then
        local cs=$C_REPO cu=$C_YELLOW ca=$C_BLUE
        [ "${staged:-0}" -eq 0 ] && cs=$C_DIM
        [ "${unstaged:-0}" -eq 0 ] && cu=$C_DIM
        [ "${ahead:-0}" -eq 0 ] && ca=$C_DIM
        if [ "$PILLS" = true ]; then
            local main=$_o   # the counts get a pill of their own
            pill_text "${cs}S: ${staged:-0}${RST} ${cu}U: ${unstaged:-0}${RST} ${ca}A: ${ahead:-0}${RST}"
            _o="$main $_o"
        else
            _o="$_o${SEP}${cs}S: ${staged:-0}${RST}${SEP}${cu}U: ${unstaged:-0}${RST}${SEP}${ca}A: ${ahead:-0}${RST}"
        fi
    fi
}

diff_seg() {
    _o=""
    [ -n "$added$removed" ] && _o="${C_ADD}+${added:-0}${RST} ${C_REM}-${removed:-0}${RST}"
    [ "$PILLS" = true ] && [ -n "$_o" ] && pill_text "$_o"
}

model_seg() {
    _o=""
    [ -n "$model" ] && _o="${C_MODEL}${model}${RST}"
    [ "$show_eff" = 1 ] && [ -n "$effort" ] && _o="${_o:+$_o/}${ec}${effort}${RST}"
    [ "$show_win" = 1 ] && [ -n "$_o" ] && [ -n "$winsz" ] && _o="$_o ${C_DIM}(${winsz})${RST}"
    [ "$PILLS" = true ] && [ -n "$_o" ] && pill_text "$_o"
}

ctx_seg() {
    local pl=$pill_growth
    [ "$show_cache_in" = 1 ] && pl=$pill_full
    if [ -n "${bars[0]}" ]; then
        bar_for 0 "$bw"
        if [ "$CTX_PILL" = true ]; then
            pill_bar "$CTX_LABEL" "$_bar"; _o="$_o$pl"
        else
            _o="${C_LABEL}${CTX_LABEL}${RST} $_bar$pl"
        fi
    else plain_bar "$CTX_LABEL" "$used_pct"; _o="$_o$pl"; fi
}

cost_seg() {
    _o=""
    [ -n "$cost" ] || return
    local txt; printf -v txt '$%.2f' "$cost"
    if [ "$COST_STYLE" = pill ] || { [ "$COST_STYLE" = auto ] && [ "$api" = true ]; }; then
        # A pill that steps through the growth colors as the bill grows (the default for API billing, where cost is the meter)
        to_cents "$cost"; step_of "$_cents" $COST_STEPS
        local cc=(240 "${T_GROW[@]}") f=${cc[$_step]}
        pill "$f" "$txt"
        # What the last prompt cost, in an inset like the cache one
        if [ -n "$cost_delta" ] && [ "$show_cost_delta" = 1 ]; then
            _o="${ESC}[38;5;${f}m${LCAP}${ESC}[48;5;${f}m${ESC}[38;5;${T_INK}m${txt}${ESC}[38;5;${f}m${ESC}[48;5;${T_INSET}m${RCAP} ${C_TOK}${cost_delta}${RST}${ESC}[38;5;${T_INSET}m${RCAP}${RST}"
        fi
    else
        _o="${C_COST}${txt}${RST}"
        [ -n "$cost_delta" ] && [ "$show_cost_delta" = 1 ] && _o="$_o ${C_TOK}${cost_delta}${RST}"
    fi
}

join_segs() { # segments... -> $_joined (empty segments skipped)
    local s out=""
    for s in "$@"; do [ -n "$s" ] && out="${out:+$out$SEP}$s"; done
    _joined=$out
}

usage_segs() { # the usage part for the current stage -> $_joined
    local m="" c a="" b="" k="" t=""
    [ "$show_model" = 1 ] && { model_seg; m=$_o; }
    ctx_seg; c=$_o
    [ -n "$five" ] && [ "$show_5h" = 1 ] && { limit_seg 5h 1 "$five" "$five_reset"; a=$_o; }
    [ -n "$seven" ] && [ "$show_7d" = 1 ] && { limit_seg 7d 2 "$seven" "$seven_reset"; b=$_o; }
    [ "$SHOW_COST" = true ] && [ "$show_cost" = 1 ] && { cost_seg; k=$_o; }
    [ "$SHOW_TOKENS" = true ] && [ "$show_tok" = 1 ] && [ -n "$tok_total" ] && { t="${C_TOK}${tok_total}${RST}"; [ "$PILLS" = true ] && { pill_text "$t"; t=$_o; }; }
    if [ "$LIMIT_PILL" = true ]; then
        # Pills sit side by side with a space instead of a separator
        local lim=""
        [ -n "$a" ] && lim=$a
        [ -n "$b" ] && lim="${lim:+$lim }$b"
        if [ "$CTX_PILL" = true ] && [ -n "$lim" ]; then c="$c $lim"; lim=""; fi
        a=$lim b=""
    fi
    join_segs "$m" "$c" "$a" "$b" "$k" "$t"
}

# ---- Layout -----------------------------------------------------------------------------------------------------
cols=${COLUMNS:-}
[[ "$cols" =~ ^[0-9]+$ ]] || cols=$(tput cols 2>/dev/null)
[[ "$cols" =~ ^[0-9]+$ ]] || cols=0
avail=$(( cols - STATUSLINE_MARGIN ))
fit() { [ "$STATUSLINE_LAYOUT" = full ] || [ "$cols" -le 0 ] || [ "$vis" -le "$avail" ]; }

show_wt=1
git_seg; gitpart=$_o
diffpart=""
[ "$SHOW_DIFF" = true ] && { diff_seg; diffpart=$_o; }

if [ "$STATUSLINE_LAYOUT" = wrap ]; then
    # Line 1: model and usage, shrunk until it fits. Line 2: repo:branch and the diff, which never shrink.
    for ((s = 0; s <= MAXSTAGE; s++)); do
        stage_vars "$s"; usage_segs; measure "$_joined"; fit && break
    done
    line1=$_joined
    join_segs "$gitpart" "$diffpart"
    out=$line1
    [ -n "$_joined" ] && out="${out:+$out$'\n'}$_joined"
else
    # One line: shrink stage by stage until it fits. Repo, Ctx and the growth pill are never dropped.
    for ((s = 0; s <= MAXSTAGE; s++)); do
        stage_vars "$s"; usage_segs; ul=$_joined
        git_seg; gitpart=$_o
        dp=""; [ "$show_diff" = 1 ] && dp=$diffpart
        join_segs "$gitpart" "$dp" "$ul"
        measure "$_joined"; fit && break
    done
    out=$_joined
    # Last resort: trim the branch name so the line fits
    if ! fit && [ -n "$branch" ]; then
        keep=$(( ${#branch} - (vis - avail) - 1 ))
        if [ "$keep" -ge 6 ]; then
            branch="${branch:0:keep}…"; git_seg; gitpart=$_o
            join_segs "$gitpart" "$dp" "$ul"; out=$_joined
        fi
    fi
fi

printf '%s' "$out"
