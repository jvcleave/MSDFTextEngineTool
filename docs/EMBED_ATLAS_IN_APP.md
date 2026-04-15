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

### 2) Add Native Xcode Embed Phases (No Run Script Required)

In Xcode:

1. Select your app target.
2. Add `textengine-msdf-runtime-macos-arm64-v1/Resources/bin/msdf-atlas-gen` to your Xcode project (File Inspector -> target membership ON).
3. Open `Build Phases` and add a `Copy Files` phase:
4. Set `Destination` to `Resources`.
5. Set `Subpath` to `bin`.
6. Add `msdf-atlas-gen` to that phase.
7. Add `libpng16.16.dylib` and `libfreetype.6.dylib` to your app target:
8. In `General` -> `Frameworks, Libraries, and Embedded Content`, set each dylib to `Embed & Sign`.
9. Build and run.

Why this works without patching in Xcode:

- app bundle output paths (`TARGET_BUILD_DIR`, `Contents/Resources`, `Contents/Frameworks`) change per build/config/archive and must be populated each build
- runtime files are external artifacts (from the zip), not compiled by Xcode, so explicit embed phases are still required
- linkage normalization (`@rpath`) should already be done in the provided zip by `package-runtime-bundle.sh`
- this keeps consumer apps on “copy/embed only” and avoids repeated `install_name_tool` edits during each app build

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
- install names/references should already be rewritten to `@rpath/...` in the runtime zip
- `msdf-atlas-gen` should already include rpath `@executable_path/../../Frameworks`
- for local Xcode development, signing these nested files is optional

Producer-side (one-time) runtime preparation:

- `Apps/TextEngineToolApp/Scripts/package-runtime-bundle.sh`

Dev-only fallback (when consuming raw local `.vendor-build` output instead of prepared zip):

- `Apps/TextEngineToolApp/TextEngineToolApp/Scripts/stage-msdf-runtime.sh`

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

- Xcode usually signs embedded dylibs in `Contents/Frameworks`
- `msdf-atlas-gen` in `Contents/Resources/bin` may still require explicit signing in some project setups
- if needed, sign `msdf-atlas-gen` with hardened runtime before final app signing
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
