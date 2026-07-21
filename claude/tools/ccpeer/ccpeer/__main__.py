"""ccpeer CLI — list / send / whoami."""

from __future__ import annotations

import argparse
import json
import sys

from . import (
    SESSIONS_DIR,
    PeerError,
    inject,
    pane_for_pid,
    prepare,
    resolve,
    self_entry,
    self_session_id,
    sessions,
)


def cmd_list(args) -> int:
    me = self_session_id()
    rows = sessions(include_dead=args.all)
    if args.json:
        for r in rows:
            r["is_self"] = r.get("sessionId") == me
            r["pane"] = pane_for_pid(r["pid"]) if r.get("_live") else None
            r["reachable"] = bool(r.get("_live") and r["pane"] and not r["is_self"])
        print(json.dumps(rows, indent=2, default=str))
        return 0

    if not rows:
        print("No Claude Code sessions registered.")
        return 0

    print(f"{'NAME':<22} {'PID':>7}  {'STATUS':<8} {'PANE':<6}  CWD")
    reachable = 0
    for r in sorted(rows, key=lambda e: str(e.get("name") or "")):
        is_me = r.get("sessionId") == me
        name = f"{r.get('name') or '?'}{' (you)' if is_me else ''}"
        status = "dead" if not r.get("_live") else str(r.get("status") or "?")
        pane = (pane_for_pid(r["pid"]) or "-") if r.get("_live") else "-"
        if r.get("_live") and pane != "-" and not is_me:
            reachable += 1
        print(f"{name:<22} {r.get('pid'):>7}  {status:<8} {pane:<6}  {r.get('cwd')}")

    print(f'\n{reachable} peer(s) reachable. Send with: ccpeer send <name> "..."')
    print("A peer with no PANE is not in tmux and cannot be messaged.")
    return 0


def cmd_whoami(args) -> int:
    me = self_entry()
    if not me:
        sid = self_session_id()
        why = (
            f"session {sid} is not in the registry at {SESSIONS_DIR}"
            if sid
            else "no CLAUDE_CODE_SESSION_ID and no claude ancestor process"
        )
        print(f"Not usable as a ccpeer session: {why}.", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(me, indent=2, default=str))
        return 0
    print(f"name:       {me.get('name')}")
    print(f"session_id: {me.get('sessionId')}")
    print(f"pid:        {me.get('pid')}")
    print(f"cwd:        {me.get('cwd')}")
    print(f"pane:       {pane_for_pid(me['pid']) or '- (not in tmux; peers cannot reach you)'}")
    return 0


def cmd_send(args) -> int:
    me = self_entry()
    if not me:
        print("Not running inside a registered Claude Code session.", file=sys.stderr)
        return 1
    target = resolve(args.target)

    body = " ".join(args.message).strip()
    if not body:
        print("Refusing to send an empty message.", file=sys.stderr)
        return 1

    pane = pane_for_pid(target["pid"])
    if not pane:
        raise PeerError(
            f"{target.get('name')} (pid {target.get('pid')}) is not in a tmux pane, "
            "so there is no prompt to inject into."
        )

    text, spilled = prepare(me.get("name"), body)
    if args.dry_run:
        print(f"Would inject into {target.get('name')} (pane {pane}):\n")
        print(text)
        return 0

    inject(pane, text)
    print(f"Injected into {target.get('name')}'s chat (pid {target.get('pid')}, pane {pane}).")
    if spilled:
        print(f"Body was {len(body)} chars (> limit), so it was parked at {spilled}")
        print("and the peer was asked to read that file.")
    print(f'They can reply with: ccpeer send {me.get("name")} "..." — it lands in your chat.')
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        prog="ccpeer",
        description="Discover and message other Claude Code sessions on this machine.",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    pl = sub.add_parser("list", help="list Claude Code sessions on this machine")
    pl.add_argument("--all", action="store_true", help="include dead/stale sessions")
    pl.add_argument("--json", action="store_true")
    pl.set_defaults(func=cmd_list)

    pw = sub.add_parser("whoami", help="show this session's peer identity")
    pw.add_argument("--json", action="store_true")
    pw.set_defaults(func=cmd_whoami)

    ps = sub.add_parser("send", help="inject a message into another session's chat")
    ps.add_argument("target", help="peer name, pid, or session-id prefix")
    ps.add_argument("message", nargs="+", help="message body")
    ps.add_argument("--dry-run", action="store_true", help="print what would be injected")
    ps.set_defaults(func=cmd_send)

    args = p.parse_args(argv)
    try:
        return args.func(args)
    except PeerError as e:
        print(f"ccpeer: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
