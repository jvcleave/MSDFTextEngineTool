#!/usr/bin/env bash

set -euo pipefail

MISSING=0

function check_command() {
  local command_name="$1"
  local install_hint="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    echo "OK: $command_name"
  else
    echo "MISSING: $command_name"
    echo "  -> $install_hint"
    MISSING=1
  fi
}

echo "Checking TextEngineTool dependencies..."
echo

check_command swift "Install Xcode command line tools (xcode-select --install) or full Xcode."
check_command cmake "Install cmake (Homebrew, MacPorts, or manual install)."

if command -v brew >/dev/null 2>&1; then
  echo "OK: brew (optional bootstrap tool)"
  for formula_name in cmake freetype libpng; do
    if brew list "$formula_name" >/dev/null 2>&1; then
      echo "OK: brew formula '$formula_name' is installed"
    else
      echo "MISSING: brew formula '$formula_name'"
      echo "  -> brew install $formula_name"
      MISSING=1
    fi
  done
else
  echo "NOTE: brew not found. This is fine if dependencies are installed by other means."
  echo "      Ensure freetype and libpng development packages are available to cmake."
fi

echo
if [ "$MISSING" -eq 0 ]; then
  echo "All required dependencies are installed."
  exit 0
fi

echo "Some required dependencies are missing."
echo "Run ./INSTALL_DEPENDENCIES.sh to install supported Homebrew dependencies."
exit 1
