# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`claude-watch` is a macOS-only bash daemon that polls `claude --print` to detect Claude Code usage limits and sends push notifications via [ntfy.sh](https://ntfy.sh). It runs as a launchd LaunchAgent.

The repo has two files:
- `claude-watch` — the CLI and daemon (all logic lives here, ~1000 lines of bash)
- `install.sh` — downloads `claude-watch` from GitHub and hands off to `claude-watch install`

## Architecture

### Single-file daemon design

All commands (`install`, `start`, `stop`, `status`, `config`, `logs`, `uninstall`, `run`) are functions inside the same `claude-watch` script. `run` (called by launchd as `claude-watch run`) executes `run_loop`, the main polling loop.

### State machine

The loop maintains a `current_state` variable (`available`, `limited`, `unknown`) and matches on `"$result:$current_state"` pairs to drive transitions. State is persisted to `~/.claude-watch/state.json` so a daemon restart picks up where it left off.

### Sleep-to-reset polling

When limited, the daemon parses a reset epoch from Claude's output (regex in `parse_reset_epoch`, implemented in embedded Python). It then sleeps `(seconds_until_reset + 30)` in one long wait rather than polling every N minutes. The background sleep (`sleep X &; wait $!`) is stored in `SLEEP_PID` so `SIGTERM` can kill it immediately — without this, `claude-watch stop` would block for up to an hour.

### JSON without jq

`json_get` and `json_set` embed Python3 heredocs and communicate via environment variables (`JG_FILE`, `JG_KEY`, etc.) to avoid shell injection from arbitrary values.

### launchd PATH problem

The LaunchAgent plist must have an explicit `PATH` because launchd doesn't inherit the user's shell PATH. `write_plist` auto-detects `claude`'s directory at install time and prepends it.

## Runtime files

| Path | Purpose |
|---|---|
| `~/.claude-watch/config.json` | User settings (topic, device, intervals) |
| `~/.claude-watch/state.json` | Live state (`state`, `reset_epoch`, timestamps) |
| `~/.claude-watch/watch.log` | Rolling log (rotated at 1 MB, tail-truncated to ~500 KB) |
| `~/Library/LaunchAgents/com.sudipto.claude-watch.plist` | launchd agent config |
| `~/bin/claude-watch` | Installed script location |

## Testing changes locally

Since there are no automated tests, verify changes by running the daemon in the foreground:

```bash
# Run the loop directly (foreground, no launchd)
./claude-watch run

# Or install your local copy and use the full lifecycle
./claude-watch install
claude-watch status
claude-watch logs -f
```

To test the limit-detection regex without actually hitting a limit, invoke `check_claude_status` manually or temporarily override `TEST_PROMPT` with a string that triggers the limit pattern:

```bash
claude-watch config test_prompt "hit your session limit resets 2:10am"
claude-watch restart
claude-watch logs -f
```

Reset it after:

```bash
claude-watch config test_prompt ok
claude-watch restart
```

## Key constraints

- **macOS only** — uses `launchctl`, `scutil --get ComputerName`, and `date -r <epoch>` (BSD `date` syntax).
- **No external dependencies** — only `bash`, `python3`, `curl`, and standard macOS tools. No `jq`, no Homebrew packages.
- **The `log()` function writes only to the log file** — launchd already redirects stdout/stderr to the same file, so echoing as well would duplicate lines.
- **Notifications are deduplicated by state transitions** — a "limit reached" push fires only once on the `available → limited` edge, not on every poll while limited.
