#!/usr/bin/env bash

set -eo pipefail

if [[ -z "${PROJECT_DIR:-}" || -z "${TARGET_BUILD_DIR:-}" || -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" || -z "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
  echo "error: required Xcode build environment variables are missing"
  exit 1
fi

REPO_ROOT="$(cd "${PROJECT_DIR}/../../.." && pwd)"
SOURCE_BINARY_DEFAULT="${REPO_ROOT}/.vendor-build/msdf-atlas-gen/bin/msdf-atlas-gen"
SOURCE_BINARY="${TEXT_ENGINE_MSDF_BINARY:-$SOURCE_BINARY_DEFAULT}"

RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DEST_BINARY_DIR="${RESOURCES_DIR}/bin"
DEST_BINARY="${DEST_BINARY_DIR}/msdf-atlas-gen"

if [[ ! -f "${SOURCE_BINARY}" ]]; then
  echo "warning: msdf-atlas-gen source binary not found at '${SOURCE_BINARY}'."
  echo "warning: app export will fail unless runtime binary is provided."
  exit 0
fi

mkdir -p "${DEST_BINARY_DIR}" "${FRAMEWORKS_DIR}"

cp -f "${SOURCE_BINARY}" "${DEST_BINARY}"
chmod 755 "${DEST_BINARY}"

is_system_dep() {
  local dep="$1"
  [[ "${dep}" == /usr/lib/* || "${dep}" == /System/Library/* ]]
}

extract_deps() {
  local file_path="$1"
  otool -L "${file_path}" | tail -n +2 | awk '{print $1}'
}

orig_deps=()
dest_deps=()
queue=("${SOURCE_BINARY}")

has_dep() {
  local candidate="$1"
  local dep
  for dep in "${orig_deps[@]}"; do
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
  for ((idx=0; idx<${#orig_deps[@]}; idx++)); do
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

SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"

for dep in "${orig_deps[@]}"; do
  dep_dest="$(dep_dest_for "${dep}")"
  if [[ "${SIGNING_IDENTITY}" == "-" ]]; then
    codesign --force --sign - "${dep_dest}"
  else
    codesign --force --sign "${SIGNING_IDENTITY}" --timestamp "${dep_dest}"
  fi
done

if [[ "${SIGNING_IDENTITY}" == "-" ]]; then
  codesign --force --sign - "${DEST_BINARY}"
else
  # Executable needs hardened runtime for notarization.
  codesign --force --sign "${SIGNING_IDENTITY}" --timestamp --options runtime "${DEST_BINARY}"
fi

echo "Staged runtime binary: ${DEST_BINARY}"
for dep in "${orig_deps[@]}"; do
  echo "Staged runtime dependency: $(dep_dest_for "${dep}")"
done
