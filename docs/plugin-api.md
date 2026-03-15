# Plugin API Design

## Manifest

Each plugin lives in `plugins/<id>` and includes `plugin.json`.

Required fields:

- `id`
- `name`
- `version`
- `apiVersion`
- `kind`
- `entry`
- `permissions`

## Runtime module shape

```js
export function createPlugin(context) {
  return {
    async start(hostConfig) {},
    async getSnapshot() {},
    async performAction(action) {},
    async stop() {}
  };
}
```

## Context

- `context.manifest`
- `context.bridgeVersion`
- `context.devMode`
- `context.getLocation()`
- `context.log(level, message, metadata?)`

## Snapshot contract

Plugins return a `PluginSnapshot` equivalent:

- `manifest`
- `status`
- `surface`
- `diagnostics`
- `lastUpdated`

The surface uses a typed model that supports metrics, media, forecast data, and action buttons.

## Actions

Host actions are versioned, explicit, and targeted:

- `playPause`
- `nextTrack`
- `previousTrack`
- `setVolume`
- `refresh`

## Reliability rules

- Unhandled plugin errors are trapped by the runtime and converted to failed status.
- A failed plugin does not terminate the runtime.
- The runtime can continue updating healthy plugins and send partial snapshots.
