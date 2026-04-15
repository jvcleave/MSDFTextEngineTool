# TextEngineTool

`TextEngineTool` is a repo for generating and validating MSDF text atlases for Metal pipelines.

It contains:
- a Swift package (`TextEngineTool` CLI + `TextEngineToolCore`)
- a macOS app (`TextEngineToolApp`) for user-facing export/preview flow
- vendored `msdf-atlas-gen` integration

## Table Of Contents

- [Repo Overview](#repo-overview)
- [Documentation](#documentation)
- [Required Dependencies](#required-dependencies)
- [Quick Start (App)](#quick-start-app)
- [TextEngineExampleApp](#textengineexampleapp)
- [CLI Usage](#cli-usage)

## Repo Overview

- `Sources/TextEngineTool`: CLI entry point
- `Sources/TextEngineToolCore`: shared atlas generation, config, parsing, runtime metadata
- `Apps/TextEngineToolApp`: macOS app project
- `Templates/charsets`: reusable charset templates
- `Vendor/msdf-atlas-gen`: pinned vendored upstream source
- `Generated`: local export outputs (repo/dev workflow)

## Documentation

- CLI workflow: [docs/CLI_GUIDE.md](docs/CLI_GUIDE.md)
- App workflow: [Apps/USER_GUIDE_APP.md](Apps/USER_GUIDE_APP.md)
- Exported file contract: [docs/EXPORTED_DATA_TYPES.md](docs/EXPORTED_DATA_TYPES.md)
- Embed atlas generation in another app: [docs/EMBED_ATLAS_IN_APP.md](docs/EMBED_ATLAS_IN_APP.md)
- Script inventory: [docs/AVAILABLE_SCRIPTS.md](docs/AVAILABLE_SCRIPTS.md)
- Vendor pin/license notes: [docs/VENDOR.md](docs/VENDOR.md)
- Potential future work: [docs/POTENTIAL_TODO.md](docs/POTENTIAL_TODO.md)

## Required Dependencies

- Swift toolchain (`swift`) from Xcode or Xcode Command Line Tools
- `cmake`
- `freetype` development libraries
- `libpng` development libraries

`INSTALL_DEPENDENCIES.sh` currently uses Homebrew to install dependencies on macOS. Homebrew is a convenience path, not a hard runtime requirement, if equivalent dependencies are already installed and discoverable by `cmake`.

Check dependencies without installing:

```bash
./CHECK_DEPENDENCIES.sh
```

Install and bootstrap supported dependencies:

```bash
./INSTALL_DEPENDENCIES.sh
```

The macOS app projects are optional and are not required to generate atlases with the CLI.

## Quick Start (App)

Open:

`Apps/TextEngineToolApp/TextEngineToolApp/TextEngineToolApp.xcodeproj`

Then use the 4-step app flow (Font, Characters, Export, Example) documented in `Apps/USER_GUIDE_APP.md`.

## TextEngineExampleApp

`TextEngineExampleApp` is a minimal consumer example focused on runtime loading and preview:

- one `LOAD EXPORT` button to pick an exported atlas folder
- runtime loading via `MSDFAtlasBundleLoader`
- preview via `MSDFTextPreviewView`
- simple controls for font size, opacity, foreground color, and background color

Open:

`Apps/TextEngineExampleApp/TextEngineExampleApp.xcodeproj`

## CLI Usage

For CLI commands and workflows, see [docs/CLI_GUIDE.md](docs/CLI_GUIDE.md).



<img width="1149" height="1171" alt="image" src="https://github.com/user-attachments/assets/0bee4463-1b59-4381-8235-ab8eea1398db" />



<img width="1154" height="1167" alt="image" src="https://github.com/user-attachments/assets/72526297-0210-4a59-87ed-9c4e6aa4c21f" />



<img width="1148" height="1172" alt="image" src="https://github.com/user-attachments/assets/e297554f-d178-4287-a239-a6aed163c815" />

<img width="1143" height="1171" alt="image" src="https://github.com/user-attachments/assets/a7233770-0b22-4f7e-abfe-37978a0606f4" />








