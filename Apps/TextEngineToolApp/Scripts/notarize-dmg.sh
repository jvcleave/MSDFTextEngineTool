#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

DMG_PATH="${DMG_PATH:-${REPO_ROOT}/Generated/Releases/TextEngineToolApp.dmg}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "error: DMG not found at ${DMG_PATH}"
  exit 1
fi

if [[ -z "${NOTARY_PROFILE}" ]]; then
  echo "error: NOTARY_PROFILE is required (xcrun notarytool keychain profile name)"
  exit 1
fi

echo "Submitting DMG for notarization..."
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

echo "Validating stapled ticket..."
xcrun stapler validate "${DMG_PATH}"

echo "Notarization + stapling complete:"
echo "  ${DMG_PATH}"
