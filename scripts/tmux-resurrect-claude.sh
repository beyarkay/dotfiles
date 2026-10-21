#!/usr/bin/env bash
# tmux-resurrect post-save-layout hook: rewrite each Claude Code pane's saved
# command to `claude --resume <session id>`, using ~/.claude/sessions/<pid>.json.
set -euo pipefail

save_file="$1"
ids=$(mktemp)
panes=$(mktemp)
out=$(mktemp)
trap 'rm -f "$ids" "$panes" "$out"' EXIT

for f in "$HOME"/.claude/sessions/*.json; do
	[ -e "$f" ] || continue
	pid=$(jq -r 'select(.kind == "interactive" and .tmux != null) | .pid' "$f" 2>/dev/null) || continue
	if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
		continue
	fi
	jq -r '[(.tmux | sub(".*\\."; "")), .sessionId, .updatedAt] | @tsv' "$f"
done >"$ids"

tmux list-panes -a -F "#{pane_id}	#{session_name}	#{window_index}	#{pane_index}" >"$panes"

awk -F '\t' -v OFS='\t' '
	FILENAME == ARGV[1] {
		if (!($1 in updated) || $3 > updated[$1]) { sid[$1] = $2; updated[$1] = $3 }
		next
	}
	FILENAME == ARGV[2] {
		if ($1 in sid) pane_sid[$2 SUBSEP $3 SUBSEP $4] = sid[$1]
		next
	}
	$1 == "pane" && $11 ~ /^:([^ ]*\/)?claude( |$)/ && (($2 SUBSEP $3 SUBSEP $6) in pane_sid) {
		args = " " $11 " "
		sub(/^ :[^ ]*claude /, " ", args)
		gsub(/ (--resume|-r|--teleport|--session-id) [^ ]+/, " ", args)
		gsub(/ (--continue|-c|--fork-session)( |$)/, " ", args)
		gsub(/  +/, " ", args)
		sub(/ $/, "", args)
		$11 = ":claude --resume " pane_sid[$2 SUBSEP $3 SUBSEP $6] args
	}
	{ print }
' "$ids" "$panes" "$save_file" >"$out"

cat "$out" >"$save_file"
