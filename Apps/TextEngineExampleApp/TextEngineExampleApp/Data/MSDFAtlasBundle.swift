import Foundation

struct MSDFAtlasMetadata: Decodable
{
    struct Atlas: Decodable
    {
        let type: String
        let imageFileName: String
        let charsetFileName: String
        let yOrigin: String
        let width: Int
        let height: Int
        let distanceRange: Double
        let emSize: Double
        let pixelRange: Double
        let padding: Int
    }

    struct Metrics: Decodable
    {
        let lineHeightEm: Double
        let ascenderEm: Double
        let descenderEm: Double
        let underlineYEm: Double
        let underlineThicknessEm: Double
        let lineHeightPx: Double
        let ascenderPx: Double
        let descenderPx: Double
        let underlineYPx: Double
        let underlineThicknessPx: Double
    }

    struct Rect: Decodable
    {
        let left: Double
        let top: Double
        let right: Double
        let bottom: Double
    }

    struct Glyph: Decodable
    {
        let unicode: Int
        let character: String
        let advanceEm: Double
        let advancePx: Double
        let planeBoundsEm: Rect?
        let planeBoundsPx: Rect?
        let atlasBoundsPx: Rect?
        let atlasBoundsUV: Rect?
    }

    struct KerningPair: Decodable
    {
        let unicode1: Int
        let unicode2: Int
        let character1: String
        let character2: String
        let advanceEm: Double
        let advancePx: Double
    }

    let version: Int
    let atlas: Atlas
    let metrics: Metrics
    let glyphs: [Glyph]
    let kerning: [KerningPair]
}

struct MSDFAtlasBundle
{
    let metadata: MSDFAtlasMetadata
    let runtimeMetadataURL: URL
    let atlasImageURL: URL
    let charset: String?

    private let glyphsByUnicode: [Int: MSDFAtlasMetadata.Glyph]

    init(
        metadata: MSDFAtlasMetadata,
        runtimeMetadataURL: URL,
        atlasImageURL: URL,
        charset: String?
    )
    {
        self.metadata = metadata
        self.runtimeMetadataURL = runtimeMetadataURL
        self.atlasImageURL = atlasImageURL
        self.charset = charset

        var indexedGlyphs: [Int: MSDFAtlasMetadata.Glyph] = [:]
        indexedGlyphs.reserveCapacity(metadata.glyphs.count)
        for glyph in metadata.glyphs
        {
            indexedGlyphs[glyph.unicode] = glyph
        }
        glyphsByUnicode = indexedGlyphs
    }

    func glyph(for character: Character) -> MSDFAtlasMetadata.Glyph?
    {
        if let scalar = character.unicodeScalars.first
        {
            return glyphsByUnicode[Int(scalar.value)]
        }
        return nil
    }
}
