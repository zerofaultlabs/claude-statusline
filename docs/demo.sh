#!/bin/bash
# Prints a sample status line for every theme, pills off then pills on (3 blank lines above and below), for a README
# screenshot. The usage bars are the same on every line (Ctx low, 5h middle, 7d high); the growth, cache and cost pills climb from low to high across themes. Pills off shows low effort on Sonnet,
# pills on shows max effort on Opus, so the effort colors show at both ends.
# `docs/demo.sh table` prints each theme's primary and secondary color ranges instead, rendered.
# Uses a throwaway HOME and its own config, so your real settings and state are untouched.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ "$1" = table ]; then
    python3 -I - "$here" <<'PY'
import sys, re, importlib.util
here = sys.argv[1]
spec = importlib.util.spec_from_file_location("ctxbar", f"{here}/statusline-ctxbar.py")
cb = importlib.util.module_from_spec(spec); spec.loader.exec_module(cb)
src = open(f"{here}/statusline-command.sh").read()
RST = "\x1b[0m"
def secondary(name):   # the 8 growth/cost steps, parsed from the theme's block in statusline-command.sh
    key = r"\*" if name == "sorbet" else name
    m = re.search(r"\n    " + key + r"\)[^\n]*\n\s+T_GROW=\(([0-9 ]+)\)", src)
    return [int(x) for x in m.group(1).split()]
W = 16
print("\n\n")
print(f"{'Theme':<8}  {'Primary':<{W + 2}}  Secondary")
for name, th in cb.THEMES.items():
    bar = cb.render(100, W, th["pal"], th["track"], th["bloom"])
    strip = "".join(f"\x1b[48;5;{c}m   {RST}" for c in secondary(name))
    print(f"{name:<8}  {bar}  {strip}")
print("\n")
PY
    exit
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude/statusline-state"
cp "$here/statusline-ctxbar.py" "$tmp/.claude/"
now=$(date +%s)

themes=(sorbet ember sunset ocean forest grape mono)
#       low                                                   high
ctx=8 five=45 seven=98                     # the same on every line, so each theme's low, middle and high bar colors show
grow=(3000 8000 15000 30000 60000 110000 300000)   # tokens the last prompt added (1M window)
hit=(99 95 88 78 62 45 20)                 # lowest cache hit, %
cost=(3 38 85 175 340 820 3210)            # session cost, cents
step=(1 4 12 25 61 140 480)                # what the last prompt cost, cents
efforts=(max max max max max max max)         # effort on the pills-on lines (the top of the range)

render() { # index pills
    # Pills off: low effort on Sonnet. Pills on: max effort on Opus, with the pill loads shifted three themes along
    local sid="demo$1$2" model=Sonnet effort=low j=$1
    [ "$2" = true ] && { model=Opus effort=${efforts[$1]} j=$(( ($1 + 3) % ${#themes[@]} )); }
    local i=$1 c=${cost[$j]} d=${step[$j]} h=${hit[$j]} g=${grow[$j]}
    printf 'STATUSLINE_THEME=%s\nCOST_STYLE=pill\nBAR_WIDTH=8\nSHOW_DIFF=false\n' "${themes[$i]}" > "$tmp/statusline.conf"
    [ "$2" = true ] && printf 'PILLS=true\nCTX_LABEL=C\n' >> "$tmp/statusline.conf"
    # Baseline from the previous prompt, so the growth pill and the cost inset have something to compare against
    printf '80000 2000 %d.%02d\n' $(( (c - d) / 100 )) $(( (c - d) % 100 )) > "$tmp/.claude/statusline-state/$sid.baseline"
    cat <<JSON | HOME="$tmp" STATUSLINE_CONF="$tmp/statusline.conf" COLUMNS="${COLUMNS:-$(tput cols)}" bash "$here/statusline-command.sh"
{"session_id":"$sid","workspace":{"current_dir":"$here","repo":{"name":"repo"}},
 "model":{"display_name":"$model"},"effort":{"level":"$effort"},
 "context_window":{"used_percentage":$ctx,"context_window_size":1000000,"total_input_tokens":$((80000 + g)),"total_output_tokens":2000,
   "current_usage":{"input_tokens":500,"cache_creation_input_tokens":$((99500 - h * 1000)),"cache_read_input_tokens":$((h * 1000))}},
 "rate_limits":{"five_hour":{"used_percentage":$five,"resets_at":$((now + 4980))},"seven_day":{"used_percentage":$seven,"resets_at":$((now + 270000))}},
 "cost":{"total_cost_usd":$((c / 100)).$(printf %02d $((c % 100))),"total_lines_added":128,"total_lines_removed":34}}
JSON
    printf '\n'
}

printf '\n\n\n'
for pills in false true; do
    for i in "${!themes[@]}"; do render "$i" "$pills"; done
    [ "$pills" = false ] && printf '\n'
done
printf '\n\n\n'
