#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.9"
# dependencies = ["numpy"]
# ///
"""
quickplot — numbers in, honest unicode plot out.

The contract: this script is the ONLY thing that turns data into a picture.
Name on the left, graphics (histogram over box plot) on the right, shared axis:

  Normal                   ▃ ▂█
                ▁ ▁▂▃▄▆█▆██████▄▅▁▂ ▃ ▁          <- histogram (2 rows, linear)
                ├──────[==┃==]──────┤            <- box & whisker
                └────┴────┴────┴────┴            <- shared axis (once, at bottom)
                18.6     ...           82.6
  Normal: n=200  min 18.6  q1 41.5  med 49.9 ...  <- aligned numeric summary below

The full seven-number summary + n is printed as TEXT, columns right-aligned —
the plot is only a visual aid, so nothing can be hidden, rounded away, or
editorialised. If a value can't be parsed it is COUNTED and reported, never
silently dropped.

Input (file arg or stdin), auto-detected:
  1. JSON object   {"Gemma":[..], "Olmo":[..]}  -> one panel per key
  2. JSON array    [1, 2, 3, ...]                -> a single panel
  3. CSV / TSV     header row of names, rows...  -> one panel per column
  4. Plain numbers  whitespace/newline separated -> a single panel

All groups share ONE fixed x-range so panels are directly comparable.

Usage:
  ./plot.py data.json
  cat scores.csv | ./plot.py
  echo '{"a":[1,2,3],"b":[2,2,9]}' | ./plot.py --title coherence
Flags:
  --width N       plot width in chars (default 46)
  --rows N        histogram height in character rows (default 2; 1 = compact)
  --title TEXT    title printed once above the panels
  --summary-only  print just the numeric summary lines, no plot
"""

import sys
import json
import math
import argparse

import numpy as np

SPARK = " ▁▂▃▄▅▆▇█"


# --------------------------- input parsing ---------------------------------
def parse_numbers(tokens):
    vals, bad = [], 0
    for t in tokens:
        t = str(t).strip()
        if t == "":
            continue
        try:
            x = float(t)
        except ValueError:
            bad += 1
            continue
        if math.isfinite(x):
            vals.append(x)
        else:
            bad += 1
    return np.array(vals, dtype=float), bad


def _is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False


def load(text):
    text = text.strip()
    if not text:
        sys.exit("quickplot: no input data on stdin/file")
    if text[0] in "[{":
        try:
            obj = json.loads(text)
        except json.JSONDecodeError as e:
            sys.exit(f"quickplot: input looks like JSON but failed to parse: {e}")
        if isinstance(obj, dict):
            out = []
            for k, v in obj.items():
                if not isinstance(v, list):
                    sys.exit(f"quickplot: JSON value for {k!r} is not a list")
                vals, bad = parse_numbers(v)
                out.append((str(k), vals, bad))
            return out
        if isinstance(obj, list):
            vals, bad = parse_numbers(obj)
            return [("data", vals, bad)]
        sys.exit("quickplot: top-level JSON must be an object or array")
    lines = [ln for ln in text.splitlines() if ln.strip() != ""]
    sep = "\t" if "\t" in lines[0] else ("," if "," in lines[0] else None)
    if sep is not None and not all(_is_number(h) for h in lines[0].split(sep)):
        header = [h.strip() for h in lines[0].split(sep)]
        cols = {h: [] for h in header}
        for ln in lines[1:]:
            cells = [c.strip() for c in ln.split(sep)]
            for i, h in enumerate(header):
                cols[h].append(cells[i] if i < len(cells) else "")
        out = []
        for h in header:
            vals, bad = parse_numbers(cols[h])
            out.append((h, vals, bad))
        return out
    vals, bad = parse_numbers(text.replace(",", " ").split())
    return [("data", vals, bad)]


# ------------------------------ rendering ----------------------------------
def fmt(v):
    a = abs(v)
    if a >= 1000:
        return f"{v / 1000:.1f}k".replace(".0k", "k")
    if a >= 100:
        return f"{v:.0f}"
    if a >= 1:
        return f"{v:.3g}"
    return f"{v:.2g}"


def col(x, lo, hi, W):
    return W // 2 if hi == lo else int(round((x - lo) / (hi - lo) * (W - 1)))


def spark_rows(vals, lo, hi, W, rows=2):
    # `rows` stacked sparkline rows => rows*8 levels of vertical resolution,
    # linear (bar heights stay proportional). Returns lines top-to-bottom.
    counts, _ = np.histogram(vals, bins=W, range=(lo, hi))
    cmax = counts.max() or 1
    levels = rows * 8
    heights = [min(levels, int(round(c / cmax * levels))) for c in counts]
    grid = []
    for ri in range(rows):  # ri=0 is the bottom row
        grid.append("".join(SPARK[max(0, min(8, h - 8 * ri))] for h in heights))
    return list(reversed(grid))  # top row first


def box_row(vals, lo, hi, W):
    # ├──── whisker ────[==== median ┃ ====]──── whisker ────┤
    q1, med, q3 = np.percentile(vals, [25, 50, 75])
    mn, mx = vals.min(), vals.max()
    row = [" "] * W
    a, b = col(mn, lo, hi, W), col(mx, lo, hi, W)
    for c in range(a, b + 1):
        row[c] = "─"
    row[a], row[b] = "├", "┤"
    lo_box, hi_box = col(q1, lo, hi, W), col(q3, lo, hi, W)
    for c in range(lo_box, hi_box + 1):
        row[c] = "="
    row[lo_box], row[hi_box] = "[", "]"
    row[col(med, lo, hi, W)] = "┃"
    return "".join(row)


def axis_rows(lo, hi, W, nticks=5):
    ticks = [int(round(i / (nticks - 1) * (W - 1))) for i in range(nticks)]
    line = ["─"] * W
    for t in ticks:
        line[t] = "┴"
    labels = [" "] * (W + 8)
    last = -2
    for i, t in enumerate(ticks):
        s = fmt(lo + (t / (W - 1)) * (hi - lo))
        start = 0 if i == 0 else (t - len(s) + 1 if i == nticks - 1 else t)
        start = max(last + 2, min(start, W + 8 - len(s)))
        for j, ch in enumerate(s):
            labels[start + j] = ch
        last = start + len(s) - 1
    return "└" + "".join(line)[1:], "".join(labels).rstrip()


SUMMARY_COLS = ["n", "min", "q1", "med", "q3", "max", "mean", "sd"]


def summary_block(groups, gut):
    # One line per group, numeric columns right-aligned to a shared width so
    # they line up vertically regardless of how many digits each value has.
    rows = []
    for label, vals, bad in groups:
        if len(vals) == 0:
            rows.append((label, None, bad))
            continue
        n = len(vals)
        q1, med, q3 = np.percentile(vals, [25, 50, 75])
        std = vals.std(ddof=1) if n > 1 else 0.0
        fields = {
            "n": str(n),
            "min": fmt(vals.min()),
            "q1": fmt(q1),
            "med": fmt(med),
            "q3": fmt(q3),
            "max": fmt(vals.max()),
            "mean": fmt(vals.mean()),
            "sd": fmt(std),
        }
        rows.append((label, fields, bad))
    width = {
        k: max((len(f[k]) for _, f, _ in rows if f), default=1) for k in SUMMARY_COLS
    }
    lines = []
    for label, fields, bad in rows:
        prefix = (label + ":").ljust(gut + 1)
        tag = f"  ⚠ {bad} unparseable" if bad else ""
        if fields is None:
            lines.append(f"{prefix} n=0 (no usable numbers){tag}")
            continue
        cells = [
            f"{k}={fields[k]:>{width[k]}}"
            if k == "n"
            else f"{k} {fields[k]:>{width[k]}}"
            for k in SUMMARY_COLS
        ]
        lines.append(prefix + " " + "  ".join(cells) + tag)
    return lines


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("file", nargs="?")
    ap.add_argument("--width", type=int, default=46)
    ap.add_argument(
        "--rows",
        type=int,
        default=2,
        help="histogram height in character rows (default 2)",
    )
    ap.add_argument("--title", default="")
    ap.add_argument("--summary-only", action="store_true")
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return

    text = open(args.file).read() if args.file else sys.stdin.read()
    groups = load(text)
    W = args.width

    nonempty = [v for _, v, _ in groups if len(v)]
    if nonempty:
        allv = np.concatenate(nonempty)
        lo, hi = float(allv.min()), float(allv.max())
        if lo == hi:
            lo, hi = lo - 0.5, hi + 0.5
    else:
        lo = hi = None

    # Name on the left, graphics (histogram over box plot) on the right.
    gut = max((len(label) for label, _, _ in groups), default=4)
    indent = " " * gut + "  "

    print()
    if args.title:
        print(args.title + "\n")
    if not args.summary_only and lo is not None:
        for label, vals, bad in groups:
            if len(vals):
                spark = spark_rows(vals, lo, hi, W, args.rows)
                print(f"{label.ljust(gut)}  {spark[0]}")
                for extra in spark[1:]:
                    print(f"{indent}{extra}")
                print(f"{indent}{box_row(vals, lo, hi, W)}")
            else:
                print(f"{label.ljust(gut)}  (no data)")
        line, labels = axis_rows(lo, hi, W)
        print(indent + line)
        print(indent + labels)
        print()

    # Summary stats as a plain list of lines below the graphics, columns aligned.
    for ln in summary_block(groups, gut):
        print(ln)
    print()


if __name__ == "__main__":
    main()
