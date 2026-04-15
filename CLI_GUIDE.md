# TextEngineTool CLI Guide

This guide covers the `TextEngineTool` command-line workflow for generating MSDF atlas assets.

## Prerequisites

```bash
./CHECK_DEPENDENCIES.sh
./INSTALL_DEPENDENCIES.sh
```

`INSTALL_DEPENDENCIES.sh` is Homebrew-based for convenience on macOS. If your machine already has compatible `cmake`, `freetype`, and `libpng` development dependencies, the CLI can still work without Homebrew.

## Command Reference

Show help:

```bash
swift run TextEngineTool
```

Show planned generation details from a config:

```bash
swift run TextEngineTool plan --config ./atlas-config.json
```

Build vendored atlas generator:

```bash
swift run TextEngineTool build-vendor
```

Generate sample config:

```bash
swift run TextEngineTool init-config --output ./atlas-config.json
```

Print resolved charset from a charset file:

```bash
swift run TextEngineTool print-charset --charset ./Templates/charsets/debug-text.txt
```

Generate atlas assets:

```bash
swift run TextEngineTool generate-atlas --config ./atlas-config.json
```

## Typical Workflow

1. Create a config:

```bash
swift run TextEngineTool init-config --output ./atlas-config.json
```

2. Edit config values:
- `fontPath` or installed font fields
- `charsetPath` (or inline charset setup, depending on config shape in use)
- `outputDirectory`
- atlas parameters (`atlasImageName`, `emSize`, `pixelRange`, `padding`, etc.)

3. Build vendored generator (if not already built):

```bash
swift run TextEngineTool build-vendor
```

4. Generate output:

```bash
swift run TextEngineTool generate-atlas --config ./atlas-config.json
```

## Output Files

Generation writes:
- atlas image (currently BMP-focused in this workflow)
- raw `msdf-atlas-gen` metadata JSON
- normalized runtime metadata JSON (`*-atlas-runtime.json`)
- charset manifest (`*-charset.txt`)

See data contract details in:
- [EXPORTED_DATA_TYPES.md](EXPORTED_DATA_TYPES.md)

## Notes

- The CLI is intended for deterministic, versionable asset generation.
- Vendored `msdf-atlas-gen` build assumptions are documented in:
  - [VENDOR.md](VENDOR.md)
