# claude-reset-notify

A small macOS background daemon that watches your Claude Code limit and pushes a notification to your phone (via [ntfy.sh](https://ntfy.sh)) the moment it resets.

It runs in the background, polls almost never, and notifies you **once** when your limit is hit and **once again** when it clears — no spam, no babysitting.

---

## Why

When Claude Code hits its 5-hour or weekly limit, you usually either:

- Refresh the terminal every few minutes hoping it's back, or
- Just walk away and forget about it for an hour

This tool removes both. It reads the reset time straight out of Claude's limit message, sleeps until that exact moment, then pings your phone within seconds of the limit clearing.

---

## How it works

When everything is fine, the daemon polls `claude --print "ok"` every **10 minutes** just to confirm you're not silently limited.

When it detects a limit, it parses the reset time from Claude's message (e.g. *"resets 2:10am"*) and goes to sleep until **30 seconds after** that moment. One single check verifies the limit has cleared, and the "limit cleared" push fires immediately.

Across a typical ~hour-long limit cycle, the daemon makes about **three** Claude calls total — not dozens.

If Claude's reset time can't be parsed for any reason, the daemon falls back to polling every 5 minutes as a safety net.

---

## What you get

- One push notification when your limit is hit (with the predicted reset time in the message body)
- One **high-priority** push notification when the limit clears (breaks through Do Not Disturb)
- A `claude-watch status` command that shows the live countdown to reset
- Notifications tagged with a **device label** (e.g. `[Work iMac]`) so you can share the same ntfy topic across multiple Macs
- Runs via macOS `launchd` — auto-starts on login, auto-restarts on crash, survives reboots

---

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
```

The installer will:

1. Verify you're on macOS with the required tools
2. Download the `claude-watch` script to `~/bin/claude-watch`
3. Add `~/bin` to your PATH in `~/.zshrc` if it isn't already
4. Prompt for an **ntfy topic name** (your private push channel — pick something hard to guess)
5. Prompt for a **device label** (defaults to your Mac's name)
6. Register a LaunchAgent so the daemon starts on every login
7. Auto-detect where your `claude` binary lives and bake that path into the LaunchAgent
8. Send a test notification

### Then on your phone

1. Install the **ntfy** app — [App Store](https://apps.apple.com/us/app/ntfy/id1625396347) / [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
2. Subscribe to the topic name you chose during install

You're done. Next time your Claude Code limit hits, you'll get a push. Around the moment it clears, you'll get another.

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

> **[Macbook Air M1] Claude Code limit reached**
> Your Claude Code limit is currently exhausted. I'll let you know when it resets. Expected reset: 2:10 AM.

> **[Work iMac] Claude Code limit cleared**
> Your Claude Code session is available again. Time to resume work.

---

## Commands

```bash
claude-watch status              # daemon + Claude state, reset countdown, device label
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

### Example `status` output (while limited)

```
claude-watch status

claude-watch status
  Daemon:            running
  Claude state:      limited
  Resets at:         2:10 AM (Thu) — in 47m
  Device label:      Macbook Air M1
  Last check:        2026-05-21 01:18:16
  Last notification: 2026-05-21 01:18:16 — [Macbook Air M1] Claude Code limit reached
  Started at:        2026-05-21 01:11:40

  ntfy topic:        sudipto-claude-19560106
  Poll (available):  600s
  Poll (limited):    300s
  Log file:          /Users/you/.claude-watch/watch.log
```

The countdown updates every time you run `status` — it's computed live from the stored reset time.

---

## Configurable settings

Edit any setting with `claude-watch config <key> <value>`, then `claude-watch restart`.

| Key | Default | Meaning |
|---|---|---|
| `ntfy_topic` | (you set this) | Your private ntfy topic name |
| `ntfy_server` | `https://ntfy.sh` | ntfy server URL — change if you self-host |
| `device_name` | your Mac's `ComputerName` | Label prepended to every notification title |
| `interval_available_seconds` | `600` (10 min) | Poll interval when Claude is available |
| `interval_limited_seconds` | `300` (5 min) | Fallback poll interval when limited but no reset time was parseable |
| `test_prompt` | `ok` | What to send to `claude --print` when polling |

Example:

```bash
claude-watch config interval_available_seconds 900   # poll every 15 min when idle
claude-watch config device_name "My Work Mac"
claude-watch restart
```

Note: when limited and a reset time *was* parsed, the daemon ignores `interval_limited_seconds` and sleeps directly to the reset moment. The interval only matters as a safety-net fallback.

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

## Polling behavior in detail

| Situation | Behavior |
|---|---|
| Available | Poll every 10 min |
| Limited, reset time known, before reset | One long sleep until 30 sec past predicted reset, then one verification poll |
| Limited, reset time known, just past reset but still limited | Poll every 60 sec for up to 10 min |
| Limited, reset time predicted but >10 min off | Discard prediction, fall back to 5-min polling |
| Limited, no reset time parsed | Standard 5-min polling (safety net) |

For a typical 1-hour limit cycle, that's about **3 Claude calls total**: one that detects the limit, one verification ~30 sec after the reset, and one to confirm available state going forward.

---

## How auto-start works

Once installed, the daemon auto-runs whenever you're logged into your Mac:

- **Log in** → starts within seconds (launchd loads the agent on login)
- **Wake from sleep** → was already running, resumes its plan on the next tick (if it slept past a reset, it polls immediately)
- **Reboot** → restarts when you log back in
- **Daemon crashes** → launchd auto-restarts it; the new run reads the stored reset time and picks up where the previous one left off
- **Mac off / login screen / logged out** → stops; resumes when you're back in
- **You ran `claude-watch stop`** → stays stopped until you `start` or reboot+login

---

## Where things live

```
~/bin/claude-watch                                       # the CLI
~/.claude-watch/config.json                              # settings
~/.claude-watch/state.json                               # current state (incl. parsed reset time)
~/.claude-watch/watch.log                                # rolling log
~/Library/LaunchAgents/com.sudipto.claude-watch.plist    # launchd config
```

---

## Updating

Re-run the install command — it overwrites the local script with the latest from `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
```

Your existing config, ntfy topic, and device label are preserved.

---

## Uninstalling

```bash
claude-watch uninstall
```

Stops the daemon, removes the LaunchAgent and `~/bin/claude-watch`, and asks whether to wipe `~/.claude-watch/` as well.

---

## Troubleshooting

**`claude-watch status` shows `Claude state: unknown`** for more than a minute. The daemon couldn't find your `claude` binary on its PATH. Re-run `claude-watch install` from a terminal where `which claude` works — the installer auto-detects claude's directory and bakes it into the LaunchAgent.

**`Claude state: unknown` right after install.** Wait ~10 seconds and check again — the first poll runs immediately on daemon start but takes a moment to complete.

**Notifications aren't arriving on your phone.** Run `claude-watch test-notify` to send a manual push. If that arrives but real ones don't, check `claude-watch logs` for state transitions. If the test doesn't arrive, double-check the ntfy topic name matches on both ends and that you've actually subscribed in the ntfy app.

**Daemon won't start.** Check `claude-watch logs | tail -20` and `launchctl list | grep claude-watch`. A non-zero second column in the launchctl output means the daemon is crashing on startup — usually a missing dependency or a malformed config file.

**Detection regex doesn't match a new Claude message format.** The detector recognizes phrases like *"hit your session limit"*, *"limit reached"*, *"rate limit"*, *"resets at..."*. If Claude changes its wording, open an issue with the output of `claude-watch logs | tail -5` and the regex can be updated.

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

## Notes & caveats

- Each Claude poll uses a tiny amount of quota (a handful of tokens). With the v1.5 sleep-to-reset polling, this is ~3 calls per limit cycle — effectively negligible.
- The detection works by parsing the limit message from `claude --print`. The exact wording can change between Claude Code versions — if detection ever stops working, the log will show the actual message so the regex can be updated.
- This is macOS-only. The LaunchAgent setup, `scutil`, and `date -r` syntax are Apple-specific.
- The daemon respects system sleep: `sleep` counts wall-clock time, so a Mac asleep through a predicted reset will simply poll on wake and notify within seconds.

---

## License

MIT
