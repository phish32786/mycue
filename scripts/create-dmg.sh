#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${1:-${DIST_DIR}/MyCue.app}"
DMG_PATH="${2:-${DIST_DIR}/MyCue.dmg}"
VOLUME_NAME="${MYCUE_DMG_VOLUME_NAME:-MyCue}"
STAGING_DIR="${ROOT_DIR}/.build/dmg-staging"
TEMP_DMG="${ROOT_DIR}/.build/MyCue-temp.dmg"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found at ${APP_PATH}" >&2
  exit 1
fi

rm -rf "${STAGING_DIR}" "${TEMP_DMG}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

STAGING_SIZE_MB="$(du -sm "${STAGING_DIR}" | awk '{print $1}')"
DMG_SIZE_MB=$((STAGING_SIZE_MB + 32))

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size "${DMG_SIZE_MB}m" \
  "${TEMP_DMG}" >/dev/null

hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" >/dev/null

rm -rf "${STAGING_DIR}" "${TEMP_DMG}"

echo "Created ${DMG_PATH}"
