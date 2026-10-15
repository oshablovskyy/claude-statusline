# Why
Inet full of status lines for claude code.  
So why not to build a new one?

# Claude Code custom status line

Shows: `Chat ctx: <pct>% | <tokens> total tokens | $<cost> | <model> | <repo:branch>`

## Files

- `statusline.sh` - the status line script (Claude Code pipes session JSON to it on stdin)
- `settings.snippet.json` - the `statusLine` entry for `~/.claude/settings.json`
- `install.sh` - copies the script to `~/.claude/scripts/` and merges the settings entry

## Install

```bash
./install.sh
```

Requires `jq`, `bc` and `git` . Restart Claude Code afterwards.

## Manual install

1. Copy `statusline.sh` to `~/.claude/scripts/statusline.sh` and `chmod +x` it.
2. Add the contents of `settings.snippet.json` to `~/.claude/settings.json`.

## Notes

- "Chat ctx" is conversation context only (input tokens / window size); use `/context` for the full breakdown.
- "Total tokens" is cumulative input + output for the session.
- Color thresholds are variables at the top of `statusline.sh`.
  - Cost: green <= $5, yellow <= $15, red above (`COST_GREEN_MAX`, `COST_YELLOW_MAX`).
  - Context: green < 50%, yellow < 75%, red above (`CTX_GREEN_MAX`, `CTX_YELLOW_MAX`).

## References
https://code.claude.com/docs/en/statusline
