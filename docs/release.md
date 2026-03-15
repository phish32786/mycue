# Release Prep

## Alpha build path

MyCue now has a self-contained alpha packaging script:

```bash
./scripts/build-alpha.sh
```

This script:

- builds the Swift host in release mode
- creates `dist/MyCue.app`
- copies the Node runtime into `Contents/Resources/Runtime`
- copies plugins into `Contents/Resources/Plugins`
- generates a minimal `Info.plist`
- optionally signs the app if `MYCUE_CODESIGN_IDENTITY` is set
- creates `dist/MyCue-alpha.zip`

## Local notarization path

After building a signed app locally, notarize and staple it with:

```bash
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="YOUR_KEY_ID"
export APPLE_NOTARY_ISSUER_ID="YOUR_ISSUER_ID"
export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8"
bash scripts/notarize-alpha.sh
```

This script:

- verifies the signed app bundle
- submits `dist/MyCue-alpha.zip` with `notarytool`
- staples the returned ticket to `dist/MyCue.app`
- repacks `dist/MyCue-alpha.zip` from the stapled app
- reruns local signature checks

## GitHub Actions

The repo now includes two workflows:

- `.github/workflows/ci.yml`
  - builds and tests the Swift host
  - validates plugin manifests
  - runs the DevKit Node tests
  - performs a smoke alpha packaging build and uploads the unsigned artifact
- `.github/workflows/alpha-package.yml`
  - manual or tag-driven alpha packaging
  - uploads `MyCue.app` and `MyCue-alpha.zip` as workflow artifacts
- `.github/workflows/signed-alpha.yml`
  - manual or tag-driven signed alpha packaging
  - imports a Developer ID certificate
  - builds a signed app bundle
  - submits the zip to Apple notarytool
  - staples the app
  - repacks the stapled zip
  - uploads the signed alpha artifacts

## GitHub secrets for signing

The signed alpha workflow expects these repository secrets:

- `APPLE_DEVELOPER_IDENTITY`
  - example: `Developer ID Application: Your Name (TEAMID)`
- `APPLE_DEVELOPER_ID_P12_BASE64`
  - base64 of the exported Developer ID Application `.p12`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
  - password used when exporting the `.p12`
- `APPLE_KEYCHAIN_PASSWORD`
  - temporary CI keychain password
- `APPLE_TEAM_ID`
  - your Apple Developer team ID
- `APPLE_NOTARY_KEY_ID`
  - App Store Connect API key ID for notarization
- `APPLE_NOTARY_ISSUER_ID`
  - App Store Connect issuer ID
- `APPLE_NOTARY_API_KEY_P8_BASE64`
  - base64 of the notarization `.p8` API key

Detailed setup instructions are in `docs/signing-setup.md`.

## Optional signing

Unsigned alpha build:

```bash
./scripts/build-alpha.sh
```

Signed alpha build:

```bash
export MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/build-alpha.sh
```

Signed + notarized alpha build:

```bash
export MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="YOUR_KEY_ID"
export APPLE_NOTARY_ISSUER_ID="YOUR_ISSUER_ID"
export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8"
./scripts/build-alpha.sh
bash scripts/notarize-alpha.sh
```

## Current limits

- No DMG generation yet
- No hardened runtime entitlements file yet
- Bundle identifier and version still default to alpha placeholders unless overridden by env vars
- Login item registration is still a saved preference only
- GitHub Actions can now produce unsigned or signed alpha artifacts, depending on which workflow you run

## Before external alpha distribution

- replace `com.mycue.alpha` with the real bundle identifier
- set the real app version/build number in workflow inputs or release env vars
- verify first-run behavior on a clean macOS machine
- verify Node runtime launch inside the app bundle on a non-repo path
