---
name: drop-user-in-file
description: Hand the keyboard to the user so they can edit a file themselves mid-session, in a real nvim popup, then read back what they changed. Use when the user says things like "drop me into <file>", "let me hand-edit X", "open X in nvim for me", "I'll edit this part myself", "pause so I can tweak it", or otherwise wants to make manual edits rather than have you make them. Requires tmux + nvim.
---

# drop-user-in-file

Float an interactive **nvim** session in a tmux `display-popup` at `PATH:LINE`,
**block until the user `:q`s**, then print the before/after unified diff. Use it
whenever the user wants to make an edit by hand instead of dictating it to you —
prose they'd rather write themselves, a fiddly value, a judgement call about
wording, etc.

NOTE: By default, do not drop the user directly into jsonl files with minimal
whitespace, those are hard to read. At the very least, pretty-print the JSONL
so that each key is on a newline. Use your judgement, if the user wants to
_review_ some data, format the jsonl file as markdown so that it's nice to read
and easy to skim. If the user wants to edit a file, leave it as JSONL.

## How to run

Invoke the bundled script via Bash with a **long timeout** (it blocks for the
whole edit session — the user may take minutes):

```bash
~/.claude/skills/drop-user-in-file/drop-user-in-file PATH [LINE]      # one file
~/.claude/skills/drop-user-in-file/drop-user-in-file PATH1 PATH2 ...  # many files
```

- `PATH` — file to open (relative paths resolve against the current working
  directory; the file is created if it doesn't exist yet).
- `LINE` — optional line number to open at (default 1).
- **Multiple files** — pass 2+ paths and each opens in its own nvim **tab**
  (`nvim -p`); the user switches tabs with `gt`/`gT` and returns to Claude with
  `:wqa` (write-all-and-quit). On return, a per-file diff is printed for every
  file. Disambiguation: exactly two args whose second is all-digits is the
  `PATH LINE` form; anything else with 2+ args is multi-file mode.
- Set the Bash tool `timeout` to the max (`600000`). A timeout is not a problem:
  the popup stays open on the user's screen and the user finishes their edit at
  their own pace — just wait for them. The user knows vim: don't explain
  `:wq`/`:q`, don't narrate task ids or timeouts, don't nag them to hurry. Stay
  quiet and wait.

After it returns, **read the printed unified diff** to see exactly what they
changed, and continue from there. Do not re-open the file to "verify" — the diff
is the source of truth.

## What it does / how it works

- Runs from Claude's TTY-less Bash subshell, but `tmux display-popup` talks to
  the tmux _server_, which paints the popup onto the user's attached client.
  `display-popup -E` blocks the invoking shell until nvim exits, so the tool
  call naturally waits for the edit to finish.
- **Window-gated:** if this Claude's tmux window isn't the one the user is
  currently viewing, the popup does _not_ ambush whatever they're looking at.
  Instead the window is renamed `✎ EDIT WAITING — …` and the popup only appears
  once they switch back to it. (No desktop notification, by design.)
- The popup is top-anchored and leaves ~20 rows at the bottom uncovered so the
  user can still read your latest message while editing.
- On return it diffs a pre-edit backup against the saved file and prints the
  full unified diff (never truncated). It reports `no changes` if they `:q`
  without saving, and notes if the file still doesn't exist afterwards.

## Requirements & failure modes

- **Must be inside tmux** — exits with an error if `$TMUX` is unset (Claude's
  Bash subshell has no TTY of its own; tmux is what renders nvim on screen).
- **nvim must be on PATH** — exits with an error otherwise.

If either is missing, tell the user the requirement rather than retrying.
