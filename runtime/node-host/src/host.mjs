import { readFile, readdir } from "node:fs/promises";
import { createInterface } from "node:readline";
import { resolve, dirname } from "node:path";
import { pathToFileURL } from "node:url";

const state = {
  initialized: false,
  devMode: false,
  pluginsPath: "",
  location: { latitude: 42.3314, longitude: -83.0458 },
  pluginSettings: {
    weather: {
      locationName: "Detroit",
      latitude: 42.3314,
      longitude: -83.0458,
      unitPreference: "automatic"
    },
    webWidget: {
      title: "Web Widget",
      subtitle: "Embedded dashboard",
      urlString: "https://calendar.google.com"
    },
    mediaGallery: {
      title: "Gallery",
      subtitle: "Local media rotation",
      folderPath: "",
      intervalSeconds: 8,
      shuffle: false
    }
  },
  hostMetrics: null,
  manifests: [],
  instances: new Map(),
  snapshots: new Map(),
  refreshTimer: null
};

function send(event, payload = null) {
  process.stdout.write(`${JSON.stringify({ event, payload })}\n`);
}

function log(level, message, pluginID = null) {
  send("plugin.log", {
    id: crypto.randomUUID(),
    level,
    pluginID,
    message,
    timestamp: new Date().toISOString()
  });
}

async function loadManifests(pluginsPath) {
  const entries = await readdir(pluginsPath, { withFileTypes: true });
  const manifests = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const manifestPath = resolve(pluginsPath, entry.name, "plugin.json");
    const raw = await readFile(manifestPath, "utf8");
    const manifest = JSON.parse(raw);
    manifests.push({ ...manifest, directory: resolve(pluginsPath, entry.name) });
  }
  return manifests;
}

async function startPlugin(manifest) {
  const modulePath = resolve(manifest.directory, manifest.entry);
  const imported = await import(pathToFileURL(modulePath).href);
  const context = {
    manifest,
    bridgeVersion: "1.0.0",
    devMode: state.devMode,
    getLocation: () => ({ ...state.location }),
    getPluginSettings: () => structuredClone(state.pluginSettings),
    getHostMetrics: () => state.hostMetrics ? structuredClone(state.hostMetrics) : null,
    log(level, message, metadata = undefined) {
      const suffix = metadata ? ` ${JSON.stringify(metadata)}` : "";
      log(level, `${message}${suffix}`, manifest.id);
    }
  };

  const plugin = imported.createPlugin(context);
  await plugin.start?.({
    location: state.location,
    devMode: state.devMode
  });

  state.instances.set(manifest.id, { manifest, plugin });
}

async function collectSnapshot(instance) {
  try {
    const snapshot = await instance.plugin.getSnapshot();
    const complete = {
      ...snapshot,
      manifest: {
        id: instance.manifest.id,
        name: instance.manifest.name,
        version: instance.manifest.version,
        apiVersion: instance.manifest.apiVersion,
        kind: instance.manifest.kind,
        entry: instance.manifest.entry,
        permissions: instance.manifest.permissions,
        defaultEnabled: instance.manifest.defaultEnabled ?? true
      },
      lastUpdated: new Date().toISOString()
    };
    state.snapshots.set(instance.manifest.id, complete);
    return complete;
  } catch (error) {
    log("error", `Snapshot failure: ${error.message}`, instance.manifest.id);
    const failedSnapshot = {
      manifest: {
        id: instance.manifest.id,
        name: instance.manifest.name,
        version: instance.manifest.version,
        apiVersion: instance.manifest.apiVersion,
        kind: instance.manifest.kind,
        entry: instance.manifest.entry,
        permissions: instance.manifest.permissions,
        defaultEnabled: instance.manifest.defaultEnabled ?? true
      },
      status: "failed",
      surface: {
        kind: instance.manifest.kind,
        title: instance.manifest.name,
        subtitle: "Plugin error",
        detail: error.message,
        theme: {
          accentHex: "#F08F71",
          backgroundHex: "#1A0D0C",
          foregroundHex: "#FFF8F3"
        },
        metrics: [],
        actions: [],
        media: null,
        hourlyForecast: [],
        dailyForecast: []
      },
      diagnostics: {
        summary: "Plugin failed",
        detail: error.stack,
        lastError: error.message
      },
      lastUpdated: new Date().toISOString()
    };
    state.snapshots.set(instance.manifest.id, failedSnapshot);
    return failedSnapshot;
  }
}

async function publishSnapshots() {
  const snapshots = [];
  for (const instance of state.instances.values()) {
    snapshots.push(await collectSnapshot(instance));
  }
  send("plugins.snapshot", snapshots);
}

async function initialize(payload) {
  state.pluginsPath = payload.pluginsPath;
  state.devMode = Boolean(payload.devMode);
  state.location = {
    latitude: payload.latitude,
    longitude: payload.longitude
  };
  state.pluginSettings = payload.pluginSettings ?? state.pluginSettings;
  state.hostMetrics = payload.hostMetrics ?? null;
  state.manifests = await loadManifests(state.pluginsPath);

  for (const manifest of state.manifests) {
    try {
      await startPlugin(manifest);
      log("info", "Plugin started", manifest.id);
    } catch (error) {
      log("error", `Plugin failed to start: ${error.message}`, manifest.id);
    }
  }

  state.initialized = true;
  await publishSnapshots();
  state.refreshTimer = setInterval(() => {
    publishSnapshots().catch((error) => {
      log("error", `Refresh loop failed: ${error.message}`);
    });
  }, 2000);
}

async function performAction(payload) {
  const instance = state.instances.get(payload.pluginID);
  if (!instance) return;
  try {
    await instance.plugin.performAction?.({
      actionID: payload.actionID,
      value: payload.value ?? null
    });
    await publishSnapshots();
  } catch (error) {
    log("error", `Action failed: ${error.message}`, payload.pluginID);
  }
}

async function updateHostMetrics(payload) {
  state.hostMetrics = payload;
  await publishSnapshots();
}

async function updateSettings(payload) {
  state.pluginSettings = payload ?? state.pluginSettings;
  if (state.pluginSettings?.weather) {
    state.location = {
      latitude: state.pluginSettings.weather.latitude,
      longitude: state.pluginSettings.weather.longitude
    };
  }
  await publishSnapshots();
}

send("runtime.ready", { version: "0.1.0" });

const input = createInterface({ input: process.stdin });
input.on("line", async (line) => {
  if (!line.trim()) return;
  const envelope = JSON.parse(line);
  switch (envelope.command) {
    case "initialize":
      await initialize(envelope.payload);
      break;
    case "action":
      await performAction(envelope.payload);
      break;
    case "hostMetrics.update":
      await updateHostMetrics(envelope.payload);
      break;
    case "settings.update":
      await updateSettings(envelope.payload);
      break;
    default:
      log("debug", `Unknown command ${envelope.command}`);
  }
});

process.on("SIGTERM", async () => {
  if (state.refreshTimer) clearInterval(state.refreshTimer);
  for (const instance of state.instances.values()) {
    await instance.plugin.stop?.();
  }
  process.exit(0);
});
