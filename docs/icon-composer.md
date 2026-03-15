# Icon Composer Handoff

MyCue now has prepared layered source assets for Apple Icon Composer in:

- `docs/assets/icon-composer/layer-01-shell.png`
- `docs/assets/icon-composer/layer-02-grid.png`
- `docs/assets/icon-composer/layer-03-monogram.png`
- `docs/assets/icon-composer/layer-04-accent.png`

Generate or refresh them with:

```bash
bash scripts/generate-icon-composer-layers.sh
```

Why this exists:

- Apple’s new Icon Composer workflow uses a new multi-layer icon file type that integrates with Xcode.
- The official workflow is tool-driven through Icon Composer/Xcode rather than a stable, documented text format that should be hand-authored from shell scripts.
- MyCue therefore keeps a flattened `.icns` fallback for the current SwiftPM packaging path, plus these layered source assets for the real Icon Composer asset.

Recommended next step on a Mac with Icon Composer:

1. Open Icon Composer.
2. Create a new icon.
3. Import the four prepared layers in order.
4. Tune the Liquid Glass properties lightly.
5. Save the Composer asset as `docs/assets/MyCue.icon`.

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
