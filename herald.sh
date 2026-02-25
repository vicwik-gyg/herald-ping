#!/bin/bash
# herald-ping: Local sound notification hook for Claude Code.
#
# Plays context-appropriate sounds when Claude Code events fire.
# Designed to be registered as a Claude Code hook script.
#
# Sound resolution order (first match wins):
#   1. Tool-specific sound  (e.g., sounds.tools.Bash)
#   2. Event category sound (e.g., sounds.session_start, sounds.error)
#
# Hook events:
#   SessionStart                    -> session_start
#   SessionEnd                      -> session_end
#   PreToolUse[AskUserQuestion]     -> attention  (+ tool: AskUserQuestion)
#   PreToolUse[*]                   -> tool_start (+ tool: Read, Bash, etc.)
#   PostToolUse (error)             -> error      (+ tool name)
#   PostToolUse (success)           -> tool_end   (+ tool name)
#
# Environment variables:
#   HERALD_PING_DIR   - Override install directory
#   HERALD_EVENT      - Override event category (for testing)
#   HERALD_TOOL       - Override tool name (for testing)
#
# Exit codes:
#   0 = Success (hook passes through, never blocks)

set -e

# --- Resolve paths ---
HERALD_DIR="${HERALD_PING_DIR:-$(cd "$(dirname "$0")" && pwd)}"
CONFIG_FILE="$HERALD_DIR/config.json"

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

# --- Parse hook input and resolve event + tool_name ---
# Outputs two lines: event_category and tool_name
resolve_event() {
    if [ -n "$HERALD_EVENT" ]; then
        echo "$HERALD_EVENT"
        echo "${HERALD_TOOL:-}"
        return
    fi

    local input
    input=$(cat)

    local hook_event="${CLAUDE_HOOK_EVENT:-}"
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

    if [ -z "$hook_event" ]; then
        # Infer hook type from input structure
        if [ -n "$tool_name" ]; then
            local is_error
            is_error=$(echo "$input" | jq -r '.tool_result.is_error // false' 2>/dev/null)
            local exit_code
            exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // empty' 2>/dev/null)

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
            PreToolUse)
                if [ "$tool_name" = "AskUserQuestion" ]; then
                    echo "attention"
                else
                    echo "tool_start"
                fi
                ;;
            PostToolUse)   echo "tool_end" ;;
            *)             echo "tool_end" ;;
        esac
    fi

    echo "$tool_name"
}

# Read both event and tool_name
read_output=$(resolve_event)
event=$(echo "$read_output" | head -1)
tool_name=$(echo "$read_output" | tail -1)

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

# Sound resolution: tool-specific first, then event category fallback
sound_key=""

# 1. Try tool-specific sound (e.g., .sounds.tools.Bash)
if [ -n "$tool_name" ]; then
    tool_count=$(jq -r ".sounds.tools.\"${tool_name}\" | length // 0" "$MANIFEST" 2>/dev/null)
    if [ -n "$tool_count" ] && [ "$tool_count" != "null" ] && [ "$tool_count" -gt 0 ] 2>/dev/null; then
        sound_key="tools.\"${tool_name}\""
    fi
fi

# 2. Fallback to event category (e.g., .sounds.session_start)
if [ -z "$sound_key" ]; then
    cat_count=$(jq -r ".sounds.${event} | length // 0" "$MANIFEST" 2>/dev/null)
    if [ -n "$cat_count" ] && [ "$cat_count" != "null" ] && [ "$cat_count" -gt 0 ] 2>/dev/null; then
        sound_key="${event}"
    fi
fi

if [ -z "$sound_key" ]; then
    exit 0
fi

# Pick a random sound from the array
sound_count=$(jq -r ".sounds.${sound_key} | length" "$MANIFEST")
random_index=$((RANDOM % sound_count))
sound_file=$(jq -r ".sounds.${sound_key}[$random_index]" "$MANIFEST")
sound_path="$PACK_DIR/$sound_file"

if [ ! -f "$sound_path" ]; then
    exit 0
fi

# --- Play sound (non-blocking) ---
if command -v afplay &>/dev/null; then
    afplay_vol=$(echo "$volume * 255" | bc 2>/dev/null | cut -d. -f1)
    afplay_vol="${afplay_vol:-128}"
    afplay -v "$afplay_vol" "$sound_path" &>/dev/null &
elif command -v paplay &>/dev/null; then
    paplay "$sound_path" &>/dev/null &
elif command -v aplay &>/dev/null; then
    aplay -q "$sound_path" &>/dev/null &
fi

exit 0
