# herald-ping

Local sound notifications for Claude Code. No external dependencies, no network calls, no telemetry.

Plays short audio cues when your AI agent needs attention, hits an error, or finishes a task.

## Install

```bash
git clone <this-repo> ~/git/herald-ping
cd ~/git/herald-ping
./install.sh
```

This will:
1. Generate default sounds using macOS TTS (`say` command)
2. Register hooks in `~/.claude/settings.json`
3. Restart Claude Code to activate

### Options

```bash
./install.sh --voice Samantha    # Use a different macOS voice
./install.sh --uninstall         # Remove hooks
```

## How it works

herald-ping registers as a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks). When Claude Code fires an event, it runs `herald.sh` which plays the appropriate sound.

| Claude Code Event | Herald Category | Default |
|---|---|---|
| `SessionStart` | `session_start` | ON |
| `SessionEnd` | `session_end` | ON |
| `PreToolUse[AskUserQuestion]` | `attention` | ON |
| `PostToolUse` (error) | `error` | ON |
| `PreToolUse` (any) | `tool_start` | OFF |
| `PostToolUse` (success) | `tool_end` | OFF |

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
    "attention": true,
    "error": true,
    "tool_start": false,
    "tool_end": false
  }
}
```

- **volume** - 0.0 to 1.0
- **active_pack** - Name of the sound pack directory in `packs/`
- **events** - Toggle individual event categories on/off

## Sound packs

A pack is a directory under `packs/` with a `manifest.json` and sound files:

```
packs/my-pack/
├── manifest.json
└── sounds/
    ├── session_start.aiff
    ├── attention.aiff
    └── error.aiff
```

### manifest.json

```json
{
  "name": "my-pack",
  "description": "Custom sound pack",
  "sounds": {
    "session_start": ["sounds/greeting1.aiff", "sounds/greeting2.aiff"],
    "attention": ["sounds/hey.aiff"],
    "error": ["sounds/oops.aiff"]
  }
}
```

Multiple files per event are supported — one is picked at random each time.

### Creating a pack from game sounds

1. Extract `.wav`/`.aiff`/`.mp3` files from a game or sound library
2. Create the pack directory and manifest
3. Set `"active_pack": "my-pack"` in `config.json`

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

- **macOS** - `afplay` (built-in)
- **Linux** - `paplay` (PulseAudio) or `aplay` (ALSA) fallback

## Project structure

```
herald-ping/
├── herald.sh                   # Main hook script
├── install.sh                  # Registers hooks in Claude Code
├── uninstall.sh                # Removes hooks
├── config.json                 # User configuration
├── packs/
│   └── default/
│       ├── manifest.json       # Sound file mapping
│       ├── generate.sh         # TTS generator for default pack
│       └── sounds/             # Generated .aiff files (gitignored)
└── README.md
```
