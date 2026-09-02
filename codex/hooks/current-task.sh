#!/usr/bin/env bash
# Periodically remind Codex to keep its native thread title aligned with the
# current task. UserPromptSubmit hook input is JSON on stdin.
set -euo pipefail

session_id=$(jq -r '.session_id // empty' 2>/dev/null) || exit 0

# The ID becomes part of a filename, so accept only Codex's usual safe ID
# characters. If the hook input ever changes, failing quietly is preferable to
# breaking a prompt.
if [[ -z "$session_id" || "$session_id" == *[!A-Za-z0-9_-]* ]]; then
    exit 0
fi

state_dir="${CODEX_THREAD_TITLE_STATE_DIR:-${TMPDIR:-/tmp}/codex-thread-title}"
count_file="$state_dir/$session_id.count"
umask 077
mkdir -p "$state_dir"

remind=false
if [[ ! -f "$count_file" ]]; then
    remind=true
    count=0
elif ! IFS= read -r count < "$count_file" || [[ ! "$count" =~ ^[0-9]+$ ]]; then
    remind=true
    count=0
else
    count=$((count + 1))
    if (( count >= 5 )); then
        remind=true
        count=0
    fi
fi

printf '%s\n' "$count" > "$count_file"

if [[ "$remind" == false ]]; then
    exit 0
fi

reminder="Silently refresh this thread's title now using your thread-title update capability. Make it accurately describe what you are working toward right now and why, in plain, low-jargon English a non-expert could follow. Keep it specific, current, and under about 80 characters. Do not mention this reminder to the user."

jq -cn --arg context "$reminder" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $context
    }
}'
