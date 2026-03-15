# Icon Composer Handoff

MyCue now keeps the Apple Icon Composer asset directly in:

- `docs/assets/MyCue.icon`

Why this exists:

- Apple’s new Icon Composer workflow uses a new multi-layer icon file type that integrates with Xcode.
- The official workflow is tool-driven through Icon Composer/Xcode rather than a stable, documented text format that should be hand-authored from shell scripts.
- MyCue therefore keeps a flattened `.icns` fallback for the current SwiftPM packaging path, but the Composer asset is the source of truth.

Recommended next step on a Mac with Icon Composer:

1. Open Icon Composer.
2. Create a new icon.
3. Edit the existing `docs/assets/MyCue.icon` asset.
4. Tune the Liquid Glass properties lightly.
5. Save it back to `docs/assets/MyCue.icon`.

Current repo behavior:

- the Composer asset now lives at `docs/assets/MyCue.icon`
- the SwiftPM packaging path still ships a generated `.icns`
- `scripts/generate-app-icon.sh` reads the layer PNGs inside `docs/assets/MyCue.icon/Assets` when present, so the packaged app icon stays aligned with the Composer source of truth

Why not package the `.icon` directly yet:

- the current app bundle is produced by a custom SwiftPM shell script, not an Xcode app target
- Apple’s public workflow for `.icon` assets is tool/Xcode-driven
- there is not a stable documented shell export path I should rely on here for release automation

Apple references:

- https://developer.apple.com/icon-composer/
- https://developer.apple.com/videos/play/wwdc2025/361/
