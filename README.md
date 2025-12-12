# Claude Code Statusline

A customizable status line for Claude Code that displays:

- **Directory** with git branch and status
- **Token usage** (input/output + cache write/read)
- **Session cost**
- **Context usage %** (color-coded)
- **API latency** (cached)
- **Model indicator**

## Preview

### Linux (Bash)
```
󰚡 ~  main 󰗡  󰾂 1K↑24K↓ 󰆓 175K↑5.6M↓  󰄬 75¢  🧠 35%
```

### Windows (Nushell)
```
📁 ~ | 🤖 O | 💰 $5.42 | 🧠 162K 81% | 📊 6↑1K↓ ⚡2K↑160K↓ | 🏓 76ms
```

## Requirements

### Linux
- `jq` - JSON processor
- `bc` - Calculator
- `curl` - For API latency
- Nerd Font - For icons (optional)

### Windows
- [Nushell](https://www.nushell.sh/) - Modern shell
- `curl` - For API latency (included in Windows 10+)

## Installation

### Linux

1. Copy the script to your Claude config directory:

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
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

### Windows (Nushell)

1. Copy the script to your Claude config directory:

```powershell
copy statusline-command.nu $env:USERPROFILE\.claude\statusline.nu
```

2. Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "nu --stdin -c \"let input = $in; source C:/Users/YOUR_USERNAME/.claude/statusline.nu; $input | statusline\""
  }
}
```

Replace `YOUR_USERNAME` with your Windows username.

3. Restart Claude Code

## Icons Reference

### Linux (Nerd Font)
| Icon | Meaning |
|------|---------|
| 󰚡 | Home directory |
|  | Git branch |
| 󰗡 | Git clean |
| 󰷉 | Git modified |
| 󰾂 | Token usage |
| 󰆓 | Cache usage |
| 󰄬 | Session cost |
| 󰧑 | Model |
| 󰛳 | API latency |
| 🧠 | Context % |

### Windows (Emoji)
| Icon | Meaning |
|------|---------|
| 📁 | Directory |
| 🤖 | Model (O=Opus, S=Sonnet, H=Haiku) |
| 💰 | Session cost |
| 🧠 | Context (tokens + %) |
| 📊 | Input↑ Output↓ tokens |
| ⚡ | Cache create↑ read↓ |
| 🏓 | API latency |

## Token Display

- Input/Output: `6↑1K↓` = 6 input tokens, 1K output tokens
- Cache: `2K↑160K↓` = 2K cache created, 160K cache read

## Context Calculation

Context % is calculated as:
```
context = (input_tokens + cache_read_input_tokens + cache_creation_input_tokens) / 200000 * 100
```

Color thresholds:
- 🟢 Green: < 50%
- 🟡 Yellow: 50-80%
- 🔴 Red: ≥ 80%

## License

MIT
