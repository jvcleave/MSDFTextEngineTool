#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

ARCH="${ARCH:-arm64}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${REPO_ROOT}/Generated/Releases/runtime}"
VENDOR_SOURCE_DIR="${REPO_ROOT}/Vendor/msdf-atlas-gen"
BUILD_DIR="${REPO_ROOT}/.vendor-build/msdf-atlas-gen-${ARCH}"
OUTPUT_BIN_DIR="${OUTPUT_ROOT}/${ARCH}/bin"
OUTPUT_BIN_PATH="${OUTPUT_BIN_DIR}/msdf-atlas-gen"

if [[ ! -d "${VENDOR_SOURCE_DIR}" ]]; then
  echo "error: missing vendor source at ${VENDOR_SOURCE_DIR}"
  exit 1
fi

case "${ARCH}" in
  arm64)
    CMAKE_ARCHES="arm64"
    PREFIX_PATHS=("/opt/homebrew")
    ;;
  x86_64)
    CMAKE_ARCHES="x86_64"
    PREFIX_PATHS=("/usr/local")
    ;;
  universal)
    CMAKE_ARCHES="arm64;x86_64"
    PREFIX_PATHS=("/opt/homebrew" "/usr/local")
    ;;
  *)
    echo "error: unsupported ARCH=${ARCH} (use arm64, x86_64, or universal)"
    exit 1
    ;;
esac

mkdir -p "${BUILD_DIR}" "${OUTPUT_BIN_DIR}"

CMAKE_PREFIX_PATH=""
for prefix in "${PREFIX_PATHS[@]}"; do
  if [[ -d "${prefix}" ]]; then
    if [[ -n "${CMAKE_PREFIX_PATH}" ]]; then
      CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH};${prefix}"
    else
      CMAKE_PREFIX_PATH="${prefix}"
    fi
  fi
done

CONFIG_ARGS=(
  -S "${VENDOR_SOURCE_DIR}"
  -B "${BUILD_DIR}"
  -DMSDF_ATLAS_USE_VCPKG=OFF
  -DMSDF_ATLAS_USE_SKIA=OFF
  -DMSDF_ATLAS_NO_ARTERY_FONT=ON
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_ARCHITECTURES="${CMAKE_ARCHES}"
)

if [[ -n "${CMAKE_PREFIX_PATH}" ]]; then
  CONFIG_ARGS+=("-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}")
fi

echo "Configuring runtime binary build (${ARCH})..."
cmake "${CONFIG_ARGS[@]}"

echo "Building msdf-atlas-gen-standalone..."
cmake --build "${BUILD_DIR}" --config Release --target msdf-atlas-gen-standalone

BUILT_BIN_CANDIDATES=(
  "${BUILD_DIR}/bin/msdf-atlas-gen"
  "${BUILD_DIR}/bin/Release/msdf-atlas-gen"
)

BUILT_BIN_PATH=""
for candidate in "${BUILT_BIN_CANDIDATES[@]}"; do
  if [[ -f "${candidate}" ]]; then
    BUILT_BIN_PATH="${candidate}"
    break
  fi
done

if [[ -z "${BUILT_BIN_PATH}" ]]; then
  echo "error: built binary not found in ${BUILD_DIR}"
  exit 1
fi

cp -f "${BUILT_BIN_PATH}" "${OUTPUT_BIN_PATH}"
chmod 755 "${OUTPUT_BIN_PATH}"

echo "Built runtime binary:"
echo "  ${OUTPUT_BIN_PATH}"
file "${OUTPUT_BIN_PATH}"
otool -L "${OUTPUT_BIN_PATH}"
