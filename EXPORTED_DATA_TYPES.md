# Exported Data Types

This document describes the files exported by `TextEngineToolApp` / `TextEngineTool`, their data structures, and how each structure is intended to be used in a Metal text renderer.

## Exported Files

Per export folder (`{projectName}`), the tool writes:

- `{projectName}-atlas.bmp`
- `{projectName}-atlas-runtime.json`
- `{projectName}-charset.txt`
- `{projectName}-atlas.json` (raw generator metadata)

`*-atlas-runtime.json` is the primary runtime contract.

## Runtime Metadata Root (`*-atlas-runtime.json`)

Top-level object:

- `version: Int`
- `atlas: Atlas`
- `metrics: Metrics`
- `glyphs: [Glyph]`
- `kerning: [KerningPair]`

## `Atlas`

Fields:

- `type: String`  
  MSDF atlas type (typically `msdf`).
- `imageFileName: String`  
  Atlas image filename to load for sampling.
- `charsetFileName: String`  
  Charset manifest filename generated with the atlas.
- `yOrigin: String`  
  Vertical origin convention (`top` or `bottom`).
- `width: Int`
- `height: Int`
- `distanceRange: Double`  
  SDF distance normalization range used in edge reconstruction.
- `emSize: Double`  
  Base em size used during generation.
- `pixelRange: Double`  
  Configured pixel range passed to atlas generation.
- `padding: Int`  
  Padding around glyphs in atlas packing.

Runtime use:

- Load texture from `imageFileName`.
- Build shader uniforms from `distanceRange`, `emSize`, `width`, `height`.
- Honor `yOrigin` when interpreting glyph bounds / UV mapping.

## `Metrics`

Fields (in em units):

- `lineHeightEm`
- `ascenderEm`
- `descenderEm`
- `underlineYEm`
- `underlineThicknessEm`

Fields (in pixel units at `emSize`):

- `lineHeightPx`
- `ascenderPx`
- `descenderPx`
- `underlineYPx`
- `underlineThicknessPx`

Runtime use:

- Line layout and baseline placement.
- Underline placement/thickness when needed.

## `Glyph`

Fields:

- `unicode: Int`  
  Unicode scalar value.
- `character: String`  
  Single-character string form.
- `advanceEm: Double`
- `advancePx: Double`
- `planeBoundsEm: Rect?`
- `planeBoundsPx: Rect?`
- `atlasBoundsPx: Rect?`
- `atlasBoundsUV: Rect?`

`Rect` shape:

- `left: Double`
- `top: Double`
- `right: Double`
- `bottom: Double`

Runtime use:

- Lookup glyph by `unicode`.
- Advance pen by `advancePx` (or scaled from `advanceEm`).
- Build screen quad from `planeBoundsPx` (or scaled `planeBoundsEm`).
- Sample texture region using `atlasBoundsUV`.
- Skip/fallback for missing glyph entries.

## `KerningPair`

Fields:

- `unicode1: Int`
- `unicode2: Int`
- `character1: String`
- `character2: String`
- `advanceEm: Double`
- `advancePx: Double`

Runtime use:

- Optional pair-adjustment after base glyph advance.
- If unused, text still renders; spacing is simply advance-only.

## `charset.txt`

Plain UTF-8 text containing the exported character set.

Runtime use:

- Validation/debug aid for supported characters.
- Optional pre-filter before layout/render.

## `*-atlas.json` (Raw Metadata)

Raw upstream generator metadata from `msdf-atlas-gen`.

Runtime guidance:

- Treat as debug/reference data.
- Prefer `*-atlas-runtime.json` for app/runtime integration.

## Units and Coordinate Notes

- `Em` fields are font-relative units.
- `Px` fields are absolute pixel-space values at generated `emSize`.
- `UV` fields are normalized `[0, 1]` atlas coordinates.
- `yOrigin` controls vertical interpretation and should match your vertex/layout transform assumptions.

## Recommended Runtime Contract

1. Parse `*-atlas-runtime.json`.
2. Load atlas image using `atlas.imageFileName`.
3. Build `unicode -> glyph` map from `glyphs`.
4. (Optional) Build kerning map from `kerning`.
5. Generate quads from glyph bounds and draw with MSDF shader decode.

