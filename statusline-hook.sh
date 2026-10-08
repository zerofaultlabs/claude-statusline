#!/bin/bash
# UserPromptSubmit hook: snapshot the session's latest token totals as the new per-prompt baseline
sid=$(jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
d="$HOME/.claude/statusline-state"
[ -n "$sid" ] && [ -f "$d/$sid.latest" ] && cp "$d/$sid.latest" "$d/$sid.baseline"
# Prune state files untouched for 14+ days (active sessions rewrite theirs on every render)
find "$d" -type f -mtime +14 -delete 2>/dev/null
exit 0
