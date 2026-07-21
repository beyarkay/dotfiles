---
name: reviewer
description: Run the adversarial, read-only codex reviewer on the current diff and fix what it finds. Invoke as /reviewer with optional focus text and scope flags — it kicks off codex immediately (spends codex/OpenAI quota) and injects the report for Claude to act on. codex reads the whole repo to dig but CANNOT edit anything.
argument-hint: "[focus text] [--uncommitted | --commit SHA | --range A..B | --base BRANCH] [--spec PATH_OR_URL]"
allowed-tools: Bash($HOME/.claude/skills/reviewer/review.sh --quiet*)
disable-model-invocation: true
---

# reviewer

The read-only, adversarial codex reviewer has been run on the current diff — it
reads the whole repo to dig, but cannot edit anything. Its report:

```!
$HOME/.claude/skills/reviewer/review.sh --quiet --focus-stdin <<'__REVIEWER_FOCUS_EOF__'
$ARGUMENTS
__REVIEWER_FOCUS_EOF__
```

---

That report is above. Now act on it:

1. **Triage** every finding — real blocker vs nit vs false positive. codex digs
   but can be wrong: verify each claim against the actual code before touching
   anything.
2. **Fix** the genuine issues yourself (the reviewer never edits). Make the
   smallest correct change per issue.
3. **Account** for the rest: for anything you skip, one line saying why (false
   positive / out of scope / intended).

Finish with a short summary of what you changed and what you deliberately left.
If codex produced no report (e.g. no changes to review, or it errored), say so
and stop — don't invent findings.

_Args after `/reviewer` are forwarded to the reviewer: free text = focus; scope
flags pick what to review (default: working tree vs merge-base with the base
branch); `--spec PATH_OR_URL` points codex at the original issue/spec by link.
Full reference in `README.md` / `review.sh --help`._
