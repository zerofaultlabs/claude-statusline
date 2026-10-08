Paste this into Claude Code.

---

Install the Claude Code status line from https://github.com/zerofaultlabs/claude-statusline.

1. Fetch the raw contents of `statusline-command.sh` and `statusline-hook.sh` from that repo and write them verbatim to `~/.claude/statusline-command.sh` and `~/.claude/statusline-hook.sh`. Read both files before writing them, and tell me if either does anything beyond what its comments say.
2. Merge this into `~/.claude/settings.json`. Preserve every existing key, and append to any existing `UserPromptSubmit` hooks instead of replacing them:
   ```json
   "statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"},
   "hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/statusline-hook.sh"}]}]}
   ```
3. Check that `jq`, `git`, and `awk` are installed. If one is missing, tell me how to install it and stop.
4. Validate:
   - Pipe fake JSON with every field the script reads into the script and show the rendered line.
   - Remove fields and confirm only the matching segments disappear.
   - Test inside and outside a git repo.
   - Test a missing transcript.
   - Confirm the hook copies `.latest` to `.baseline` in `~/.claude/statusline-state/`.
   - Confirm the hook deletes a state file dated 15 days back (`touch -t`) and keeps recent ones.
5. Show me the settings.json diff and a sample rendered line.

Notes for me to consider afterwards: the Ctx color thresholds (20/50/80%) assume a 1M-token window. Lower them for a 200k window. Set `SHOW_GIT_COUNTS=true` at the top of the script to add staged/unstaged/ahead counts.
