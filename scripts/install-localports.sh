#!/usr/bin/env bash
# Install (or reinstall) the localports login agent. Safe to re-run.
set -euo pipefail

LABEL="com.brk.localports"
DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "localports: launchd agent is macOS only, skipping" >&2
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

# launchd reads the plist by path at bootstrap time, so render rather than symlink.
sed "s|{{HOME}}|$HOME|g" "$DOTFILES/launchd/$LABEL.plist" >"$TARGET"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$TARGET"
launchctl kickstart -k "$DOMAIN/$LABEL"

for _ in $(seq 1 20); do
  if curl -fs --max-time 2 -o /dev/null http://127.0.0.1:1111/; then
    echo "localports: running at http://localhost:1111"
    exit 0
  fi
  sleep 0.5
done

echo "localports: agent did not come up; see ~/Library/Logs/localports.log" >&2
exit 1
