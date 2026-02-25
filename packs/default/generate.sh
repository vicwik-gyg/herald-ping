#!/bin/bash
# Generate default TTS sound files using macOS 'say' command.
# Run this once after install to create the default sound pack.
# Replace these files with custom sounds anytime.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOUNDS_DIR="$SCRIPT_DIR/sounds"
TOOLS_DIR="$SOUNDS_DIR/tools"
mkdir -p "$SOUNDS_DIR" "$TOOLS_DIR"

VOICE="${1:-Daniel}"

echo "Generating default sounds with voice: $VOICE"

# --- Session lifecycle ---
say -v "$VOICE" -o "$SOUNDS_DIR/session_start.aiff" "At your service."
say -v "$VOICE" -o "$SOUNDS_DIR/session_end.aiff" "Will that be all?"
say -v "$VOICE" -o "$SOUNDS_DIR/prompt_start.aiff" "Right away."
say -v "$VOICE" -o "$SOUNDS_DIR/stop.aiff" "I've finished. Over to you."

# --- Attention and permissions ---
say -v "$VOICE" -o "$SOUNDS_DIR/attention.aiff" "Pardon the interruption."
say -v "$VOICE" -o "$SOUNDS_DIR/permission.aiff" "I'll need your approval for this."

# --- Errors and warnings ---
say -v "$VOICE" -o "$SOUNDS_DIR/error.aiff" "I'm terribly sorry, something went wrong."
say -v "$VOICE" -o "$SOUNDS_DIR/context_warning.aiff" "Running low on memory. Compacting context."

# --- Tool lifecycle ---
say -v "$VOICE" -o "$SOUNDS_DIR/tool_start.aiff" "Working."
say -v "$VOICE" -o "$SOUNDS_DIR/tool_end.aiff" "Done."

# --- Subagents ---
say -v "$VOICE" -o "$SOUNDS_DIR/subagent_start.aiff" "Dispatching an assistant."
say -v "$VOICE" -o "$SOUNDS_DIR/subagent_stop.aiff" "Assistant has returned."

# --- Tool-specific sounds ---
say -v "$VOICE" -o "$TOOLS_DIR/bash.aiff" "Running command."
say -v "$VOICE" -o "$TOOLS_DIR/read.aiff" "Reading."
say -v "$VOICE" -o "$TOOLS_DIR/write.aiff" "Writing file."
say -v "$VOICE" -o "$TOOLS_DIR/edit.aiff" "Editing."
say -v "$VOICE" -o "$TOOLS_DIR/search.aiff" "Searching."
say -v "$VOICE" -o "$TOOLS_DIR/web.aiff" "Fetching."
say -v "$VOICE" -o "$TOOLS_DIR/task.aiff" "Delegating."

echo "Default sounds generated in $SOUNDS_DIR"
