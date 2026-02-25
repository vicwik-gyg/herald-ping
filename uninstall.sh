#!/bin/bash
# Uninstall herald-ping hooks from Claude Code settings.
#
# This removes hook entries from settings but leaves the herald-ping
# directory intact so you can reinstall later.

set -e

HERALD_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

echo "herald-ping uninstaller"
echo "======================="

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "No settings file found at $SETTINGS_FILE. Nothing to uninstall."
    exit 0
fi

# Back up settings
cp "$SETTINGS_FILE" "$SETTINGS_FILE.herald-backup"

# Remove all hook entries that reference herald.sh
jq '
  def remove_herald:
    if . == null then null
    else [.[] | select(.hooks[0].command | test("herald\\.sh") | not)]
    end;

  .hooks.SessionStart = (.hooks.SessionStart | remove_herald) |
  .hooks.SessionEnd = (.hooks.SessionEnd | remove_herald) |
  .hooks.PreToolUse = (.hooks.PreToolUse | remove_herald) |
  .hooks.PostToolUse = (.hooks.PostToolUse | remove_herald) |

  # Clean up empty arrays
  if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
  if .hooks.SessionEnd == [] then del(.hooks.SessionEnd) else . end |
  if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end |
  if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |

  # Clean up empty hooks object
  if (.hooks | length) == 0 then del(.hooks) else . end
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "Hooks removed from $SETTINGS_FILE"
echo "Backup saved at $SETTINGS_FILE.herald-backup"
echo ""
echo "Sound files and config left in $HERALD_DIR"
echo "To fully remove: rm -rf $HERALD_DIR"
