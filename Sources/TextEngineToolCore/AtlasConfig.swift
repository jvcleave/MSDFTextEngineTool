import Foundation

public struct LoadedAtlasConfig: Equatable
{
    public let config: AtlasConfig
    public let configFileURL: URL?
    public let fontURL: URL
    public let temporaryFontURL: URL?
    public let charsetURL: URL?
    public let outputDirectoryURL: URL
    public let atlasImageURL: URL
    public let metadataURL: URL
    public let runtimeMetadataURL: URL
    public let charsetManifestURL: URL
}

public struct AtlasConfig: Codable, Equatable
{
    public var fontPath: String
    public var fontPostScriptName: String?
    public var charsetPath: String
    public var outputDirectory: String
    public var atlasImageName: String
    public var charsetManifestName: String
    public var metadataFileName: String
    public var runtimeMetadataFileName: String
    public var imageFormat: String
    public var imageType: String
    public var atlasWidth: Int
    public var atlasHeight: Int
    public var emSize: Double
    public var pixelRange: Double
    public var padding: Int
    public var yOrigin: String

    public init(
        fontPath: String = "Fonts/YourFontFile.ttf",
        fontPostScriptName: String? = nil,
        charsetPath: String = "Templates/charsets/debug-text.txt",
        outputDirectory: String = "Generated/AtlasOutput",
        atlasImageName: String = "atlas.bmp",
        charsetManifestName: String = "charset.txt",
        metadataFileName: String = "atlas.json",
        runtimeMetadataFileName: String = "atlas-runtime.json",
        imageFormat: String = "bmp",
        imageType: String = "msdf",
        atlasWidth: Int = 1024,
        atlasHeight: Int = 1024,
        emSize: Double = 64.0,
        pixelRange: Double = 4.0,
        padding: Int = 8,
        yOrigin: String = "top"
    )
    {
        self.fontPath = fontPath
        self.fontPostScriptName = fontPostScriptName
        self.charsetPath = charsetPath
        self.outputDirectory = outputDirectory
        self.atlasImageName = atlasImageName
        self.charsetManifestName = charsetManifestName
        self.metadataFileName = metadataFileName
        self.runtimeMetadataFileName = runtimeMetadataFileName
        self.imageFormat = imageFormat
        self.imageType = imageType
        self.atlasWidth = atlasWidth
        self.atlasHeight = atlasHeight
        self.emSize = emSize
        self.pixelRange = pixelRange
        self.padding = padding
        self.yOrigin = yOrigin
    }

    public init(
        fontInput: TextAtlasFontInput,
        charsetPath: String = "Templates/charsets/debug-text.txt",
        outputDirectory: String = "Generated/AtlasOutput",
        atlasImageName: String = "atlas.bmp",
        charsetManifestName: String = "charset.txt",
        metadataFileName: String = "atlas.json",
        runtimeMetadataFileName: String = "atlas-runtime.json",
        imageFormat: String = "bmp",
        imageType: String = "msdf",
        atlasWidth: Int = 1024,
        atlasHeight: Int = 1024,
        emSize: Double = 64.0,
        pixelRange: Double = 4.0,
        padding: Int = 8,
        yOrigin: String = "top"
    )
    {
        self.init(
            fontPath: "",
            fontPostScriptName: nil,
            charsetPath: charsetPath,
            outputDirectory: outputDirectory,
            atlasImageName: atlasImageName,
            charsetManifestName: charsetManifestName,
            metadataFileName: metadataFileName,
            runtimeMetadataFileName: runtimeMetadataFileName,
            imageFormat: imageFormat,
            imageType: imageType,
            atlasWidth: atlasWidth,
            atlasHeight: atlasHeight,
            emSize: emSize,
            pixelRange: pixelRange,
            padding: padding,
            yOrigin: yOrigin
        )
        fontInput.apply(to: &self)
    }

    public static func loadResolved(
        from configPath: String,
        relativeTo currentDirectoryURL: URL
    ) throws -> LoadedAtlasConfig
    {
        let configFileURL = resolvePath(
            configPath,
            relativeTo: currentDirectoryURL
        )
        let configData = try Data(contentsOf: configFileURL)
        let config = try JSONDecoder().decode(AtlasConfig.self, from: configData)
        let baseDirectoryURL = configFileURL.deletingLastPathComponent()

        return try config.makeLoadedAtlasConfig(
            relativeTo: baseDirectoryURL,
            configFileURL: configFileURL
        )
    }

    public func makeLoadedAtlasConfig(
        relativeTo baseDirectoryURL: URL
    ) throws -> LoadedAtlasConfig
    {
        return try makeLoadedAtlasConfig(
            relativeTo: baseDirectoryURL,
            configFileURL: nil
        )
    }

    private func makeLoadedAtlasConfig(
        relativeTo baseDirectoryURL: URL,
        configFileURL: URL?
    ) throws -> LoadedAtlasConfig
    {
        let resolvedFontAsset = try FontAssetResolver.resolveFont(
            fontPath: fontPath,
            fontPostScriptName: fontPostScriptName,
            relativeTo: baseDirectoryURL
        )
        let trimmedCharsetPath = charsetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let charsetURL: URL?
        if trimmedCharsetPath.isEmpty
        {
            charsetURL = nil
        }
        else
        {
            charsetURL = Self.resolvePath(
                trimmedCharsetPath,
                relativeTo: baseDirectoryURL
            )
        }
        let outputDirectoryURL = Self.resolvePath(outputDirectory, relativeTo: baseDirectoryURL)
        let atlasImageURL = outputDirectoryURL.appendingPathComponent(atlasImageName)
        let metadataURL = outputDirectoryURL.appendingPathComponent(metadataFileName)
        let runtimeMetadataURL = outputDirectoryURL.appendingPathComponent(runtimeMetadataFileName)
        let charsetManifestURL = outputDirectoryURL.appendingPathComponent(charsetManifestName)

        return LoadedAtlasConfig(
            config: self,
            configFileURL: configFileURL,
            fontURL: resolvedFontAsset.fontURL,
            temporaryFontURL: resolvedFontAsset.temporaryFontURL,
            charsetURL: charsetURL,
            outputDirectoryURL: outputDirectoryURL,
            atlasImageURL: atlasImageURL,
            metadataURL: metadataURL,
            runtimeMetadataURL: runtimeMetadataURL,
            charsetManifestURL: charsetManifestURL
        )
    }

    static func resolvePath(
        _ path: String,
        relativeTo baseDirectoryURL: URL
    ) -> URL
    {
        if NSString(string: path).isAbsolutePath
        {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        return baseDirectoryURL
            .appendingPathComponent(path)
            .standardizedFileURL
    }
}
