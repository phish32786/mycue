import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { validatePlugin } from "../src/manifest-lib.mjs";

test("starter plugins validate", async () => {
  const root = resolve(process.cwd(), "plugins");
  for (const pluginID of ["launcher", "media-gallery", "system-stats", "spotify", "weather", "web-widget"]) {
    const result = await validatePlugin(resolve(root, pluginID));
    assert.equal(result.valid, true);
  }
});
