#!/usr/bin/env bash
# Put a status marker on the current tmux window's name, or take it off again.
#
#   tmux-window.sh        strip whatever marker is on there
#   tmux-window.sh 🗜️     strip it, then append this one
#
# The markers are emoji and some of them — 🗜️ — are a base code point plus a
# U+FE0F variation selector, i.e. two characters. A bracket expression matches
# exactly one, so the old inline `sed 's/ [❓🚧🗜️]$//'` stripped ❓ and 🚧 but
# left 🗜️ stuck on the window name forever. Hence the explicit alternation.
set -euo pipefail

MARKERS='❓|🚧|🗜️'

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

name=$(tmux display-message -t "$TMUX_PANE" -p '#W' 2>/dev/null) || exit 0
name=$(printf '%s' "$name" | sed -E "s/ ($MARKERS)$//")

if [ "${1:-}" != "" ]; then
    name="${name} $1"
fi

tmux rename-window -t "$TMUX_PANE" "$name" 2>/dev/null || true
