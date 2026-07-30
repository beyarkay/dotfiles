#!/usr/bin/env bash
# PostToolUse hook — keep a one-line "current task" description fresh.
#
# Maintains a per-session tool-call counter and, when no task is set yet or ~EVERY
# tool calls have passed since the last nudge, injects a SILENT reminder (via
# hookSpecificOutput.additionalContext) telling Claude to refresh the task file.
# The status line script (statusline.sh) reads that same file and displays it.
#
# State (keyed by session_id, per the documented /tmp-$SESSION_ID pattern):
#   /tmp/claude-task-<sid>.txt     the current one-line goal  (Claude writes this)
#   /tmp/claude-task-<sid>.count   nudge counter              (this hook writes this)
set -euo pipefail

EVERY=5 # nudge roughly every this many tool calls

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$sid" ] || exit 0

task_file="/tmp/claude-task-${sid}.txt"
count_file="/tmp/claude-task-${sid}.count"

n=0
[ -f "$count_file" ] && n=$(cat "$count_file" 2>/dev/null || echo 0)
case "$n" in '' | *[!0-9]*) n=0 ;; esac
n=$((n + 1))

cur=""
[ -f "$task_file" ] && cur=$(head -1 "$task_file" 2>/dev/null || true)

nudge=0
if [ -z "$cur" ]; then
    nudge=1
elif [ "$n" -ge "$EVERY" ]; then
    nudge=1
fi

# Reset the counter when we nudge so the next nudge is ~EVERY calls later.
if [ "$nudge" -eq 1 ]; then printf '0' >"$count_file"; else printf '%s' "$n" >"$count_file"; fi
[ "$nudge" -eq 1 ] || exit 0

guidance="Write it in plain, low-jargon English a non-expert could follow — say what you are actually doing right now and why, not a code-level label. Specific, up-to-date, under ~80 chars."
if [ -z "$cur" ]; then
    reminder="[current-task] No current-task goal is set for the status line yet. Silently set one describing what you are working toward RIGHT NOW. ${guidance} Run this WITHOUT telling the user:
  printf '%s' 'YOUR PLAIN-ENGLISH ONE-LINE GOAL' > ${task_file}"
else
    reminder="[current-task] Status-line goal currently reads: \"${cur}\". You should update this frequently (every ~5 tool calls). If the status line is stale or no longer matches what you are working toward RIGHT NOW, silently update it WITHOUT telling the user. ${guidance}
  printf '%s' 'YOUR PLAIN-ENGLISH ONE-LINE GOAL' > ${task_file}
If it is still accurate and current, do nothing."
fi

jq -cn --arg ctx "$reminder" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
