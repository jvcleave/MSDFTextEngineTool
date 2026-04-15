#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <TextEngineToolApp.app path>"
  exit 1
fi

APP_PATH="$1"
BIN_PATH="${APP_PATH}/Contents/Resources/bin/msdf-atlas-gen"
FRAMEWORKS_PATH="${APP_PATH}/Contents/Frameworks"

if [[ ! -f "${BIN_PATH}" ]]; then
  echo "error: missing runtime binary at ${BIN_PATH}"
  exit 1
fi

if [[ ! -d "${FRAMEWORKS_PATH}" ]]; then
  echo "error: missing frameworks folder at ${FRAMEWORKS_PATH}"
  exit 1
fi

for required_lib in libpng16.16.dylib libfreetype.6.dylib; do
  if [[ ! -f "${FRAMEWORKS_PATH}/${required_lib}" ]]; then
    echo "error: missing bundled dependency ${required_lib}"
    exit 1
  fi
done

MSDF_DEPS="$(otool -L "${BIN_PATH}")"
echo "${MSDF_DEPS}"

if echo "${MSDF_DEPS}" | grep -E '/opt/homebrew|/usr/local/opt' >/dev/null; then
  echo "error: runtime binary still links to external Homebrew paths"
  exit 1
fi

echo "Runtime bundle verification passed for ${APP_PATH}"
