# Apple Signing Setup

This is the shortest path to getting the signed release workflow working for MyCue.

## Privacy note

Keep real signing identities and notarization identifiers out of committed repo content.
Use placeholders in docs and scripts, and keep the real values in:

- local environment variables
- untracked files
- GitHub Actions secrets

## 1. Create a Developer ID Application certificate

Use Apple’s Developer ID certificate flow and create a `Developer ID Application` certificate, then install it into your Mac’s keychain.

Apple docs:

- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)

Practical output you need on your Mac:

- a `Developer ID Application: ...` identity in Keychain Access
- the matching private key in the same keychain

## 2. Export the certificate as `.p12`

In Keychain Access:

1. Open `My Certificates`
2. Find the `Developer ID Application` identity
3. Expand it and confirm the private key is present
4. Right-click the identity
5. Choose `Export`
6. Save it as a `.p12`
7. Choose a strong export password

You will use:

- the `.p12` file
- the `.p12` export password
- the visible certificate name, for example:
  - `Developer ID Application: Your Name (TEAMID)`

## 3. Create an App Store Connect API key for notarization

Create an App Store Connect API key and download the `.p8` file.

Apple doc:

- [App Store Connect API - Get started](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

You will need:

- `KEY_ID`
- `ISSUER_ID`
- the downloaded `AuthKey_KEYID.p8`
- your `TEAM_ID`

Important:

- Apple only lets you download the `.p8` once
- store it somewhere safe immediately

## 4. Add GitHub repository secrets

GitHub doc:

- [Using secrets in GitHub Actions](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)

Required repo secrets:

- `APPLE_DEVELOPER_IDENTITY`
- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_NOTARY_KEY_ID`
- `APPLE_NOTARY_ISSUER_ID`
- `APPLE_NOTARY_API_KEY_P8_BASE64`

### Fast path with the helper script

Export these environment variables:

```bash
export APPLE_DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_DEVELOPER_ID_P12_PASSWORD="your-p12-password"
export APPLE_KEYCHAIN_PASSWORD="temporary-ci-keychain-password"
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="KEYID12345"
export APPLE_NOTARY_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Then run:

```bash
scripts/setup-github-signing-secrets.sh \
  /path/to/developer-id.p12 \
  /path/to/AuthKey_KEYID12345.p8
```

This uploads the secrets directly to the configured GitHub repo using `gh secret set`.

## 5. Run the signed workflow

In GitHub Actions:

1. Open the signed release workflow
2. Click `Run workflow`
3. Optionally set:
   - `app_version`
   - `build_number`

The workflow will:

- build the app
- sign it
- notarize the zip
- staple the notarization ticket to the app
- repack the stapled zip
- upload the signed artifacts

## 6. What to expect if it fails

Most likely first failures:

- wrong certificate name in `APPLE_DEVELOPER_IDENTITY`
- `.p12` export does not contain the private key
- bad `.p12` password
- wrong `KEY_ID` / `ISSUER_ID`
- invalid or revoked `.p8` notarization key

If it fails, the fastest next step is to inspect the GitHub Actions log for:

- the `codesign` step
- the `notarytool submit` step
- the `stapler` step

## Local notarization smoke test

Before wiring GitHub secrets, validate notarization on this Mac:

1. Build a signed app:

```bash
export MYCUE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
bash scripts/build-alpha.sh
```

2. Save the notarization key somewhere local, for example:

```bash
mkdir -p "$HOME/.private_keys"
cp /path/to/AuthKey_KEYID12345.p8 "$HOME/.private_keys/"
```

3. Export the notarization environment:

```bash
export APPLE_TEAM_ID="TEAMID"
export APPLE_NOTARY_KEY_ID="KEYID12345"
export APPLE_NOTARY_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_KEYID12345.p8"
```

4. Run the local notarization helper:

```bash
bash scripts/notarize-alpha.sh
```

5. Validate the result:

```bash
codesign --verify --deep --strict --verbose=2 dist/MyCue.app
spctl -a -vv dist/MyCue.app
```

`spctl` should stop reporting `Unnotarized Developer ID` once the app has been notarized and stapled successfully.
