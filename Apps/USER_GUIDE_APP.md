# TextEngineToolApp User Guide (Metal Shader Workflow)

This guide is for users who want to generate text atlas assets in `TextEngineToolApp` and render them in a custom Metal text pipeline.

## 1. Goal

Use the app to export:

- atlas image (`*.bmp`)
- runtime metadata (`*-atlas-runtime.json`)
- charset manifest (`*-charset.txt`)

Then load those files in your Metal runtime and render MSDF text quads.

## 2. App Flow

`TextEngineToolApp` has a 4-step flow.

### Step 1: Font

Choose a font using either path:

**Font file** — click a quick-access location button (`User Fonts`, `System Fonts`, `Library Fonts`) or `Browse…` to pick a `.ttf`, `.otf`, `.ttc`, or `.otc` file. The app auto-fills `Project name` from the filename (editable later).

**Installed font** — click `Installed Fonts…` to open the font picker sheet. Type part of a family name to filter (e.g. `Helvetica`), then click a PostScript name to select it. The app auto-fills `Project name` from the PostScript name (editable later).

### Step 2: Characters

- Choose character groups (`A-Z`, digits, punctuation, symbols, space).
- Add any extra characters in `Additional Characters`.
- The app deduplicates and shows final character count.

### Step 3: Export

- Confirm `Project name`.
- Optionally open **Advanced Options** and tune:
  - atlas width/height
  - em size
  - pixel range
  - padding
  - y-origin
- Click `Export` (default output) or `Choose Folder…` (custom base directory).

Export output folder contains:

- `{projectName}-atlas.bmp`
- `{projectName}-atlas-runtime.json`
- `{projectName}-charset.txt`
- `{projectName}-atlas.json` only when **Advanced > Export raw generator JSON** is enabled (debug/reference)

### Step 4: Example

- Preview the exported atlas in-app with text, size, opacity, and color controls.
- This step mirrors the reference pipeline used by the app:
  - `MSDFAtlasBundleLoader` loads exported files from disk.
  - `MSDFAtlasBundle` provides parsed metadata + glyph lookup.
  - `MSDFExampleTextRenderer` builds quads and renders in Metal.
- Use this to validate assets before integrating into your engine.

## 3. What Your Metal Runtime Should Read

From `*-atlas-runtime.json`:

- `atlas.imageFileName` for the atlas texture file
- `atlas.width`, `atlas.height`
- `atlas.distanceRange`
- `atlas.emSize`
- `atlas.yOrigin`
- `glyphs[]` entries:
  - `unicode`
  - `advancePx`
  - `planeBoundsPx`
  - `atlasBoundsUV`
- `kerning[]` entries (optional use in layout)

Recommended load order:

1. Read runtime JSON.
2. Load texture file referenced by `atlas.imageFileName`.
3. Build glyph lookup map by `unicode`.
4. Build text layout using `advancePx` (and optional kerning).
5. Build per-glyph quads from `planeBoundsPx` + `atlasBoundsUV`.
6. Render with MSDF decode in fragment shader.

## 4. Shader/Render Notes

- Use linear sampling (`MTLSamplerMinMagFilter.linear`).
- Keep atlas texture in non-sRGB space.
- Use `distanceRange` and screen-space scale to compute edge smoothing.
- Respect `yOrigin` (`top` vs `bottom`) when mapping glyph UV/layout.
- Missing glyph strategy: skip, substitute `'?'`, or pre-validate against `charset`.

Reference implementation files in the app:

- `Apps/TextEngineToolApp/TextEngineToolApp/Sources/Data/MSDFAtlasBundleLoader.swift`
- `Apps/TextEngineToolApp/TextEngineToolApp/Sources/Data/MSDFAtlasBundle.swift`
- `Apps/TextEngineToolApp/TextEngineToolApp/Sources/Data/MSDFExampleTextRenderer.swift`
- `Apps/TextEngineToolApp/TextEngineToolApp/Sources/Data/MSDFExampleTextRenderer.metal`

## 5. Practical Validation Checklist

- Does your runtime load the image file name from JSON (not hard-coded)?
- Do text quads align with expected baseline/ascender?
- Are glyph edges stable at small and large sizes?
- Do spaces and punctuation advance correctly?
- Are unsupported characters handled cleanly?

## 6. v1 Scope Notes

- Both font file and installed font selection are supported in the app workflow.
- BMP output is expected and supported (including app preview).
- Dependency/bootstrap and packaging follow-ups are tracked in `../docs/POTENTIAL_TODO.md`.
