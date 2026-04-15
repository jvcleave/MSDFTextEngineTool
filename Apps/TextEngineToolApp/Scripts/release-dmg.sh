#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

ARCH="${ARCH:-arm64}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/Generated/Releases}"
DMG_NAME="${DMG_NAME:-TextEngineToolApp}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

BUILD_RUNTIME=0
NOTARIZE=1

usage() {
  cat <<'EOF'
Usage: release-dmg.sh [options]

Builds a signed TextEngineToolApp archive, creates a signed DMG, and optionally notarizes it.

Options:
  --build-runtime           Build runtime binary first (runs build-runtime-binary.sh).
  --skip-notarize           Skip notarization/stapling.
  --notary-profile <name>   notarytool keychain profile name (required unless --skip-notarize).
  --arch <arch>             Runtime/archive arch: arm64 (default), x86_64, universal.
  -h, --help                Show this help.

Environment overrides:
  SIGN_IDENTITY             Required. Code signing identity passed to archive/dmg scripts.
  DEVELOPMENT_TEAM          Required. Team ID passed to archive script.
  OUTPUT_DIR                Release output directory (default: Generated/Releases).
  DMG_NAME                  DMG file name without extension (default: TextEngineToolApp).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-runtime)
      BUILD_RUNTIME=1
      shift
      ;;
    --skip-notarize)
      NOTARIZE=0
      shift
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      if [[ -z "${NOTARY_PROFILE}" ]]; then
        echo "error: --notary-profile requires a value"
        exit 1
      fi
      shift 2
      ;;
    --arch)
      ARCH="${2:-}"
      if [[ -z "${ARCH}" ]]; then
        echo "error: --arch requires a value"
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "${NOTARIZE}" -eq 1 && -z "${NOTARY_PROFILE}" ]]; then
  echo "error: notarization enabled but no notary profile provided."
  echo "hint: pass --notary-profile <profile-name> or use --skip-notarize"
  exit 1
fi

if [[ -z "${SIGN_IDENTITY}" || -z "${DEVELOPMENT_TEAM}" ]]; then
  echo "error: SIGN_IDENTITY and DEVELOPMENT_TEAM must be set."
  echo "example: SIGN_IDENTITY='Developer ID Application: Example Company (TEAMID1234)' DEVELOPMENT_TEAM='TEAMID1234' Apps/TextEngineToolApp/Scripts/release-dmg.sh --notary-profile <profile-name>"
  exit 1
fi

DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"

echo "Release pipeline configuration:"
echo "  arch: ${ARCH}"
echo "  output dir: ${OUTPUT_DIR}"
echo "  dmg: ${DMG_PATH}"
echo "  build runtime: ${BUILD_RUNTIME}"
echo "  notarize: ${NOTARIZE}"
echo "  signing team: ${DEVELOPMENT_TEAM}"

if [[ "${BUILD_RUNTIME}" -eq 1 ]]; then
  echo "Step 1/4: building runtime binary..."
  ARCH="${ARCH}" OUTPUT_ROOT="${OUTPUT_DIR}/runtime" "${SCRIPT_DIR}/build-runtime-binary.sh"
else
  echo "Step 1/4: skipping runtime binary build."
fi

echo "Step 2/4: archiving app..."
TARGET_ARCH="${ARCH}" OUTPUT_ROOT="${OUTPUT_DIR}" SIGN_IDENTITY="${SIGN_IDENTITY}" DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" "${SCRIPT_DIR}/archive-app.sh"

echo "Step 3/4: creating DMG..."
OUTPUT_DIR="${OUTPUT_DIR}" DMG_NAME="${DMG_NAME}" SIGN_IDENTITY="${SIGN_IDENTITY}" "${SCRIPT_DIR}/make-dmg.sh"

if [[ "${NOTARIZE}" -eq 1 ]]; then
  echo "Step 4/4: notarizing DMG..."
  DMG_PATH="${DMG_PATH}" NOTARY_PROFILE="${NOTARY_PROFILE}" "${SCRIPT_DIR}/notarize-dmg.sh"
else
  echo "Step 4/4: skipping notarization."
fi

echo "Release pipeline complete:"
echo "  ${DMG_PATH}"
