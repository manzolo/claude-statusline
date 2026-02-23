#!/bin/sh
# Claude Code Statusline Installer
set -e

DEST="$HOME/.claude"
SCRIPT="$DEST/statusline-command.sh"
SETTINGS="$DEST/settings.json"

mkdir -p "$DEST"

# Download the statusline script
curl -fsSL "https://raw.githubusercontent.com/manzolo/claude-statusline/main/statusline-command.sh" -o "$SCRIPT"
chmod +x "$SCRIPT"

# Configure settings.json
if [ -f "$SETTINGS" ]; then
    # Update existing settings with statusLine config
    tmp=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "bash '"$SCRIPT"'"}}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "Updated existing $SETTINGS"
else
    cat > "$SETTINGS" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "bash $SCRIPT"
  }
}
EOF
    echo "Created $SETTINGS"
fi

echo ""
echo "Statusline installed successfully!"
echo "Restart Claude Code to see the new statusline."
