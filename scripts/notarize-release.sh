#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${1:-${DIST_DIR}/MyCue.app}"
ZIP_PATH="${2:-${DIST_DIR}/MyCue.zip}"
DMG_PATH="${3:-${DIST_DIR}/MyCue.dmg}"

APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_NOTARY_KEY_ID="${APPLE_NOTARY_KEY_ID:-}"
APPLE_NOTARY_ISSUER_ID="${APPLE_NOTARY_ISSUER_ID:-}"
APPLE_NOTARY_API_KEY_PATH="${APPLE_NOTARY_API_KEY_PATH:-}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found at ${APP_PATH}" >&2
  exit 1
fi

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Zip archive not found at ${ZIP_PATH}" >&2
  exit 1
fi

if [[ -z "${APPLE_TEAM_ID}" || -z "${APPLE_NOTARY_KEY_ID}" || -z "${APPLE_NOTARY_ISSUER_ID}" || -z "${APPLE_NOTARY_API_KEY_PATH}" ]]; then
  cat >&2 <<EOF
Missing notarization environment.

Required:
  APPLE_TEAM_ID
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_ISSUER_ID
  APPLE_NOTARY_API_KEY_PATH

Example:
  export APPLE_TEAM_ID="TEAMID"
  export APPLE_NOTARY_KEY_ID="ABC123DEFG"
  export APPLE_NOTARY_ISSUER_ID="00000000-0000-0000-0000-000000000000"
  export APPLE_NOTARY_API_KEY_PATH="$HOME/.private_keys/AuthKey_ABC123DEFG.p8"
EOF
  exit 1
fi

if [[ ! -f "${APPLE_NOTARY_API_KEY_PATH}" ]]; then
  echo "Notary API key not found at ${APPLE_NOTARY_API_KEY_PATH}" >&2
  exit 1
fi

echo "==> Verifying signed app before notarization"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
codesign -dv --verbose=4 "${APP_PATH}" 2>&1 | sed -n '1,20p'

echo "==> Submitting zip to Apple notarization service"
xcrun notarytool submit "${ZIP_PATH}" \
  --key "${APPLE_NOTARY_API_KEY_PATH}" \
  --key-id "${APPLE_NOTARY_KEY_ID}" \
  --issuer "${APPLE_NOTARY_ISSUER_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "${APP_PATH}"

echo "==> Repacking stapled zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> Rebuilding DMG"
bash "${ROOT_DIR}/scripts/create-dmg.sh" "${APP_PATH}" "${DMG_PATH}"

echo "==> Final verification"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl -a -vv "${APP_PATH}" || true

echo
echo "Release artifacts:"
echo "  App: ${APP_PATH}"
echo "  Zip: ${ZIP_PATH}"
echo "  DMG: ${DMG_PATH}"
