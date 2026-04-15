# TextEngineTool Potential TODO

This file tracks optional or later-phase work that is not required for the current TextEngineTool baseline.

## Engine known limitations

- v1 assumes local dependency bootstrap through `INSTALL_DEPENDENCIES.sh` rather than a fully self-contained packaged `msdf-atlas-gen` runtime.

## Open engine questions

- Do we need kerning support in the first pass, or is advance-only layout enough for current overlay use cases?
- Do we want one shared atlas across multiple filters, or one atlas per font/style family?
- Do we need runtime atlas generation later for user-selected fonts, or is bundled static content enough?

## Potential later engine features

- Bundle/sign the generator and its runtime dependencies inside the app.
- Replace the external executable path with a framework or static-library-based integration.
- Reduce machine-specific dependency assumptions.

## Potential later app features

- Support a system font picker in addition to file-based font selection.
- Model installed-font selection with both a resolved font asset path and an optional PostScript name where needed.
