#!/bin/bash
# Create a new herald-ping sound pack with TTS-generated sounds.
#
# Usage:
#   ./create-pack.sh glados              # Interactive - prompts for phrases
#   ./create-pack.sh glados --voice Samantha  # Specify macOS voice
#   ./create-pack.sh glados --from template.json  # Load phrases from file
#
# Template file format (JSON):
#   {
#     "voice": "Samantha",
#     "phrases": {
#       "session_start": ["Hello again."],
#       "session_end": ["Goodbye."],
#       "attention": ["I need you."],
#       "error": ["That was a mistake."],
#       "tools": {
#         "Bash": ["Executing."],
#         "Read": ["Let me see."],
#         "Write": ["Writing now."],
#         "Edit": ["Modifying."],
#         "Grep": ["Searching."],
#         "Glob": ["Looking."],
#         "WebFetch": ["Fetching."],
#         "Task": ["Delegating."]
#       }
#     }
#   }

set -e

HERALD_DIR="$(cd "$(dirname "$0")" && pwd)"
PACK_NAME="${1:?Usage: ./create-pack.sh <pack-name> [--voice Voice] [--from template.json]}"
shift

VOICE="Daniel"
TEMPLATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --voice) VOICE="$2"; shift 2 ;;
        --from)  TEMPLATE="$2"; shift 2 ;;
        *)       echo "Unknown option: $1"; exit 1 ;;
    esac
done

PACK_DIR="$HERALD_DIR/packs/$PACK_NAME"
SOUNDS_DIR="$PACK_DIR/sounds"
TOOLS_DIR="$SOUNDS_DIR/tools"

if [ -d "$PACK_DIR" ]; then
    echo "Pack '$PACK_NAME' already exists at $PACK_DIR"
    echo "Delete it first if you want to recreate: rm -rf $PACK_DIR"
    exit 1
fi

mkdir -p "$SOUNDS_DIR" "$TOOLS_DIR"

echo "Creating pack: $PACK_NAME"
echo "Voice: $VOICE"
echo ""

# --- Load or prompt for phrases ---
if [ -n "$TEMPLATE" ] && [ -f "$TEMPLATE" ]; then
    echo "Loading phrases from $TEMPLATE"
    VOICE=$(jq -r '.voice // "'"$VOICE"'"' "$TEMPLATE")

    generate_from_template() {
        local category="$1"
        local output_file="$2"
        local phrases
        phrases=$(jq -r ".phrases.${category} // [] | .[]" "$TEMPLATE" 2>/dev/null)

        if [ -z "$phrases" ]; then
            return
        fi

        local i=0
        while IFS= read -r phrase; do
            if [ $i -eq 0 ]; then
                say -v "$VOICE" -o "$output_file" "$phrase"
            else
                local base="${output_file%.*}"
                local ext="${output_file##*.}"
                say -v "$VOICE" -o "${base}_${i}.${ext}" "$phrase"
            fi
            ((i++))
        done <<< "$phrases"
    }

    generate_tool_from_template() {
        local tool_name="$1"
        local output_file="$2"
        local phrases
        phrases=$(jq -r ".phrases.tools.\"${tool_name}\" // [] | .[]" "$TEMPLATE" 2>/dev/null)

        if [ -z "$phrases" ]; then
            return
        fi

        local i=0
        while IFS= read -r phrase; do
            if [ $i -eq 0 ]; then
                say -v "$VOICE" -o "$output_file" "$phrase"
            else
                local base="${output_file%.*}"
                local ext="${output_file##*.}"
                say -v "$VOICE" -o "${base}_${i}.${ext}" "$phrase"
            fi
            ((i++))
        done <<< "$phrases"
    }

    echo "Generating sounds..."

    # Event categories
    for event in session_start session_end attention error tool_start tool_end; do
        generate_from_template "$event" "$SOUNDS_DIR/${event}.aiff"
    done

    # Tool-specific
    for tool in Bash Read Write Edit Grep Glob WebFetch Task; do
        tool_lower=$(echo "$tool" | tr '[:upper:]' '[:lower:]')
        generate_tool_from_template "$tool" "$TOOLS_DIR/${tool_lower}.aiff"
    done

else
    # Interactive mode
    echo "Enter phrases for each event (press Enter to skip)."
    echo "Separate multiple phrases with | for random selection."
    echo ""

    prompt_and_generate() {
        local label="$1"
        local output_file="$2"
        local default_phrase="$3"

        printf "  %-20s [%s]: " "$label" "$default_phrase"
        read -r input
        input="${input:-$default_phrase}"

        if [ -z "$input" ]; then
            return
        fi

        # Split on | for multiple phrases
        IFS='|' read -ra phrases <<< "$input"
        local i=0
        for phrase in "${phrases[@]}"; do
            phrase=$(echo "$phrase" | xargs) # trim whitespace
            if [ -z "$phrase" ]; then continue; fi
            if [ $i -eq 0 ]; then
                say -v "$VOICE" -o "$output_file" "$phrase"
            else
                local base="${output_file%.*}"
                local ext="${output_file##*.}"
                say -v "$VOICE" -o "${base}_${i}.${ext}" "$phrase"
            fi
            ((i++))
        done
    }

    echo "Event sounds:"
    prompt_and_generate "session_start" "$SOUNDS_DIR/session_start.aiff" "At your service."
    prompt_and_generate "session_end"   "$SOUNDS_DIR/session_end.aiff"   "Will that be all?"
    prompt_and_generate "attention"     "$SOUNDS_DIR/attention.aiff"     "Pardon the interruption."
    prompt_and_generate "error"         "$SOUNDS_DIR/error.aiff"         "Something went wrong."
    echo ""
    echo "Tool sounds (what to say when Claude uses each tool):"
    prompt_and_generate "Bash"          "$TOOLS_DIR/bash.aiff"           "Running command."
    prompt_and_generate "Read"          "$TOOLS_DIR/read.aiff"           "Reading."
    prompt_and_generate "Write"         "$TOOLS_DIR/write.aiff"          "Writing file."
    prompt_and_generate "Edit"          "$TOOLS_DIR/edit.aiff"           "Editing."
    prompt_and_generate "Grep/Glob"     "$TOOLS_DIR/search.aiff"         "Searching."
    prompt_and_generate "WebFetch"      "$TOOLS_DIR/web.aiff"            "Fetching."
    prompt_and_generate "Task"          "$TOOLS_DIR/task.aiff"           "Delegating."
fi

# --- Build manifest.json ---
# Scan what was actually generated and build the manifest
build_sound_array() {
    local dir="$1"
    local prefix="$2"
    local base="$3"

    local files=()
    for f in "$dir/${base}".aiff "$dir/${base}"_*.aiff; do
        [ -f "$f" ] && files+=("${prefix}$(basename "$f")")
    done

    if [ ${#files[@]} -eq 0 ]; then
        echo "null"
    else
        printf '%s\n' "${files[@]}" | jq -R . | jq -s .
    fi
}

# Build the manifest dynamically from generated files
manifest=$(jq -n \
    --arg name "$PACK_NAME" \
    --arg desc "Custom TTS pack ($VOICE voice)" \
    --argjson session_start "$(build_sound_array "$SOUNDS_DIR" "sounds/" "session_start")" \
    --argjson session_end "$(build_sound_array "$SOUNDS_DIR" "sounds/" "session_end")" \
    --argjson attention "$(build_sound_array "$SOUNDS_DIR" "sounds/" "attention")" \
    --argjson error "$(build_sound_array "$SOUNDS_DIR" "sounds/" "error")" \
    --argjson tool_start "$(build_sound_array "$SOUNDS_DIR" "sounds/" "tool_start")" \
    --argjson tool_end "$(build_sound_array "$SOUNDS_DIR" "sounds/" "tool_end")" \
    --argjson bash "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "bash")" \
    --argjson read "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "read")" \
    --argjson write "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "write")" \
    --argjson edit "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "edit")" \
    --argjson search "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "search")" \
    --argjson web "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "web")" \
    --argjson task "$(build_sound_array "$TOOLS_DIR" "sounds/tools/" "task")" \
    '{
        name: $name,
        description: $desc,
        sounds: (
            {}
            + (if $session_start != null then {session_start: $session_start} else {} end)
            + (if $session_end != null then {session_end: $session_end} else {} end)
            + (if $attention != null then {attention: $attention} else {} end)
            + (if $error != null then {error: $error} else {} end)
            + (if $tool_start != null then {tool_start: $tool_start} else {} end)
            + (if $tool_end != null then {tool_end: $tool_end} else {} end)
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
echo "To activate: edit config.json and set \"active_pack\": \"$PACK_NAME\""
echo "Or run: jq '.active_pack = \"$PACK_NAME\"' $HERALD_DIR/config.json > tmp.json && mv tmp.json $HERALD_DIR/config.json"
