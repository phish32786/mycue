# Alpha Checklist

## Build and launch

- Build the app with `swift build` and `swift test`
- Build the distributable app with `MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-alpha.sh`
- Notarize and staple it with `bash scripts/notarize-alpha.sh`
- Launch `dist/MyCue.app` outside the repo root
- Verify the Node plugin runtime starts from bundled resources
- Verify settings still open on the main display
- Verify `codesign -dv --verbose=4 dist/MyCue.app` shows the expected Developer ID authority
- Verify `spctl -a -vv dist/MyCue.app` accepts the notarized app

## Hardware mode

- Connect the XENEON EDGE before launch
- Verify MyCue opens on the XENEON instead of the built-in display
- Verify kiosk/full-screen presentation on the XENEON
- Verify touch input does not click through to the main display
- Verify `bash scripts/verify-touch-seize.sh dist/MyCue.app open` passes
- Verify existing calibration is reused when valid
- Verify `Reset calibration` restarts the corner flow
- Verify unplug/replug recovery using `Retry hardware`
- Verify `Restart touch` restores input after HID interruption
- Verify relaunch does not require re-approving Input Monitoring for the same signed build

## DevKit mode

- Launch without the XENEON connected
- Verify automatic fallback to DevKit window mode
- Verify standard close/minimize/zoom controls
- Verify `Command-Q` works
- Verify resizing preserves the 32:9 aspect ratio
- Verify cards scale with the DevKit window

## Dashboard workflow

- Verify `CTL` reveals settings/edit controls and auto-hides
- Verify page strip only appears with the transient HUD or edit mode
- Verify edit mode stays visible until exited
- Verify drag reorder works in DevKit
- Verify hardware touch reorder works on the XENEON
- Verify page add/remove/reorder persists after relaunch

## Plugins

- Verify System Stats renders live host metrics
- Verify Spotify renders metadata, artwork, transport, and volume
- Verify Weather renders forecast for saved coordinates
- Verify Launcher actions open apps/URLs
- Verify Web Widget loads an allowed page
- Verify Media Gallery loads images from the configured folder
- Verify failed/degraded plugins show recovery UI
- Verify `Restart runtime` recovers plugin surfaces without relaunch

## Failure handling

- Kill the Node runtime and confirm recovery through `Restart runtime`
- Force a plugin failure and verify module-level error UI
- Verify settings surface shows plugin diagnostics for failed/degraded modules
- Verify the app remains responsive while one plugin is failed

## Persistence

- Verify display selection persists
- Verify weather settings persist
- Verify web widget settings persist
- Verify media gallery folder/interval/shuffle persist
- Verify page membership and card spans persist
- Verify disabled plugins remain disabled after relaunch

## Release readiness gaps

- Developer ID signing
- Notarization
- Hardened runtime and entitlements review
- Clean first-run test on another Mac
- Real-world Spotify/device edge-case validation
- Real-world web embed failure messaging pass
