import http from "node:http";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const pluginID = process.argv.includes("--plugin")
  ? process.argv[process.argv.indexOf("--plugin") + 1]
  : "system-stats";
const pluginDir = resolve(process.cwd(), "plugins", pluginID);
const manifest = JSON.parse(await readFile(resolve(pluginDir, "plugin.json"), "utf8"));
const module = await import(pathToFileURL(resolve(pluginDir, manifest.entry)).href);
const instance = module.createPlugin({
  manifest,
  bridgeVersion: "1.0.0",
  devMode: true,
  getLocation: () => ({ latitude: 42.3314, longitude: -83.0458 }),
  log() {}
});

await instance.start?.({ devMode: true });

const server = http.createServer(async (_request, response) => {
  const snapshot = await instance.getSnapshot();
  const html = `<!doctype html>
  <html>
    <head>
      <meta charset="utf-8" />
      <title>MyCue DevKit Preview</title>
      <style>
        body { margin: 0; background: #091318; color: #f5fbff; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        .frame { width: 1280px; height: 360px; margin: 24px auto; border-radius: 28px; padding: 24px; background: linear-gradient(135deg, #0b1c22, #091318); box-shadow: 0 24px 60px rgba(0,0,0,.35); }
        .title { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
        .subtitle { color: rgba(255,255,255,.68); margin-bottom: 20px; }
        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
        .card { background: rgba(255,255,255,.06); border-radius: 18px; padding: 16px; }
        .metric { font-size: 22px; font-weight: 700; margin-bottom: 6px; }
        pre { white-space: pre-wrap; font-size: 12px; color: #c2d8e2; }
      </style>
    </head>
    <body>
      <div class="frame">
        <div class="title">${snapshot.surface.title}</div>
        <div class="subtitle">${snapshot.surface.subtitle}</div>
        <div class="grid">
          ${snapshot.surface.metrics.map((metric) => `<div class="card"><div class="metric">${metric.displayValue}</div><div>${metric.label}</div></div>`).join("")}
        </div>
        <pre>${JSON.stringify(snapshot, null, 2)}</pre>
      </div>
    </body>
  </html>`;

  response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  response.end(html);
});

server.listen(4173, () => {
  console.log(`Previewing ${pluginID} at http://localhost:4173`);
});
