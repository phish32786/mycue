# Debug Mode Design

Debug mode is host-owned so production plugins remain unaware of the diagnostics shell.

## Included in the first scaffold

- runtime connection state
- plugin lifecycle and crash logs
- recent IPC log stream
- plugin count and render count
- selected display info

## Planned additions

- touch visualization
- calibration overlay
- FPS and frame pacing
- per-plugin CPU and memory metrics
- device and HID path diagnostics
