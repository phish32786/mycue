# Product And Technical Architecture

## Goals

- Deliver a native macOS control-surface experience on the XENEON EDGE with minimal setup friction.
- Keep plugin failures isolated from the host UI.
- Make plugin development simulator-first and fast.
- Preserve a clean path to deeper HID integration, calibration, and richer plugin rendering.

## Recommended stack

- Host app: Swift 6, SwiftUI, AppKit for display/window control
- Shared bridge contract: Swift Codable + JSON line protocol
- Plugin runtime: Node.js 23+
- Initial rendering strategy: host-rendered surfaces from typed plugin snapshots
- DevKit: Node CLI + lightweight HTTP preview
- Persistence: `UserDefaults` for host settings, JSON files for plugin manifests and calibration data

## System boundaries

### Native host

- Selects and manages the dashboard display.
- Presents kiosk-style full-screen behavior on the chosen screen.
- Owns the visual shell, settings, debug overlay, and touch target sizing.
- Launches and supervises the Node runtime process.
- Maintains logs, plugin crash state, and restart policy.

### Node runtime

- Loads plugin manifests from `plugins/*/plugin.json`.
- Applies permission metadata and lifecycle rules.
- Polls plugins for state updates.
- Converts plugin state into a versioned `DashboardSurface` contract.
- Reports logs, failures, and snapshot updates back to the host.

### Plugins

- Implement `createPlugin(context)` in Node.js.
- Return a lifecycle object with `start`, `getSnapshot`, `performAction`, and `stop`.
- Never render directly into the host in v1.
- Operate against explicit permissions and host-provided context.

## Rendering decision

V1 uses host-rendered plugin surfaces instead of arbitrary embedded plugin UI. This is the highest-leverage tradeoff for the first production scaffold because it gives:

- consistent touch sizing and motion
- a single visual language across plugins
- no webview crash path inside the dashboard surface
- better observability and error boundaries

Future phases can add an optional custom-surface path for plugins that need bespoke UI.

## Reused prior local work

Only two categories are intentionally adapted from `~/projects/icue`:

- display targeting heuristics for XENEON/XENEON-like screens
- calibration math and JSON persistence for touch mapping

The previous dashboard runtime, plugin model, and UI implementation are not reused.

## Agent workflow

The implementation is organized as role-based workstreams:

- Architecture agent: contracts, boundaries, phase plan
- Native macOS agent: windowing, multi-display behavior, settings integration
- Plugin platform agent: runtime host, manifests, lifecycle, IPC
- UI/UX agent: appliance-like dashboard shell and tile language
- System stats agent: local metric collection and sensor fallbacks
- Spotify agent: desktop-client-first transport integration and auth stubs
- Weather agent: API strategy and forecast mapping
- DevKit agent: preview, mocks, validation
- Debug/observability agent: logs, overlays, runtime traces
- Security/reliability agent: failure domains, permission model, restart strategy
- Testing/QA agent: baseline regression coverage
- Documentation agent: onboarding and integration guides

Cross-review rule: protocol or runtime changes must be reflected in docs and tests in the same slice.
