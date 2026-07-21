"""ccbar — a tqdm that draws itself in the Claude Code status line.

Why this exists
---------------
When Claude runs a long job it tends to narrate progress into the transcript
("1/200", "2/200", ...), which is unreadable. Instead, a job runs as a
*background* Bash task with its progress mirrored here. The bar appears live in
the status line, and Claude is only re-invoked when the job exits.

Two ways in
-----------
1. Library: wrap a Python loop in this tqdm subclass (the job cooperates).
2. CLI (`python3 -m ccbar`, or just `ccbar`): watch an external quantity — a
   file's line count, a directory's file count, any command that prints a
   number. The job needs to know nothing about us, which means any process,
   including one that is already running, can have a bar.

How it works
------------
Every tqdm instance mirrors its `format_dict` (tqdm's own internal render state:
n, total, elapsed, rate, prefix, ...) into a JSON file under

    /tmp/claude-pbar-<CLAUDE_CODE_SESSION_ID>/<pid>-<pos>.json

`ccbar.render` globs that directory and replays the state through
`tqdm.format_meter()`, so what the status line shows is genuinely tqdm's own
formatting — real items/second, real ETA — re-rendered at the terminal's
current width rather than the width the job happened to guess.

Writes are throttled and atomic (write-temp-then-rename), so the status line
never reads a half-written file, and a million-iteration loop does not turn into
a million disk writes.

Falls back to being a plain tqdm when CLAUDE_CODE_SESSION_ID is unset, so the
same script still works outside Claude Code.
"""

from __future__ import annotations

import json
import os
import sys
import time

from tqdm import tqdm as _tqdm

__all__ = ["tqdm", "trange", "state_dir", "clear"]

# Minimum seconds between state-file writes. tqdm's display() can fire far
# faster than the status line's 1 Hz refresh, so anything below this is wasted.
_WRITE_INTERVAL = 0.15

# Width the job renders its own fallback bar at. render.py normally re-renders
# at the real terminal width and ignores this; it only matters if render.py
# cannot import tqdm.
_FALLBACK_NCOLS = 72


def state_dir(create: bool = False) -> str | None:
    """Directory holding this session's bar state, or None outside Claude Code."""
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID")
    if not sid:
        return None
    path = os.path.join("/tmp", f"claude-pbar-{sid}")
    if create:
        try:
            os.makedirs(path, exist_ok=True)
        except OSError:
            return None
    return path


def clear() -> None:
    """Remove every bar for this session (used by the SessionEnd hook)."""
    path = state_dir()
    if not path or not os.path.isdir(path):
        return
    for name in os.listdir(path):
        try:
            os.unlink(os.path.join(path, name))
        except OSError:
            pass
    try:
        os.rmdir(path)
    except OSError:
        pass


class _Null:
    """Swallows tqdm's terminal output when there is no terminal to draw on."""

    # tqdm picks ASCII vs Unicode block characters by sniffing file.encoding.
    # The status line renders UTF-8 fine, so claim it here or we get "###" bars.
    encoding = "utf-8"

    def write(self, *_a, **_kw):
        return 0

    def flush(self, *_a, **_kw):
        pass

    def isatty(self):
        return False


class tqdm(_tqdm):  # noqa: N801  (deliberately shadows tqdm.tqdm)
    """tqdm that also mirrors its state into the Claude Code status line."""

    def __init__(self, *args, **kwargs):
        self._cc_dir = state_dir(create=True)
        self._cc_path = None
        self._cc_last_write = 0.0
        self._cc_closed = False

        # Under a background Bash task stderr is a captured log, not a terminal.
        # Drawing there would smear thousands of carriage-return redraws across
        # the log for no benefit, so draw into the void and let the status line
        # be the display. Keep normal tqdm behaviour when a real terminal exists.
        if self._cc_dir is not None and "file" not in kwargs:
            stderr = kwargs.get("file", sys.stderr)
            if not (hasattr(stderr, "isatty") and stderr.isatty()):
                kwargs["file"] = _Null()

        super().__init__(*args, **kwargs)

        if self._cc_dir is not None:
            pos = abs(getattr(self, "pos", 0) or 0)
            self._cc_path = os.path.join(self._cc_dir, f"{os.getpid()}-{pos}.json")
            self._cc_write(force=True)

    # tqdm funnels every redraw through display(); piggy-back on it so we catch
    # update(), set_description(), refresh() and manual n assignment alike.
    def display(self, *args, **kwargs):
        result = super().display(*args, **kwargs)
        self._cc_write()
        return result

    def close(self):
        already = getattr(self, "disable", False)
        super().close()
        if not already and not self._cc_closed:
            self._cc_closed = True
            self._cc_write(force=True, done=True)

    def _cc_write(self, force: bool = False, done: bool = False) -> None:
        if self._cc_path is None:
            return
        now = time.monotonic()
        if not force and (now - self._cc_last_write) < _WRITE_INTERVAL:
            return
        self._cc_last_write = now

        try:
            fmt = dict(self.format_dict)
        except Exception:
            return

        # format_dict is exactly the kwargs format_meter() accepts, so storing it
        # verbatim lets the renderer reproduce this bar faithfully at any width.
        fmt.pop("ncols", None)
        fmt.pop("nrows", None)

        payload = {
            "fmt": fmt,
            "done": done,
            "ts": time.time(),
            "pid": os.getpid(),
            "pos": abs(getattr(self, "pos", 0) or 0),
            "bar": self._cc_fallback_bar(fmt),
        }

        tmp = f"{self._cc_path}.{os.getpid()}.tmp"
        try:
            with open(tmp, "w") as handle:
                json.dump(payload, handle, default=str)
            os.replace(tmp, self._cc_path)  # atomic: readers see old or new, never partial
        except OSError:
            try:
                os.unlink(tmp)
            except OSError:
                pass

    def _cc_fallback_bar(self, fmt: dict) -> str:
        try:
            return self.format_meter(**{**fmt, "ncols": _FALLBACK_NCOLS})
        except Exception:
            return ""


def trange(*args, **kwargs):
    """Status-line-aware `tqdm(range(...))`."""
    return tqdm(range(*args), **kwargs)
