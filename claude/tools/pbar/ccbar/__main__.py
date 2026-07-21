"""ccbar CLI — put a status-line progress bar on things, from the shell.

The useful trick here is that the watched job does not have to cooperate. Point
ccbar at a quantity that grows — lines in a file, files in a directory, any
command that prints a number — and it polls that quantity and draws the bar. So
anything can have a progress bar, including a process that is already running
and code you cannot or do not want to modify.

Modes
-----
  --watch-lines FILE    poll the number of lines in FILE
  --watch-glob PATTERN  poll the number of paths matching PATTERN
  --watch 'CMD'         poll CMD's output, using the last number it prints
  (default)             read stdin, one tick per line
  --absolute            read stdin, each line is the current value (not a tick)

Ending
------
  -- CMD ARGS...        run CMD, poll while it lives, exit with its exit code
  --until-full          exit once the count reaches --expect-max
  (stdin modes)         exit at EOF

Examples
--------
  # Watch a JSONL file being written by a job we also launch.
  ccbar --watch-lines out.jsonl --expect-max 5000 -- python3 build_dataset.py

  # Watch a directory fill up, for a job started elsewhere.
  ccbar --watch-glob 'shards/*.jsonl' --expect-max 32 --until-full

  # Any command that prints a number.
  ccbar --watch 'ls shards/ | wc -l' --expect-max 32 --until-full

  # Classic pipe: one tick per line.
  seq 200 | while read -r i; do work "$i"; echo; done | ccbar --expect-max 200
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import subprocess
import sys
import time

from . import tqdm

_NUMBER = re.compile(r"-?\d+(?:\.\d+)?")


def _probe_lines(path: str) -> int:
    """Count lines in a file, tolerating it not existing yet."""
    try:
        with open(path, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def _probe_glob(pattern: str) -> int:
    try:
        return len(glob.glob(pattern))
    except Exception:
        return 0


def _probe_command(cmd: str) -> int:
    """Run cmd and take the last number it prints.

    Last rather than first because the common shapes (`wc -l`, `ls | wc -l`)
    put the count at the end, sometimes after a filename or whitespace.
    """
    try:
        out = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=10
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return 0
    found = _NUMBER.findall(out)
    if not found:
        return 0
    try:
        return int(float(found[-1]))
    except ValueError:
        return 0


def _advance(bar, value: int) -> None:
    """Move the bar to an absolute value, keeping tqdm's rate estimate sane."""
    delta = value - bar.n
    if delta > 0:
        # Prefer update() over assigning n: it feeds tqdm's smoothed rate
        # estimate, which is what makes it/s and the ETA meaningful.
        bar.update(delta)
    elif delta < 0:
        # The quantity shrank (file truncated, files deleted). Rewind rather
        # than letting update() see a negative delta.
        bar.n = value
        bar.refresh()
    else:
        # No change, but still refresh: it keeps elapsed and the ETA ticking,
        # and keeps the state file's mtime fresh so a slow-but-alive job is not
        # misreported as stalled.
        bar.refresh()


def _run(args: argparse.Namespace, probe, wrapped: list[str]) -> int:
    proc = None
    if wrapped:
        try:
            proc = subprocess.Popen(wrapped)
        except OSError as exc:
            print(f"ccbar: cannot run {wrapped[0]}: {exc}", file=sys.stderr)
            return 127

    bar = tqdm(total=args.expect_max, desc=args.desc, unit=args.unit)
    try:
        while True:
            _advance(bar, probe())
            if proc is not None:
                if proc.poll() is not None:
                    break
            elif args.until_full and args.expect_max and bar.n >= args.expect_max:
                break
            time.sleep(args.interval)
        _advance(bar, probe())  # final sample, so the bar lands on the true count
    except KeyboardInterrupt:
        return 130
    finally:
        bar.close()
        if proc is not None and proc.poll() is None:
            proc.terminate()

    return proc.returncode if proc is not None else 0


def _run_stdin(args: argparse.Namespace) -> int:
    bar = tqdm(total=args.expect_max, desc=args.desc, unit=args.unit)
    try:
        for line in sys.stdin:
            if args.echo:
                sys.stdout.write(line)
            if args.absolute:
                found = _NUMBER.findall(line)
                if found:
                    _advance(bar, int(float(found[-1])))
            else:
                bar.update(1)
    except KeyboardInterrupt:
        return 130
    finally:
        bar.close()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ccbar",
        description="Draw a tqdm progress bar in the Claude Code status line.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--expect-max",
        "--total",
        dest="expect_max",
        type=int,
        default=None,
        metavar="N",
        help="the count the bar is heading for (tqdm's total)",
    )
    parser.add_argument("--desc", default="", help="plain-English label, keep under ~28 chars")
    parser.add_argument("--unit", default="it", help="unit name (default: it)")

    source = parser.add_mutually_exclusive_group()
    source.add_argument("--watch-lines", metavar="FILE", help="poll line count of FILE")
    source.add_argument("--watch-glob", metavar="PATTERN", help="poll count of matching paths")
    source.add_argument("--watch", metavar="CMD", help="poll CMD's output for a number")

    parser.add_argument(
        "--interval", type=float, default=0.5, metavar="SEC", help="poll interval (default: 0.5)"
    )
    parser.add_argument(
        "--until-full",
        action="store_true",
        help="in watch modes with no wrapped command, exit once the count reaches --expect-max",
    )
    parser.add_argument(
        "--absolute",
        action="store_true",
        help="stdin mode: each line is the current count, not a tick",
    )
    parser.add_argument("--echo", action="store_true", help="stdin mode: forward stdin to stdout")
    parser.add_argument(
        "--demo", type=int, metavar="N", default=None, help="run a synthetic N-step bar"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)

    # Everything after a bare "--" is the command to run and watch.
    wrapped: list[str] = []
    if "--" in argv:
        cut = argv.index("--")
        argv, wrapped = argv[:cut], argv[cut + 1 :]

    args = build_parser().parse_args(argv)

    if args.demo is not None:
        for _ in tqdm(range(args.demo), desc=args.desc or "demo", unit=args.unit):
            time.sleep(0.05)
        return 0

    if args.watch_lines:
        probe = lambda: _probe_lines(args.watch_lines)  # noqa: E731
    elif args.watch_glob:
        probe = lambda: _probe_glob(args.watch_glob)  # noqa: E731
    elif args.watch:
        probe = lambda: _probe_command(args.watch)  # noqa: E731
    else:
        if wrapped:
            print(
                "ccbar: -- CMD needs a watch source (--watch-lines/--watch-glob/--watch)",
                file=sys.stderr,
            )
            return 2
        if sys.stdin.isatty():
            build_parser().print_help()
            return 2
        return _run_stdin(args)

    if not wrapped and not args.until_full:
        # Otherwise it would poll forever with nothing to end it.
        if args.expect_max:
            args.until_full = True
        else:
            print(
                "ccbar: a watch mode needs either -- CMD, or --until-full with --expect-max",
                file=sys.stderr,
            )
            return 2

    return _run(args, probe, wrapped)


if __name__ == "__main__":
    sys.exit(main())
