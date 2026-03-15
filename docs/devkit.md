# DevKit Design

## Goals

- Let plugin authors develop without the physical XENEON EDGE attached.
- Simulate the device aspect ratio and dashboard density.
- Provide mock host APIs and fast iteration.

## Included tools

- `preview.mjs`: renders plugin snapshots in a `2560x720` browser-like preview shell
- `validate.mjs`: validates plugin manifests and entrypoint layout
- sample plugins in `plugins/`

## Initial workflow

```bash
node devkit/src/validate.mjs
node devkit/src/preview.mjs --plugin weather
```

## Next steps

- hot reload file watcher
- simulated touch injection
- mock permission prompts
- plugin packaging command
