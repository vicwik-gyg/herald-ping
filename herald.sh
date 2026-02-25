#!/bin/bash
# herald-ping: Local sound notification hook for Claude Code.
#
# Plays context-appropriate sounds when Claude Code events fire.
# Registered for all Claude Code hook events via install.sh.
#
# Sound resolution order (first match wins):
#   1. Tool-specific sound  (e.g., sounds.tools.Bash)
#   2. Event category sound (e.g., sounds.session_start, sounds.error)
#
# Event categories:
#   session_start    SessionStart                     - session begins
#   session_end      SessionEnd                       - session ends
#   prompt_start     UserPromptSubmit                 - user sends a prompt, work begins
#   permission       Notification[permission]         - waiting for permission approval
#   attention        PreToolUse[AskUserQuestion]      - Claude asks the user a question
#   tool_start       PreToolUse[*]                    - before a tool runs (per-tool sounds)
#   tool_end         PostToolUse                      - tool completed successfully
#   error            PostToolUseFailure               - tool failed
#   stop             Stop                             - Claude finished, waiting for input
#   context_warning  PreCompact                       - context window full, compacting
#   subagent_start   SubagentStart                    - spawned a subagent
#   subagent_stop    SubagentStop                     - subagent finished
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

    case "$hook_event" in
        SessionStart)
            echo "session_start"
            ;;
        SessionEnd)
            echo "session_end"
            ;;
        UserPromptSubmit)
            echo "prompt_start"
            ;;
        Notification)
            # Check notification type for permission prompts
            local notif_type
            notif_type=$(echo "$input" | jq -r '.notification_type // empty' 2>/dev/null)
            if [ "$notif_type" = "permission_prompt" ]; then
                echo "permission"
            else
                echo "attention"
            fi
            ;;
        PreToolUse)
            if [ "$tool_name" = "AskUserQuestion" ]; then
                echo "attention"
            else
                echo "tool_start"
            fi
            ;;
        PostToolUse)
            echo "tool_end"
            ;;
        PostToolUseFailure)
            echo "error"
            ;;
        Stop)
            echo "stop"
            ;;
        PreCompact)
            echo "context_warning"
            ;;
        SubagentStart)
            echo "subagent_start"
            ;;
        SubagentStop)
            echo "subagent_stop"
            ;;
        *)
            # Fallback: try to infer from input structure
            if [ -n "$tool_name" ]; then
                local is_error
                is_error=$(echo "$input" | jq -r '.tool_result.is_error // false' 2>/dev/null)
                if [ "$is_error" = "true" ]; then
                    echo "error"
                else
                    echo "tool_end"
                fi
            else
                exit 0
            fi
            ;;
    esac

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

# --- Skip if a sound is already playing ---
PID_FILE="$HERALD_DIR/.sound.pid"
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        # Previous sound still playing -- let it finish, skip this one
        exit 0
    fi
fi

# --- Play sound (non-blocking) ---
if command -v afplay &>/dev/null; then
    afplay_vol=$(echo "$volume * 255" | bc 2>/dev/null | cut -d. -f1)
    afplay_vol="${afplay_vol:-128}"
    afplay -v "$afplay_vol" "$sound_path" &>/dev/null &
    echo $! > "$PID_FILE"
elif command -v paplay &>/dev/null; then
    paplay "$sound_path" &>/dev/null &
    echo $! > "$PID_FILE"
elif command -v aplay &>/dev/null; then
    aplay -q "$sound_path" &>/dev/null &
    echo $! > "$PID_FILE"
fi

exit 0
