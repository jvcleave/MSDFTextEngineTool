#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

APP_PATH="${APP_PATH:-${REPO_ROOT}/Generated/Releases/TextEngineToolApp.xcarchive/Products/Applications/TextEngineToolApp.app}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/Generated/Releases}"
DMG_NAME="${DMG_NAME:-TextEngineToolApp}"
VOLUME_NAME="${VOLUME_NAME:-TextEngineToolApp}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: app not found at ${APP_PATH}"
  exit 1
fi

if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "error: SIGN_IDENTITY is required for DMG signing."
  echo "example: SIGN_IDENTITY='Developer ID Application: Example Company (TEAMID1234)' Apps/TextEngineToolApp/Scripts/make-dmg.sh"
  exit 1
fi

"${SCRIPT_DIR}/verify-runtime-bundle.sh" "${APP_PATH}"

mkdir -p "${OUTPUT_DIR}"

STAGING_DIR="$(mktemp -d "${OUTPUT_DIR}/dmg-staging.XXXXXX")"
cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "Signing DMG with identity: ${SIGN_IDENTITY}"
codesign --force --sign "${SIGN_IDENTITY}" "${DMG_PATH}"

echo "DMG created:"
echo "  ${DMG_PATH}"
