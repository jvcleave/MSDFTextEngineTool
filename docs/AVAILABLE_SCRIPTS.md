# AVAILABLE_SCRIPTS

This document lists first-party shell scripts in this repo and what each one does.

Scope:

- Includes scripts tracked in this repo.
- Excludes vendored third-party scripts (none are currently present under `Vendor/` as `.sh` files).

## Quick Map

| Script | Purpose |
|---|---|
| `CHECK_DEPENDENCIES.sh` | Verifies local toolchain/dependencies for atlas generation workflows. |
| `INSTALL_DEPENDENCIES.sh` | Installs Homebrew dependencies and builds vendored runtime binary. |
| `Apps/TextEngineToolApp/Scripts/build-runtime-binary.sh` | Builds `msdf-atlas-gen` for a target arch into release runtime output. |
| `Apps/TextEngineToolApp/Scripts/package-runtime-bundle.sh` | Packages precompiled runtime zip (`msdf-atlas-gen` + dylibs + manifest). |
| `Apps/TextEngineToolApp/Scripts/archive-app.sh` | Archives signed `TextEngineToolApp.app` via `xcodebuild archive`. |
| `Apps/TextEngineToolApp/Scripts/make-dmg.sh` | Creates and signs a DMG from an archived app. |
| `Apps/TextEngineToolApp/Scripts/notarize-dmg.sh` | Submits DMG for notarization, then staples and validates ticket. |
| `Apps/TextEngineToolApp/Scripts/verify-runtime-bundle.sh` | Verifies bundled runtime binary/dependencies inside an app bundle. |
| `Apps/TextEngineToolApp/Scripts/release-dmg.sh` | End-to-end wrapper: archive, DMG, optional notarization. |
| `Apps/TextEngineToolApp/TextEngineToolApp/Scripts/stage-msdf-runtime.sh` | Xcode build-phase script to stage and patch runtime binary/libs into app bundle. |

## Script Details

### `CHECK_DEPENDENCIES.sh`

Purpose:

- Checks for `swift`, `cmake`, and (if Homebrew exists) formula installs for `cmake`, `freetype`, `libpng`.

Usage:

```bash
./CHECK_DEPENDENCIES.sh
```

Exit behavior:

- `0` when all required dependencies are present.
- `1` when required items are missing.

---

### `INSTALL_DEPENDENCIES.sh`

Purpose:

- Installs Homebrew formulas (`cmake`, `freetype`, `libpng`) and runs `swift run TextEngineTool build-vendor`.

Usage:

```bash
./INSTALL_DEPENDENCIES.sh
```

Requirements:

- Homebrew (`brew`) must be installed.

---

### `Apps/TextEngineToolApp/Scripts/build-runtime-binary.sh`

Purpose:

- Builds `msdf-atlas-gen-standalone` from vendored source with CMake and writes binary to release runtime folder.

Defaults:

- `ARCH=arm64`
- output: `Generated/Releases/runtime/<arch>/bin/msdf-atlas-gen`

Key env vars:

- `ARCH`: `arm64`, `x86_64`, or `universal`
- `OUTPUT_ROOT`: runtime output root (default `Generated/Releases/runtime`)

Usage:

```bash
ARCH=arm64 Apps/TextEngineToolApp/Scripts/build-runtime-binary.sh
```

---

### `Apps/TextEngineToolApp/Scripts/package-runtime-bundle.sh`

Purpose:

- Creates a reusable runtime zip bundle for other apps:
  - `Resources/bin/msdf-atlas-gen`
  - `Frameworks/*.dylib`
  - `runtime-manifest.json`
- Rewrites non-system linkage to `@rpath`.

Defaults:

- `ARCH=arm64`
- `VERSION=1`
- output: `Generated/Releases/runtime-bundles/textengine-msdf-runtime-macos-<arch>-v<version>.zip`

Key env vars:

- `ARCH`
- `VERSION`
- `OUTPUT_ROOT`
- `RUNTIME_BINARY` (override source binary path)
- `BUNDLE_NAME` (override zip root/file naming)

Usage:

```bash
ARCH=arm64 VERSION=1 Apps/TextEngineToolApp/Scripts/package-runtime-bundle.sh
```

---

### `Apps/TextEngineToolApp/Scripts/archive-app.sh`

Purpose:

- Runs `xcodebuild archive` for `TextEngineToolApp`.
- Injects runtime binary path through `TEXT_ENGINE_MSDF_BINARY`.
- Verifies bundled runtime after archive.

Required env vars:

- `SIGN_IDENTITY`
- `DEVELOPMENT_TEAM`

Common optional env vars:

- `TARGET_ARCH` (default `arm64`)
- `OUTPUT_ROOT`, `ARCHIVE_PATH`
- `RUNTIME_BINARY`
- `SCHEME`, `CONFIGURATION`, `DESTINATION`
- `EXPORT_OPTIONS_PLIST` (optional export step)

Usage:

```bash
SIGN_IDENTITY='Developer ID Application: Example (TEAMID1234)' \
DEVELOPMENT_TEAM='TEAMID1234' \
Apps/TextEngineToolApp/Scripts/archive-app.sh
```

---

### `Apps/TextEngineToolApp/Scripts/make-dmg.sh`

Purpose:

- Builds DMG from archived `.app`, adds `Applications` symlink, signs DMG.

Required env vars:

- `SIGN_IDENTITY`

Common optional env vars:

- `APP_PATH` (default archive product path)
- `OUTPUT_DIR` (default `Generated/Releases`)
- `DMG_NAME`
- `VOLUME_NAME`

Usage:

```bash
SIGN_IDENTITY='Developer ID Application: Example (TEAMID1234)' \
Apps/TextEngineToolApp/Scripts/make-dmg.sh
```

---

### `Apps/TextEngineToolApp/Scripts/notarize-dmg.sh`

Purpose:

- Submits DMG to Apple notarization service, waits, staples, validates.

Required env vars:

- `NOTARY_PROFILE` (notarytool keychain profile)

Common optional env vars:

- `DMG_PATH` (default `Generated/Releases/TextEngineToolApp.dmg`)

Usage:

```bash
NOTARY_PROFILE='MyNotaryProfile' \
Apps/TextEngineToolApp/Scripts/notarize-dmg.sh
```

---

### `Apps/TextEngineToolApp/Scripts/verify-runtime-bundle.sh`

Purpose:

- Verifies `msdf-atlas-gen` and required dylibs exist in app bundle.
- Fails if Homebrew absolute linkage is still present.

Arguments:

- `<TextEngineToolApp.app path>`

Usage:

```bash
Apps/TextEngineToolApp/Scripts/verify-runtime-bundle.sh \
Generated/Releases/TextEngineToolApp.xcarchive/Products/Applications/TextEngineToolApp.app
```

---

### `Apps/TextEngineToolApp/Scripts/release-dmg.sh`

Purpose:

- Orchestrates full release flow:
  - optional runtime build
  - archive
  - DMG creation
  - optional notarization

Required env vars:

- `SIGN_IDENTITY`
- `DEVELOPMENT_TEAM`

Default behavior:

- notarization is ON (requires `--notary-profile <name>` unless `--skip-notarize`)

Options:

- `--build-runtime`
- `--skip-notarize`
- `--notary-profile <name>`
- `--arch <arm64|x86_64|universal>`

Common optional env vars:

- `OUTPUT_DIR`
- `DMG_NAME`

Usage:

```bash
SIGN_IDENTITY='Developer ID Application: Example (TEAMID1234)' \
DEVELOPMENT_TEAM='TEAMID1234' \
Apps/TextEngineToolApp/Scripts/release-dmg.sh \
  --notary-profile MyNotaryProfile
```

---

### `Apps/TextEngineToolApp/TextEngineToolApp/Scripts/stage-msdf-runtime.sh`

Purpose:

- Intended for Xcode Build Phase inside `TextEngineToolApp`.
- Copies runtime binary into app resources and dylibs into frameworks.
- Patches linkage (`install_name_tool`/`@rpath`) and optionally signs nested binaries.

Inputs:

- Xcode-provided env vars (`PROJECT_DIR`, `TARGET_BUILD_DIR`, `UNLOCALIZED_RESOURCES_FOLDER_PATH`, `FRAMEWORKS_FOLDER_PATH`, `EXPANDED_CODE_SIGN_IDENTITY`)
- optional `TEXT_ENGINE_MSDF_BINARY` to override runtime binary source path

Typical invocation:

- Invoked by Xcode automatically as a Run Script Build Phase.

