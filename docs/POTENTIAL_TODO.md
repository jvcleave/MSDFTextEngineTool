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

## Potential SATIN export plan

### Goal
Add an optional export path from `TextEngineTool` that produces a Satin-compatible font atlas package for `Satin.TextGeometry` + `Satin.TextMaterial`.

### Why
- Current runtime export (`*-atlas-runtime.json`) is optimized for the TextEngineTool MSDF renderer.
- Satin expects a different atlas JSON schema (`FontAtlas`) and currently uses a single-channel SDF decode path.

### Target Outputs
- `*-satin.json` (Satin `FontAtlas` schema)
- atlas image file (same naming pattern, configurable)
- existing files remain unchanged:
  - `*-atlas-runtime.json`
  - `*-atlas.json` (optional in app export unless Advanced toggle is enabled)
  - `*-charset.txt`

### Compatibility Modes
1. `satinSDF` (recommended first):
   - Export atlas with `imageType: "sdf"`.
   - Works with Satin’s current `TextMaterial` shader (`.r` channel sample).
2. `satinMSDF` (optional follow-up):
   - Keep `imageType: "msdf"`.
   - Requires Satin shader update to MSDF median decode.

### Schema Mapping (Runtime -> Satin FontAtlas)
- Satin root fields:
  - `name`: font display name / PostScript name fallback
  - `size`: `atlas.emSize` (rounded to `Int`)
  - `bold`: from config/profile (default `false`)
  - `italic`: from config/profile (default `false`)
  - `width`: `atlas.width`
  - `height`: `atlas.height`
  - `characters`: dictionary keyed by single-character `String`
- Satin character fields:
  - `x`: `glyph.atlasBoundsPx.left`
  - `y`: `glyph.atlasBoundsPx.top`
  - `width`: `glyph.atlasBoundsPx.right - left`
  - `height`: `glyph.atlasBoundsPx.bottom - top`
  - `originX`: `-glyph.planeBoundsPx.left`
  - `originY`: `glyph.planeBoundsPx.bottom`
  - `advance`: `glyph.advancePx`

### Implementation Steps
1. Add Satin export model types in `TextEngineToolCore` (parallel to runtime metadata model).
2. Add a mapper from `RuntimeAtlasMetadata` -> Satin model.
3. Add writer utility for `*-satin.json`.
4. Extend `TextAtlasEngine.generateAtlas` and `generateAtlasStreaming`:
   - optional Satin export toggle/profile
   - write Satin JSON when enabled
5. Add config/profile support:
   - default off for backward compatibility
   - preset for `satinSDF`
6. Update docs (`EXPORTED_DATA_TYPES.md`) with Satin format and file names.
7. Add an example load check in `TextEngineExampleApp` (optional lightweight test).

### Validation Checklist
- Satin JSON decodes with `Satin.FontAtlas.load(url:)`.
- `TextGeometry(text:font:)` builds quads without missing glyphs for exported charset.
- Glyph positioning appears correct (baseline, spacing, punctuation).
- Whitespace and unsupported glyph behavior is predictable.
- Existing runtime export remains unchanged.

### Non-Goals (Phase 1)
- Kerning integration into Satin runtime (Satin `TextGeometry` currently does not consume kerning pairs).
- Multi-line layout changes in Satin.
- Automatic Satin shader patching for MSDF.

### Risks
- Coordinate sign mistakes for `originY` can shift baseline.
- If atlas type is MSDF but Satin shader remains SDF, visual quality will be incorrect.
- Missing `atlasBoundsPx`/`planeBoundsPx` glyphs must be skipped safely.

### Milestones
- [ ] M1: Satin model + mapper compile.
- [ ] M2: `*-satin.json` emitted from non-streaming export.
- [ ] M3: Streaming export path emits `*-satin.json`.
- [ ] M4: `satinSDF` profile added and documented.
- [ ] M5: Verified in a Satin sample scene (`TextMesh` renders correctly).
