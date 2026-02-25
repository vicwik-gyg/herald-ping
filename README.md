# herald-ping

Local sound notifications for Claude Code. No external dependencies, no network calls, no telemetry.

Plays short audio cues when your AI agent needs attention, hits an error, or uses a specific tool.

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

herald-ping registers as a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks). When Claude Code fires an event, `herald.sh` resolves the right sound and plays it.

### Sound resolution order

1. **Tool-specific** — if the manifest has `sounds.tools.Bash`, that plays when Claude runs a Bash command
2. **Event category** — falls back to `sounds.tool_start`, `sounds.error`, etc.

### Event mapping

| Claude Code Event | Category | Default | Tool-specific available |
|---|---|---|---|
| `SessionStart` | `session_start` | ON | - |
| `SessionEnd` | `session_end` | ON | - |
| `PreToolUse[AskUserQuestion]` | `attention` | ON | yes |
| `PostToolUse` (error) | `error` | ON | yes |
| `PreToolUse` (any) | `tool_start` | OFF | yes (Bash, Read, Write, Edit, Grep, Glob, WebFetch, Task) |
| `PostToolUse` (success) | `tool_end` | OFF | yes |

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

- **volume** — 0.0 to 1.0
- **active_pack** — Name of the sound pack directory in `packs/`
- **events** — Toggle categories on/off. Tool-specific sounds fire when their parent category is enabled (e.g., `Bash` sounds need `tool_start: true`)

## Sound packs

### Creating a pack with TTS

```bash
# Interactive — prompts for phrases per tool
./create-pack.sh my-pack --voice Samantha

# From a template file
./create-pack.sh glados --from templates/glados.json
```

See `templates/` for examples (GLaDOS, Peon).

### Template format

```json
{
  "voice": "Samantha",
  "phrases": {
    "session_start": ["Oh, it's you."],
    "error": ["Well, that was a spectacular failure."],
    "tools": {
      "Bash": ["Running your little command.", "Executing."],
      "Read": ["Let me read that for you."],
      "Write": ["Writing to disk. How permanent."],
      "Edit": ["Making modifications."],
      "Grep": ["Searching. Like a needle in a haystack."],
      "WebFetch": ["Reaching out to the internet."],
      "Task": ["Delegating to a subagent."]
    }
  }
}
```

Multiple phrases per event = random selection each time.

### Using real sound files

1. Create the pack directory: `mkdir -p packs/my-pack/sounds/tools`
2. Drop `.wav`/`.aiff`/`.mp3` files in
3. Write a `manifest.json`:

```json
{
  "name": "my-pack",
  "sounds": {
    "session_start": ["sounds/hello.wav"],
    "error": ["sounds/oops.wav"],
    "tools": {
      "Bash": ["sounds/tools/bash1.wav", "sounds/tools/bash2.wav"],
      "Read": ["sounds/tools/read.wav"]
    }
  }
}
```

4. Set `"active_pack": "my-pack"` in `config.json`

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

- **macOS** — `afplay` (built-in)
- **Linux** — `paplay` (PulseAudio) or `aplay` (ALSA) fallback

## Project structure

```
herald-ping/
├── herald.sh                   # Main hook script (event router + player)
├── install.sh                  # Registers hooks in Claude Code
├── uninstall.sh                # Removes hooks
├── create-pack.sh              # Pack creator (interactive or from template)
├── config.json                 # User configuration
├── templates/                  # Example pack templates
│   ├── glados.json
│   └── peon.json
├── packs/
│   └── default/
│       ├── manifest.json       # Sound mapping (events + tools)
│       ├── generate.sh         # TTS generator for default pack
│       └── sounds/             # Generated .aiff files (gitignored)
│           ├── session_start.aiff
│           ├── error.aiff
│           └── tools/
│               ├── bash.aiff
│               ├── read.aiff
│               └── ...
└── README.md
```
