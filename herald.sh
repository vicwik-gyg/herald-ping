#!/bin/bash
# herald-ping: Local sound notification hook for Claude Code.
#
# Plays context-appropriate sounds when Claude Code events fire.
# Designed to be registered as a Claude Code hook script.
#
# Hook events and their herald categories:
#   SessionStart                    -> session_start
#   SessionEnd                      -> session_end
#   PreToolUse[AskUserQuestion]     -> attention
#   PostToolUse (exit_code != 0)    -> error
#   PreToolUse  (general)           -> tool_start
#   PostToolUse (general)           -> tool_end
#
# Environment variables (set by Claude Code):
#   HERALD_PING_DIR   - Override install directory
#   HERALD_EVENT      - Override event category (for testing)
#
# Exit codes:
#   0 = Success (hook passes through, never blocks)

set -e

# --- Resolve paths ---
HERALD_DIR="${HERALD_PING_DIR:-$(cd "$(dirname "$0")" && pwd)}"
CONFIG_FILE="$HERALD_DIR/config.json"
STATE_FILE="$HERALD_DIR/.state.json"

# --- Read config ---
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

enabled=$(jq -r '.enabled // true' "$CONFIG_FILE")
if [ "$enabled" != "true" ]; then
    exit 0
fi

volume=$(jq -r '.volume // 0.5' "$CONFIG_FILE")
active_pack=$(jq -r '.active_pack // "default"' "$CONFIG_FILE")

# --- Determine event category ---
resolve_event() {
    # Allow manual override for testing
    if [ -n "$HERALD_EVENT" ]; then
        echo "$HERALD_EVENT"
        return
    fi

    # Read hook input from stdin
    local input
    input=$(cat)

    # Detect hook type from environment or input structure
    local hook_event="${CLAUDE_HOOK_EVENT:-}"

    # If no explicit hook event, infer from input structure
    if [ -z "$hook_event" ]; then
        # Check if input has tool_name (PreToolUse/PostToolUse)
        local tool_name
        tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
        local tool_input_keys
        tool_input_keys=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)

        if [ -n "$tool_name" ]; then
            # Check for error in PostToolUse
            local exit_code
            exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // empty' 2>/dev/null)
            local is_error
            is_error=$(echo "$input" | jq -r '.tool_result.is_error // false' 2>/dev/null)

            if [ -n "$exit_code" ] || [ "$is_error" = "true" ]; then
                # PostToolUse
                if [ "$is_error" = "true" ] || { [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; }; then
                    echo "error"
                else
                    echo "tool_end"
                fi
            else
                # PreToolUse
                if [ "$tool_name" = "AskUserQuestion" ]; then
                    echo "attention"
                else
                    echo "tool_start"
                fi
            fi
        else
            # SessionStart or SessionEnd (no tool_name)
            local source
            source=$(echo "$input" | jq -r '.source // empty' 2>/dev/null)
            if [ -n "$source" ]; then
                echo "session_start"
            else
                echo "session_end"
            fi
        fi
    else
        case "$hook_event" in
            SessionStart)  echo "session_start" ;;
            SessionEnd)    echo "session_end" ;;
            PreToolUse)    echo "tool_start" ;;
            PostToolUse)   echo "tool_end" ;;
            *)             echo "tool_end" ;;
        esac
    fi
}

event=$(resolve_event)

# --- Check if event is enabled ---
event_enabled=$(jq -r ".events.${event} // false" "$CONFIG_FILE")
if [ "$event_enabled" != "true" ]; then
    exit 0
fi

# --- Resolve sound file ---
PACK_DIR="$HERALD_DIR/packs/$active_pack"
MANIFEST="$PACK_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
    exit 0
fi

# Get array of sound files for this event, pick one at random
sound_count=$(jq -r ".sounds.${event} | length" "$MANIFEST")
if [ "$sound_count" -eq 0 ] || [ "$sound_count" = "null" ]; then
    exit 0
fi

random_index=$((RANDOM % sound_count))
sound_file=$(jq -r ".sounds.${event}[$random_index]" "$MANIFEST")
sound_path="$PACK_DIR/$sound_file"

if [ ! -f "$sound_path" ]; then
    exit 0
fi

# --- Play sound (non-blocking) ---
# macOS: afplay with volume (0.0-1.0 mapped to afplay's 0-255)
if command -v afplay &>/dev/null; then
    afplay_vol=$(echo "$volume * 255" | bc 2>/dev/null | cut -d. -f1)
    afplay_vol="${afplay_vol:-128}"
    afplay -v "$afplay_vol" "$sound_path" &>/dev/null &
# Linux: paplay or aplay fallback
elif command -v paplay &>/dev/null; then
    paplay "$sound_path" &>/dev/null &
elif command -v aplay &>/dev/null; then
    aplay -q "$sound_path" &>/dev/null &
fi

exit 0
