# claude-watch

A small macOS background daemon that monitors your Claude Code limit and sends ntfy push notifications when the limit is hit or cleared.

## What it does

- Polls `claude --print "ok"` every **10 minutes** when available, every **5 minutes** when limited
- Sends **exactly one** notification when the limit is hit ("limit reached, I'll tell you when it clears")
- Sends **exactly one** notification when the limit clears ("limit cleared, time to resume")
- Runs in the background via macOS `launchd`, auto-starts on login, auto-restarts on crash
- No notification spam — fires only on state transitions

## Install

1. Save `claude-watch` somewhere (e.g., `~/Downloads/claude-watch`)
2. Make it executable and run install:

```bash
chmod +x ~/Downloads/claude-watch
~/Downloads/claude-watch install
```

The installer will:
- Copy itself to `~/bin/claude-watch`
- Prompt you for an ntfy topic name (pick something hard to guess)
- Write config to `~/.claude-watch/config.json`
- Register a macOS LaunchAgent so it runs on login
- Send a test notification

3. Install the **ntfy** app on your phone (App Store / Play Store)
4. Subscribe to the topic name you chose

That's it. The daemon is now running and will keep running whenever you're logged in.

## Commands

```bash
claude-watch status              # daemon + Claude state
claude-watch start               # start daemon
claude-watch stop                # stop daemon
claude-watch restart             # restart daemon
claude-watch logs                # last 50 log lines
claude-watch logs -f             # follow logs live
claude-watch config              # show current config
claude-watch config interval_available_seconds 900   # change a setting
claude-watch test-notify         # send a test push
claude-watch uninstall           # remove everything
claude-watch help                # full help
```

## Configurable settings

Edit via `claude-watch config <key> <value>`:

| Key | Default | Meaning |
|---|---|---|
| `ntfy_topic` | (you set this) | Your private ntfy topic |
| `ntfy_server` | `https://ntfy.sh` | ntfy server URL |
| `interval_available_seconds` | `600` (10 min) | Poll interval when Claude is available |
| `interval_limited_seconds` | `300` (5 min) | Poll interval when limited |
| `test_prompt` | `ok` | Prompt sent to `claude --print` to test |

Restart the daemon after config changes: `claude-watch restart`

## Where things live

```
~/bin/claude-watch                                  # the CLI itself
~/.claude-watch/config.json                         # settings
~/.claude-watch/state.json                          # current state
~/.claude-watch/watch.log                           # rolling log
~/Library/LaunchAgents/com.sudipto.claude-watch.plist   # launchd config
```

## Notes

- Each poll uses a tiny bit of your Claude quota (a few tokens). Negligible against subscription limits.
- The daemon runs only when you're logged in. If you log out or shut down, it stops; when you log back in, launchd auto-restarts it.
- If `claude` returns an unexpected error (neither success nor a recognized limit message), the daemon holds its current state and logs the error rather than spamming you.
