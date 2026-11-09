---
name: quickplot
description: Quick honest terminal distribution plots (sparkline histogram + box-and-whisker) of numeric data. Use when the user wants a fast in-terminal look at the distribution/spread of some values (e.g. coherence/alignment scores across models) — "histogram of these", "show me the distribution", "plot these numbers", "box plot of", "what do these look like". For throwaway terminal viz, NOT publication plots.
---

# quickplot

Turn raw numbers into a compact unicode **sparkline histogram + box-and-whisker
plot, plus a full numeric summary**, printed in the terminal. For
quick-and-dirty "what does this distribution look like" checks — real/paper
plots happen elsewhere.

Group name on the left, graphics (histogram over box-&-whisker) on the right,
all on a shared fixed x-axis; the full numeric summary is a column-aligned list
below. The histogram is 2 character rows tall by default (16 levels of vertical
resolution, linear — bar heights stay proportional), which makes low-count tail
bins visible without distorting anything; `--rows 1` drops to a compact single
row.

```
200 samples each

Normal                            ▃ ▂█
                     ▁  ▁▂▁▃▄▆▆█▆██████▄█▅▁▂▅ ▃ ▁▁ ▁         <- histogram (2 rows)
                     ├──────────[==┃==]───────────┤          <- box & whisker
Exponential  █
             █▃▆█▅▅▄▃▄▄▃▃▁▂▁▁▂  ▁▁ ▁      ▁
             ├─[==┃===]─────────────────────┤
Uniform       ▃ ▁ ▄▃ ▁   ▃   ▆   ▁▃ ▁▃  ▁█        ▁ ▃▁▁ ▁▃▄
             ▅█▇█▄██▅█▇▇▇█▄▄▇█▇▅▅██▇██▇▇██▅▅▇▅▂▇▄▅█▄███▅███
             ├──────────[===========┃==========]──────────┤
             └──────────┴──────────┴───────────┴──────────┴  <- shared axis (once)
             0.16       24.6       49          75.6     100

Normal:      n=200  min 18.6  q1 41.5  med 49.9  q3 56  max 82.6  mean 49.5  sd 11.2
Exponential: n=200  min 0.16  q1 4.31  med 10.8  q3 21  max 69.9  mean 14.5  sd 13.6
Uniform:     n=200  min 1.22  q1 24.6  med 50.1  q3 75  max  100  mean 50.2  sd 29.5
```

Box & whisker reads `├` min · `[` q1 · `┃` median · `]` q3 · `┤` max. Stacking
several groups lets you eyeball-compare spreads since every box sits on the
same axis.

## The contract — why this is a script, not eyeballing

`plot.py` is the **only** thing allowed to turn the data into a picture or a
summary. It computes the histogram, the box plot, and the full seven-number
summary itself. You run it and **paste its output verbatim**.

Do NOT, separately, describe the distribution in prose ("looks roughly
normal", "Olmo is worse", "tightly clustered"), round the numbers, or report a
subset of them. The user explicitly does not want that layer — the script's
output is the answer. The plot is only a visual aid; the authoritative numbers
are the text summary line, which prints n, min, q1, median, q3, max, mean, and
std for every group. Unparseable values are counted and flagged (`⚠ N
unparseable`), never silently dropped. If they ask a follow-up about the
numbers, answer from that printed summary.

## How to run

Self-contained `uv` script (only dep: `numpy`) — nothing to install. Pass a
file or pipe via stdin:

```bash
~/.claude/skills/quickplot/plot.py data.json
echo '{"Gemma":[...],"Olmo":[...],"Qwen":[...]}' | ~/.claude/skills/quickplot/plot.py --title coherence
cat scores.csv | ~/.claude/skills/quickplot/plot.py
```

Typical flow: the data already exists (a list in the conversation, a column in
a CSV/parquet, an array in a script). Get it into one of the input formats
below — usually by writing a small JSON object to `/tmp` or piping — then run
the script and show what it prints.

## Input formats (auto-detected)

| Input                                    | Result               |
| ---------------------------------------- | -------------------- |
| JSON object `{"Gemma":[..],"Olmo":[..]}` | one panel per key    |
| JSON array `[1,2,3,...]`                 | a single panel       |
| CSV/TSV with a header row of names       | one panel per column |
| plain whitespace/newline numbers         | a single panel       |

For the common "models × metrics" case (Gemma/Olmo/Qwen each scored on
coherence + alignment), the cleanest input is a flat JSON object with one key
per group, e.g. `{"Gemma coherence":[...], "Gemma alignment":[...], ...}`. All
groups share the **same fixed x-range** so the panels are directly comparable.

## Flags

- `--width N` — plot width in characters (default 46)
- `--rows N` — histogram height in character rows (default 2; `1` = compact)
- `--title TEXT` — title printed once above the panels
- `--summary-only` — print just the numeric summary lines, no plot

## Out of scope

Scatter, line, or time-series plots, and anything headed for a paper or slide
deck. This is terminal distribution-at-a-glance only.
