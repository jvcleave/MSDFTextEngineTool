import Foundation

public struct GeneratedAtlasBundle
{
    public let loadedConfig: LoadedAtlasConfig
    public let charset: String
    public let runtimeMetadata: RuntimeAtlasMetadata
}

public struct ExportedAtlasBundle
{
    public let folderURL: URL
    public let metadataURL: URL
    public let imageURL: URL
    public let charsetManifestURL: URL?
    public let metadata: RuntimeAtlasMetadata
    public let charset: String?
}

public struct TextAtlasEngine
{
    public let rootDirectoryURL: URL

    public init(rootDirectoryURL: URL)
    {
        self.rootDirectoryURL = rootDirectoryURL
    }

    public func makeLoadedAtlasConfig(
        config: AtlasConfig,
        relativeTo baseDirectoryURL: URL
    ) throws -> LoadedAtlasConfig
    {
        return try config.makeLoadedAtlasConfig(relativeTo: baseDirectoryURL)
    }

    public func makeAtlasConfig(
        fontInput: TextAtlasFontInput,
        charsetPath: String,
        outputDirectory: String,
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
    ) -> AtlasConfig
    {
        return AtlasConfig(
            fontInput: fontInput,
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
    }

    public func generateAtlas(
        config: AtlasConfig,
        relativeTo baseDirectoryURL: URL,
        charset: String? = nil
    ) throws -> GeneratedAtlasBundle
    {
        let loadedConfig = try config.makeLoadedAtlasConfig(relativeTo: baseDirectoryURL)
        let resolvedCharset = try resolvedCharset(
            loadedConfig: loadedConfig,
            charset: charset
        )

        try FileManager.default.createDirectory(
            at: loadedConfig.outputDirectoryURL,
            withIntermediateDirectories: true
        )
        try resolvedCharset.write(
            to: loadedConfig.charsetManifestURL,
            atomically: true,
            encoding: .utf8
        )

        let vendoredMSDFAtlasGen = VendoredMSDFAtlasGen(
            rootDirectoryURL: rootDirectoryURL
        )
        try vendoredMSDFAtlasGen.generateAtlas(
            loadedConfig: loadedConfig,
            charset: resolvedCharset
        )

        let rawMetadataData = try Data(contentsOf: loadedConfig.metadataURL)
        let runtimeMetadata = try RuntimeAtlasMetadataBuilder.build(
            rawMetadataData: rawMetadataData,
            loadedConfig: loadedConfig
        )
        try RuntimeAtlasMetadataBuilder.write(
            runtimeMetadata,
            to: loadedConfig.runtimeMetadataURL
        )

        return GeneratedAtlasBundle(
            loadedConfig: loadedConfig,
            charset: resolvedCharset,
            runtimeMetadata: runtimeMetadata
        )
    }

    public func generateAtlasStreaming(
        config: AtlasConfig,
        relativeTo baseDirectoryURL: URL,
        charset: String? = nil,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> GeneratedAtlasBundle
    {
        let loadedConfig = try config.makeLoadedAtlasConfig(relativeTo: baseDirectoryURL)
        let resolvedCharset = try resolvedCharset(
            loadedConfig: loadedConfig,
            charset: charset
        )

        try FileManager.default.createDirectory(
            at: loadedConfig.outputDirectoryURL,
            withIntermediateDirectories: true
        )
        try resolvedCharset.write(
            to: loadedConfig.charsetManifestURL,
            atomically: true,
            encoding: .utf8
        )

        let vendoredMSDFAtlasGen = VendoredMSDFAtlasGen(
            rootDirectoryURL: rootDirectoryURL
        )
        try await vendoredMSDFAtlasGen.generateAtlasStreaming(
            loadedConfig: loadedConfig,
            charset: resolvedCharset,
            onLine: onLine
        )

        let rawMetadataData = try Data(contentsOf: loadedConfig.metadataURL)
        let runtimeMetadata = try RuntimeAtlasMetadataBuilder.build(
            rawMetadataData: rawMetadataData,
            loadedConfig: loadedConfig
        )
        try RuntimeAtlasMetadataBuilder.write(
            runtimeMetadata,
            to: loadedConfig.runtimeMetadataURL
        )

        return GeneratedAtlasBundle(
            loadedConfig: loadedConfig,
            charset: resolvedCharset,
            runtimeMetadata: runtimeMetadata
        )
    }

    public func loadExportedAtlasBundle(
        from folderURL: URL
    ) throws -> ExportedAtlasBundle
    {
        let standardizedFolderURL = folderURL.standardizedFileURL
        let metadataURL = standardizedFolderURL.appendingPathComponent("atlas-runtime.json")

        if !FileManager.default.fileExists(atPath: metadataURL.path)
        {
            throw ToolError("Missing atlas runtime metadata at \(metadataURL.path)")
        }

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(
            RuntimeAtlasMetadata.self,
            from: metadataData
        )
        let imageURL = standardizedFolderURL.appendingPathComponent(
            metadata.atlas.imageFileName
        )

        if !FileManager.default.fileExists(atPath: imageURL.path)
        {
            throw ToolError("Missing atlas image at \(imageURL.path)")
        }

        let charsetManifestURL = standardizedFolderURL.appendingPathComponent(
            metadata.atlas.charsetFileName
        )
        let charset: String?
        if FileManager.default.fileExists(atPath: charsetManifestURL.path)
        {
            charset = try CharsetLoader.loadCharset(from: charsetManifestURL)
        }
        else
        {
            charset = nil
        }

        let resolvedCharsetManifestURL = charset == nil ? nil : charsetManifestURL

        return ExportedAtlasBundle(
            folderURL: standardizedFolderURL,
            metadataURL: metadataURL,
            imageURL: imageURL,
            charsetManifestURL: resolvedCharsetManifestURL,
            metadata: metadata,
            charset: charset
        )
    }

    private func resolvedCharset(
        loadedConfig: LoadedAtlasConfig,
        charset: String?
    ) throws -> String
    {
        if let charset
        {
            return charset
        }

        if let charsetURL = loadedConfig.charsetURL
        {
            return try CharsetLoader.loadCharset(from: charsetURL)
        }

        throw ToolError(
            "No charset was provided and config.charsetPath was empty"
        )
    }
}
