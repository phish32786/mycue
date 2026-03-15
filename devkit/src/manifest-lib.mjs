import { access, readFile } from "node:fs/promises";
import { constants } from "node:fs";
import { resolve } from "node:path";

const requiredFields = ["id", "name", "version", "apiVersion", "kind", "entry", "permissions"];

export async function readManifest(pluginDir) {
  const manifestPath = resolve(pluginDir, "plugin.json");
  const raw = await readFile(manifestPath, "utf8");
  return JSON.parse(raw);
}

export async function validatePlugin(pluginDir) {
  const manifest = await readManifest(pluginDir);
  const problems = [];

  for (const field of requiredFields) {
    if (!(field in manifest)) {
      problems.push(`Missing required field ${field}`);
    }
  }

  const entryPath = resolve(pluginDir, manifest.entry ?? "index.mjs");
  try {
    await access(entryPath, constants.R_OK);
  } catch {
    problems.push(`Missing entrypoint ${entryPath}`);
  }

  return {
    valid: problems.length === 0,
    manifest,
    problems
  };
}
