#!/bin/bash
# Install the Claude Code custom status line on this machine.
# - copies statusline.sh to ~/.claude/scripts/
# - merges the "statusLine" key into ~/.claude/settings.json (backup is created)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
TARGET_SCRIPT="${CLAUDE_DIR}/scripts/statusline.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"

for dep in jq bc git; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Missing dependency: $dep (macOS: brew install $dep)" >&2
        exit 1
    fi
done

mkdir -p "${CLAUDE_DIR}/scripts"
cp "${SRC_DIR}/statusline.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
echo "Installed script: $TARGET_SCRIPT"

if [ -f "$SETTINGS" ]; then
    backup="${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS" "$backup"
    echo "Backup created: $backup"
    tmp="$(mktemp)"
    jq -s '.[0] * .[1]' "$SETTINGS" "${SRC_DIR}/settings.snippet.json" > "$tmp"
    mv "$tmp" "$SETTINGS"
else
    cp "${SRC_DIR}/settings.snippet.json" "$SETTINGS"
fi
echo "Updated settings: $SETTINGS"

echo "Done. Restart Claude Code to see the status line."
