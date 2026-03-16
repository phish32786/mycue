import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";

test("launcher plugin exposes expected shortcuts in snapshot", async () => {
  const modulePath = resolve(process.cwd(), "plugins/launcher/index.mjs");
  const { createPlugin } = await import(`file://${modulePath}?t=${Date.now()}-${Math.random()}`);

  const plugin = createPlugin({ log() {} });
  const snapshot = await plugin.getSnapshot();

  assert.equal(snapshot.status, "running");
  assert.equal(snapshot.surface.kind, "launcher");
  assert.equal(snapshot.surface.actions.length, 6);
  assert.deepEqual(
    snapshot.surface.actions.map((action) => action.id),
    [
      "open-spotify",
      "open-safari",
      "open-activity-monitor",
      "open-discord",
      "open-corsair",
      "open-downloads"
    ]
  );
  assert.match(snapshot.diagnostics.detail, /6 launcher targets configured/);
});
