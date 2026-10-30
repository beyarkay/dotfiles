#!/usr/bin/env bash
# Shows how a grind run is going, from the workflow's journal, while it runs.
#   progress.sh RUN_DIR            write RUN_DIR/progress.yaml and print a score table
#   progress.sh RUN_DIR diff vNN   word diff of vNN against the draft it was edited from
# GRIND_JOURNAL overrides the journal lookup; HONESTY_MIN (default 90) sets the pass mark.
set -euo pipefail

run=$(cd "$1" && pwd)

if [[ ${2:-} == diff ]]; then
    base=$(yq ".[] | select(.version == \"$3\") | .from" "$run/progress.yaml")
    new=("$run/drafts/$3"*)
    old=("$run/drafts/$base"*)
    git diff --no-index --word-diff=color "${old[0]}" "${new[0]}" || true
    exit 0
fi

journal=${GRIND_JOURNAL:-}
if [[ -z $journal ]]; then
    while IFS= read -r agent; do
        candidate="$(dirname "$agent")/journal.jsonl"
        [[ -z $journal || $candidate -nt $journal ]] && journal=$candidate
    done < <(rg -l --fixed-strings "$run/brief.yaml" ~/.claude/projects/*/*/subagents/workflows/*/agent-*.jsonl 2>/dev/null || true)
    [[ -n $journal ]] || { echo "no workflow journal mentions $run" >&2; exit 1; }
fi

jq -s --argjson min "${HONESTY_MIN:-90}" '
  def penalty: {fabrication: 25, misleading: 15, constraint: 15, stretch: 5, nit: 1};
  def honesty: [100 - ((.violations // []) | map(penalty[.severity]) | add // 0), 0] | max;
  def blocking: (.violations // []) | map(select(.severity == "fabrication" or .severity == "misleading" or .severity == "constraint"));
  def effectiveness: (.criteria | (map(.weight) | add) as $w | if $w > 0 then (map(.weight * .score) | add) / $w | round else 0 end);
  def finding: "\(.severity): \(.quote) -> \(.problem)";
  def pick($kind): map(select(.label | startswith($kind))) | first | .result;

  (map(select(.type == "started")) | map({(.key): .label}) | add) as $labels
  | map(select(.type != "started" and .type != "launched") | . + {label: $labels[.key]})
  | map(select(.label // "" | test("v[0-9]{2}")))
  | group_by(.label | capture("(?<v>v[0-9]{2})").v)
  | map(
      (.[0].label | capture("(?<v>v[0-9]{2})").v) as $v
      | (pick("audit")) as $a | (pick("grade")) as $g | (pick("edit")) as $e
      | (pick("confirm audit")) as $ca | (pick("confirm grade")) as $cg
      | {
          version: $v,
          from: (map(select(.label | startswith("edit"))) | first | .label // "" | capture("from (?<b>v[0-9]{2})").b? // null),
          changes: ($e.changelog // null),
          honesty: (if $a then $a | honesty else null end),
          passed: (if $a then ($a | blocking | length) == 0 and ($a | honesty) >= $min else null end),
          blocking: (if $a then $a | blocking | map(finding) else null end),
          other_findings: (if $a then ($a.violations - ($a | blocking)) | map(finding) else null end),
          effectiveness: (if $g then $g | effectiveness else null end),
          criteria: (if $g then $g.criteria | map({(.name): .score}) | add else null end),
          decision: ($g.decision // null),
          weaknesses: ($g.weaknesses // null),
          questions_for_owner: ($a.questions_for_owner // null),
          confirm: (if $ca or $cg then {
            honesty: (if $ca then $ca | honesty else null end),
            blocking: (if $ca then $ca | blocking | map(finding) else null end),
            effectiveness: (if $cg then $cg | effectiveness else null end)
          } else null end),
          failed_agents: (map(select(.type != "result")) | map("\(.label): \(.type)") | if length > 0 then . else null end)
        }
      | with_entries(select(.value != null))
    )
' "$journal" |
    yq -P '(.. | select(tag == "!!str" and test("\n"))) style = "literal"' >"$run/progress.yaml"

{
    printf 'version\tfrom\thonesty\tpassed\teffectiveness\tdecision\n'
    yq -o=tsv '.[] | [.version, .from // "-", .honesty // "-", (.passed | tostring), .effectiveness // "-", .decision // "-"]' "$run/progress.yaml"
} | column -t -s $'\t'
best=$(yq '[.[] | select(.passed == true and .effectiveness != null)] | sort_by(.effectiveness) | reverse | .[0].version // ""' "$run/progress.yaml")
echo "best passing so far: ${best:-none yet}${best:+ ($(echo "$run"/drafts/"$best"*))}"
echo "details: $run/progress.yaml"
