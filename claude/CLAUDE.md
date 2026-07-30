# HI CLAUDE

can you see this? let me know if you can, i'm not sure if it's working

## Preferred tools

Rust, ruff, uv, ty, zsh, tmux, neovim, fd, ripgrep, firefox, iterm2, bun, Skim
(PDF viewer), homebrew, hyperfine.

Note that you won't use all of these. But if you need to, I'd prefer you to use
the tools listed above.

## Precommit hooks

In any project with javascript/python/rust/shell scripts/tests, you should
install comprehensive pre-commit hooks that run _all_ tests and do a full lint
and format over the code (auto-fixing if possible).

## Commit early and often

Many small incremental commits please, with nice descriptions. You should
commit before and after any changes, so that we can move around git history as
needed.

## Use `git -C`, not `cd; git`

Do _not_ use `cd <dir>; git <subcommand>` not `cd <dir> && git <subcommand>`,
claude-code harness has a bug that causes this to hang ~indefinitely.

## Interactive editing: `drop-user-in-file`

When the user wants to hand-edit a file mid-session (or asks to be "dropped
into" a file), use the **`drop-user-in-file` skill** — it floats an
interactive nvim popup at PATH:LINE, blocks until they `:q`, and returns the
diff. Full usage and requirements live in its `SKILL.md`
(`~/.claude/skills/drop-user-in-file/`).

## Long-running jobs: `ccbar` / the `pbar` skill

Never narrate a loop at me ("1/200", "2/200", ...). For any job that iterates
more than ~20 times or runs longer than ~30 seconds, run it as a background task
under **`ccbar`** (on PATH), which draws a real tqdm bar (items/second, ETA) in
the status line and wakes you only when the job exits:

    ccbar --watch-lines out.jsonl --expect-max 5000 --desc "writing rows" -- python3 build.py
    ccbar --watch-glob 'shards/*.jsonl' --expect-max 32 --desc "writing shards" -- ./gen.sh

The job needs no changes — `ccbar` just watches a file or directory grow. Full
usage lives in the **`pbar` skill**'s `SKILL.md` (`~/.claude/skills/pbar/`).

## TODO list

I'll _often_ give you multiple things, you should make _heavy_ usage of your
TODO tool. Add tasks _immediately_ to your TODO list (don't wait to complete
your task, you often forget about what I've said by the time you finish them.

## AI Writing

If I ask you for prose or written work (I don't often), you should read
https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing and _not_ do
anything on that list.

You should also recall Steven Pinker's "Sense of Style" when writing and abide
by those principles.

## Keywords

- **ASSERT X** := If X is not true, make it true. If it is true, tell the user that it's true and move on.
- **TODO X** := add X _immediately_ to your internal TODO list. Do not complete your existing task first, do not run any other tool calls. **TODO X** requires immediate attention

## Abbreviation Abstinence

You are absolutely banned from using abbreviations, acronyms, or anything less
than the full and proper names for things when talking to me. Do not use `emb`,
not even in a table where you think space might be tight. You can use short
words in code, but _never_ in your responses to me or things that you suspect
I'll read. Never `coh`, always `coherence`. Never `emb`, always `embodiment`.

## Tombstone comments & Comment hygiene

You will default to adding _lots_ of very verbose self-explanatory comments and
also tombstone comments which refer to things that no longer exist. do not do
this. I've put examples below. These should all be removed and not be put in
the codebase at all, they just increase the diff and increase noise, making
review difficult. I've formatted the examples as diffs so you know what's
better

### Tombstone comments

```diff
-# ── lr (the round-1 good band) ───────────────────────────────────
   lr:
     min: 8e-4
     max: 3e-3
```

```diff
-# A pooled mean+max summary of the whole map, concatenated onto each
-# per-tile feature column so the windowed heads also see grid-global
-# context (the #290 pathway). 0 disables it.
+# Mean+max summary, disabled if global_feat_dim == 0
 self.global_feat_dim = global_feat_dim
 if global_feat_dim > 0:
```

```diff
-"""model dim of the self-attention stage over the encoded map (the 121 grid
-cells become tokens, so full attention is cheap and every head gets
-grid-global information in one hop). The SFT arch sweep (sn7fd8l8) found
-this the dominant win; 128 was the best value. 0 disables the stage,
-recovering a conv-only ablation baseline. Int not bool for W&B sweeps."""
+"""Number of heads attenting to the full size x size grid. if zero, transformer not used"""
 attn_heads: int = 8
```

```diff
 lr: float = 1e-3
-"""peak learning rate (after warmup, before cosine decay). ~1e-3 is the
-centre of the 91w8vyea attention-arch sweep's top-cluster (8.6e-4–1.5e-3,
-best 8.95e-4); the old 3.242e-3 predated attention (a #244-era conv-only
-sweep) and sat above the [8e-4, 3e-3] band this architecture was swept in."""
+"""peak learning rate (after warmup, before cosine decay)"""
```

### Self explanatory comments

```diff
-# End-of-turn probability — sigmoid of the eot head's single
-# logit. Surfaced in the side panel so the user can see when
-# the model thinks the factory is finished.
 eot_prob = float(torch.sigmoid(agent.eot_logit(encoded_BCWH, g_1G)).item())
```

```diff
-# MultiheadAttention needs dim % heads == 0; snap heads down to the
-# largest divisor <= the requested count so any (dim, heads) the sweep
-# samples is runnable rather than crashing the run.
+# Don't crash if dim % heads != 0, just clamp it
 while dim % heads != 0 and heads > 1:
     heads -= 1

```

```diff
-# ── lr (the round-1 good band) ───────────────────────────────────
   lr:
     min: 8e-4
     max: 3e-3
```

## Maximal parallelisation

All tasks _must_ be done in parallel to the greatest extent possible, if you
can make multiple API calls at once, do so! You should default to using up to
~30 network requests at once.

## Incremental feedback

For any task or script that involves network requests (e.g. API calls, weight
downloads, connecting with a server, downloading a file, etc), you _must_ use a
progress bar of some kind (tqdm if using python) to visualise the progress, and
this progress should be as fine-grained as possible. If there are multiple
independent things happening (e.g. processing multiple items in a file), then
you _must_ write incremental results to disk as soon as they land, do not
buffer them in memory, persist them atomically and immediately.
