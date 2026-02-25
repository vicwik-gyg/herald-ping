#!/bin/bash
# Record a new herald-ping sound pack using your microphone.
#
# Walks you through each event, records your voice, and builds
# the manifest automatically.
#
# Requirements: sox (brew install sox)
#
# Usage:
#   ./record-pack.sh mypack
#   ./record-pack.sh mypack --retake error   # Re-record a single event
#   ./record-pack.sh mypack --add stop       # Add a variant for random selection
#   ./record-pack.sh mypack --add-all        # Add a variant for every event

set -e

HERALD_DIR="$(cd "$(dirname "$0")" && pwd)"
PACK_NAME="${1:?Usage: ./record-pack.sh <pack-name> [--retake <event>] [--add <event>]}"
shift

RETAKE=""
ADD=""
ADD_ALL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --retake)  RETAKE="$2"; shift 2 ;;
        --add)     ADD="$2"; shift 2 ;;
        --add-all) ADD_ALL=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

PACK_DIR="$HERALD_DIR/packs/$PACK_NAME"
SOUNDS_DIR="$PACK_DIR/sounds"
TOOLS_DIR="$SOUNDS_DIR/tools"

# --- Check for sox ---
if ! command -v rec &>/dev/null; then
    echo "This script requires sox for recording."
    echo "Install it with: brew install sox"
    exit 1
fi

mkdir -p "$SOUNDS_DIR" "$TOOLS_DIR"

echo "=============================="
echo "  herald-ping voice recorder"
echo "=============================="
echo ""
echo "Pack: $PACK_NAME"
echo "Output: $PACK_DIR"
echo ""
echo "For each event, you'll see a suggested phrase."
echo "Press ENTER to start recording, then ENTER again to stop."
echo "Press 's' to skip an event."
echo "Press 'r' to re-record the last one."
echo ""

# --- Recording function ---
record_sound() {
    local label="$1"
    local filename="$2"
    local suggestion="$3"
    local output_path="$4"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $label"
    echo "  Suggestion: \"$suggestion\""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    while true; do
        printf "  [ENTER=record / s=skip / r=re-record]: "
        read -r action

        if [ "$action" = "s" ]; then
            echo "  Skipped."
            echo ""
            return 1
        fi

        if [ "$action" = "r" ] && [ -f "$output_path" ]; then
            echo "  Re-recording..."
        fi

        echo "  🎙  Recording... (press ENTER to stop)"
        # Record with sox: 44.1kHz, mono, trim silence from start/end
        rec -q -c 1 -r 44100 "$output_path" &
        REC_PID=$!

        read -r  # Wait for ENTER
        kill "$REC_PID" 2>/dev/null
        wait "$REC_PID" 2>/dev/null

        # Trim leading/trailing silence
        if [ -f "$output_path" ]; then
            sox "$output_path" "${output_path}.tmp" \
                silence 1 0.1 0.5% reverse \
                silence 1 0.1 0.5% reverse \
                2>/dev/null && mv "${output_path}.tmp" "$output_path"

            # Show duration
            duration=$(sox --i -D "$output_path" 2>/dev/null | cut -d. -f1-2)
            echo "  Saved: ${duration}s"
        fi

        printf "  Keep this? [ENTER=yes / r=redo]: "
        read -r confirm
        if [ "$confirm" != "r" ]; then
            echo ""
            return 0
        fi
        echo "  Redoing..."
    done
}

# --- Event definitions: label, filename, suggestion ---
EVENTS=(
    "session_start|sounds/session_start.wav|At your service."
    "session_end|sounds/session_end.wav|Will that be all?"
    "prompt_start|sounds/prompt_start.wav|Right away."
    "stop|sounds/stop.wav|Work has been completed, sir."
    "attention|sounds/attention.wav|I have a question for you."
    "permission|sounds/permission.wav|I'll need your approval for this."
    "error|sounds/error.wav|Something went wrong."
    "context_warning|sounds/context_warning.wav|Running low on memory."
    "tool_start|sounds/tool_start.wav|Working. (or a short sound)"
    "tool_end|sounds/tool_end.wav|Done. (or a short sound)"
    "subagent_start|sounds/subagent_start.wav|Dispatching an assistant."
    "subagent_stop|sounds/subagent_stop.wav|Assistant has returned."
)

TOOL_EVENTS=(
    "Bash|sounds/tools/bash.wav|Running command."
    "Read|sounds/tools/read.wav|Reading."
    "Write|sounds/tools/write.wav|Writing file."
    "Edit|sounds/tools/edit.wav|Editing."
    "Search (Grep/Glob)|sounds/tools/search.wav|Searching."
    "WebFetch|sounds/tools/web.wav|Fetching."
    "Task|sounds/tools/task.wav|Delegating."
)

# --- Helper: record a variant for an event entry ---
record_variant() {
    local entry="$1"
    IFS='|' read -r label filename suggestion <<< "$entry"
    base_path="$PACK_DIR/${filename%.wav}"
    n=1
    while [ -f "${base_path}_${n}.wav" ]; do
        ((n++))
    done
    variant_path="${base_path}_${n}.wav"
    echo "Adding variant #$((n+1)) for $label"
    record_sound "$label (variant #$((n+1)))" "$(basename "$variant_path")" "$suggestion" "$variant_path" || true
}

# --- Record events ---
if [ "$ADD_ALL" -eq 1 ]; then
    # Add a variant for every event
    echo "=== Adding variants for event sounds ==="
    echo ""
    for entry in "${EVENTS[@]}"; do
        record_variant "$entry"
    done

    echo ""
    echo "=== Adding variants for tool sounds ==="
    echo ""
    for entry in "${TOOL_EVENTS[@]}"; do
        record_variant "$entry"
    done
elif [ -n "$ADD" ]; then
    # Add a variant for a single event
    found=0
    for entry in "${EVENTS[@]}" "${TOOL_EVENTS[@]}"; do
        IFS='|' read -r label filename suggestion <<< "$entry"
        if [ "$label" = "$ADD" ] || [ "$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')" = "$ADD" ]; then
            record_variant "$entry"
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "Event '$ADD' not found."
        exit 1
    fi
elif [ -n "$RETAKE" ]; then
    # Re-record a single event
    found=0
    for entry in "${EVENTS[@]}" "${TOOL_EVENTS[@]}"; do
        IFS='|' read -r label filename suggestion <<< "$entry"
        if [ "$label" = "$RETAKE" ] || [ "$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')" = "$RETAKE" ]; then
            record_sound "$label" "$filename" "$suggestion" "$PACK_DIR/$filename"
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "Event '$RETAKE' not found."
        exit 1
    fi
else
    echo "=== Event sounds ==="
    echo ""
    for entry in "${EVENTS[@]}"; do
        IFS='|' read -r label filename suggestion <<< "$entry"
        record_sound "$label" "$filename" "$suggestion" "$PACK_DIR/$filename" || true
    done

    echo ""
    echo "=== Tool-specific sounds (optional) ==="
    echo "These override tool_start for specific tools."
    echo ""
    for entry in "${TOOL_EVENTS[@]}"; do
        IFS='|' read -r label filename suggestion <<< "$entry"
        record_sound "$label" "$filename" "$suggestion" "$PACK_DIR/$filename" || true
    done
fi

# --- Build manifest from recorded files ---
echo ""
echo "Building manifest..."

# Helper: find all .wav files matching a base name and return as JSON array
build_array() {
    local dir="$1"
    local prefix="$2"
    local base="$3"

    local files=()
    for f in "$dir/${base}".wav "$dir/${base}"_*.wav; do
        [ -f "$f" ] && files+=("${prefix}$(basename "$f")")
    done

    if [ ${#files[@]} -eq 0 ]; then
        echo "null"
    else
        printf '%s\n' "${files[@]}" | jq -R . | jq -s .
    fi
}

manifest=$(jq -n \
    --arg name "$PACK_NAME" \
    --arg desc "Voice-recorded pack" \
    --argjson session_start "$(build_array "$SOUNDS_DIR" "sounds/" "session_start")" \
    --argjson session_end "$(build_array "$SOUNDS_DIR" "sounds/" "session_end")" \
    --argjson prompt_start "$(build_array "$SOUNDS_DIR" "sounds/" "prompt_start")" \
    --argjson stop "$(build_array "$SOUNDS_DIR" "sounds/" "stop")" \
    --argjson attention "$(build_array "$SOUNDS_DIR" "sounds/" "attention")" \
    --argjson permission "$(build_array "$SOUNDS_DIR" "sounds/" "permission")" \
    --argjson error "$(build_array "$SOUNDS_DIR" "sounds/" "error")" \
    --argjson context_warning "$(build_array "$SOUNDS_DIR" "sounds/" "context_warning")" \
    --argjson tool_start "$(build_array "$SOUNDS_DIR" "sounds/" "tool_start")" \
    --argjson tool_end "$(build_array "$SOUNDS_DIR" "sounds/" "tool_end")" \
    --argjson subagent_start "$(build_array "$SOUNDS_DIR" "sounds/" "subagent_start")" \
    --argjson subagent_stop "$(build_array "$SOUNDS_DIR" "sounds/" "subagent_stop")" \
    --argjson bash "$(build_array "$TOOLS_DIR" "sounds/tools/" "bash")" \
    --argjson read "$(build_array "$TOOLS_DIR" "sounds/tools/" "read")" \
    --argjson write "$(build_array "$TOOLS_DIR" "sounds/tools/" "write")" \
    --argjson edit "$(build_array "$TOOLS_DIR" "sounds/tools/" "edit")" \
    --argjson search "$(build_array "$TOOLS_DIR" "sounds/tools/" "search")" \
    --argjson web "$(build_array "$TOOLS_DIR" "sounds/tools/" "web")" \
    --argjson task "$(build_array "$TOOLS_DIR" "sounds/tools/" "task")" \
    '{
        name: $name,
        description: $desc,
        sounds: (
            {}
            + (if $session_start != null then {session_start: $session_start} else {} end)
            + (if $session_end != null then {session_end: $session_end} else {} end)
            + (if $prompt_start != null then {prompt_start: $prompt_start} else {} end)
            + (if $stop != null then {stop: $stop} else {} end)
            + (if $attention != null then {attention: $attention} else {} end)
            + (if $permission != null then {permission: $permission} else {} end)
            + (if $error != null then {error: $error} else {} end)
            + (if $context_warning != null then {context_warning: $context_warning} else {} end)
            + (if $tool_start != null then {tool_start: $tool_start} else {} end)
            + (if $tool_end != null then {tool_end: $tool_end} else {} end)
            + (if $subagent_start != null then {subagent_start: $subagent_start} else {} end)
            + (if $subagent_stop != null then {subagent_stop: $subagent_stop} else {} end)
            + {tools: (
                {}
                + (if $bash != null then {Bash: $bash} else {} end)
                + (if $read != null then {Read: $read} else {} end)
                + (if $write != null then {Write: $write} else {} end)
                + (if $edit != null then {Edit: $edit} else {} end)
                + (if $search != null then {Grep: $search, Glob: $search} else {} end)
                + (if $web != null then {WebFetch: $web} else {} end)
                + (if $task != null then {Task: $task} else {} end)
            )}
        )
    }')

echo "$manifest" > "$PACK_DIR/manifest.json"

echo ""
echo "Pack '$PACK_NAME' created at $PACK_DIR"
echo ""
echo "To activate:"
echo "  jq '.active_pack = \"$PACK_NAME\"' $HERALD_DIR/config.json > tmp.json && mv tmp.json $HERALD_DIR/config.json"
echo ""
echo "To re-record a single event:"
echo "  ./record-pack.sh $PACK_NAME --retake stop"
