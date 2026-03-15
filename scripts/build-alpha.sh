#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build/release"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="MyCue"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
RUNTIME_DIR="${RESOURCES_DIR}/Runtime"
PLUGINS_DIR="${RESOURCES_DIR}/Plugins"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-alpha.zip"
EXECUTABLE_NAME="edge-control"
EXECUTABLE_PATH="${BUILD_DIR}/${EXECUTABLE_NAME}"
SIGN_IDENTITY="${MYCUE_CODESIGN_IDENTITY:-}"
BUNDLE_IDENTIFIER="${MYCUE_BUNDLE_IDENTIFIER:-com.mycue.alpha}"
APP_VERSION="${MYCUE_APP_VERSION:-0.1.0-alpha}"
BUILD_NUMBER="${MYCUE_BUILD_NUMBER:-1}"

mkdir -p "${DIST_DIR}"
echo "==> Generating app icon"
bash "${ROOT_DIR}/scripts/generate-app-icon.sh"
ICON_SOURCE="${ROOT_DIR}/Resources/AppIcon.icns"

echo "==> Building release executable"
swift build -c release --product "${EXECUTABLE_NAME}"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Release executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

echo "==> Creating app bundle"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RUNTIME_DIR}" "${PLUGINS_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
cp -R "${ROOT_DIR}/runtime/node-host" "${RUNTIME_DIR}/"
cp -R "${ROOT_DIR}/plugins/." "${PLUGINS_DIR}/"
cp "${ICON_SOURCE}" "${RESOURCES_DIR}/AppIcon.icns"
find "${APP_DIR}" -name ".DS_Store" -delete

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>MyCue</string>
  <key>CFBundleExecutable</key>
  <string>MyCue</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MyCue</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Codesigning app bundle"
  codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
  echo "==> Skipping codesign (set MYCUE_CODESIGN_IDENTITY to sign)"
fi

echo "==> Creating zip archive"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo
echo "Created:"
echo "  App: ${APP_DIR}"
echo "  Zip: ${ZIP_PATH}"
