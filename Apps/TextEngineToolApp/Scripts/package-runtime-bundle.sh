#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_ROOT}/../.." && pwd)"

ARCH="${ARCH:-arm64}"
VERSION="${VERSION:-1}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${REPO_ROOT}/Generated/Releases/runtime-bundles}"
DEFAULT_RELEASE_RUNTIME_BINARY="${REPO_ROOT}/Generated/Releases/runtime/${ARCH}/bin/msdf-atlas-gen"
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

BUNDLE_NAME="${BUNDLE_NAME:-textengine-msdf-runtime-macos-${ARCH}-v${VERSION}}"
ZIP_PATH="${OUTPUT_ROOT}/${BUNDLE_NAME}.zip"

mkdir -p "${OUTPUT_ROOT}"

WORK_DIR="$(mktemp -d "${OUTPUT_ROOT}/bundle-work.XXXXXX")"
cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

BUNDLE_DIR="${WORK_DIR}/${BUNDLE_NAME}"
RES_BIN_DIR="${BUNDLE_DIR}/Resources/bin"
FRAMEWORKS_DIR="${BUNDLE_DIR}/Frameworks"
DEST_BINARY="${RES_BIN_DIR}/msdf-atlas-gen"

mkdir -p "${RES_BIN_DIR}" "${FRAMEWORKS_DIR}"
cp -f "${RUNTIME_BINARY}" "${DEST_BINARY}"
chmod 755 "${DEST_BINARY}"

is_system_dep() {
  local dep="$1"
  [[ "${dep}" == /usr/lib/* || "${dep}" == /System/Library/* ]]
}

extract_deps() {
  local file_path="$1"
  otool -L "${file_path}" | tail -n +2 | awk '{print $1}'
}

declare -a orig_deps=()
declare -a dest_deps=()
declare -a queue=("${RUNTIME_BINARY}")

has_dep() {
  local candidate="$1"
  local dep
  for dep in "${orig_deps[@]-}"; do
    if [[ "${dep}" == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

add_dep() {
  local original="$1"
  local dest="$2"
  orig_deps+=("${original}")
  dest_deps+=("${dest}")
}

dep_dest_for() {
  local original="$1"
  local idx
  local dep_count=${#orig_deps[@]}
  for ((idx=0; idx<dep_count; idx++)); do
    if [[ "${orig_deps[$idx]}" == "${original}" ]]; then
      echo "${dest_deps[$idx]}"
      return 0
    fi
  done
  return 1
}

while [[ ${#queue[@]} -gt 0 ]]; do
  current="${queue[0]}"
  queue=("${queue[@]:1}")

  while IFS= read -r dep; do
    [[ -z "${dep}" ]] && continue

    if [[ "${dep}" == @rpath/* || "${dep}" == @loader_path/* || "${dep}" == @executable_path/* ]]; then
      continue
    fi

    if is_system_dep "${dep}"; then
      continue
    fi

    if [[ ! -f "${dep}" ]]; then
      echo "warning: dependency '${dep}' does not exist on disk"
      continue
    fi

    if has_dep "${dep}"; then
      continue
    fi

    dep_base="$(basename "${dep}")"
    dep_dest="${FRAMEWORKS_DIR}/${dep_base}"
    cp -f "${dep}" "${dep_dest}"
    chmod 755 "${dep_dest}"

    add_dep "${dep}" "${dep_dest}"
    queue+=("${dep}")
  done < <(extract_deps "${current}")
done

for dep in "${orig_deps[@]}"; do
  dep_dest="$(dep_dest_for "${dep}")"
  install_name_tool -id "@rpath/$(basename "${dep_dest}")" "${dep_dest}"
done

patch_refs() {
  local target="$1"
  local dep
  for dep in "${orig_deps[@]}"; do
    dep_dest="$(dep_dest_for "${dep}")"
    dep_name="@rpath/$(basename "${dep_dest}")"
    if otool -L "${target}" | tail -n +2 | awk '{print $1}' | grep -Fxq "${dep}"; then
      install_name_tool -change "${dep}" "${dep_name}" "${target}"
    fi
  done
}

patch_refs "${DEST_BINARY}"

for dep in "${orig_deps[@]}"; do
  patch_refs "$(dep_dest_for "${dep}")"
done

RPATH_VALUE="@executable_path/../../Frameworks"
if ! otool -l "${DEST_BINARY}" | awk '/LC_RPATH/{getline;getline;print $2}' | grep -Fxq "${RPATH_VALUE}"; then
  install_name_tool -add_rpath "${RPATH_VALUE}" "${DEST_BINARY}"
fi

assert_no_external_paths() {
  local target="$1"
  local deps
  deps="$(otool -L "${target}")"
  if echo "${deps}" | grep -E '/opt/homebrew|/usr/local/opt' >/dev/null; then
    echo "error: external package-manager linkage detected in ${target}"
    echo "${deps}"
    exit 1
  fi
}

assert_no_external_paths "${DEST_BINARY}"
for dep in "${dest_deps[@]}"; do
  assert_no_external_paths "${dep}"
done

binary_sha="$(shasum -a 256 "${DEST_BINARY}" | awk '{print $1}')"
manifest_path="${BUNDLE_DIR}/runtime-manifest.json"

{
  echo "{"
  echo "  \"runtimeVersion\": \"v${VERSION}\","
  echo "  \"platform\": \"macOS\","
  echo "  \"architecture\": \"${ARCH}\","
  echo "  \"createdAtUTC\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
  echo "  \"installPaths\": {"
  echo "    \"binary\": \"Contents/Resources/bin/msdf-atlas-gen\","
  echo "    \"libraries\": \"Contents/Frameworks\""
  echo "  },"
  echo "  \"binary\": {"
  echo "    \"path\": \"Resources/bin/msdf-atlas-gen\","
  echo "    \"sha256\": \"${binary_sha}\""
  echo "  },"
  echo "  \"libraries\": ["
  for ((idx=0; idx<${#dest_deps[@]}; idx++)); do
    dep_dest="${dest_deps[$idx]}"
    dep_name="$(basename "${dep_dest}")"
    dep_sha="$(shasum -a 256 "${dep_dest}" | awk '{print $1}')"
    if (( idx < ${#dest_deps[@]} - 1 )); then
      comma=","
    else
      comma=""
    fi
    echo "    {\"path\": \"Frameworks/${dep_name}\", \"sha256\": \"${dep_sha}\"}${comma}"
  done
  echo "  ]"
  echo "}"
} > "${manifest_path}"

rm -f "${ZIP_PATH}"
xattr -cr "${BUNDLE_DIR}" 2>/dev/null || true
(cd "${WORK_DIR}" && COPYFILE_DISABLE=1 /usr/bin/zip -qry "${ZIP_PATH}" "${BUNDLE_NAME}")

echo "Runtime bundle created:"
echo "  ${ZIP_PATH}"
echo "Bundle root inside zip:"
echo "  ${BUNDLE_NAME}/"
echo "Binary source:"
echo "  ${RUNTIME_BINARY}"
echo "Bundled dylibs:"
for dep in "${dest_deps[@]}"; do
  echo "  $(basename "${dep}")"
done
