# reviewer

Adversarial, **read-only** code review powered by `codex exec`. Hands a diff (and
optionally the original issue/spec, *by link*) to codex and asks it to hunt for
bugs, inconsistencies and mistakes. codex can read the entire repository and run
`git`/`rg`/`cat` to verify its suspicions, but the read-only sandbox means it
**cannot edit, create or delete anything** — it reports findings only.

Two ways in:

- **`/reviewer [args]`** (the skill) — kicks off codex on the current diff
  immediately and injects the report into the conversation for Claude to act on.
  See `SKILL.md`.
- **`review.sh` directly** — the engine, usable from any shell or by Claude as a
  Bash call.

## `review.sh` usage

```bash
review.sh [--spec PATH_OR_URL]... [scope] [options] ["focus text"]
```

### Scope (pick at most one; default = auto)

- **(default/auto)** — working tree vs the merge-base with the base branch:
  committed branch work **plus** uncommitted WIP. On the base branch itself this
  is just your WIP (falls back to the last commit if the tree is clean).
- `--uncommitted` — only staged + unstaged + untracked changes.
- `--commit SHA` — only the changes introduced by one commit.
- `--range A..B` / `--range main...HEAD` — an explicit git range.

### Options

- `--spec PATH_OR_URL` — the original issue / spec / bug report the change is
  meant to satisfy (repeatable). **Always a link, never a paraphrase**, so the
  review can't be biased by a retelling. Local paths are passed for codex to read
  directly; URLs (incl. GitHub issue/PR links) are fetched verbatim via `gh`
  (falling back to `curl`). If an explicitly-supplied spec can't be
  resolved/fetched, the script aborts *before* spending quota.
- `--base BRANCH` — base branch for auto scope (autodetected otherwise).
- `--model MODEL` — codex model override (default: codex's configured model).
- `-C, --cd DIR` — repo directory (default: current dir).
- `--focus TEXT` — extra reviewer instructions (equivalently, trailing free text).
- `--focus-stdin` — read the focus from stdin (only if stdin isn't a terminal),
  so a caller can feed arbitrary text — quotes, `$`, backticks, globs — via a
  heredoc without the shell re-parsing it. How the `/reviewer` skill forwards
  your prompt. An explicit `--focus` wins.
- `--quiet, -q` — print only the banner + final report on stdout; codex's live
  event stream is suppressed (kept in a log). Used by the `/reviewer` skill.
- `--dry-run` — print the banner, assembled prompt and codex command; spend
  nothing. Use to preview.
- `-h, --help` — full help.

### Large diffs

Diffs over **200 lines** are handed to codex as a `--stat` summary plus the exact
git command to reproduce the full diff; codex reads the real diff itself via its
read-only repo access. This keeps the prompt small and avoids dumping thousands
of lines (e.g. large untracked data dirs the default scope pulls in). Smaller
diffs are embedded inline.

### Kickoff banner

Before codex starts, the script prints the diff endpoints and size, e.g.:

```
reviewer: diff to review — HEAD (eaa6b52, my-feature-branch) vs main (4a31ccb), incl. uncommitted WIP
reviewer: +5 / -1 across 2 file(s) · focus: the retry logic
```

The `+/-` counts come from a hunk-aware counter (verified against
`git diff --numstat`). Glance at it — if the size looks wrong, narrow the scope.

## Cost

Running a real review spends the user's `codex`/OpenAI quota. A `/reviewer`
invocation is itself the go-ahead. A `--dry-run` is free. If Claude decides to
review its *own* work unprompted, it should get a quick go-ahead first.

## The reviewer never edits

codex only reports. Fixes are Claude's job (or yours) — then optionally re-run
the reviewer to confirm.
