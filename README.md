# Claude Code Statusline

A custom statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with icons, context window usage, git info, and Docker container count.

## Preview

```
🤖 Opus 4.7 │ 🧠 ▰▰▱▱▱ 42% 84K/200K │ 📁 my-project │ 🌿 main *3 ↑2 ↓1 │ 🐳 containers:3
```

## Features

| Section | Description |
|---------|-------------|
| 🤖 Model | Active model name (e.g. Opus 4.7, Sonnet 4.6) |
| 🧠 Context | Visual bar + percentage + used/total tokens |
| 📁 Directory | Current project folder name |
| 🌿 Git branch | Branch name, dirty file count (`*N`), ahead/behind upstream (`↑N ↓N`) |
| 🐳 Docker | Running container count (hidden if 0) |

Git and Docker checks are cached for ~3s in `/tmp/claude-statusline-<uid>/` to keep renders fast on large repos.

Context bar colors:
- **Green** < 50%
- **Yellow** 50-79%
- **Red** >= 80%

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/claude-statusline/main/install.sh | sh
```

If you'd rather not pipe a remote script to your shell, this self-contained
one-liner does the same work inline (download + register in `settings.json`):

```bash
mkdir -p ~/.claude && \
  curl -fsSL https://raw.githubusercontent.com/manzolo/claude-statusline/main/statusline-command.sh \
       -o ~/.claude/statusline-command.sh && \
  chmod +x ~/.claude/statusline-command.sh && \
  tmp=$(mktemp) && \
  jq --arg cmd "bash $HOME/.claude/statusline-command.sh" \
     '. + {statusLine:{type:"command",command:$cmd}}' \
     ~/.claude/settings.json 2>/dev/null > "$tmp" || \
  jq -n --arg cmd "bash $HOME/.claude/statusline-command.sh" \
     '{statusLine:{type:"command",command:$cmd}}' > "$tmp"; \
  mv "$tmp" ~/.claude/settings.json
```

## Update

Pull the latest `statusline-command.sh` over the installed one (leaves
`settings.json` untouched):

```bash
curl -fsSL https://raw.githubusercontent.com/manzolo/claude-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
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

Remove the script and strip the `statusLine` key from `settings.json` in one
shot:

```bash
rm -f ~/.claude/statusline-command.sh && \
  tmp=$(mktemp) && \
  jq 'del(.statusLine)' ~/.claude/settings.json > "$tmp" && \
  mv "$tmp" ~/.claude/settings.json
```

## License

MIT
