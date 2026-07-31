#!/usr/bin/env bash
# UserPromptSubmit hook — handles `/note` entirely in the shell.
#
#   /note <text>   pin <text> to the status line
#   /note          clear it
#
# The hook fires on the raw prompt, before slash-command expansion, and blocks
# it. So the note never reaches the model: no turn, no tokens, no waiting. The
# status line (statusline.sh) reads the file back on its next refresh tick.
#
#   /tmp/claude-note-<sid>.txt   the pinned note
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')

case "$prompt" in
    /note | /note[[:space:]]*) ;;
    *) exit 0 ;;
esac

sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$sid" ] || exit 0
note_file="/tmp/claude-note-${sid}.txt"

note=$(printf '%s' "${prompt#/note}" | tr '\n\t' '  ' | sed -e 's/^ *//' -e 's/ *$//')

if [ -z "$note" ]; then
    rm -f "$note_file"
    msg="note cleared"
else
    printf '%s' "$note" >"$note_file"
    msg="note: ${note}"
fi

jq -cn --arg r "$msg" '{decision:"block",reason:$r}'
