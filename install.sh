#!/usr/bin/env bash
# claude-watch installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/coderdipto/claude-reset-notify/main/install.sh | bash
#
# Optional env vars:
#   CLAUDE_WATCH_REPO    override repo (default: coderdipto/claude-reset-notify)
#   CLAUDE_WATCH_BRANCH  override branch (default: main)
#   CLAUDE_WATCH_TOPIC   skip ntfy topic prompt by passing it here
#   CLAUDE_WATCH_DEVICE  skip device name prompt by passing it here

set -euo pipefail

REPO="${CLAUDE_WATCH_REPO:-coderdipto/claude-reset-notify}"
BRANCH="${CLAUDE_WATCH_BRANCH:-main}"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/claude-watch"

INSTALL_DIR="$HOME/bin"
INSTALL_PATH="$INSTALL_DIR/claude-watch"

# Colors
if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""
fi

info()  { echo "${C_BLUE}ℹ${C_RESET}  $*"; }
ok()    { echo "${C_GREEN}✓${C_RESET}  $*"; }
warn()  { echo "${C_YELLOW}⚠${C_RESET}  $*"; }
err()   { echo "${C_RED}✗${C_RESET}  $*" >&2; }

# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "${C_BOLD}claude-watch installer${C_RESET}"
echo ""

# Platform check
if [ "$(uname -s)" != "Darwin" ]; then
    err "claude-watch only supports macOS (this is $(uname -s))."
    exit 1
fi
ok "macOS detected"

# Dependency check
for cmd in curl python3 launchctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "Required command not found: $cmd"
        exit 1
    fi
done
ok "Required tools present"

# Claude Code check (warn only)
if ! command -v claude >/dev/null 2>&1; then
    warn "'claude' command not found on PATH"
    warn "Install Claude Code first, then re-run this installer."
    warn "Continuing anyway — the daemon will fail until claude is available."
fi

# Create install dir
mkdir -p "$INSTALL_DIR"

# Download the script
info "Downloading from $SCRIPT_URL"
if ! curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH.tmp"; then
    err "Download failed."
    exit 1
fi
mv "$INSTALL_PATH.tmp" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
ok "Installed to $INSTALL_PATH"

# Warn about PATH
if ! echo ":$PATH:" | grep -q ":$INSTALL_DIR:"; then
    warn "$INSTALL_DIR is not on your PATH."
    info "Add this line to ~/.zshrc:"
    echo "    export PATH=\"\$HOME/bin:\$PATH\""
    echo ""
fi

# Hand off to the script's own install command.
# Stdin is the pipe from curl when curl|bash, so reopen /dev/tty for interactive prompts.
if [ -t 0 ] || [ -e /dev/tty ]; then
    echo ""
    info "Running first-time setup..."
    echo ""
    # Pass topic/device via env if provided, otherwise the script will prompt
    NTFY_TOPIC_FLAG="${CLAUDE_WATCH_TOPIC:-}" \
    DEVICE_NAME_FLAG="${CLAUDE_WATCH_DEVICE:-}" \
    "$INSTALL_PATH" install </dev/tty
else
    warn "No TTY available — skipping interactive setup."
    info "Finish setup manually:"
    echo "    $INSTALL_PATH install"
fi
