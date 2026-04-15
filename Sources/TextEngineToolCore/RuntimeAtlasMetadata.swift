import Foundation

struct RawMSDFAtlasMetadata: Decodable
{
    struct Atlas: Decodable
    {
        let type: String
        let distanceRange: Double
        let distanceRangeMiddle: Double?
        let size: Double
        let width: Double
        let height: Double
        let yOrigin: String
    }

    struct Metrics: Decodable
    {
        let emSize: Double
        let lineHeight: Double
        let ascender: Double
        let descender: Double
        let underlineY: Double
        let underlineThickness: Double
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
        let advance: Double
        let planeBounds: Rect?
        let atlasBounds: Rect?
    }

    struct KerningPair: Decodable
    {
        let unicode1: Int
        let unicode2: Int
        let advance: Double
    }

    let atlas: Atlas
    let metrics: Metrics
    let glyphs: [Glyph]
    let kerning: [KerningPair]?
}

public struct RuntimeAtlasMetadata: Codable, Equatable
{
    public struct Atlas: Codable, Equatable
    {
        public let type: String
        public let imageFileName: String
        public let charsetFileName: String
        public let yOrigin: String
        public let width: Int
        public let height: Int
        public let distanceRange: Double
        public let emSize: Double
        public let pixelRange: Double
        public let padding: Int
    }

    public struct Metrics: Codable, Equatable
    {
        public let lineHeightEm: Double
        public let ascenderEm: Double
        public let descenderEm: Double
        public let underlineYEm: Double
        public let underlineThicknessEm: Double
        public let lineHeightPx: Double
        public let ascenderPx: Double
        public let descenderPx: Double
        public let underlineYPx: Double
        public let underlineThicknessPx: Double
    }

    public struct Rect: Codable, Equatable
    {
        public let left: Double
        public let top: Double
        public let right: Double
        public let bottom: Double
    }

    public struct Glyph: Codable, Equatable
    {
        public let unicode: Int
        public let character: String
        public let advanceEm: Double
        public let advancePx: Double
        public let planeBoundsEm: Rect?
        public let planeBoundsPx: Rect?
        public let atlasBoundsPx: Rect?
        public let atlasBoundsUV: Rect?
    }

    public struct KerningPair: Codable, Equatable
    {
        public let unicode1: Int
        public let unicode2: Int
        public let character1: String
        public let character2: String
        public let advanceEm: Double
        public let advancePx: Double
    }

    public let version: Int
    public let atlas: Atlas
    public let metrics: Metrics
    public let glyphs: [Glyph]
    public let kerning: [KerningPair]
}

public enum RuntimeAtlasMetadataBuilder
{
    public static func build(
        rawMetadataData: Data,
        loadedConfig: LoadedAtlasConfig
    ) throws -> RuntimeAtlasMetadata
    {
        let rawMetadata = try JSONDecoder().decode(
            RawMSDFAtlasMetadata.self,
            from: rawMetadataData
        )

        let emToPx = rawMetadata.atlas.size
        let atlasWidth = rawMetadata.atlas.width
        let atlasHeight = rawMetadata.atlas.height

        let runtimeGlyphs = rawMetadata.glyphs
            .sorted { $0.unicode < $1.unicode }
            .map
            { glyph in
                RuntimeAtlasMetadata.Glyph(
                    unicode: glyph.unicode,
                    character: scalarString(glyph.unicode),
                    advanceEm: glyph.advance,
                    advancePx: glyph.advance * emToPx,
                    planeBoundsEm: rect(glyph.planeBounds),
                    planeBoundsPx: rect(glyph.planeBounds, scale: emToPx),
                    atlasBoundsPx: rect(glyph.atlasBounds),
                    atlasBoundsUV: uvRect(
                        glyph.atlasBounds,
                        atlasWidth: atlasWidth,
                        atlasHeight: atlasHeight
                    )
                )
            }

        let runtimeKerning = (rawMetadata.kerning ?? [])
            .map
            { kerningPair in
                RuntimeAtlasMetadata.KerningPair(
                    unicode1: kerningPair.unicode1,
                    unicode2: kerningPair.unicode2,
                    character1: scalarString(kerningPair.unicode1),
                    character2: scalarString(kerningPair.unicode2),
                    advanceEm: kerningPair.advance,
                    advancePx: kerningPair.advance * emToPx
                )
            }

        return RuntimeAtlasMetadata(
            version: 1,
            atlas: .init(
                type: rawMetadata.atlas.type,
                imageFileName: loadedConfig.config.atlasImageName,
                charsetFileName: loadedConfig.config.charsetManifestName,
                yOrigin: rawMetadata.atlas.yOrigin,
                width: Int(rawMetadata.atlas.width.rounded()),
                height: Int(rawMetadata.atlas.height.rounded()),
                distanceRange: rawMetadata.atlas.distanceRange,
                emSize: rawMetadata.atlas.size,
                pixelRange: loadedConfig.config.pixelRange,
                padding: loadedConfig.config.padding
            ),
            metrics: .init(
                lineHeightEm: rawMetadata.metrics.lineHeight,
                ascenderEm: rawMetadata.metrics.ascender,
                descenderEm: rawMetadata.metrics.descender,
                underlineYEm: rawMetadata.metrics.underlineY,
                underlineThicknessEm: rawMetadata.metrics.underlineThickness,
                lineHeightPx: rawMetadata.metrics.lineHeight * emToPx,
                ascenderPx: rawMetadata.metrics.ascender * emToPx,
                descenderPx: rawMetadata.metrics.descender * emToPx,
                underlineYPx: rawMetadata.metrics.underlineY * emToPx,
                underlineThicknessPx: rawMetadata.metrics.underlineThickness * emToPx
            ),
            glyphs: runtimeGlyphs,
            kerning: runtimeKerning
        )
    }

    public static func write(
        _ runtimeMetadata: RuntimeAtlasMetadata,
        to url: URL
    ) throws
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(runtimeMetadata)
        try data.write(to: url, options: .atomic)
    }

    private static func scalarString(_ unicodeValue: Int) -> String
    {
        guard let scalar = UnicodeScalar(unicodeValue)
        else
        {
            return ""
        }
        return String(Character(scalar))
    }

    private static func rect(
        _ rawRect: RawMSDFAtlasMetadata.Rect?,
        scale: Double = 1.0
    ) -> RuntimeAtlasMetadata.Rect?
    {
        guard let rawRect
        else
        {
            return nil
        }

        return RuntimeAtlasMetadata.Rect(
            left: rawRect.left * scale,
            top: rawRect.top * scale,
            right: rawRect.right * scale,
            bottom: rawRect.bottom * scale
        )
    }

    private static func uvRect(
        _ rawRect: RawMSDFAtlasMetadata.Rect?,
        atlasWidth: Double,
        atlasHeight: Double
    ) -> RuntimeAtlasMetadata.Rect?
    {
        guard let rawRect
        else
        {
            return nil
        }

        return RuntimeAtlasMetadata.Rect(
            left: rawRect.left / atlasWidth,
            top: rawRect.top / atlasHeight,
            right: rawRect.right / atlasWidth,
            bottom: rawRect.bottom / atlasHeight
        )
    }
}
