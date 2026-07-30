#!/usr/bin/env python3
"""Live index of everything listening on localhost, served at http://localhost:1111.

Discovers listening TCP sockets with lsof, enriches them with the owning
process's command line and working directory, and probes each one to see if it
speaks HTTP. Nothing to register or configure; new servers just show up.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 1111
SCAN_INTERVAL = 2.0
IDLE_AFTER = 60.0
STALE_AFTER = 5.0
PROBE_TIMEOUT = 1.5
PROBE_TTL = 30.0
PROBE_WORKERS = 30
BODY_LIMIT = 65536

HOME = os.path.expanduser("~")
LOOPBACK_ADDRS = {"*", "127.0.0.1", "::1", "::", "0.0.0.0", "[::1]", "[::]"}

# Local dev certificates are self-signed as a rule; we only want the page title.
UNVERIFIED_TLS = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
UNVERIFIED_TLS.check_hostname = False
UNVERIFIED_TLS.verify_mode = ssl.CERT_NONE

TITLE_RE = re.compile(rb"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
H1_RE = re.compile(rb"<h1[^>]*>(.*?)</h1>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<[^>]+>")
CHARSET_RE = re.compile(r"charset=([\w-]+)", re.IGNORECASE)


def _run(cmd):
    try:
        done = subprocess.run(cmd, capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return done.stdout.decode("utf-8", "replace")


def _port_of(addr):
    host, sep, port = addr.rpartition(":")
    if not sep or not port.isdigit():
        return None, None
    return host or "*", int(port)


def _listeners():
    """port -> {"pids": set, "addrs": set} for every listening TCP socket."""
    found = {}
    names = {}
    pid = None
    for line in _run(["lsof", "+c", "0", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]).splitlines():
        tag, value = line[:1], line[1:]
        if tag == "p" and value.isdigit():
            pid = int(value)
        elif tag == "c" and pid is not None:
            names[pid] = value
        elif tag == "n" and pid is not None:
            host, port = _port_of(value)
            if port is None:
                continue
            entry = found.setdefault(port, {"pids": set(), "addrs": set()})
            entry["pids"].add(pid)
            entry["addrs"].add(host)
    return found, names


def _command_lines(pids):
    if not pids:
        return {}
    out = _run(["ps", "-o", "pid=,command=", "-p", ",".join(str(p) for p in sorted(pids))])
    commands = {}
    for line in out.splitlines():
        pid, _, command = line.strip().partition(" ")
        if pid.isdigit():
            commands[int(pid)] = command.strip()
    return commands


def _working_dirs(pids):
    if not pids:
        return {}
    out = _run(["lsof", "-a", "-p", ",".join(str(p) for p in sorted(pids)), "-d", "cwd", "-Fpn"])
    dirs = {}
    pid = None
    for line in out.splitlines():
        tag, value = line[:1], line[1:]
        if tag == "p" and value.isdigit():
            pid = int(value)
        elif tag == "n" and pid is not None:
            dirs[pid] = value
    return dirs


def _decode(body, content_type):
    match = CHARSET_RE.search(content_type or "")
    for encoding in (match.group(1) if match else None, "utf-8", "latin-1"):
        if not encoding:
            continue
        try:
            return body.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return body.decode("utf-8", "replace")


def _clean(text):
    return " ".join(html.unescape(TAG_RE.sub(" ", text)).split())[:120]


def _describe(scheme, url, status, headers, body):
    content_type = headers.get("Content-Type", "") if headers else ""
    title = ""
    for pattern in (TITLE_RE, H1_RE):
        match = pattern.search(body)
        if match:
            title = _clean(_decode(match.group(1), content_type))
            if title:
                break
    if not title and "json" in content_type.lower():
        title = "JSON endpoint"
    return {
        "scheme": scheme,
        "url": url,
        "status": status,
        "title": title,
        "server": (headers.get("Server", "") if headers else "")[:60],
        "content_type": content_type.split(";")[0].strip(),
    }


def _probe(port):
    """Return HTTP details for a port, or None if it does not speak HTTP."""
    for scheme in ("http", "https"):
        url = "{}://127.0.0.1:{}/".format(scheme, port)
        context = UNVERIFIED_TLS if scheme == "https" else None
        request = urllib.request.Request(url, headers={"User-Agent": "localports"})
        try:
            with urllib.request.urlopen(request, timeout=PROBE_TIMEOUT, context=context) as response:
                return _describe(scheme, response.geturl(), response.status, response.headers,
                                 response.read(BODY_LIMIT))
        except urllib.error.HTTPError as error:
            try:
                body = error.read(BODY_LIMIT)
            except Exception:
                body = b""
            return _describe(scheme, url, error.code, error.headers, body)
        except Exception:
            continue
    return None


def _shorten(path):
    if path == HOME:
        return "~"
    if path.startswith(HOME + "/"):
        return "~" + path[len(HOME):]
    return path


def _is_app(cwd):
    """Background helper of an installed app rather than something you started.

    Only the working directory is trustworthy here. Testing the executable path
    for a .app bundle looks tempting but misfires: macOS framework Pythons live
    in Python.app/Contents/MacOS, so every venv server would be misfiled.
    """
    return cwd in ("/", "") or ".app/" in cwd or cwd.endswith(".app")


class Scanner:
    """Rescans on a timer so page loads render an already-warm snapshot.

    The timer only runs while someone is actually watching. lsof is not free,
    and this is a login agent that spends most of its life unobserved.
    """

    def __init__(self, own_port):
        self.own_port = own_port
        self.snapshot = {"services": [], "scanned_at": 0.0}
        self.lock = threading.Lock()
        self.scan_lock = threading.Lock()
        self.probes = {}
        self.last_seen = 0.0

    def _probe_cached(self, port, pids):
        key = (port, tuple(sorted(pids)))
        now = time.time()
        hit = self.probes.get(key)
        if hit and now - hit[1] < PROBE_TTL:
            return hit[0]
        result = _probe(port)
        self.probes[key] = (result, now)
        return result

    def scan(self):
        with self.scan_lock:
            self._scan()

    def _scan(self):
        listeners, names = _listeners()
        every_pid = {pid for entry in listeners.values() for pid in entry["pids"]}
        commands = _command_lines(every_pid)
        dirs = _working_dirs(every_pid)

        reachable = [port for port, entry in listeners.items()
                     if entry["addrs"] & LOOPBACK_ADDRS and port != self.own_port]
        with ThreadPoolExecutor(max_workers=PROBE_WORKERS) as pool:
            probed = dict(zip(reachable, pool.map(
                lambda port: self._probe_cached(port, listeners[port]["pids"]), reachable)))

        services = []
        for port, entry in sorted(listeners.items()):
            pid = sorted(entry["pids"])[0]
            command = commands.get(pid, "")
            cwd = dirs.get(pid, "")
            http = probed.get(port)
            services.append({
                "port": port,
                "pid": pid,
                "name": names.get(pid) or "?",
                "command": _shorten(command),
                "cwd": _shorten(cwd),
                "loopback": bool(entry["addrs"] & LOOPBACK_ADDRS),
                "http": http,
                "group": "self" if port == self.own_port
                         else "app" if _is_app(cwd)
                         else "web" if http
                         else "other",
            })
        now = time.time()
        self.probes = {key: hit for key, hit in self.probes.items()
                       if now - hit[1] < PROBE_TTL * 4}
        with self.lock:
            self.snapshot = {"services": services, "scanned_at": now}

    def latest(self):
        with self.lock:
            return self.snapshot

    def mark_active(self):
        self.last_seen = time.time()

    def touch(self):
        """Note that someone is watching, and refresh if the snapshot went cold."""
        self.mark_active()
        if self.last_seen - self.latest()["scanned_at"] > STALE_AFTER:
            self._guarded_scan()

    def _guarded_scan(self):
        try:
            self.scan()
        except Exception as error:
            print("scan failed: {}".format(error), file=sys.stderr, flush=True)

    def run_forever(self):
        while True:
            if time.time() - self.last_seen < IDLE_AFTER:
                self._guarded_scan()
            time.sleep(SCAN_INTERVAL)


PAGE = """<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>localhost</title>
<style>
  :root {
    --bg:#faf9f7; --panel:#fff; --ink:#1a1a19; --muted:#78756e; --line:#e3e0da;
    --accent:#0b6b58; --live:#18a06a; --shadow:0 1px 2px rgba(0,0,0,.05);
  }
  @media (prefers-color-scheme:dark) {
    :root {
      --bg:#131316; --panel:#1b1b1f; --ink:#e9e7e3; --muted:#8d8a84; --line:#2c2c32;
      --accent:#5fd7b4; --live:#3ecf8e; --shadow:none;
    }
  }
  * { box-sizing:border-box }
  body {
    margin:0; padding:2.5rem 1.25rem 4rem; background:var(--bg); color:var(--ink);
    font:14px/1.5 ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace;
  }
  main { max-width:56rem; margin:0 auto }
  header { display:flex; align-items:baseline; gap:.75rem; margin-bottom:1.75rem }
  h1 { font-size:1rem; font-weight:600; letter-spacing:.14em; text-transform:uppercase; margin:0 }
  #stamp { color:var(--muted); font-size:.75rem; margin-left:auto }
  h2 {
    font-size:.7rem; font-weight:600; letter-spacing:.16em; text-transform:uppercase;
    color:var(--muted); margin:2.25rem 0 .75rem;
  }
  ul { list-style:none; margin:0; padding:0; display:grid; gap:.5rem }
  li {
    background:var(--panel); border:1px solid var(--line); border-radius:8px;
    box-shadow:var(--shadow); transition:border-color .12s;
  }
  li:hover { border-color:var(--accent) }
  a.card, div.card { display:flex; gap:1rem; padding:.85rem 1rem; text-decoration:none; color:inherit }
  .port { font-weight:600; font-variant-numeric:tabular-nums; min-width:5.5rem; color:var(--accent) }
  a.card .port::before {
    content:""; display:inline-block; width:6px; height:6px; border-radius:50%;
    background:var(--live); margin-right:.6rem; vertical-align:middle;
  }
  div.card .port { color:var(--muted) }
  .body { min-width:0; flex:1 }
  .title { font-weight:600; margin-bottom:.15rem; overflow-wrap:anywhere }
  .meta { color:var(--muted); font-size:.78rem; overflow-wrap:anywhere }
  .tag {
    float:right; color:var(--muted); font-size:.7rem; letter-spacing:.06em;
    border:1px solid var(--line); border-radius:4px; padding:.05rem .4rem; margin-left:.5rem;
  }
  section.muted li { opacity:.62 }
  .empty { color:var(--muted); padding:1rem 0 }
  footer { color:var(--muted); font-size:.75rem; margin-top:3rem; text-align:center }
  kbd { border:1px solid var(--line); border-radius:4px; padding:.05rem .35rem }
</style>
</head><body><main>
<header><h1>Localhost</h1><span id="stamp">scanning&hellip;</span></header>
<div id="out"></div>
<footer>Auto-refreshing. Raw data at <a href="/api" style="color:var(--accent)">/api</a>.</footer>
</main>
<script>
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => (
  {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));

function card(s) {
  const h = s.http;
  const title = h && h.title ? h.title : s.name;
  const bits = [s.command || s.name];
  if (s.cwd) bits.push(s.cwd);
  const tag = h && h.status >= 400 ? `<span class="tag">${h.status}</span>`
            : !h && s.group !== "self" ? `<span class="tag">not http</span>` : "";
  const inner = `<div class="port">:${s.port}</div><div class="body">`
    + `<div class="title">${tag}${esc(title)}</div>`
    + `<div class="meta">${esc(bits.join("  ·  "))}</div></div>`;
  return h
    ? `<li><a class="card" href="${esc(h.url)}">${inner}</a></li>`
    : `<li><div class="card">${inner}</div></li>`;
}

function section(name, list, muted) {
  if (!list.length) return "";
  return `<section class="${muted ? "muted" : ""}"><h2>${name}</h2>`
    + `<ul>${list.map(card).join("")}</ul></section>`;
}

async function tick() {
  try {
    const data = await (await fetch("/api", {cache: "no-store"})).json();
    const by = g => data.services.filter(s => s.group === g);
    const web = by("web");
    document.getElementById("out").innerHTML =
      (web.length ? section("Web", web, false)
                  : `<p class="empty">Nothing is serving HTTP right now.</p>`)
      + section("Other listeners", by("other"), true)
      + section("System &amp; apps", by("app"), true);
    const age = Math.max(0, Math.round(Date.now() / 1000 - data.scanned_at));
    const listening = data.services.filter(s => s.group !== "self").length;
    document.getElementById("stamp").textContent =
      `${web.length} web · ${listening} listening · ${age}s ago`;
  } catch (e) {
    document.getElementById("stamp").textContent = "disconnected";
  }
}
tick();
setInterval(tick, 2000);
</script>
</body></html>
"""


class Handler(BaseHTTPRequestHandler):
    scanner = None
    protocol_version = "HTTP/1.1"

    def _send(self, body, content_type):
        payload = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        if path == "/":
            self.scanner.mark_active()
            self._send(PAGE, "text/html; charset=utf-8")
        elif path == "/api":
            self.scanner.touch()
            self._send(json.dumps(self.scanner.latest()), "application/json")
        else:
            self.send_error(404)

    def log_message(self, *args):
        pass


RANK = {"web": 0, "other": 1, "self": 2, "app": 3}


def print_table(scanner, show_apps):
    scanner.scan()
    services = [s for s in scanner.latest()["services"] if show_apps or s["group"] != "app"]
    if not services:
        print("nothing listening")
        return
    width = max(len(s["name"]) for s in services)
    group = None
    for service in sorted(services, key=lambda s: (RANK[s["group"]], s["port"])):
        if service["group"] != group:
            group = service["group"]
            print("\n{}".format({"web": "web", "other": "other listeners",
                                 "self": "this dashboard", "app": "system & apps"}[group]))
        http = service["http"]
        label = (http["title"] if http and http["title"] else "") or service["cwd"]
        print("  {:>6}  {:<{w}}  {:<32}  {}".format(
            ":" + str(service["port"]), service["name"],
            http["url"][:32] if http else "-", label, w=width))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--list", action="store_true", help="print a table and exit")
    parser.add_argument("--all", action="store_true", help="include system and app helpers")
    args = parser.parse_args()

    scanner = Scanner(args.port)
    if args.list:
        print_table(scanner, args.all)
        return

    threading.Thread(target=scanner.run_forever, daemon=True).start()
    Handler.scanner = scanner
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    print("localports on http://localhost:{}".format(args.port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
