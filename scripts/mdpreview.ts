// Live markdown preview for nvim's :MdPreview. GET /<absolute path>.md returns
// the file rendered by pandoc through mdpreview.html; the page holds an event
// stream open and reloads whenever the file's mtime changes. Other files under
// $HOME are served as-is so relative images and links work.
// Prints its base URL on stdout.
import { stat } from "node:fs/promises";
import { basename, resolve } from "node:path";

const home = process.env.HOME ?? "/nonexistent";
const template = resolve(import.meta.dir, "mdpreview.html");
const encoder = new TextEncoder();

async function mtime(path: string): Promise<string> {
  try {
    return String((await stat(path)).mtimeMs);
  } catch {
    return "missing";
  }
}

const escape = (s: string) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]!);

async function render(path: string): Promise<string> {
  const seen = await mtime(path);
  const proc = Bun.spawn(
    [
      "pandoc", path,
      "--from=gfm+tex_math_dollars",
      "--to=html5",
      "--standalone",
      `--template=${template}`,
      "--katex",
      "--syntax-highlighting=monochrome",
      `--metadata=pagetitle:${basename(path)}`,
      `--variable=mtime:${seen}`,
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  const [out, err, code] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (code === 0) return out;
  return `<!doctype html><meta charset="utf-8"><title>pandoc failed</title>
<pre style="white-space:pre-wrap">${escape(err)}</pre>
<script>new EventSource(location.pathname + "?events").onmessage = (e) => e.data !== "${seen}" && location.reload();</script>`;
}

function events(path: string): Response {
  let timer: ReturnType<typeof setInterval>;
  let last = "";
  let ticks = 0;
  const stream = new ReadableStream({
    start(ctl) {
      const tick = async () => {
        const now = await mtime(path);
        try {
          if (now !== last) ctl.enqueue(encoder.encode(`data: ${now}\n\n`));
          else if (++ticks % 50 === 0) ctl.enqueue(encoder.encode(": ping\n\n"));
        } catch {
          clearInterval(timer);
        }
        last = now;
      };
      tick();
      timer = setInterval(tick, 200);
    },
    cancel() {
      clearInterval(timer);
    },
  });
  return new Response(stream, {
    headers: { "content-type": "text/event-stream", "cache-control": "no-store" },
  });
}

const server = Bun.serve({
  hostname: "127.0.0.1",
  port: 0,
  idleTimeout: 0,
  async fetch(req) {
    // Only answer to the address we printed, so another site can't reach in via DNS rebinding.
    if (req.headers.get("host") !== `127.0.0.1:${server.port}`) return new Response("wrong host", { status: 403 });
    const url = new URL(req.url);
    const path = resolve(decodeURIComponent(url.pathname));
    if (!path.startsWith(home + "/")) return new Response("only files under $HOME", { status: 403 });
    if (url.search === "?events") return events(path);
    if (/\.(md|markdown)$/i.test(path)) {
      return new Response(await render(path), {
        headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
      });
    }
    const file = Bun.file(path);
    if (!(await file.exists())) return new Response("not found", { status: 404 });
    return new Response(file);
  },
});

console.log(`http://127.0.0.1:${server.port}`);
