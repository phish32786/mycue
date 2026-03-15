# MyCue

MyCue is a native macOS dashboard host for the CORSAIR XENEON EDGE 14.5" touchscreen. The host is written in SwiftUI/AppKit, plugins run in a Node.js runtime, and the initial developer experience is simulator-first so plugin authors do not need the physical display on their desk.

This repository currently contains the first production-oriented scaffold:

- a native host shell with kiosk-style display placement
- a typed host/plugin bridge with crash containment and logging
- a Node runtime that loads manifest-based plugins
- starter plugins for system stats, Spotify, and weather
- a DevKit preview and manifest validator
- baseline tests and architecture docs
- hardware-mode HID touch ingestion with calibration-aware mapping for detected XENEON-class screens

## Commands

```bash
swift build
swift test
swift run edge-control
./scripts/build-alpha.sh
node runtime/node-host/src/host.mjs
node devkit/src/preview.mjs --plugin system-stats
node devkit/src/validate.mjs
node --test devkit/test
```

## Current assumptions

- The virtual device profile defaults to `2560x720`, matching the current CORSAIR XENEON EDGE product page.
- When the XENEON screen is not detected, the app automatically falls back to windowed DevKit mode with normal macOS window controls and standard quit behavior.
- On detected hardware, the host attempts to seize the touch HID path and uses persisted corner calibration data. If calibration is missing or invalid, the dashboard enters a dwell-based corner calibration flow.
- System stats now come from the native host using safe non-privileged macOS APIs. Advanced sensor telemetry such as direct CPU/GPU temperatures, fan RPM, and GPU utilization still needs a deeper native integration path.

## Layout

- `Sources/EdgeControlShared`: shared bridge protocol and calibration models
- `Sources/EdgeControlHost`: native macOS host app shell
- `runtime/node-host`: Node plugin runtime
- `plugins`: manifest-based starter plugins
- `devkit`: preview runner, mocks, and validation tooling
- `docs`: architecture, roadmap, plugin API, DevKit, debug mode, and workflow notes

## Alpha packaging

- Run `./scripts/build-alpha.sh` to create `dist/MyCue.app` and `dist/MyCue-alpha.zip`
- Set `MYCUE_CODESIGN_IDENTITY` if you want the bundle signed during packaging
- Release prep notes are in `docs/release.md`
- The manual alpha QA checklist is in `docs/alpha-checklist.md`
