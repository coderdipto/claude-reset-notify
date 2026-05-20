# claude-reset-notify

A small macOS background daemon that watches your Claude Code limit and pushes a notification to your phone (via [ntfy.sh](https://ntfy.sh)) the moment it resets.

It runs in the background, polls quietly, and notifies you **once** when your limit is hit and **once again** when it clears — no spam, no babysitting.

---

## Why

When Claude Code hits its 5-hour or weekly limit, you usually either:

- Refresh the terminal every few minutes hoping it's back, or
- Just walk away and forget about it for an hour

This tool removes both. It sits in the background, pings you on your phone when the limit clears, and otherwise stays out of your way.

---

## What it does

- Polls `claude --print "ok"` every **10 minutes** when your account is available, every **5 minutes** when limited
- Sends **one** push notification when the limit is hit
- Sends **one more** push notification when the limit clears
- Notification titles include a **device label** (e.g. `[Work iMac]`) so you can share the same ntfy topic across multiple Macs
- Runs via macOS `launchd` — auto-starts on login, auto-restarts on crash
- Holds state silently on unexpected errors instead of misfiring notifications

---

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
```

The installer will:

1. Verify you're on macOS with the required tools
2. Download the `claude-watch` script to `~/bin/claude-watch`
3. Prompt for an **ntfy topic name** (your private push channel — pick something hard to guess)
4. Prompt for a **device label** (defaults to your Mac's name)
5. Register a LaunchAgent so the daemon starts on every login
6. Send a test notification

### Then on your phone

1. Install the **ntfy** app — [App Store](https://apps.apple.com/us/app/ntfy/id1625396347) / [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
2. Subscribe to the topic name you chose during install

You're done. Next time your Claude Code limit hits, you'll get a push. Next time it clears, you'll get another.

---

## Using the same topic on multiple Macs

Run the same installer on each Mac with the **same topic** but a **different device label**. Notifications will be tagged so you can tell which machine fired the alert.

To skip prompts on subsequent Macs:

```bash
CLAUDE_WATCH_TOPIC="your-existing-topic" \
CLAUDE_WATCH_DEVICE="Work iMac" \
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
```

Notifications will look like:

> **[Sudipto's MacBook Pro] Claude Code limit reached**
> Your Claude Code limit is currently exhausted. I'll let you know when it resets.

> **[Work iMac] Claude Code limit cleared**
> Your Claude Code session is available again. Time to resume work.

---

## Commands

```bash
claude-watch status              # show daemon + Claude state, last check, device label
claude-watch start               # start the daemon
claude-watch stop                # stop the daemon (stays stopped until you start it again)
claude-watch restart             # restart (use after config changes)
claude-watch logs                # last 50 log lines
claude-watch logs -f             # follow logs live
claude-watch config              # show current config
claude-watch config <key> <val>  # change a setting
claude-watch test-notify         # send a test push
claude-watch uninstall           # remove the daemon, plist, and (optionally) config
claude-watch help                # full help
```

---

## Configurable settings

Edit any setting with `claude-watch config <key> <value>`, then `claude-watch restart`.

| Key | Default | Meaning |
|---|---|---|
| `ntfy_topic` | (you set this) | Your private ntfy topic name |
| `ntfy_server` | `https://ntfy.sh` | ntfy server URL — change if you self-host |
| `device_name` | your Mac's `ComputerName` | Label prepended to every notification title |
| `interval_available_seconds` | `600` (10 min) | Poll interval when Claude is available |
| `interval_limited_seconds` | `300` (5 min) | Poll interval when Claude is limited |
| `test_prompt` | `ok` | What to send to `claude --print` when polling |

Example:

```bash
claude-watch config interval_limited_seconds 180   # poll every 3 min when limited
claude-watch config device_name "My Work Mac"
claude-watch restart
```

---

## Notification reference

You'll see exactly four kinds of pushes:

| When | Title | Priority |
|---|---|---|
| Install completed | `[device] claude-watch installed` | default |
| `claude-watch test-notify` | `[device] claude-watch test` | default |
| Limit just hit | `[device] Claude Code limit reached` | default |
| Limit just cleared | `[device] Claude Code limit cleared` | **high** (breaks through DND) |

The "limit cleared" notification is high-priority on purpose — it's the only one you actually need to act on.

---

## How auto-start works

Once installed, the daemon auto-runs whenever you're logged into your Mac:

- **Log in** → starts within seconds (launchd loads the agent on login)
- **Wake from sleep** → was already running, resumes polling on the next tick
- **Reboot** → restarts when you log back in
- **Daemon crashes** → launchd auto-restarts it
- **Mac off / login screen / logged out** → stops; resumes when you're back in
- **You ran `claude-watch stop`** → stays stopped until you `start` or reboot+login

---

## Where things live

```
~/bin/claude-watch                                       # the CLI
~/.claude-watch/config.json                              # settings
~/.claude-watch/state.json                               # current state
~/.claude-watch/watch.log                                # rolling log
~/Library/LaunchAgents/com.sudipto.claude-watch.plist    # launchd config
```

---

## Updating

Re-run the install command — it overwrites the local script with the latest from `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
```

Your existing config and ntfy topic are preserved.

---

## Uninstalling

```bash
claude-watch uninstall
```

Stops the daemon, removes the LaunchAgent and `~/bin/claude-watch`, and asks whether to wipe `~/.claude-watch/` as well.

---

## A note on safety

This is a `curl | bash` installer. If you'd rather inspect it first:

```bash
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh -o /tmp/install.sh
less /tmp/install.sh
bash /tmp/install.sh
```

The installer is also visible in the repo at [`install.sh`](install.sh) and the daemon itself at [`claude-watch`](claude-watch).

---

## Notes

- Each poll uses a tiny amount of Claude Code quota (a handful of tokens). Negligible against subscription limits, but not literally zero.
- The detection works by parsing the limit message from `claude --print`. The exact wording can change between Claude Code versions — if detection ever stops working, open an issue with the output of `claude-watch logs`.
- This is macOS-only. The LaunchAgent and `scutil` calls are Apple-specific.

---

## License

MIT
