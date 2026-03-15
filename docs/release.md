# Release Prep

## Package build path

MyCue now has a self-contained packaging script:

```bash
./scripts/build-release.sh
```

This script:

- builds the Swift host in release mode
- creates `dist/MyCue.app`
- copies the Node runtime into `Contents/Resources/Runtime`
- copies plugins into `Contents/Resources/Plugins`
- generates `Resources/AppIcon.icns`
- optionally signs the app if `MYCUE_CODESIGN_IDENTITY` is set
- creates `dist/MyCue.zip`
- creates `dist/MyCue.dmg`

## Local notarization path

After building a signed app locally, notarize and staple it with:

```bash
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="YOUR_KEY_ID"
export APPLE_NOTARY_ISSUER_ID="YOUR_ISSUER_ID"
export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8"
bash scripts/notarize-release.sh
```

This script:

- verifies the signed app bundle
- submits `dist/MyCue.zip` with `notarytool`
- staples the returned ticket to `dist/MyCue.app`
- rebuilds `dist/MyCue.dmg` from the stapled app
- reruns local signature checks

## GitHub Actions

The repo includes these packaging workflows:

- `.github/workflows/ci.yml`
  - builds and tests the Swift host
  - validates plugin manifests
  - runs the DevKit Node tests
  - performs a smoke package build and uploads the unsigned artifacts
- `.github/workflows/package.yml`
  - manual or tag-driven package build
  - uploads `MyCue.app`, `MyCue.zip`, and `MyCue.dmg`
- `.github/workflows/signed-release.yml`
  - manual or tag-driven signed release build
  - imports a Developer ID certificate
  - builds a signed app bundle
  - submits the zip to Apple notarytool
  - staples the app
  - repacks the zip
  - uploads the signed release artifacts

## Repository hygiene

Keep personal identifiers out of tracked repo content:

- do not commit real names, team IDs, key IDs, issuer IDs, email addresses, or machine names into docs or helper scripts
- keep examples generic, for example `Your Name (TEAMID)`, `TEAMID`, `KEYID12345`, and `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- keep real signing and notarization values in local environment variables, untracked files, or GitHub Actions secrets only

## GitHub secrets for signing

The signed release workflow expects these repository secrets:

- `APPLE_DEVELOPER_IDENTITY`
- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`
- `APPLE_NOTARY_API_KEY_P8_BASE64`

Detailed setup instructions are in `docs/signing-setup.md`.

## Build examples

Unsigned package build:

```bash
./scripts/build-release.sh
```

Signed package build:

```bash
export MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/build-release.sh
```

Signed + notarized package build:

```bash
export MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="YOUR_KEY_ID"
export APPLE_NOTARY_ISSUER_ID="YOUR_ISSUER_ID"
export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8"
./scripts/build-release.sh
bash scripts/notarize-release.sh
```

## Current limits

- workflow filenames still use legacy names in a few places
- DMG packaging is drag-to-Applications and intentionally simple
- bundle identifier and version still default to placeholders unless overridden by env vars

## Before external distribution

- replace `com.mycue` with the real bundle identifier if needed
- set the real app version/build number in workflow inputs or release env vars
- verify first-run behavior on a clean macOS machine
- verify bundled runtime launch on a non-repo path
