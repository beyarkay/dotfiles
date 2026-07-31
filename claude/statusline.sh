#!/usr/bin/env bash
# Claude Code status line:
#   line 1: the self-maintained "current task" goal (from /tmp/claude-task-<sid>.txt,
#           kept fresh by hooks/current-task.sh)
#   line 2: context-window usage, plus the free-text note from /tmp/claude-note-<sid>.txt
#           (set with /note, handled by hooks/note.sh)
#   line 3+: live tqdm progress bars for running background jobs, if any
#           (from /tmp/claude-pbar-<sid>/, written by tools/pbar/ccbar.py).
#           Needs statusLine.refreshInterval set, or these only redraw when an
#           assistant message lands — i.e. never, during a long background job.
# Each newline-separated line renders as its own row (multi-line statusLine is
# supported); ANSI styling works per line.
set -euo pipefail

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

task=""
[ -n "$sid" ] && [ -f "/tmp/claude-task-${sid}.txt" ] && task=$(head -1 "/tmp/claude-task-${sid}.txt" 2>/dev/null || true)

note=""
[ -n "$sid" ] && [ -f "/tmp/claude-note-${sid}.txt" ] && note=$(head -1 "/tmp/claude-note-${sid}.txt" 2>/dev/null || true)

dim=$'\e[2m'; rst=$'\e[0m'; bold=$'\e[1m'; cyan=$'\e[36m'; yellow=$'\e[33m'

# Line 1 — the goal.
if [ -n "$task" ]; then
  printf "%b\n" "${cyan}${bold}\xf0\x9f\x8e\xaf ${task}${rst}"
else
  printf "%b\n" "${dim}\xf0\x9f\x8e\xaf (no current task set)${rst}"
fi

# Line 2 — context usage, then the note.
if [ -n "$ctx" ]; then
  pct=$(printf '%.0f' "$ctx" 2>/dev/null || printf '%s' "$ctx")
  line2="${dim}${pct}% context${rst}"
else
  line2="${dim}— context${rst}"
fi
[ -n "$note" ] && line2="${line2}${dim} | ${rst}${yellow}${note}${rst}"
printf "%b\n" "$line2"

# Line 3+ — progress bars, only while a job is actually running. The directory
# test keeps the common case free: no bars, no python, no cost. ccbar.render is
# hard-wired to exit 0 silently on any error so a broken bar can never take the
# rest of the status line down with it.
pbar_dir="/tmp/claude-pbar-${sid}"
if [ -n "$sid" ] && [ -d "$pbar_dir" ] && compgen -G "${pbar_dir}/*.json" > /dev/null 2>&1; then
  PYTHONPATH="$HOME/.claude/tools/pbar" python3 -m ccbar.render "$sid" 2>/dev/null || true
fi
