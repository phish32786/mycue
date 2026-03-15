#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  cat >&2 <<'EOF'
Usage:
  scripts/setup-github-signing-secrets.sh /path/to/developer-id.p12 /path/to/AuthKey_KEYID.p8

Required environment variables:
  APPLE_DEVELOPER_IDENTITY
  APPLE_DEVELOPER_ID_P12_PASSWORD
  APPLE_KEYCHAIN_PASSWORD
  APPLE_TEAM_ID
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_ISSUER_ID

Optional:
  GITHUB_REPO=owner/repo
EOF
  exit 1
fi

P12_PATH="$1"
P8_PATH="$2"
REPO="${GITHUB_REPO:-owner/repo}"

required_vars=(
  APPLE_DEVELOPER_IDENTITY
  APPLE_DEVELOPER_ID_P12_PASSWORD
  APPLE_KEYCHAIN_PASSWORD
  APPLE_TEAM_ID
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_ISSUER_ID
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required environment variable: ${var}" >&2
    exit 1
  fi
done

if [[ ! -f "${P12_PATH}" ]]; then
  echo "P12 file not found: ${P12_PATH}" >&2
  exit 1
fi

if [[ ! -f "${P8_PATH}" ]]; then
  echo "P8 file not found: ${P8_PATH}" >&2
  exit 1
fi

set_secret() {
  local name="$1"
  local value="$2"
  printf '%s' "${value}" | gh secret set "${name}" --repo "${REPO}"
}

echo "Uploading GitHub Actions secrets to ${REPO}"

set_secret "APPLE_DEVELOPER_IDENTITY" "${APPLE_DEVELOPER_IDENTITY}"
set_secret "APPLE_DEVELOPER_ID_P12_PASSWORD" "${APPLE_DEVELOPER_ID_P12_PASSWORD}"
set_secret "APPLE_KEYCHAIN_PASSWORD" "${APPLE_KEYCHAIN_PASSWORD}"
set_secret "APPLE_TEAM_ID" "${APPLE_TEAM_ID}"
set_secret "APPLE_NOTARY_KEY_ID" "${APPLE_NOTARY_KEY_ID}"
set_secret "APPLE_NOTARY_ISSUER_ID" "${APPLE_NOTARY_ISSUER_ID}"
set_secret "APPLE_DEVELOPER_ID_P12_BASE64" "$(base64 < "${P12_PATH}" | tr -d '\n')"
set_secret "APPLE_NOTARY_API_KEY_P8_BASE64" "$(base64 < "${P8_PATH}" | tr -d '\n')"

echo "Done."
