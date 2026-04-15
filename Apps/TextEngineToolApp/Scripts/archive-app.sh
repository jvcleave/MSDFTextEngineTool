#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

PROJECT_PATH="${REPO_ROOT}/Apps/TextEngineToolApp/TextEngineToolApp/TextEngineToolApp.xcodeproj"
SCHEME="${SCHEME:-TextEngineToolApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
DESTINATION="${DESTINATION:-platform=macOS,arch=${TARGET_ARCH}}"

OUTPUT_ROOT="${OUTPUT_ROOT:-${REPO_ROOT}/Generated/Releases}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${OUTPUT_ROOT}/TextEngineToolApp.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-${OUTPUT_ROOT}/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
DEFAULT_RELEASE_RUNTIME_BINARY="${REPO_ROOT}/Generated/Releases/runtime/arm64/bin/msdf-atlas-gen"
DEFAULT_VENDOR_RUNTIME_BINARY="${REPO_ROOT}/.vendor-build/msdf-atlas-gen/bin/msdf-atlas-gen"

if [[ -f "${DEFAULT_RELEASE_RUNTIME_BINARY}" ]]; then
  RUNTIME_BINARY="${RUNTIME_BINARY:-${DEFAULT_RELEASE_RUNTIME_BINARY}}"
else
  RUNTIME_BINARY="${RUNTIME_BINARY:-${DEFAULT_VENDOR_RUNTIME_BINARY}}"
fi

if [[ ! -f "${RUNTIME_BINARY}" ]]; then
  echo "error: runtime binary not found at ${RUNTIME_BINARY}"
  echo "hint: run Apps/TextEngineToolApp/Scripts/build-runtime-binary.sh first"
  exit 1
fi

if [[ -z "${SIGN_IDENTITY}" || -z "${DEVELOPMENT_TEAM}" ]]; then
  echo "error: SIGN_IDENTITY and DEVELOPMENT_TEAM are required for archive signing."
  echo "example: SIGN_IDENTITY='Developer ID Application: Example Company (TEAMID1234)' DEVELOPMENT_TEAM='TEAMID1234' Apps/TextEngineToolApp/Scripts/archive-app.sh"
  exit 1
fi

mkdir -p "${OUTPUT_ROOT}"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"

echo "Archiving ${SCHEME} (${CONFIGURATION})..."
TEXT_ENGINE_MSDF_BINARY="${RUNTIME_BINARY}" xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  ARCHS="${TARGET_ARCH}" \
  ONLY_ACTIVE_ARCH=YES \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
  archive \
  -archivePath "${ARCHIVE_PATH}"

ARCHIVED_APP_PATH="${ARCHIVE_PATH}/Products/Applications/TextEngineToolApp.app"

"${SCRIPT_DIR}/verify-runtime-bundle.sh" "${ARCHIVED_APP_PATH}"

if [[ -n "${EXPORT_OPTIONS_PLIST}" ]]; then
  echo "Exporting archive using ${EXPORT_OPTIONS_PLIST}..."
  xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

  EXPORTED_APP_PATH="${EXPORT_PATH}/TextEngineToolApp.app"
  if [[ -d "${EXPORTED_APP_PATH}" ]]; then
    "${SCRIPT_DIR}/verify-runtime-bundle.sh" "${EXPORTED_APP_PATH}"
  else
    echo "warning: exported app not found at ${EXPORTED_APP_PATH}"
  fi
else
  echo "Skipped export step (set EXPORT_OPTIONS_PLIST to run exportArchive)."
fi

echo "Archive complete:"
echo "  ${ARCHIVE_PATH}"
echo "Runtime binary used:"
echo "  ${RUNTIME_BINARY}"
echo "Target arch:"
echo "  ${TARGET_ARCH}"
echo "Code sign identity:"
echo "  ${SIGN_IDENTITY}"
