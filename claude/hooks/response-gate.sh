#!/usr/bin/env bash
# Stop hook — check the final reply against a ruleset and send it back for a rewrite.
#
# There is no "before you answer" hook. MessageDisplay fires while the text
# streams but is display-only; it cannot edit or suppress anything. Stop is the
# only event that can reopen a finished turn: it carries the final text in
# `last_assistant_message`, and exiting 2 hands stderr to Claude as an
# instruction and makes it keep going. So the gate is: read the reply, check it,
# exit 2 with a list of what it broke.
#
# The reply the user already read stays on screen — nothing can retract printed
# text. The rewrite lands underneath it.
#
#   response-rules.yaml            the ruleset
#   /tmp/claude-gate-<sid>.state   "<prompt_id> <rewrites so far>"
#   /tmp/claude-gate.log           what fired and why
#
# Off switch: CLAUDE_RESPONSE_GATE=0
set -uo pipefail

# The model judge shells out to `claude`, which loads this same hook. Without
# this the gate recurses into itself.
[ -n "${CLAUDE_RESPONSE_GATE_INNER:-}" ] && exit 0
[ "${CLAUDE_RESPONSE_GATE:-1}" = 0 ] && exit 0

RULES="${CLAUDE_RESPONSE_RULES:-$HOME/.claude/hooks/response-rules.yaml}"
LOG=/tmp/claude-gate.log
[ -r "$RULES" ] || exit 0

input=$(cat)
IFS=$'\t' read -r sid pid agent < <(
    printf '%s' "$input" | jq -r '[.session_id//"", .prompt_id//"", .agent_id//""] | @tsv'
)
reply=$(printf '%s' "$input" | jq -r '.last_assistant_message // ""')

[ -n "$agent" ] && exit 0                      # a subagent answers to Claude, not to the user
[ -n "${reply//[[:space:]]/}" ] || exit 0

cfg=$(yq -o=json '.' "$RULES" 2>/dev/null) || exit 0
max_rewrites=$(jq -r '.max_rewrites // 2' <<<"$cfg")

state="/tmp/claude-gate-${sid}.state"
if ! read -r last_pid rewrites 2>/dev/null < "$state"; then last_pid=""; rewrites=0; fi
[ "$last_pid" = "$pid" ] && [[ $rewrites =~ ^[0-9]+$ ]] || rewrites=0
if [ "$rewrites" -ge "$max_rewrites" ]; then
    printf '%s\t%s\tgave up after %s rewrite(s)\n' "$(date +%FT%T%z)" "${sid:0:8}" "$rewrites" >>"$LOG"
    exit 0
fi

# Fenced blocks and inline spans are code, and the rules are about prose.
# shellcheck disable=SC2016  # the backticks are literal markdown, not a subshell
prose=$(printf '%s\n' "$reply" | awk '/^[[:space:]]*```/ {fence = !fence; next} !fence' | sed -E 's/`[^`]*`//g')

violations=()
names=()
while IFS= read -r rule; do
    { read -r name; read -r regex; read -r message; read -r scope; } < <(
        jq -r '.name, .regex, .message, (.scope // "prose")' <<<"$rule"
    )
    [ -n "$regex" ] && [ "$regex" != null ] || continue
    case "$scope" in raw) haystack=$reply ;; *) haystack=$prose ;; esac
    hits=$(printf '%s\n' "$haystack" | rg -oP -e "$regex" 2>/dev/null | sort -u | head -3 | paste -sd'; ' -)
    [ -n "$hits" ] || continue
    # The token alone is not enough to act on — show the line it sits in.
    context=$(printf '%s\n' "$haystack" | rg -P -e "$regex" 2>/dev/null | head -2 |
        sed -E 's/^[[:space:]]+//; s/(.{130}).*/\1…/; s/^/  in: /')
    violations+=("$(printf -- '- %s (matched: %s)\n  %s\n%s' "$name" "$hits" "$message" "$context")")
    names+=("$name")
done < <(jq -c '.patterns[]?' <<<"$cfg")

if [ ${#violations[@]} -eq 0 ] && [ "$(jq -r '.judge.enabled // false' <<<"$cfg")" = true ]; then
    judge_prompt=$(cat <<EOF
You are a strict style checker. Judge the reply below against these rules, and
against nothing else. Do not judge whether the reply is correct, complete or
well written — only whether it breaks a listed rule.

RULES:
$(jq -r '.judge.rules // ""' <<<"$cfg")

REPLY:
<<<REPLY_START>>>
$reply
<<<REPLY_END>>>

Answer with compact JSON on one line and nothing else.
Obeys every rule: {"ok":true}
Breaks a rule:    {"ok":false,"violations":["<rule name> — what is wrong and how to fix it"]}
When in doubt, answer {"ok":true}. A false alarm costs the user a whole turn.
EOF
    )
    verdict=$(
        CLAUDE_RESPONSE_GATE_INNER=1 timeout "$(jq -r '.judge.timeout // 45' <<<"$cfg")" \
            claude -p "$judge_prompt" \
            --model "$(jq -r '.judge.model // "haiku"' <<<"$cfg")" \
            --disallowed-tools '*' 2>/dev/null | rg -o '\{.*\}' | tail -1
    )
    if [ -n "$verdict" ] && [ "$(jq -r '.ok // true' <<<"$verdict" 2>/dev/null)" = false ]; then
        while IFS= read -r v; do
            [ -n "$v" ] || continue
            violations+=("$(printf -- '- %s' "$v")")
            names+=(judge)
        done < <(jq -r '.violations[]?' <<<"$verdict" 2>/dev/null)
    fi
fi

[ ${#violations[@]} -gt 0 ] || exit 0

printf '%s %s\n' "$pid" "$((rewrites + 1))" >"$state"
printf '%s\t%s\trewrite %s: %s\n' "$(date +%FT%T%z)" "${sid:0:8}" "$((rewrites + 1))" "$(IFS=,; echo "${names[*]}")" >>"$LOG"

{
    printf 'Your reply to the user broke %d rule(s):\n\n' "${#violations[@]}"
    printf '%s\n' "${violations[@]}"
    printf '\nRewrite the reply so it obeys every rule, and send the rewrite on its own\n'
    printf 'without an apology or a summary of the edit. If a match is a term you were\n'
    # shellcheck disable=SC2016  # the backticks are literal markdown, not a subshell
    printf 'deliberately quoting, put it in `backticks` — code spans and fenced blocks\n'
    printf 'are exempt. If you believe a rule misfired, say so plainly instead of\n'
    printf 'contorting the reply to get past it.\n'
} >&2
exit 2
