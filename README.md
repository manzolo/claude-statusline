# Claude Code Statusline

A custom statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with icons, context window usage, git info, and Docker container count.

## Preview

```
🤖 Opus 4.6 │ 🧠 ▰▰▱▱▱ 42% 84K/200K │ 📁 my-project │ 🌿 main │ 🐳 containers:3
```

## Features

| Section | Description |
|---------|-------------|
| 🤖 Model | Active model name (e.g. Opus 4.6, Sonnet 4.6) |
| 🧠 Context | Visual bar + percentage + used/total tokens |
| 📁 Directory | Current project folder name |
| 🌿 Git branch | Branch name + dirty file count |
| 🐳 Docker | Running container count (hidden if 0) |

Context bar colors:
- **Green** < 50%
- **Yellow** 50-79%
- **Red** >= 80%

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/claude-statusline/main/install.sh | sh
```

## Manual Install

1. Copy the script:

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/claude-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh
```

2. Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

3. Restart Claude Code.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- `jq` (for JSON parsing)
- `git` (optional, for branch info)
- `docker` (optional, for container count)

## Uninstall

Remove the script and the `statusLine` key from settings:

```bash
rm ~/.claude/statusline-command.sh
```

Then remove the `"statusLine"` block from `~/.claude/settings.json`.

## License

MIT
