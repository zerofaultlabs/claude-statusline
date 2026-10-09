Paste this into Claude Code.

---

Install the Claude Code status line from https://github.com/zerofaultlabs/claude-statusline. Do the steps in order and stop to ask me where it says so.

1. **Check the tools.** Confirm `bash`, `jq`, `git`, and `python3` are installed. On macOS, run `python3 --version` rather than only checking that the binary exists: without the Command Line Tools, `/usr/bin/python3` is a stub that pops up an installer dialog and does not run. If something is missing, tell me how to install it and stop.
2. **Check for a Nerd Font.** The status line draws its pills, bolt, and rounded caps with Nerd Font glyphs, so my terminal needs one. Look for an installed one (for example `fc-list | grep -i nerd`, or `ls ~/Library/Fonts /Library/Fonts | grep -i nerd` on macOS). If there is none, ask me whether I would like you to install one. Do not install anything until I answer. If I say yes:
   - macOS with Homebrew: `brew install --cask font-jetbrains-mono-nerd-font`.
   - Linux: download JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases/latest into `~/.local/share/fonts/`, unzip it, and run `fc-cache -f`.
   - Then tell me plainly that installing the font is not enough: I have to select it as the font in my terminal's settings (iTerm2, Terminal.app, VS Code, Ghostty, and so on), and you cannot do that for me. Tell me which setting to change for the terminal I am using.
3. **Install the files.** Fetch the raw contents of `statusline-command.sh`, `statusline-ctxbar.py`, and `statusline-hook.sh` from that repo and write them verbatim to `~/.claude/`. Read all three before writing them, and tell me if any of them does anything other than render a status line, snapshot token counts, and delete old files in `~/.claude/statusline-state/`. If `~/.claude/statusline.conf` does not exist, copy `statusline.conf.example` there (it is entirely commented out, so it changes nothing until I edit it).
4. **Merge my settings.** Add this to `~/.claude/settings.json`. Preserve every existing key, and append to any existing `UserPromptSubmit` hooks instead of replacing them:
   ```json
   "statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"},
   "hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/statusline-hook.sh"}]}]}
   ```
5. **Validate.** Use a temporary `HOME` (or a copy of the scripts) so my real state is untouched.
   - Pipe fake JSON with every field the script reads and show the rendered line.
   - Remove fields and confirm only the matching segments disappear. A payload with no usage and no rate limits (a brand-new session) must still render, with Ctx at 0%.
   - Test `COLUMNS` at 200, 120, 90, and 60 and confirm the line gets shorter without wrapping, and with `STATUSLINE_LAYOUT=wrap` that it prints two lines.
   - Test a payload with no `rate_limits` and `BILLING=api`, and confirm the cost shows as a pill and 5h and 7d are hidden.
   - Test each theme (`sorbet`, `ember`, `sunset`) and `STATUSLINE_BG=light` for errors.
   - Test inside and outside a git repo, and with a missing transcript.
   - Confirm the hook copies `.latest` to `.baseline`, deletes `.hitmin`, and deletes a state file dated 15 days back (`touch -t`) while keeping recent ones.
6. **Show me** the settings.json diff and a sample rendered line, and remind me to pick a Nerd Font in my terminal if I have not.

After that, mention that every setting is in `~/.claude/statusline.conf`: the theme, the layout when the window is narrow (`compact` or `wrap`), billing (`plan` or `api`), and light-terminal mode.
