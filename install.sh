#!/bin/bash

# Claude Statusline Installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Installing Claude Code statusline..."

# Create .claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Copy the statusline script
cp "$SCRIPT_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
echo "✓ Copied statusline-command.sh to $CLAUDE_DIR/"

# Update or create settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
    # Check if statusLine already exists
    if jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
        # Update existing statusLine
        tmp=$(mktemp)
        jq '.statusLine = {"type": "command", "command": "/bin/bash ~/.claude/statusline-command.sh"}' "$SETTINGS_FILE" > "$tmp"
        mv "$tmp" "$SETTINGS_FILE"
        echo "✓ Updated statusLine in $SETTINGS_FILE"
    else
        # Add statusLine to existing settings
        tmp=$(mktemp)
        jq '. + {"statusLine": {"type": "command", "command": "/bin/bash ~/.claude/statusline-command.sh"}}' "$SETTINGS_FILE" > "$tmp"
        mv "$tmp" "$SETTINGS_FILE"
        echo "✓ Added statusLine to $SETTINGS_FILE"
    fi
else
    # Create new settings.json
    echo '{"statusLine": {"type": "command", "command": "/bin/bash ~/.claude/statusline-command.sh"}}' | jq . > "$SETTINGS_FILE"
    echo "✓ Created $SETTINGS_FILE"
fi

echo ""
echo "Installation complete! Restart Claude Code to see your new statusline."
