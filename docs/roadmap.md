# Phased Implementation Roadmap

## Phase 1

### Goals

- Lock architecture and shared protocol
- Build the native host scaffold
- Build the Node runtime scaffold
- Build the DevKit scaffold
- Ship starter plugin vertical slices

### Architecture decisions

- Host-rendered typed surfaces
- JSON-lines IPC over stdio
- Manifest-driven Node plugin loading
- Simulator-first virtual-device workflow

### Implementation plan

- Add shared models and message envelopes
- Add display selection, settings persistence, and kiosk placement
- Add runtime process supervision and snapshot ingestion
- Add system stats, Spotify, and weather plugin modules
- Add DevKit preview and validation commands

### Risks and tradeoffs

- GPU and thermal data are limited without privileged integrations
- Spotify control quality depends on the local desktop client
- Weather quality depends on network availability

## Phase 2

### Goals

- Add direct HID ingestion and device seizure for hardware mode
- Use persisted calibration data in the input pipeline
- Improve restart/recovery and plugin health policies

## Phase 3

### Goals

- Add richer plugin settings and capability prompts
- Add optional custom-surface plugins
- Add plugin packaging and signing workflow
- Add automated release packaging
