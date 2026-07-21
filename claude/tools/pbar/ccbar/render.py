"""Render this session's live ccbar progress bars as status line rows.

Called by statusline.sh as:  python3 -m ccbar.render <session_id>

Prints one row per active bar (nothing at all when no job is running, so the
status line is unchanged during normal work). Re-renders each bar through
tqdm's own format_meter() at the real terminal width, which Claude Code hands
us in $COLUMNS.

Liveness
--------
A bar is kept because its owning process is alive, NOT because its counter moved
recently. Those are different things: a job that generates for six minutes
between ticks is perfectly healthy, and an earlier version of this file reaped
exactly that case after a 5-minute silence — dropping live bars off the status
line and teaching callers to invent self-repainting workarounds. We have the pid,
so we ask the operating system instead of guessing from silence.

To keep a slow bar visibly alive, elapsed is extrapolated from when the job last
wrote its state. The clock therefore keeps ticking through long quiet stretches
even though the job is not touching the file. This is honest: elapsed really is
advancing, n really is not.

Contract with the status line: never fail, never hang, never print junk. Any
unexpected error exits 0 with no output, leaving the rest of the status line
intact.
"""

from __future__ import annotations

import glob
import json
import os
import sys
import time

# A finished bar lingers this long so you actually see it hit 100%, then clears.
DONE_LINGER = 8.0
# A bar whose process is gone but which never closed: the job crashed or was
# killed. Say so briefly, then clear it.
ORPHAN_LINGER = 30.0
# Don't let a fan-out of parallel jobs push the prompt off screen.
MAX_BARS = 3

# Columns to keep clear of $COLUMNS. Budget: 2 for the leading glyph (emoji are
# double-width), 1 for its space, ~3 for the interface's own spacing (padding is
# documented as additional to a built-in margin), and 2 spare for terminals that
# measure emoji width differently.
#
# Deliberately generous, because the failure is lopsided: guess too small and
# tqdm merely draws fewer block characters; guess too large and Claude Code
# truncates the tail, which is where the rate and ETA live — the whole point of
# the bar. Override with CCBAR_RESERVE if a terminal disagrees.
RESERVE = 8

# A long desc squeezes the bar and can push the rate off the end. Clamp it.
MAX_DESC = 28

DIM = "\033[2m"
RESET = "\033[0m"
GREEN = "\033[32m"
CYAN = "\033[36m"
YELLOW = "\033[33m"


def terminal_width() -> int:
    """Claude Code sets COLUMNS for status line scripts (v2.1.153+)."""
    for source in (os.environ.get("COLUMNS"), os.environ.get("CC_COLUMNS")):
        try:
            width = int(source)
            if width > 20:
                return width
        except (TypeError, ValueError):
            continue
    return 80


def alive(pid: object) -> bool:
    """Is the process that owns this bar still running?"""
    try:
        pid = int(pid)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return False
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)  # signal 0: existence check only, delivers nothing
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # exists, just not ours to signal
    except OSError:
        return False


def load(path: str) -> dict | None:
    try:
        with open(path) as handle:
            payload = json.load(handle)
    except (OSError, ValueError):
        return None
    if not isinstance(payload, dict) or "fmt" not in payload:
        return None
    payload["_path"] = path
    return payload


def reap(path: str) -> None:
    try:
        os.unlink(path)  # self-cleaning; no cron, no sweeper
    except OSError:
        pass


def stamp_died(path: str, payload: dict, died: float) -> None:
    """Record when we first noticed the owning process was gone.

    The "job exited" grace period has to run from the moment of *detection*, not
    from the job's last write: a job that was legitimately quiet for ten minutes
    and then crashed is already well past any grace measured from its last tick,
    so it would be reaped instantly and vanish without explanation. This renderer
    is stateless — a fresh process every second — so the observation has to go
    somewhere durable. Safe to write: the owner is dead, nobody else is writing.
    """
    data = {key: value for key, value in payload.items() if not key.startswith("_")}
    data["died_ts"] = died
    tmp = f"{path}.render.tmp"
    try:
        with open(tmp, "w") as handle:
            json.dump(data, handle, default=str)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def render_bar(payload: dict, ncols: int) -> str:
    fmt = dict(payload.get("fmt") or {})
    fmt["ncols"] = ncols
    prefix = fmt.get("prefix") or ""
    if len(prefix) > MAX_DESC:
        fmt["prefix"] = prefix[: MAX_DESC - 1] + "…"

    # Keep the clock honest between the job's writes, so a slow-but-alive bar
    # visibly ticks instead of looking frozen. Rate and ETA are left alone: they
    # reflect measured throughput, which is still the best available estimate.
    if payload.get("_tick"):
        try:
            fmt["elapsed"] = float(fmt.get("elapsed") or 0) + payload["_age"]
        except (TypeError, ValueError):
            pass

    try:
        from tqdm import tqdm

        return tqdm.format_meter(**fmt)
    except Exception:
        # tqdm missing or a format_dict key this tqdm version rejects: fall back
        # to the bar the job pre-rendered at its own guessed width.
        return str(payload.get("bar") or "")


def main(argv: list[str]) -> int:
    if not argv:
        return 0
    state = os.path.join("/tmp", f"claude-pbar-{argv[0]}")
    if not os.path.isdir(state):
        return 0

    now = time.time()
    bars = []
    for path in glob.glob(os.path.join(state, "*.json")):
        payload = load(path)
        if payload is None:
            continue
        age = max(0.0, now - float(payload.get("ts") or 0))
        done = bool(payload.get("done"))
        running = alive(payload.get("pid"))

        if done:
            # Finished cleanly. Hold it at 100% briefly, then clear.
            if age > DONE_LINGER:
                reap(path)
                continue
            payload["_state"] = "done"
        elif running:
            # Alive. Keep it, however long it has been quiet — a silent job is
            # not a dead job, and this is the case the old 5-minute cutoff broke.
            payload["_state"] = "running"
        else:
            # Process gone without closing the bar: crashed, killed, or OOMed.
            # Grace runs from detection, not from the job's last write.
            died = payload.get("died_ts")
            if died is None:
                died = now
                stamp_died(path, payload, died)
            try:
                expired = (now - float(died)) > ORPHAN_LINGER
            except (TypeError, ValueError):
                expired = True
            if expired:
                reap(path)
                continue
            payload["_state"] = "orphan"

        payload["_age"] = age
        payload["_tick"] = payload["_state"] == "running"
        bars.append(payload)

    if not bars:
        return 0

    bars.sort(key=lambda item: (item.get("pos", 0), item.get("pid", 0)))
    overflow = len(bars) - MAX_BARS
    width = terminal_width()

    try:
        reserve = int(os.environ.get("CCBAR_RESERVE", RESERVE))
    except ValueError:
        reserve = RESERVE

    for payload in bars[:MAX_BARS]:
        state = payload["_state"]
        if state == "orphan":
            glyph, colour = "⚠️", YELLOW
            suffix = f"  {DIM}(job exited){RESET}"
            reserved = reserve + 14
        elif state == "done":
            glyph, colour, suffix, reserved = "✅", GREEN, "", reserve
        else:
            glyph, colour, suffix, reserved = "⏳", CYAN, "", reserve

        text = render_bar(payload, max(24, width - reserved))
        if not text:
            continue
        print(f"{colour}{glyph} {text}{RESET}{suffix}")

    if overflow > 0:
        print(f"{DIM}   +{overflow} more bar(s) running{RESET}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception:
        sys.exit(0)  # a broken bar must never break the status line
