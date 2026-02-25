#!/bin/bash
# Install herald-ping hooks into Claude Code settings.
#
# This script:
#   1. Generates default sounds if missing
#   2. Patches ~/.claude/settings.json to register hooks
#
# Usage:
#   ./install.sh              # Install with defaults
#   ./install.sh --voice Samantha  # Use a different TTS voice
#   ./install.sh --uninstall  # Remove hooks (alias for uninstall.sh)

set -e

HERALD_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
VOICE="Daniel"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --voice)
            VOICE="$2"
            shift 2
            ;;
        --uninstall)
            exec "$HERALD_DIR/uninstall.sh"
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "herald-ping installer"
echo "====================="
echo "Install dir: $HERALD_DIR"
echo "Settings:    $SETTINGS_FILE"
echo ""

# --- Make scripts executable ---
chmod +x "$HERALD_DIR/herald.sh"
chmod +x "$HERALD_DIR/uninstall.sh"
chmod +x "$HERALD_DIR/packs/default/generate.sh"

# --- Generate default sounds if missing ---
if [ ! -f "$HERALD_DIR/packs/default/sounds/session_start.aiff" ]; then
    echo "Generating default sounds (voice: $VOICE)..."
    "$HERALD_DIR/packs/default/generate.sh" "$VOICE"
    echo ""
fi

# --- Patch Claude Code settings ---
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Error: $SETTINGS_FILE not found."
    echo "Make sure Claude Code is installed and has been run at least once."
    exit 1
fi

echo "Patching $SETTINGS_FILE..."

# Back up settings
cp "$SETTINGS_FILE" "$SETTINGS_FILE.herald-backup"

# Register herald.sh for each hook event type
HERALD_SCRIPT="$HERALD_DIR/herald.sh"

jq --arg script "$HERALD_SCRIPT" '
  # Ensure hooks object exists
  .hooks //= {} |

  # SessionStart hook
  .hooks.SessionStart = (
    [(.hooks.SessionStart // [])[] | select(.hooks[0].command | test("herald\\.sh") | not)] +
    [{"hooks": [{"type": "command", "command": ("CLAUDE_HOOK_EVENT=SessionStart " + $script)}]}]
  ) |

  # SessionEnd hook
  .hooks.SessionEnd = (
    [(.hooks.SessionEnd // [])[] | select(.hooks[0].command | test("herald\\.sh") | not)] +
    [{"hooks": [{"type": "command", "command": ("CLAUDE_HOOK_EVENT=SessionEnd " + $script)}]}]
  ) |

  # PreToolUse - all tools (tool-specific sounds + attention for AskUserQuestion)
  .hooks.PreToolUse = (
    [(.hooks.PreToolUse // [])[] | select(.hooks[0].command | test("herald\\.sh") | not)] +
    [{"hooks": [{"type": "command", "command": ("CLAUDE_HOOK_EVENT=PreToolUse " + $script)}]}]
  ) |

  # PostToolUse - all tools (completion/error)
  .hooks.PostToolUse = (
    [(.hooks.PostToolUse // [])[] | select(.hooks[0].command | test("herald\\.sh") | not)] +
    [{"hooks": [{"type": "command", "command": ("CLAUDE_HOOK_EVENT=PostToolUse " + $script)}]}]
  )
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo ""
echo "herald-ping installed successfully."
echo ""
echo "Enabled events (edit $HERALD_DIR/config.json to change):"
jq -r '.events | to_entries[] | "  " + .key + ": " + (if .value then "ON" else "OFF" end)' "$HERALD_DIR/config.json"
echo ""
echo "Restart Claude Code for hooks to take effect."
echo "To uninstall: $HERALD_DIR/uninstall.sh"
