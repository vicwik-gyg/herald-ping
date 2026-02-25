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

# Event category sounds
say -v "$VOICE" -o "$SOUNDS_DIR/session_start.aiff" "At your service."
say -v "$VOICE" -o "$SOUNDS_DIR/session_end.aiff" "Will that be all?"
say -v "$VOICE" -o "$SOUNDS_DIR/attention.aiff" "Pardon the interruption."
say -v "$VOICE" -o "$SOUNDS_DIR/error.aiff" "I'm terribly sorry, something went wrong."
say -v "$VOICE" -o "$SOUNDS_DIR/tool_start.aiff" "Right away."
say -v "$VOICE" -o "$SOUNDS_DIR/tool_end.aiff" "Done."

# Tool-specific sounds
say -v "$VOICE" -o "$TOOLS_DIR/bash.aiff" "Running command."
say -v "$VOICE" -o "$TOOLS_DIR/read.aiff" "Reading."
say -v "$VOICE" -o "$TOOLS_DIR/write.aiff" "Writing file."
say -v "$VOICE" -o "$TOOLS_DIR/edit.aiff" "Editing."
say -v "$VOICE" -o "$TOOLS_DIR/search.aiff" "Searching."
say -v "$VOICE" -o "$TOOLS_DIR/web.aiff" "Fetching."
say -v "$VOICE" -o "$TOOLS_DIR/task.aiff" "Delegating."

echo "Default sounds generated in $SOUNDS_DIR"
