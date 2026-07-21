---
name: pbar
description: Put a live tqdm progress bar (items/second, ETA) in the status line for any long or repetitive job — batch loops, N-item processing, writing files or JSONL shards, downloads, sweeps, evaluations, migrations — instead of spamming the transcript with "1/200", "2/200". Use whenever a job iterates more than ~20 times or runs longer than ~30 seconds. The `ccbar` CLI can watch a growing file or directory, so the job needs no changes at all.
---

# pbar — progress bars in the status line

## When to use this

Any job that loops more than ~20 times or runs longer than ~30 seconds: batch
processing, writing a large file, embedding, downloads, evaluations, sweeps,
migrations, test matrices.

The failure mode this exists to prevent: running the loop in the foreground and
narrating it, so the user reads `1/200`, `2/200`, `3/200` down the transcript.
That is unreadable and it burns a turn per item.

## The rule

**Run the job as a background Bash task and let the bar do the talking.**

Two things have to be true together, or this does not work:

1. `run_in_background: true` on the Bash call. This is what stops the transcript
   spam — Claude is re-invoked once, when the job exits, not per iteration.
2. `ccbar` is watching it. This is what draws the bar.

Then **say nothing until it finishes**. Do not poll it, do not narrate it, do not
read the task output to peek. The user is watching the bar; a text update is
noise. Tell the user in one line that it is running, then let the harness wake
you when it exits.

## Default choice: `ccbar` watches from outside

`ccbar` is on PATH. Reach for this first — **the job needs no changes**, so it
works on shell loops, other people's scripts, and processes you cannot modify.
Point it at a quantity that grows and give it the number to expect.

```bash
# Watch a file being written, and run the job too. Exits with the job's exit code.
ccbar --watch-lines out.jsonl --expect-max 5000 --desc "writing rows" -- python3 build.py

# Watch a directory fill with shards.
ccbar --watch-glob 'shards/*.jsonl' --expect-max 32 --desc "writing shards" -- ./gen.sh

# Watch anything that prints a number; no wrapped command, stop when full.
ccbar --watch 'ls shards/ | wc -l' --expect-max 32 --desc "counting" --until-full

# Classic pipe: one tick per line of stdin.
seq 200 | while read -r i; do work "$i"; echo; done | ccbar --expect-max 200 --desc "working"
```

Sources (pick one): `--watch-lines FILE`, `--watch-glob PATTERN`, `--watch 'CMD'`
(uses the last number CMD prints), or stdin (one tick per line, or `--absolute`
to read each line as the current count).

Ending: `-- CMD` polls while CMD lives and propagates its exit code;
`--until-full` stops at `--expect-max`; stdin modes stop at EOF.

Other flags: `--interval SEC` (default 0.5), `--unit`, `--echo`, `--demo N`.

## When the loop is Python you control

Wrapping the loop gives an exact count instead of an inferred one, which is
worth it when there is no file or directory that reflects progress.

```python
import os, sys
sys.path.insert(0, os.path.expanduser("~/.claude/tools/pbar"))
from ccbar import tqdm   # drop-in for tqdm.tqdm; trange also available

for item in tqdm(items, desc="embedding"):
    ...
```

Ordinary tqdm otherwise — `total=`, `unit=`, `update(n)`, `set_description()`,
nesting via `position=` all behave normally.

## Writing a good `desc`

It is the only prose the user sees, so make it plain English ("writing shards",
not "proc_batch"). **Keep it under ~28 characters** — longer ones are clamped
with an ellipsis, because a long label squeezes the bar and can push the rate off
the right edge.

## Checking it works

```bash
ccbar --demo 100 --desc "smoke test"     # with run_in_background: true
```

## Notes and limits

- **Requires `statusLine.refreshInterval`** in settings.json (currently `1`
  second). Without it the status line only redraws when an assistant message
  lands — which is precisely never during a long background job.
- Up to 3 bars show at once; more are counted as `+N more`. Parallel jobs and
  nested bars each get their own row.
- **A slow bar is never dropped, however long it goes between ticks.** A bar
  lives as long as its owning process lives, checked against the operating
  system rather than inferred from silence. Elapsed keeps ticking through quiet
  stretches, so a job that generates for ten minutes between updates still shows
  a visibly live bar. **Do not build self-repainting workarounds** — an earlier
  version reaped quiet-but-healthy bars after 5 minutes, and that is fixed.
- If the process dies without finishing, the bar is flagged `⚠️ (job exited)`
  for 30 seconds rather than silently vanishing — so a bar disappearing without
  that marker means it finished, not that it crashed. A finished bar lingers 8
  seconds at 100%, then clears.
- `--expect-max` is a guess, and that is fine — it only sets the denominator and
  the ETA. If the real count overshoots, tqdm keeps going past 100% rather than
  breaking.
- Outside Claude Code (`CLAUDE_CODE_SESSION_ID` unset) the bar degrades to plain
  tqdm on stderr, so the same command still works in a normal terminal.
- The bar is the user-facing output; tqdm's own stderr drawing is suppressed when
  there is no terminal, keeping the background task log clean.

## Where the code lives

`~/.claude/tools/pbar/ccbar/` — `__init__.py` (the tqdm subclass), `__main__.py`
(the CLI), `render.py` (the status line renderer). The `ccbar` on PATH is a shim
at `~/.local/bin/ccbar`. The status line calls `ccbar.render` from
`~/.claude/statusline.sh`, which needs `statusLine.refreshInterval` in
`~/.claude/settings.json`.
