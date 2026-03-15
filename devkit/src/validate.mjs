import { readdir } from "node:fs/promises";
import { resolve } from "node:path";
import { validatePlugin } from "./manifest-lib.mjs";

const pluginsRoot = resolve(process.cwd(), "plugins");
const entries = await readdir(pluginsRoot, { withFileTypes: true });
let failed = false;

for (const entry of entries) {
  if (!entry.isDirectory()) continue;
  const result = await validatePlugin(resolve(pluginsRoot, entry.name));
  if (result.valid) {
    console.log(`ok  ${result.manifest.id}`);
  } else {
    failed = true;
    console.log(`bad ${entry.name}`);
    for (const problem of result.problems) {
      console.log(`  - ${problem}`);
    }
  }
}

if (failed) {
  process.exit(1);
}
