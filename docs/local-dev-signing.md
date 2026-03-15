# Local Dev Signing

This is the local-development signing path for MyCue when you want macOS privacy permissions, especially Input Monitoring, to stick more reliably across rebuilds.

Preferred signing identity on this Mac:

```bash
Developer ID Application: Your Name (TEAMID)
```

Use the self-signed `MyCue Local Dev` identity only as a fallback when the real Developer ID certificate is unavailable.

## Goal

Create a stable local code-signing identity and use it every time you build `dist/MyCue.app`.

## Current build command

```bash
MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" bash scripts/build-release.sh
```

The packaging script already supports signing. It only needs a valid identity in your login keychain.

## One-time setup

If the real Developer ID identity is not available, run:

```bash
bash scripts/setup-local-dev-signing.sh
```

That script:

- creates a self-signed local code-signing certificate
- exports it as a PKCS#12
- imports it into the login keychain

## Important manual step

If macOS still does not list the identity as valid, open **Keychain Access** and locate:

`MyCue Local Dev`

Then trust it for code signing or set it to `Always Trust` for local development use.

Verify with:

```bash
security find-identity -v -p codesigning
```

You should see a valid identity for one of:

- `Developer ID Application: Your Name (TEAMID)`
- `MyCue Local Dev`

## Build a signed local app

```bash
MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" bash scripts/build-release.sh
```

Output:

- `dist/MyCue.app`
- `dist/MyCue.zip`
- `dist/MyCue.dmg`

## Recommended TCC / Input Monitoring flow

For XENEON hardware testing, use this flow after local signing is set up:

1. Remove stale `MyCue` entries from **System Settings > Privacy & Security > Input Monitoring** if the app has been rebuilt many times unsigned.
2. Build a signed local app:

```bash
MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" bash scripts/build-release.sh
```

3. Launch `dist/MyCue.app`.
4. If macOS prompts for Input Monitoring, allow it.
5. Quit and relaunch `dist/MyCue.app`.

After that, future rebuilds signed with the same identity should be much less likely to lose the permission state.

## Gatekeeper status

A local Developer ID signed build is still expected to show as `Unnotarized Developer ID` until notarization is configured:

```bash
spctl -a -vv dist/MyCue.app
```

That is normal for now. Signing stabilizes TCC/Input Monitoring; notarization is a separate release step.

## HID seize QA check

Use the bundled contention check to confirm MyCue is actually holding the XENEON HID interfaces:

```bash
bash scripts/verify-touch-seize.sh dist/MyCue.app open
```

Expected success:

- `PASS: MyCue is holding the XENEON HID interfaces`

If this fails, inspect:

- `~/Library/Logs/MyCue/touch.log`

That log captures the hardware touch service startup and seize status.

## Why this matters

Unsigned or ad-hoc signed rebuilds can cause macOS privacy systems like Input Monitoring to treat each build as a different app. A stable local signing identity reduces that churn during QA and hardware iteration.
