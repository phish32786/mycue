#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.tmp/local-dev-signing"
KEYCHAIN_PATH="${HOME}/Library/Keychains/login.keychain-db"
CERT_NAME="${MYCUE_LOCAL_CERT_NAME:-MyCue Local Dev}"
P12_PASSWORD="${MYCUE_LOCAL_P12_PASSWORD:-mycue-dev}"

mkdir -p "${WORK_DIR}"

cat > "${WORK_DIR}/openssl-mycue-dev.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no

[ dn ]
CN = ${CERT_NAME}
O = ${CERT_NAME}
OU = Development

[ ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
EOF

openssl req \
  -newkey rsa:2048 \
  -nodes \
  -keyout "${WORK_DIR}/mycue-dev.key" \
  -x509 \
  -days 3650 \
  -out "${WORK_DIR}/mycue-dev.crt" \
  -config "${WORK_DIR}/openssl-mycue-dev.cnf"

openssl pkcs12 \
  -export \
  -legacy \
  -out "${WORK_DIR}/mycue-dev.p12" \
  -inkey "${WORK_DIR}/mycue-dev.key" \
  -in "${WORK_DIR}/mycue-dev.crt" \
  -passout "pass:${P12_PASSWORD}"

security import "${WORK_DIR}/mycue-dev.p12" \
  -k "${KEYCHAIN_PATH}" \
  -P "${P12_PASSWORD}" \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security

cat <<EOF

Local dev signing materials created and imported:
  Certificate: ${CERT_NAME}
  Work dir:    ${WORK_DIR}

Next steps:
1. Open Keychain Access and locate "${CERT_NAME}" under login keychain.
2. Trust it for code signing if macOS still reports no valid signing identity.
3. Verify with:
   security find-identity -v -p codesigning
4. Build a signed app with:
   MYCUE_CODESIGN_IDENTITY="${CERT_NAME}" bash scripts/build-release.sh

EOF
