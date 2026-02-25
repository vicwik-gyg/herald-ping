# herald-ping

Local sound notifications for Claude Code. No external dependencies, no network calls, no telemetry.

Plays audio cues when your AI agent needs attention, hits an error, finishes work, or uses a specific tool.

## Install

```bash
git clone <this-repo> ~/git/herald-ping
cd ~/git/herald-ping
./install.sh
```

This will:
1. Generate default sounds using macOS TTS (`say` command)
2. Register hooks in `~/.claude/settings.json`

Restart Claude Code for hooks to take effect.

### Options

```bash
./install.sh --voice Samantha    # Use a different macOS voice
./install.sh --uninstall         # Remove hooks
```

## How it works

herald-ping registers as a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks). When Claude Code fires an event, `herald.sh` resolves the right sound and plays it.

### Sound resolution

1. **Tool-specific** — if the manifest has `sounds.tools.Bash`, that plays when Claude runs a Bash command
2. **Event category fallback** — falls back to `sounds.tool_start`, `sounds.error`, etc.

If a sound is already playing, new sounds are skipped. Phrases always play to completion without overlap.

### Event mapping

| Claude Code Hook | Category | Default | Description |
|---|---|---|---|
| `SessionStart` | `session_start` | ON | Session begins |
| `SessionEnd` | `session_end` | ON | Session ends |
| `UserPromptSubmit` | `prompt_start` | OFF | You sent a prompt, work begins |
| `Stop` | `stop` | ON | Claude finished, waiting for you |
| `Notification` | `permission` | ON | Claude needs tool approval |
| `PreToolUse[AskUserQuestion]` | `attention` | ON | Claude asks a question |
| `PostToolUseFailure` | `error` | ON | A tool call failed |
| `PreCompact` | `context_warning` | ON | Context window full |
| `PreToolUse` | `tool_start` | OFF | Before any tool call |
| `PostToolUse` | `tool_end` | OFF | Tool completed |
| `SubagentStart` | `subagent_start` | OFF | Spawned a subagent |
| `SubagentStop` | `subagent_stop` | OFF | Subagent returned |

Tool-specific sounds (Bash, Read, Write, Edit, Grep, Glob, WebFetch, Task) override `tool_start` when defined in the manifest.

## Configuration

Edit `config.json`:

```json
{
  "enabled": true,
  "volume": 0.5,
  "active_pack": "default",
  "events": {
    "session_start": true,
    "session_end": true,
    "prompt_start": false,
    "permission": true,
    "attention": true,
    "tool_start": false,
    "tool_end": false,
    "error": true,
    "stop": true,
    "context_warning": true,
    "subagent_start": false,
    "subagent_stop": false
  }
}
```

- **volume** — 0.0 to 1.0
- **active_pack** — Name of the sound pack directory under `packs/`
- **events** — Toggle categories on/off. Tool-specific sounds require their parent category enabled (e.g., `Bash` needs `tool_start: true`)

### Switch the active pack

```bash
jq '.active_pack = "my-pack"' config.json > tmp.json && mv tmp.json config.json
```

## Sound packs

A pack is a directory under `packs/` containing a `manifest.json` and audio files. You only need to include sounds for events you care about — missing events are silently skipped.

### Pack structure

```
packs/my-pack/
├── manifest.json
└── sounds/
    ├── session_start.wav
    ├── stop.wav
    ├── error.wav
    └── tools/
        ├── bash.wav
        └── read.wav
```

### manifest.json

```json
{
  "name": "my-pack",
  "description": "My custom pack",
  "sounds": {
    "session_start": ["sounds/session_start.wav"],
    "session_end": ["sounds/session_end.wav"],
    "prompt_start": ["sounds/prompt_start.wav"],
    "stop": ["sounds/stop.wav", "sounds/stop_alt.wav"],
    "attention": ["sounds/attention.wav"],
    "permission": ["sounds/permission.wav"],
    "error": ["sounds/error.wav"],
    "context_warning": ["sounds/context_warning.wav"],
    "tool_start": ["sounds/tool_start.wav"],
    "tool_end": ["sounds/tool_end.wav"],
    "subagent_start": ["sounds/subagent_start.wav"],
    "subagent_stop": ["sounds/subagent_stop.wav"],
    "tools": {
      "Bash": ["sounds/tools/bash.wav"],
      "Read": ["sounds/tools/read.wav"],
      "Write": ["sounds/tools/write.wav"],
      "Edit": ["sounds/tools/edit.wav"],
      "Grep": ["sounds/tools/search.wav"],
      "Glob": ["sounds/tools/search.wav"],
      "WebFetch": ["sounds/tools/web.wav"],
      "Task": ["sounds/tools/task.wav"]
    }
  }
}
```

Multiple files per event = one picked at random each time.

---

## Creating packs

### Method 1: Record with your microphone

Record your own voice lines for each event. Requires `sox` (`brew install sox`).

```bash
# Record a full pack (walks through each event interactively)
./record-pack.sh my-pack

# Re-record a single event
./record-pack.sh my-pack --retake stop
```

The script:
- Shows each event with a suggested phrase
- Press ENTER to start recording, ENTER to stop
- Auto-trims silence from start and end
- Lets you redo or skip any event
- Builds the manifest automatically

### Method 2: Add audio files manually

Use any `.wav`, `.aiff`, or `.mp3` files from any source — game clips, sound libraries, recordings from another app, etc.

**Step 1: Create the pack directory**

```bash
mkdir -p packs/my-pack/sounds/tools
```

**Step 2: Add your audio files**

Copy or move files into the pack. File names don't matter — the manifest maps them.

```bash
cp ~/Downloads/hello.wav packs/my-pack/sounds/
cp ~/Downloads/ding.mp3 packs/my-pack/sounds/
cp ~/Downloads/keyboard-clack.wav packs/my-pack/sounds/tools/
```

**Step 3: Create the manifest**

Create `packs/my-pack/manifest.json` mapping events to your files:

```json
{
  "name": "my-pack",
  "sounds": {
    "stop": ["sounds/ding.mp3"],
    "session_start": ["sounds/hello.wav"],
    "tools": {
      "Bash": ["sounds/tools/keyboard-clack.wav"]
    }
  }
}
```

Only include events you have sounds for. Everything else is silently skipped.

**Step 4: Activate the pack**

```bash
jq '.active_pack = "my-pack"' config.json > tmp.json && mv tmp.json config.json
```

**Adding more sounds later:**

1. Drop new files into the pack's `sounds/` directory
2. Add them to `manifest.json`
3. Changes take effect on the next event (no restart needed)

**Multiple variants per event:**

List multiple files for random selection:

```json
"stop": ["sounds/done1.wav", "sounds/done2.wav", "sounds/done3.wav"]
```

### Method 3: Generate with TTS

Use macOS text-to-speech to generate voice lines from text phrases.

```bash
# Interactive — prompts for phrases per event
./create-pack.sh my-pack --voice Samantha

# From a template file
./create-pack.sh glados --from templates/glados.json
```

**Available voices:** run `say -v '?'` to list all macOS voices.

**Template format** (see `templates/` for full examples):

```json
{
  "voice": "Samantha",
  "phrases": {
    "session_start": ["Hello."],
    "stop": ["All done.", "Finished."],
    "error": ["Something went wrong."],
    "tools": {
      "Bash": ["Running command."],
      "Read": ["Reading file."]
    }
  }
}
```

---

## Uninstall

```bash
./uninstall.sh
```

Removes hooks from Claude Code settings. Sound files and config are left in place for reinstall.

To fully remove:
```bash
./uninstall.sh
rm -rf ~/git/herald-ping
```

## Supported platforms

- **macOS** — `afplay` for playback, `say` for TTS, `sox` for recording
- **Linux** — `paplay` (PulseAudio) or `aplay` (ALSA) for playback

## Project structure

```
herald-ping/
├── herald.sh                   # Main hook script (event router + player)
├── install.sh                  # Registers hooks in Claude Code settings
├── uninstall.sh                # Removes hooks from settings
├── record-pack.sh              # Record voice packs via microphone (requires sox)
├── create-pack.sh              # Generate TTS packs (interactive or from template)
├── config.json                 # User configuration (volume, active pack, event toggles)
├── templates/                  # Example TTS templates
│   ├── glados.json
│   └── peon.json
└── packs/
    └── default/
        ├── manifest.json       # Sound mapping (events + tool-specific)
        ├── generate.sh         # TTS generator for default pack
        └── sounds/             # Audio files (gitignored)
            ├── session_start.aiff
            ├── stop.aiff
            ├── error.aiff
            └── tools/
                ├── bash.aiff
                └── ...
```
