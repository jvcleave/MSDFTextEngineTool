#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required but was not found."
  echo "Install Homebrew first: https://brew.sh/"
  exit 1
fi

FORMULAS=(
  cmake
  freetype
  libpng
)

echo "Installing required Homebrew packages..."
for formula in "${FORMULAS[@]}"; do
  if brew list "$formula" >/dev/null 2>&1; then
    echo "  - $formula already installed"
  else
    echo "  - installing $formula"
    brew install "$formula"
  fi
done

echo
echo "Resolved dependency prefixes:"
for formula in "${FORMULAS[@]}"; do
  echo "  - $formula: $(brew --prefix "$formula")"
done

echo
echo "Building vendored msdf-atlas-gen..."
cd "$REPO_ROOT"
swift run TextEngineTool build-vendor

echo
echo "Bootstrap complete."
echo "You can now run atlas generation commands locally."
