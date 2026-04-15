# TextEngineToolApp DMG Release Plan

Last updated: 2026-04-15
Owner: TextEngineToolApp team
Primary goal: Ship a distributable `TextEngineToolApp.dmg` that runs on supported macOS systems without requiring the source repo layout, Homebrew, or manual dependency installs.

## Status Legend

- `[ ]` Not started
- `[-]` In progress
- `[x]` Complete
- `[!]` Blocked

## Success Criteria

1. Export flow works in a clean macOS user account with only the installed app.
2. App does not rely on `Vendor/`, `.vendor-build/`, or repo-relative paths at runtime.
3. App package includes required native generator runtime components.
4. App is signed, notarized, and staple-validated.
5. A DMG is produced and smoke-tested on a second machine.

## Current Baseline (2026-04-15)

- `TextEngineToolApp` uses `TextEngineToolCore` and export flow runs through `TextAtlasEngine`.
- `VendoredMSDFAtlasGen` still contains `cmake` build fallback logic and expects vendored source/build paths.
- Current built `msdf-atlas-gen` links to Homebrew `freetype` and `libpng` on development machine.
- UI warns users to prebuild vendor binary (`swift run TextEngineTool build-vendor`) before export.

## Work Plan

### Phase 0: Planning + Scope Lock

- [x] Create tracked plan doc for DMG release execution.
- [x] Confirm minimum supported macOS version for release build. (`macOS 15.0`)
- [x] Confirm architecture strategy (`arm64` only vs universal). (`arm64` only selected)
- [x] Decide distribution mode (Developer ID direct download vs other channels). (Developer ID direct download selected)

### Phase 1: Self-Contained Runtime in App Bundle

- [x] Define app bundle runtime layout (`Contents/Resources/bin` and `Contents/Frameworks`).
- [x] Produce release `msdf-atlas-gen` binary for target architecture(s).
- [x] Bundle required native dependencies (or static-link if feasible).
- [x] Set install names/rpaths so bundled executable resolves bundled libs only.
- [x] Add Xcode copy phases / build scripts to place binaries/libs in app bundle.
- [x] Update `TextEngineToolCore` runtime resolver to load bundled executable first.
- [x] Remove/disable runtime dependency on repo root path detection in app flow.
- [x] Replace user-facing `build-vendor` prerequisite messaging with bundled-runtime checks.

### Phase 2: Build + Archive Automation

- [x] Add reproducible archive command/script for `TextEngineToolApp` (`xcodebuild archive`).
- [ ] Add export command/script for signed app artifact (`xcodebuild -exportArchive` as needed).
- [ ] Add versioning inputs (marketing version + build number) for release runs.
- [x] Add CI/local release checklist for deterministic outputs.

### Phase 3: Signing, Notarization, and Validation

- [x] Verify entitlements and hardened runtime configuration for distribution.
- [x] Sign app and nested binaries/libraries with Developer ID.
- [x] Submit app for notarization and wait for success.
- [x] Staple notarization ticket.
- [x] Run `spctl` and `codesign --verify --deep --strict` validation checks.

### Phase 4: DMG Packaging

- [x] Create DMG packaging script (input: signed app, output: versioned DMG).
- [x] Include expected install UX (Applications symlink, optional background/layout).
- [x] Sign DMG (if required by release policy).
- [x] Notarize DMG and staple.
- [x] Verify DMG open/install/launch flow (local smoke test).

### Phase 5: Release Readiness

- [ ] Write end-user install and first-run guide for DMG workflow.
- [ ] Document troubleshooting for Gatekeeper/signature/notarization issues.
- [ ] Publish release notes template and rollback procedure.
- [ ] Tag and publish release artifact.

## Progress Log

| Date | Status | Update |
|---|---|---|
| 2026-04-15 | `[x]` | Initial DMG release plan created. |
| 2026-04-15 | `[-]` | Baseline dependency and runtime coupling analysis completed; implementation not yet started. |
| 2026-04-15 | `[x]` | Implemented bundled-generator-first resolution in `TextEngineToolCore` with dev fallback build path. |
| 2026-04-15 | `[x]` | Refactored app export flow to run without repo-root requirement and updated warning/disable logic. |
| 2026-04-15 | `[x]` | Verified package + app compile (`swift build`, `xcodebuild` Debug build). |
| 2026-04-15 | `[x]` | Added `Stage MSDF Runtime` Xcode build phase and staging script to copy generator/runtime dylibs into app bundle. |
| 2026-04-15 | `[x]` | Verified bundled runtime linkage: `msdf-atlas-gen` now resolves `libpng`/`libfreetype` via `@rpath` from app bundle. |
| 2026-04-15 | `[x]` | Verified `Debug` and `Release` app builds both stage runtime assets successfully. |
| 2026-04-15 | `[x]` | Added release scripts: archive (`archive-app.sh`), runtime verifier (`verify-runtime-bundle.sh`), and DMG packager (`make-dmg.sh`). |
| 2026-04-15 | `[x]` | Produced local archive and DMG at `Generated/Releases/TextEngineToolApp.xcarchive` and `Generated/Releases/TextEngineToolApp.dmg`. |
| 2026-04-15 | `[x]` | Added repeatable runtime builder script (`build-runtime-binary.sh`) and built arm64 release generator artifact. |
| 2026-04-15 | `[x]` | Updated archive flow to consume release runtime artifact via `TEXT_ENGINE_MSDF_BINARY` and verified archive output. |
| 2026-04-15 | `[x]` | Mounted DMG and confirmed expected contents (`TextEngineToolApp.app` + `Applications` symlink). |
| 2026-04-15 | `[-]` | Added notarization helper script (`notarize-dmg.sh`); execution pending notary credentials/profile. |
| 2026-04-15 | `[x]` | Locked release automation to arm64 (`TARGET_ARCH=arm64`, arm64 destination, arm64 ARCHS override). |
| 2026-04-15 | `[x]` | Updated archive + DMG scripts to use environment-provided Developer ID signing values and validated signed outputs. |
| 2026-04-15 | `[x]` | Notarization completed via keychain profile; submission accepted, DMG stapled and validated. |
| 2026-04-15 | `[x]` | Final verification passed: `codesign --verify --deep --strict` on app and `spctl -a --type open --context context:primary-signature` accepted DMG as Notarized Developer ID. |
| 2026-04-15 | `[x]` | Lowered app deployment target from `26.2` to `15.0`, rebuilt archive/DMG, and re-notarized successfully. |

## Local Release Checklist

1. Ensure `.vendor-build/msdf-atlas-gen/bin/msdf-atlas-gen` exists and runs.
2. Run `Apps/TextEngineToolApp/Scripts/archive-app.sh`.
3. Confirm runtime verification passes in script output.
4. Run `APP_PATH="<archive app path>" Apps/TextEngineToolApp/Scripts/make-dmg.sh`.
5. Mount/open DMG and confirm app + `Applications` symlink are present.

## Risks and Mitigations

- Risk: Bundled native executable still references absolute Homebrew library paths.
  Mitigation: enforce `otool -L`/`install_name_tool` checks in release script before signing.
- Risk: App works in dev environment but fails outside repo due to path assumptions.
  Mitigation: run smoke tests from exported `.app` copied to a clean location and clean user account.
- Risk: Notarization failures due to nested binary signing order.
  Mitigation: explicit signing order in scripts (nested libs/binaries first, app last), then verify before upload.

## Definition of Done

- [ ] `TextEngineToolApp` export workflow passes smoke test on a clean machine.
- [x] Versioned notarized DMG exists and is installable.
- [ ] Release documentation and repeatable release script are committed.
