import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

function getArgValue(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

const mdArg = getArgValue("--md");
const portArg = getArgValue("--port");

if (!mdArg) {
  console.error("Missing required argument: --md /absolute/path/to/file.md");
  process.exit(1);
}

const port = Number(portArg ?? 8080);
if (!Number.isFinite(port) || port <= 0) {
  console.error(`Invalid port: ${portArg ?? ""}`);
  process.exit(1);
}

const mdPath = path.resolve(mdArg);
const mdDir = path.dirname(mdPath);
const mdDirResolved = path.resolve(mdDir);

async function fileExists(p) {
  try {
    const stat = await fs.promises.stat(p);
    return stat.isFile();
  } catch {
    return false;
  }
}

function guessContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case ".png":
      return "image/png";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".gif":
      return "image/gif";
    case ".webp":
      return "image/webp";
    case ".svg":
      return "image/svg+xml";
    case ".css":
      return "text/css; charset=utf-8";
    case ".js":
      return "text/javascript; charset=utf-8";
    case ".html":
      return "text/html; charset=utf-8";
    case ".txt":
      return "text/plain; charset=utf-8";
    case ".md":
      return "text/markdown; charset=utf-8";
    case ".json":
      return "application/json; charset=utf-8";
    default:
      return "application/octet-stream";
  }
}

function safeResolveWithinDir(requestPathname) {
  // requestPathname starts with "/" for absolute-path URLs (e.g. "/images/x.png")
  const rel = decodeURIComponent(requestPathname.replace(/^\/+/, ""));
  const resolved = path.resolve(mdDirResolved, rel);

  // Prevent path traversal: requested path must stay within mdDir.
  if (!resolved.startsWith(mdDirResolved + path.sep) && resolved !== mdDirResolved) {
    return null;
  }

  return resolved;
}

function renderIndexHtml() {
  const title = path.basename(mdPath);
  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Markdown Preview - ${title}</title>
    <style>
      :root { color-scheme: light; }
      body {
        margin: 0;
        padding: 24px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: #080707;
        background: #fff;
      }
      .header {
        position: sticky;
        top: 0;
        background: rgba(255,255,255,0.85);
        backdrop-filter: blur(6px);
        padding: 12px 0;
        margin-bottom: 16px;
        border-bottom: 1px solid #e7e7e7;
        display: flex;
        flex-wrap: wrap;
        align-items: flex-start;
        justify-content: space-between;
        gap: 12px;
      }
      .header-text { flex: 1; min-width: 200px; }
      .refresh-btn {
        font: inherit;
        padding: 0;
        width: 36px;
        height: 36px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border: 1px solid #d8dde6;
        border-radius: 6px;
        background: #fff;
        color: #080707;
        cursor: pointer;
        flex-shrink: 0;
      }
      .refresh-btn:hover { background: #f3f2f2; }
      .refresh-btn svg { display: block; }
      .title { font-size: 16px; font-weight: 600; margin: 0 0 6px; }
      .meta { font-size: 12px; color: #555; margin: 0; }
      .content { max-width: 880px; }
      .loading { font-size: 14px; color: #555; }
      .error { padding: 12px; background: #ffe9e9; border: 1px solid #ffb7b7; border-radius: 8px; }
      img {
        display: block;
        margin: 18px auto;
        max-width: 640px;
        height: auto;
        border: 1px solid #d8dde6;
        border-radius: 8px;
        padding: 8px;
        background: #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.08);
      }
      img[alt*="banner"] { border: 0; box-shadow: none; padding: 0; background: transparent; }
      h1 { font-size: 26px; margin: 18px 0 12px; }
      h2 { font-size: 20px; margin: 18px 0 10px; }
      h3 { font-size: 16px; margin: 16px 0 8px; }
      p { margin: 0 0 10px; line-height: 1.6; }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono",
          "Courier New", monospace;
        font-size: 12px;
        background: #f3f2f2;
        padding: 2px 6px;
        border-radius: 6px;
      }
      pre {
        background: #f3f2f2;
        padding: 12px;
        border-radius: 8px;
        overflow: auto;
      }
      pre code { background: transparent; padding: 0; border-radius: 0; }
      a { color: #0070d2; text-decoration: underline; }
      blockquote {
        margin: 12px 0;
        padding: 10px 12px;
        border-left: 4px solid #d8dde6;
        background: #f3f2f2;
        color: #3e3e3c;
      }
      table { border-collapse: collapse; width: 100%; margin: 14px 0; }
      th, td { border: 1px solid #d0d0d0; padding: 6px 8px; vertical-align: top; }
      th { background: rgb(109, 52, 183); color: #fff; text-align: left; }
      hr { border: 0; border-top: 1px solid #d8dde6; margin: 16px 0; }
    </style>
  </head>
  <body>
    <div class="header">
      <div class="header-text">
        <p class="title">${title}</p>
        <p class="meta">Checks for changes ~1s. Re-renders only when content changes.</p>
      </div>
      <button type="button" class="refresh-btn" id="refreshPage" title="Reload the whole page (e.g. after changing images)" aria-label="Refresh page">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
          <path d="M21 3v5h-5" />
          <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
          <path d="M8 16H3v5" />
        </svg>
      </button>
    </div>
    <div id="status" class="loading">Loading...</div>
    <div id="content" class="content"></div>

    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/dompurify@3.1.6/dist/purify.min.js"></script>
    <script>
      const statusEl = document.getElementById("status");
      const contentEl = document.getElementById("content");
      let lastMarkdownHash = null;

      // Lightweight non-crypto hash for change detection.
      // Collisions are very unlikely for typical markdown content.
      function hashString(str) {
        let h1 = 0xdeadbeef ^ str.length;
        let h2 = 0x41c6ce57 ^ str.length;
        for (let i = 0; i < str.length; i++) {
          const ch = str.charCodeAt(i);
          h1 = Math.imul(h1 ^ ch, 2654435761);
          h2 = Math.imul(h2 ^ ch, 1597334677);
        }
        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
        return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(16);
      }

      function renderMarkdown(markdown) {
        // marked.parse() is the canonical API for v4+.
        const rawHtml = window.marked.parse(markdown);
        const safeHtml = window.DOMPurify.sanitize(rawHtml, { USE_PROFILES: { html: true } });
        contentEl.innerHTML = safeHtml;
      }

      async function loadAndMaybeRender() {
        try {
          const res = await fetch("/__markdown?cb=" + Date.now(), { cache: "no-store" });
          if (!res.ok) {
            throw new Error("Failed to fetch markdown: " + res.status);
          }
          const markdown = await res.text();

          const newHash = hashString(markdown);
          if (lastMarkdownHash === newHash) {
            return; // Skip re-render if nothing changed.
          }

          lastMarkdownHash = newHash;
          statusEl.textContent = "Updating...";
          statusEl.className = "loading";
          renderMarkdown(markdown);
          statusEl.textContent = "";
        } catch (e) {
          statusEl.className = "error";
          statusEl.textContent = "Preview error: " + (e && e.message ? e.message : String(e));
        }
      }

      // Initial load.
      loadAndMaybeRender();

      // Lightweight polling for changes.
      setInterval(loadAndMaybeRender, 1000);

      document.getElementById("refreshPage").addEventListener("click", () => {
        location.reload();
      });
    </script>
  </body>
</html>`;
}

const server = http.createServer(async (req, res) => {
  if (!req || !req.url) {
    res.writeHead(400);
    res.end("Bad request");
    return;
  }

  const url = new URL(req.url, "http://localhost");

  // Only GET is supported in this simple dev server.
  if (req.method !== "GET") {
    res.writeHead(405, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Method not allowed");
    return;
  }

  try {
    if (url.pathname === "/__markdown") {
      const ok = await fileExists(mdPath);
      if (!ok) {
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Markdown file not found on disk.");
        return;
      }

      const markdown = await fs.promises.readFile(mdPath, "utf8");
      res.writeHead(200, { "Content-Type": "text/markdown; charset=utf-8" });
      res.end(markdown);
      return;
    }

    if (url.pathname === "/") {
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(renderIndexHtml());
      return;
    }

    // Default: treat everything else as a request for a file under mdDir
    // so markdown image paths like `images/...` resolve naturally.
    const resolvedPath = safeResolveWithinDir(url.pathname);
    if (!resolvedPath) {
      res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Forbidden path.");
      return;
    }

    const ok = await fileExists(resolvedPath);
    if (!ok) {
      // Avoid noisy logs for common browser requests.
      if (url.pathname === "/favicon.ico") {
        res.writeHead(204);
        res.end();
        return;
      }

      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found.");
      return;
    }

    const contentType = guessContentType(resolvedPath);
    res.writeHead(200, { "Content-Type": contentType });
    fs.createReadStream(resolvedPath).pipe(res);
  } catch (e) {
    console.error("Preview server error:", e);
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Internal server error.");
  }
});

server.listen(port, "127.0.0.1", async () => {
  const protocolUrl = `http://localhost:${port}`;
  const mdExists = await fileExists(mdPath);
  if (!mdExists) {
    console.warn("Warning: markdown file does not exist:", mdPath);
  }

  console.log(`Preview server listening at ${protocolUrl}`);
  console.log(`Serving markdown: ${mdPath}`);
  console.log(`Serving images from: ${mdDirResolved}`);
});

