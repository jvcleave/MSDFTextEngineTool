# Embed Atlas Generation In Another App

This guide is for a different macOS app that wants to generate atlases using `TextEngineToolCore` without requiring end users to install Homebrew, `cmake`, or dev libraries.

## Goal

Make atlas generation self-contained in your app bundle:

- `msdf-atlas-gen` executable is bundled with your app
- native dylib dependencies are bundled with your app
- `TextEngineToolCore` is configured to use that bundled binary
- no runtime auto-build fallback in user environments

## Xcode Fast Path: "I Have The Zip, How Do I Use It?"

Assume you were given:

- `textengine-msdf-runtime-macos-arm64-v1.zip`

### 1) Put Runtime Files In Your App Repo

Extract it into your project, for example:

- `ThirdParty/TextEngineRuntime/textengine-msdf-runtime-macos-arm64-v1/`

Expected contents:

- `Resources/bin/msdf-atlas-gen`
- `Frameworks/libpng16.16.dylib`
- `Frameworks/libfreetype.6.dylib`
- `runtime-manifest.json`

### 2) Add A Run Script Build Phase In Xcode

In Xcode:

1. Select your app target.
2. Open `Build Phases`.
3. Add `+` -> `New Run Script Phase`.
4. Name it `Stage TextEngine Runtime`.
5. Place it near the end of build phases (before app launch is fine for local dev).
6. Paste this script:

```bash
set -euo pipefail

RUNTIME_ROOT="${SRCROOT}/ThirdParty/TextEngineRuntime/textengine-msdf-runtime-macos-arm64-v1"
DEST_BIN_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin"
DEST_FW_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

mkdir -p "${DEST_BIN_DIR}" "${DEST_FW_DIR}"

cp -f "${RUNTIME_ROOT}/Resources/bin/msdf-atlas-gen" "${DEST_BIN_DIR}/msdf-atlas-gen"
cp -f "${RUNTIME_ROOT}/Frameworks/"*.dylib "${DEST_FW_DIR}/"
chmod 755 "${DEST_BIN_DIR}/msdf-atlas-gen"

# Make sure runtime binary resolves bundled libraries.
install_name_tool -change /opt/homebrew/opt/libpng/lib/libpng16.16.dylib @rpath/libpng16.16.dylib "${DEST_BIN_DIR}/msdf-atlas-gen" 2>/dev/null || true
install_name_tool -change /opt/homebrew/opt/freetype/lib/libfreetype.6.dylib @rpath/libfreetype.6.dylib "${DEST_BIN_DIR}/msdf-atlas-gen" 2>/dev/null || true

# Rpath for bundled dylibs.
if ! otool -l "${DEST_BIN_DIR}/msdf-atlas-gen" | awk '/LC_RPATH/{getline;getline;print $2}' | grep -Fxq "@executable_path/../../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../../Frameworks" "${DEST_BIN_DIR}/msdf-atlas-gen"
fi
```

Why this phase is needed:

- app bundle output paths (`TARGET_BUILD_DIR`, `Contents/Resources`, `Contents/Frameworks`) change per build/config/archive and must be populated each build
- runtime files are external artifacts (from the zip), not compiled by Xcode, so Xcode will not place them automatically
- `msdf-atlas-gen` may need runtime linkage normalization (`@rpath`) to ensure it finds bundled dylibs instead of machine-local paths
- without this step, builds may succeed but atlas generation can fail at runtime with missing binary or dylib errors

### 3) Configure `TextEngineToolCore` To Use Bundled Runtime Only

- Pass `generatorBinaryURL` pointing to `Resources/bin/msdf-atlas-gen`.
- Set `allowGeneratorBuild: false`.
- This prevents user machines from attempting `cmake` build fallback.

## Detailed Reference

### Add `TextEngineToolCore` To Your App

Add this package and import:

```swift
import TextEngineToolCore
```

### A) Bundle The Generator Runtime

Your app should ship these runtime assets:

- executable: `MyApp.app/Contents/Resources/bin/msdf-atlas-gen`
- non-system dylibs: `MyApp.app/Contents/Frameworks/*.dylib`

Important:

- all non-system deps must be copied into `Contents/Frameworks`
- install names/references must be rewritten to `@rpath/...`
- `msdf-atlas-gen` must include rpath `@executable_path/../../Frameworks`
- for local Xcode development, signing these nested files is optional

Reference implementation:

- runtime staging script used by `TextEngineToolApp`:
  - `Apps/TextEngineToolApp/TextEngineToolApp/Scripts/stage-msdf-runtime.sh`

If you use that script as a template in your own app target:

- keep `TEXT_ENGINE_MSDF_BINARY` pointed at your built `msdf-atlas-gen`
- keep script before final app codesign step in build/archive flow

### B) Configure `TextAtlasEngine` For Bundled Runtime Only

Use `generatorBinaryURL` and disable auto-build:

```swift
import Foundation
import TextEngineToolCore

func generateAtlasExample(
    fontURL: URL,
    charset: String
) throws -> GeneratedAtlasBundle {
    let fm = FileManager.default
    let appSupport = try fm.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("MyApp/Atlas", isDirectory: true)

    try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)

    let charsetURL = appSupport.appendingPathComponent("charset.txt")
    try charset.write(to: charsetURL, atomically: true, encoding: .utf8)

    let outputDir = appSupport.appendingPathComponent("Generated", isDirectory: true)

    let binaryURL = Bundle.main.resourceURL?
        .appendingPathComponent("bin/msdf-atlas-gen")

    let engine = TextAtlasEngine(
        rootDirectoryURL: appSupport,
        generatorBinaryURL: binaryURL,
        allowGeneratorBuild: false
    )

    let config = engine.makeAtlasConfig(
        fontInput: .fontFile(fontURL),
        charsetPath: charsetURL.path,
        outputDirectory: outputDir.path,
        atlasImageName: "atlas.png",
        charsetManifestName: "charset.txt",
        metadataFileName: "atlas.json",
        runtimeMetadataFileName: "atlas-runtime.json",
        imageFormat: "png",
        imageType: "msdf",
        atlasWidth: 1024,
        atlasHeight: 1024,
        emSize: 64,
        pixelRange: 4,
        padding: 8,
        yOrigin: "top"
    )

    return try engine.generateAtlas(
        config: config,
        relativeTo: appSupport
    )
}
```

Notes:

- You can also use installed fonts via:
  - `.installedFont(postScriptName: "HelveticaNeue-Bold")`
- If `generatorBinaryURL` is `nil`, core also checks bundled candidates under `Bundle.main.resourceURL`, but passing it explicitly is clearer.

### C) What Files You Get

`generateAtlas` writes:

- atlas image (for example `atlas.png`)
- raw metadata (`atlas.json`)
- runtime metadata (`atlas-runtime.json`)
- charset manifest (`charset.txt`)

### D) Validate You Are Truly Dependency-Free

Check bundled executable linkage:

```bash
otool -L MyApp.app/Contents/Resources/bin/msdf-atlas-gen
```

Expected:

- system libs from `/usr/lib` or `/System/Library`
- bundled libs referenced as `@rpath/<name>.dylib`
- no `/opt/homebrew/...` or other machine-local absolute paths

### E) Common Failures

- `msdf-atlas-gen binary was not found`
  - binary was not copied to `Contents/Resources/bin`, or wrong `generatorBinaryURL`
- `dyld: Library not loaded ...`
  - dylibs were not copied, not patched to `@rpath`, or missing rpath on executable
- app tries to build with `cmake` on user machine
  - `allowGeneratorBuild` was left `true`

### F) Production Signing And Notarization (Optional)

Use this only when you are producing distributed builds (outside local dev):

- sign bundled dylibs first
- sign `msdf-atlas-gen` with hardened runtime
- sign app last
- notarize/staple your app or DMG

Reference scripts:

- `Apps/TextEngineToolApp/TextEngineToolApp/Scripts/stage-msdf-runtime.sh`
- `Apps/TextEngineToolApp/Scripts/release-dmg.sh`

## DIY: Build The Runtime Zip Yourself

If you need to produce `textengine-msdf-runtime-macos-arm64-v1.zip` yourself:

```bash
cd TextEngineTool
ARCH=arm64 VERSION=1 Apps/TextEngineToolApp/Scripts/package-runtime-bundle.sh
```

Output:

- `Generated/Releases/runtime-bundles/textengine-msdf-runtime-macos-arm64-v1.zip`
