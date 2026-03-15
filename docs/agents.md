# Agent Coordination Notes

## Workstream order

1. Architecture defines the bridge, rendering contract, and phase boundaries.
2. Native macOS work sets up the host shell and display behavior.
3. Plugin platform work brings up the runtime and starter plugins.
4. UI/UX work tunes the dashboard presentation and touch ergonomics.
5. DevKit and debug work makes iteration practical.
6. QA and docs close the loop on validation and onboarding.

## Review gates

- Protocol changes require matching updates in Swift models, Node runtime payloads, and docs.
- Plugin permissions and failure handling require a security/reliability review.
- Display or calibration changes require regression checks against the reused local calibration model.
