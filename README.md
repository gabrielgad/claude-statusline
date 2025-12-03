# Claude Code Statusline

A customizable status line for Claude Code that displays:

- **Directory** with git branch and status
- **Token usage** (input/output + cache write/read)
- **Session cost**
- **Weekly billing cost** (aligned to Claude's billing week)
- **Time until block reset** (via ccusage)
- **Context usage %** (color-coded: green <50%, yellow <80%, red ≥80%)

## Preview

```
󰚡 ~  main 󰗡  󰾂 1K↑24K↓ 󰆓 175K↑5.6M↓  󰄬 75¢  󰃭 $688.22/wk  󰔟 1h 57m left 🧠 35%
```

## Requirements

- `jq` - JSON processor
- `bc` - Calculator
- `npx` - For ccusage (time left + context %)
- Nerd Font - For icons (optional, will show boxes without it)

## Installation

1. Copy the script to your Claude config directory:

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
```

2. Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash ~/.claude/statusline-command.sh"
  }
}
```

Or if you already have settings, just add the `statusLine` block.

3. Restart Claude Code

## Configuration

### Billing Week

The script calculates weekly cost based on Claude's billing cycle (resets Mondays at 3pm PT). The reference date is set to Dec 8, 2025. This should work for future weeks automatically.

### Icons

| Icon | Meaning |
|------|---------|
| 󰚡 | Home directory |
|  | Git branch |
| 󰗡 | Git clean |
| 󰷉 | Git modified |
| 󰾂 | Token usage |
| 󰆓 | Cache usage |
| 󰄬 | Session cost |
| 󰃭 | Weekly cost |
| 󰔟 | Time until reset |
| 🧠 | Context % |

### Token Display

- `󰾂 1K↑24K↓` = 1K input tokens, 24K output tokens
- `󰆓 175K↑5.6M↓` = 175K cache write, 5.6M cache read

### Pricing

Uses Opus 4.5 pricing:
- Input: $15/M tokens
- Output: $75/M tokens
- Cache write: $18.75/M tokens
- Cache read: $1.875/M tokens

## License

MIT
