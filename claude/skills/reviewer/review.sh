#!/usr/bin/env bash
#
# reviewer — adversarial, read-only code review powered by `codex exec`.
#
# Hands a diff + the ORIGINAL spec (by link, not by paraphrase) to codex and
# asks it to hunt for bugs, inconsistencies and mistakes. codex runs in a
# read-only sandbox: it can read the whole repo, run git/rg/cat to dig deeper,
# but it CANNOT edit anything. It reports findings only.
#
# Usage:
#   review.sh [--spec PATH_OR_URL]... [scope] [options] ["focus text"]
#
# Scope (pick at most one; default = auto):
#   (default/auto)      Working tree vs merge-base with the base branch, i.e.
#                       committed branch work PLUS uncommitted WIP. On the base
#                       branch itself this is just your WIP (falls back to the
#                       last commit if the tree is clean).
#   --uncommitted       Only staged + unstaged + untracked changes.
#   --commit SHA        Only the changes introduced by one commit.
#   --range GITRANGE    An explicit git range, e.g. main...HEAD or A..B.
#
# Options:
#   --spec PATH_OR_URL  The original issue / spec / bug report this change is
#                       meant to satisfy. Repeatable. Local paths are passed to
#                       codex to read directly; URLs (incl. GitHub issue/PR
#                       links) are fetched verbatim and embedded. codex judges
#                       the diff against the REAL source, not a summary.
#   --base BRANCH       Base branch for auto scope (default: autodetect
#                       main/master/trunk/develop or origin/*).
#   --model MODEL       codex model override (default: codex's configured model).
#   -C, --cd DIR        Repo directory to review in (default: current dir).
#   --focus TEXT        Extra reviewer instructions appended to the prompt.
#                       Equivalent: pass the text as trailing free-text args.
#   --focus-stdin       Read the focus text from stdin instead of the argument
#                       list (only if stdin is not a terminal). Lets a caller
#                       feed arbitrary text — quotes, $, backticks, globs — via
#                       a heredoc without the shell re-parsing it. An explicit
#                       --focus wins over it.
#   --quiet, -q         Print only the final report on stdout (suppress codex's
#                       live event stream, which is kept in a log file). Ideal
#                       for feeding the report into another tool's context.
#   --dry-run           Print the assembled prompt and the codex command; run
#                       nothing (no API cost). Use to inspect before spending.
#   -h, --help          This help.
#
# Large diffs (> 200 lines) are handed to codex as a --stat summary plus the git
# command to reproduce them; codex reads the full diff itself via its read-only
# repo access. Smaller diffs are embedded inline.
#
# Exit status is codex's own, or non-zero on a setup error.

set -euo pipefail

die() {
    printf 'reviewer: %s\n' "$*" >&2
    exit 1
}
warn() { printf 'reviewer: %s\n' "$*" >&2; }

# Tool availability is checked later: git after arg-parsing (needed even for
# --dry-run), codex only before a real run (so --help/--dry-run work without it).

# ---- defaults ---------------------------------------------------------------
DIR="$PWD"
MODE="auto"
BASE=""
COMMIT=""
RANGE=""
MODEL=""
FOCUS=""
FOCUS_STDIN=0
DRY_RUN=0
QUIET=0
SPECS=()
SPEC_TMPFILES=()
POSITIONAL=()

# Clean up any verbatim-fetched spec temp files (they may hold private issue/PR
# text). The EXIT trap covers normal exits, errors and dry-run; the signal trap
# re-exits through it so Ctrl-C / kill during a long review also cleans up.
cleanup() {
    [ "${#SPEC_TMPFILES[@]}" -gt 0 ] && rm -f "${SPEC_TMPFILES[@]}"
    return 0
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# At most one scope option may be chosen.
set_scope() {
    [ "$MODE" = "auto" ] || die "pick at most one scope option (already have --$MODE)"
    MODE="$1"
}

# ---- arg parsing ------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
    --spec)
        [ $# -ge 2 ] || die "--spec needs a value"
        SPECS+=("$2")
        shift 2
        ;;
    --uncommitted)
        set_scope uncommitted
        shift
        ;;
    --commit)
        [ $# -ge 2 ] || die "--commit needs a SHA"
        set_scope commit
        COMMIT="$2"
        shift 2
        ;;
    --range)
        [ $# -ge 2 ] || die "--range needs a git range"
        set_scope range
        RANGE="$2"
        shift 2
        ;;
    --base)
        [ $# -ge 2 ] || die "--base needs a branch"
        BASE="$2"
        shift 2
        ;;
    --model)
        [ $# -ge 2 ] || die "--model needs a value"
        MODEL="$2"
        shift 2
        ;;
    -C | --cd)
        [ $# -ge 2 ] || die "$1 needs a directory"
        DIR="$2"
        shift 2
        ;;
    --focus)
        [ $# -ge 2 ] || die "--focus needs text"
        FOCUS="$2"
        shift 2
        ;;
    --focus-stdin)
        FOCUS_STDIN=1
        shift
        ;;
    --quiet | -q)
        QUIET=1
        shift
        ;;
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    -h | --help)
        awk 'NR<3{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"
        exit 0
        ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

# Focus from stdin (--focus-stdin): lets a slash command feed arbitrary text —
# quotes, $, backticks, globs — via a heredoc, so the shell never re-parses it.
# Read only when stdin is a pipe/file (not a terminal), so a manual run that
# passes the flag without piping doesn't hang. An explicit --focus wins.
if [ "$FOCUS_STDIN" -eq 1 ] && [ -z "$FOCUS" ] && [ ! -t 0 ]; then
    FOCUS=$(cat)
fi

# Free-text (non-flag) arguments become the reviewer's focus, so a slash-command
# prompt is forwarded straight to codex, e.g.  review.sh "scrutinise the retry
# logic". An explicit --focus (or --focus-stdin) wins if both are supplied.
if [ -z "$FOCUS" ] && [ "${#POSITIONAL[@]}" -gt 0 ]; then
    FOCUS="${POSITIONAL[*]}"
fi

# ---- resolve repo -----------------------------------------------------------
command -v git >/dev/null 2>&1 || die "git not found on PATH"

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) ||
    die "not inside a git repository: $DIR"

git_root() { git -C "$ROOT" "$@"; }

# ---- helpers ----------------------------------------------------------------
abspath() {
    # portable realpath (macOS bash 3.2 has no realpath)
    local p="$1"
    if [ -d "$p" ]; then
        (cd "$p" >/dev/null 2>&1 && pwd)
        return
    fi
    local d b
    d=$(dirname -- "$p")
    b=$(basename -- "$p")
    printf '%s/%s\n' "$(cd "$d" >/dev/null 2>&1 && pwd)" "$b"
}

resolve_local() {
    # Print an absolute path for a local spec, trying CWD then the repo root.
    # (Relative --spec paths should work regardless of -C.) Non-zero if neither.
    local s="$1"
    if [ -e "$s" ]; then
        abspath "$s"
        return 0
    fi
    if [ -e "$ROOT/$s" ]; then
        abspath "$ROOT/$s"
        return 0
    fi
    return 1
}

is_blank() { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]; }

detect_base() {
    local b
    for b in main master trunk develop; do
        git_root show-ref --verify --quiet "refs/heads/$b" && {
            echo "$b"
            return
        }
    done
    for b in origin/main origin/master origin/HEAD; do
        git_root show-ref --verify --quiet "refs/remotes/$b" 2>/dev/null && {
            echo "$b"
            return
        }
    done
    echo "HEAD"
}

untracked_diff() {
    # Emit untracked files as additions (read-only; does not touch the index).
    local f
    git_root ls-files --others --exclude-standard | while IFS= read -r f; do
        [ -n "$f" ] || continue
        git_root diff --no-index -- /dev/null "$f" 2>/dev/null || true
    done
}

untracked_stat() {
    # List untracked files with line counts (they're absent from git diff --stat).
    local f
    git_root ls-files --others --exclude-standard | while IFS= read -r f; do
        [ -n "$f" ] || continue
        printf ' %s (untracked, %s lines)\n' "$f" "$(wc -l <"$ROOT/$f" 2>/dev/null | tr -d ' ')"
    done
}

diffstat() {
    # Count added/removed CONTENT lines in a unified diff read from stdin. Counts
    # only inside hunks, so +++/--- file headers are never miscounted. Prints
    # "<added> <removed>".
    awk '
    /^@@/ { inhunk=1; next }
    /^(diff |index |--- |\+\+\+ |Binary |new file|deleted file|rename |similarity |old mode|new mode|GIT binary)/ { inhunk=0; next }
    inhunk && /^\+/ { add++ }
    inhunk && /^-/  { del++ }
    END { printf "%d %d\n", add+0, del+0 }
  '
}

# ---- compute the diff -------------------------------------------------------
[ -n "$BASE" ] || BASE=$(detect_base)

case "$MODE" in
commit)
    git_root cat-file -e "${COMMIT}^{commit}" 2>/dev/null || die "no such commit: $COMMIT"
    DIFF=$(git_root show --patch --stat "$COMMIT")
    SCOPE_DESC="the change introduced by commit $COMMIT"
    ;;
range)
    DIFF=$(git_root diff "$RANGE") || die "bad git range: $RANGE"
    SCOPE_DESC="git range $RANGE"
    ;;
uncommitted)
    DIFF=$(
        git_root diff HEAD
        untracked_diff
    )
    SCOPE_DESC="the uncommitted changes (staged + unstaged + untracked)"
    ;;
auto)
    MB=$(git_root merge-base "$BASE" HEAD 2>/dev/null || git_root rev-parse HEAD)
    DIFF=$(
        git_root diff "$MB"
        untracked_diff
    )
    SCOPE_DESC="the working tree vs its merge-base with '$BASE' ($MB) — committed branch work plus any uncommitted changes"
    if is_blank "$DIFF"; then
        DIFF=$(git_root show --patch --stat HEAD)
        SCOPE_DESC="the last commit (HEAD) — there is no diff against base '$BASE'"
    fi
    ;;
esac

is_blank "$DIFF" && die "no changes to review for the selected scope"

# ---- kickoff banner + large-diff handling -----------------------------------
# Context so you can see exactly what's being handed to codex. If the diff is big
# (> DIFF_MAX_LINES), hand codex only the --stat summary plus the command to
# reproduce it, and let it pull the real diff itself (read-only repo access) —
# keeps the prompt small and avoids dumping thousands of lines (e.g. untracked
# data dirs pulled in by the default scope).
DIFF_MAX_LINES=200
REPORT="${TMPDIR:-/tmp}/reviewer-report.$$.md"
HEAD_SHA=$(git_root rev-parse --short HEAD 2>/dev/null || echo '?')
CUR_BRANCH=$(git_root rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
read -r N_ADD N_DEL < <(printf '%s' "$DIFF" | diffstat)
N_FILES=$(printf '%s\n' "$DIFF" | grep -cE '^diff ' || true)
DIFF_LINES=$(printf '%s\n' "$DIFF" | wc -l | tr -d ' ')

STAT=""  # non-empty ⇒ hand codex the summary instead of the full diff
REPRO="" # the git command codex should run to see the full diff
if [ "$DIFF_LINES" -gt "$DIFF_MAX_LINES" ]; then
    case "$MODE" in
    commit)
        STAT=$(git_root show --stat --oneline "$COMMIT")
        REPRO="git show $COMMIT"
        ;;
    range)
        STAT=$(git_root diff --stat "$RANGE")
        REPRO="git diff $RANGE"
        ;;
    uncommitted)
        STAT=$(
            git_root diff --stat HEAD
            untracked_stat
        )
        REPRO="git diff HEAD  (and read the untracked files listed)"
        ;;
    auto)
        STAT=$(
            git_root diff --stat "$MB"
            untracked_stat
        )
        REPRO="git diff $MB  (and read the untracked files listed)"
        ;;
    esac
fi

case "$MODE" in
auto)
    if [ "$MB" = "$(git_root rev-parse HEAD)" ]; then
        ENDPOINTS="uncommitted changes on ${CUR_BRANCH} (HEAD ${HEAD_SHA})"
    else
        BASE_SHA=$(git_root rev-parse --short "$BASE" 2>/dev/null || echo '?')
        ENDPOINTS="HEAD (${HEAD_SHA}, ${CUR_BRANCH}) vs ${BASE} (${BASE_SHA}), incl. uncommitted WIP"
    fi
    ;;
uncommitted) ENDPOINTS="uncommitted changes on ${CUR_BRANCH} (HEAD ${HEAD_SHA})" ;;
commit) ENDPOINTS="commit ${COMMIT} on ${CUR_BRANCH}" ;;
range) ENDPOINTS="range ${RANGE}" ;;
esac

BANNER=$(printf 'reviewer: diff to review — %s\nreviewer: +%s / -%s across %s file(s)%s%s' \
    "$ENDPOINTS" "${N_ADD:-0}" "${N_DEL:-0}" "$N_FILES" \
    "${FOCUS:+ · focus: $FOCUS}" \
    "${STAT:+ · large diff (${DIFF_LINES} lines) → codex gets --stat and reads it itself}")
printf '%s\n' "$BANNER" >&2

# ---- gather specs -----------------------------------------------------------
# An explicitly supplied spec that cannot be resolved/fetched is a SETUP ERROR:
# fail closed rather than silently spend quota reviewing against no/wrong spec.
SPEC_LINKS=""  # local paths codex must read itself
SPEC_EMBEDS="" # verbatim content fetched from URLs
SPEC_FAILS=()  # supplied specs we could not resolve
for s in ${SPECS[@]+"${SPECS[@]}"}; do
    if printf '%s' "$s" | grep -qiE '^https?://'; then
        tmpf=$(mktemp -t reviewer-spec.XXXXXX)
        SPEC_TMPFILES+=("$tmpf")
        if printf '%s' "$s" | grep -qE 'github\.com/.+/issues/[0-9]+' && command -v gh >/dev/null 2>&1; then
            gh issue view "$s" --comments >"$tmpf" 2>/dev/null || curl -fsSL "$s" >"$tmpf" 2>/dev/null || true
        elif printf '%s' "$s" | grep -qE 'github\.com/.+/pull/[0-9]+' && command -v gh >/dev/null 2>&1; then
            gh pr view "$s" --comments >"$tmpf" 2>/dev/null || curl -fsSL "$s" >"$tmpf" 2>/dev/null || true
        else
            curl -fsSL "$s" >"$tmpf" 2>/dev/null || true
        fi
        if [ -s "$tmpf" ]; then
            SPEC_EMBEDS="${SPEC_EMBEDS}
----- ORIGINAL SPEC, fetched verbatim from ${s} ($(wc -c <"$tmpf" | tr -d ' ') bytes) -----
$(cat "$tmpf")
----- END SPEC (${s}) -----
"
        else
            SPEC_FAILS+=("$s (fetch returned nothing)")
        fi
    elif p=$(resolve_local "$s"); then
        SPEC_LINKS="${SPEC_LINKS}  - $p"$'\n'
    else
        SPEC_FAILS+=("$s (no such file; tried CWD and $ROOT)")
    fi
done
if [ "${#SPEC_FAILS[@]}" -gt 0 ]; then
    die "could not resolve --spec source(s); aborting before spending quota:$(printf '\n  - %s' "${SPEC_FAILS[@]}")"
fi

# ---- assemble the prompt ----------------------------------------------------
if [ -n "$SPEC_LINKS" ] || [ -n "$SPEC_EMBEDS" ]; then
    SPEC_BLOCK="THE ORIGINAL REQUEST (READ IT YOURSELF, IN FULL, FIRST).
This change is meant to satisfy the specification / issue / bug report below.
Do NOT trust any paraphrase of it — go to the source. Judge the diff against
what the source actually asks for, and call out anywhere the change
misunderstands it, under-delivers on it, quietly drops a requirement, or
contradicts it."
    [ -n "$SPEC_LINKS" ] && SPEC_BLOCK="${SPEC_BLOCK}

Read these file(s) directly from disk:
${SPEC_LINKS}"
    [ -n "$SPEC_EMBEDS" ] && SPEC_BLOCK="${SPEC_BLOCK}
${SPEC_EMBEDS}"
else
    SPEC_BLOCK="THE ORIGINAL REQUEST.
No spec was supplied. Review purely for correctness, safety and quality."
fi

[ -n "$FOCUS" ] && FOCUS_BLOCK="
EXTRA FOCUS FROM THE REQUESTER:
$FOCUS
" || FOCUS_BLOCK=""

if [ -n "$STAT" ]; then
    DIFF_SECTION="This diff is large (${DIFF_LINES} lines), so only its --stat
summary is shown below. You have read-only access to the whole repo — run
  ${REPRO}
yourself to read the actual changes, and open any file you need to dig deeper.

===== DIFF --stat SUMMARY (${N_FILES} files, +${N_ADD:-0}/-${N_DEL:-0}) =====
${STAT}
===== END SUMMARY ====="
else
    DIFF_SECTION="The full diff follows.

===== BEGIN DIFF UNDER REVIEW =====
${DIFF}
===== END DIFF UNDER REVIEW ====="
fi

PROMPT="You are acting as a hostile, highly skeptical senior code reviewer. Your
sole job is to find problems in the change under review. Assume it is buggy
until you have proven otherwise by reading the code. Being agreeable is a
failure; missing a real bug is a worse one. Do not praise, do not summarise the
change back to me — hunt for what is wrong.

WHAT TO HUNT FOR (non-exhaustive): correctness and logic errors, off-by-one and
boundary mistakes, unhandled edge cases and error paths, null/None and type
confusions, race conditions and concurrency bugs, resource leaks, security holes
(injection, path traversal, secrets, authz), performance regressions,
API/contract mismatches with callers, inconsistencies with the surrounding
code's conventions, dead or unreachable code, copy-paste errors, wrong or
missing tests, and — above all — ways the change fails to actually do what was
asked.

DIG INTO THE REPOSITORY — THIS IS REQUIRED, NOT OPTIONAL. You have read-only
access to the ENTIRE repository and you are strongly encouraged to use it. Do
not review the diff in isolation. Open the files it touches and their
neighbours; trace the callers and callees of every changed function; grep for
other usages of changed symbols, constants and config keys; read the relevant
tests; consult git history/blame where it clarifies intent; and verify EVERY
assumption against the actual code rather than guessing. A finding you confirmed
by reading the surrounding code is worth ten you speculated about. A shallow,
diff-only review is a failed review.

${SPEC_BLOCK}
${FOCUS_BLOCK}
DO NOT MAKE ANY CHANGES. You are a reviewer, not an implementer. Do not edit,
create, move or delete any files, and do not write fixes into the tree. Report
findings and recommendations only. (You are sandboxed read-only, so writes will
fail anyway — don't waste effort attempting them.)

OUTPUT FORMAT — produce a concise report, nothing else:
  1. VERDICT: one line — e.g. \"looks correct\", \"has blocking bugs\",
     \"risky, needs changes before merge\".
  2. FINDINGS: ordered most-severe first. For each:
       - severity: blocker | major | minor | nit
       - title: one line
       - location: file:line (real, cite it)
       - why it's wrong: the concrete failure scenario, or the exact spec
         clause it violates
       - recommendation: the direction of the fix (describe it; do NOT write
         the code)
  3. UNVERIFIED: anything you could not confirm, and why.
If, after genuinely digging, you find nothing wrong, say so plainly rather than
inventing nits.

The change under review is ${SCOPE_DESC}.

${DIFF_SECTION}"

# ---- run --------------------------------------------------------------------
CODEX_ARGS=(exec --sandbox read-only --color never -C "$ROOT"
    -c approval_policy="never" -o "$REPORT")
[ -n "$MODEL" ] && CODEX_ARGS+=(-m "$MODEL")
CODEX_ARGS+=(-)

if [ "$DRY_RUN" -eq 1 ]; then
    printf '===== DRY RUN: codex command =====\n'
    printf 'codex'
    for a in "${CODEX_ARGS[@]}"; do printf ' %q' "$a"; done
    printf ' < <prompt>\n\n'
    printf '===== DRY RUN: assembled prompt =====\n%s\n' "$PROMPT"
    exit 0
fi

command -v codex >/dev/null 2>&1 || die "codex not found on PATH"

printf 'reviewer: starting codex (model %s, read-only sandbox) → report %s\n\n' \
    "${MODEL:-<codex default>}" "$REPORT" >&2

# Don't let a nonzero codex exit trip `set -e` before we print the report.
set +e
if [ "$QUIET" -eq 1 ]; then
    # Quiet: hide codex's live event stream (kept in a log); emit only the banner
    # + final report on stdout, so the output is clean to inject elsewhere.
    CODEX_LOG="${TMPDIR:-/tmp}/reviewer-codex.$$.log"
    printf '%s' "$PROMPT" | codex "${CODEX_ARGS[@]}" >"$CODEX_LOG" 2>&1
    status=$?
else
    printf '%s' "$PROMPT" | codex "${CODEX_ARGS[@]}"
    status=$?
fi
set -e

if [ "$QUIET" -eq 1 ]; then
    printf '%s\n\n' "$BANNER"
    if [ -s "$REPORT" ]; then
        cat "$REPORT"
    else
        printf '(reviewer: codex produced no report; exit %s. Full codex log: %s)\n' "$status" "$CODEX_LOG"
    fi
elif [ -s "$REPORT" ]; then
    printf '\n\n===== FINAL REVIEW REPORT (%s) =====\n' "$REPORT"
    cat "$REPORT"
fi
exit $status
