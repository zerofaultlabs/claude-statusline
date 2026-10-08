# claude-statusline

A status line for [Claude Code](https://claude.com/claude-code) that keeps a long session's vital signs in view: context usage, rate limits, cost, and cache hits.

![The status line, annotated](docs/statusline.png)

```
repo:branch | +120 -34 | Opus/high (1M) | Ctx ███░░░░░ 42% (+1.2k) | 5h ██░░░░░░ 30% (1h6m) | 7d █░░░░░░░ 12% (4d2h) | $1.23 | 35.4k | Hit 90%
```

Written up in [Put Your Claude Code Session's Vital Signs in the Status Line](https://zerofaultlabs.io/) on the ZeroFault Labs blog, which covers why each number is there.

## What it shows

| Segment | Meaning |
| --- | --- |
| `repo:branch` | Branch in cyan. A gray `(wt: name)` appears only when the worktree name differs from the branch. |
| `+N -N` | Lines added and removed this session. |
| `Model/effort (size)` | Effort is colored from cool to hot: low=blue, medium=cyan, high=yellow, xhigh=orange, max=red. |
| `Ctx ███░░░░░ NN% (+N)` | Context usage. Green below 20%, yellow from 20%, red from 50%, violet from 80%. The `(+N)` is token growth since your last prompt. |
| `5h` and `7d` | Rate-limit bars with time until reset. Green below 50%, yellow from 50%, red above 80%. |
| `$X.XX` | Session cost. |
| White number | Total session tokens: input + cache writes + output, no cache reads. Counted incrementally from the transcript, so it stays fast in long sessions. |
| `Hit NN%` | Cache hit rate of the last API call. |

Every segment appears only if Claude Code reports its data.

## Install

Requires `bash`, `jq`, `git`, and `awk`. Developed on macOS. The file-size call tries GNU `stat` first, so Linux should work, but it is less tested.

**With Claude Code.** Open a session and paste the prompt from [`INSTALL_PROMPT.md`](INSTALL_PROMPT.md). It reads the scripts, merges your settings without overwriting anything, and tests against fake data.

**By hand.**

```bash
git clone https://github.com/zerofaultlabs/claude-statusline.git
cp claude-statusline/statusline-command.sh claude-statusline/statusline-hook.sh ~/.claude/
```

Then add this to `~/.claude/settings.json`, merging with what is already there:

```json
"statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"},
"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/statusline-hook.sh"}]}]}
```

Read both scripts first. They are short, and they run on every refresh.

## Files

- `statusline-command.sh` renders the line.
- `statusline-hook.sh` is a `UserPromptSubmit` hook. It snapshots token totals for the per-prompt growth figure and deletes state files older than 14 days from `~/.claude/statusline-state/`.

## Limits

- The 5h and 7d segments appear only when Claude Code reports rate-limit data for your plan.
- The Ctx color thresholds (20/50/80%) assume a 1M-token window. Lower them for a 200k window (see `ctx_color` in the script).
- The token total measures work done, not a bill. Use your provider's usage page for money.
- A session resumed after 14 days rebuilds its token total on the next render: correct, but slower once.

## Customize

Set `SHOW_GIT_COUNTS=true` at the top of `statusline-command.sh` to add staged, unstaged, and ahead counts. To drop a segment, delete its line; nothing else depends on it.

## Share yours

Added a segment you can't live without? Open an issue or start a discussion and tell me which number it is. The best additions may make it into the script.

## License

[MIT](LICENSE)
