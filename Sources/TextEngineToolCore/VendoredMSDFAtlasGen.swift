import Foundation

public struct VendoredMSDFAtlasGen
{
    public let rootDirectoryURL: URL

    private var vendorDirectoryURL: URL
    {
        rootDirectoryURL.appendingPathComponent("Vendor/msdf-atlas-gen")
    }

    private var buildDirectoryURL: URL
    {
        rootDirectoryURL.appendingPathComponent(".vendor-build/msdf-atlas-gen")
    }

    public init(rootDirectoryURL: URL)
    {
        self.rootDirectoryURL = rootDirectoryURL
    }

    public var isBuilt: Bool
    {
        builtBinaryURL() != nil
    }

    func ensureBuilt() throws -> URL
    {
        guard FileManager.default.fileExists(atPath: vendorDirectoryURL.path)
        else
        {
            throw ToolError("Vendored msdf-atlas-gen was not found at \(vendorDirectoryURL.path)")
        }

        if let existingBinaryURL = builtBinaryURL()
        {
            return existingBinaryURL
        }

        try FileManager.default.createDirectory(
            at: buildDirectoryURL,
            withIntermediateDirectories: true
        )

        var configureArguments = [
            "-S", vendorDirectoryURL.path,
            "-B", buildDirectoryURL.path,
            "-DMSDF_ATLAS_USE_VCPKG=OFF",
            "-DMSDF_ATLAS_USE_SKIA=OFF",
            "-DMSDF_ATLAS_NO_ARTERY_FONT=ON",
            "-DCMAKE_BUILD_TYPE=Release",
        ]

        let homebrewPrefix = "/opt/homebrew"
        if FileManager.default.fileExists(atPath: homebrewPrefix)
        {
            configureArguments.append("-DCMAKE_PREFIX_PATH=\(homebrewPrefix)")
        }

        try ProcessRunner.run(
            command: "cmake",
            arguments: configureArguments,
            currentDirectoryURL: rootDirectoryURL
        )
        try ProcessRunner.run(
            command: "cmake",
            arguments: [
                "--build", buildDirectoryURL.path,
                "--config", "Release",
                "--target", "msdf-atlas-gen-standalone",
            ],
            currentDirectoryURL: rootDirectoryURL
        )

        if let binaryURL = builtBinaryURL()
        {
            return binaryURL
        }

        throw ToolError("Built msdf-atlas-gen but could not locate the output binary")
    }

    public func ensureBuiltStreaming(onLine: @escaping @Sendable (String) -> Void) async throws -> URL
    {
        guard FileManager.default.fileExists(atPath: vendorDirectoryURL.path)
        else
        {
            throw ToolError("Vendored msdf-atlas-gen was not found at \(vendorDirectoryURL.path)")
        }

        if let existingBinaryURL = builtBinaryURL()
        {
            onLine("msdf-atlas-gen binary already built at \(existingBinaryURL.path)")
            return existingBinaryURL
        }

        try FileManager.default.createDirectory(
            at: buildDirectoryURL,
            withIntermediateDirectories: true
        )

        var configureArguments = [
            "-S", vendorDirectoryURL.path,
            "-B", buildDirectoryURL.path,
            "-DMSDF_ATLAS_USE_VCPKG=OFF",
            "-DMSDF_ATLAS_USE_SKIA=OFF",
            "-DMSDF_ATLAS_NO_ARTERY_FONT=ON",
            "-DCMAKE_BUILD_TYPE=Release",
        ]

        let homebrewPrefix = "/opt/homebrew"
        if FileManager.default.fileExists(atPath: homebrewPrefix)
        {
            configureArguments.append("-DCMAKE_PREFIX_PATH=\(homebrewPrefix)")
        }

        onLine("Configuring cmake…")
        try await ProcessRunner.runStreaming(
            command: "cmake",
            arguments: configureArguments,
            currentDirectoryURL: rootDirectoryURL,
            onLine: onLine
        )

        onLine("Building msdf-atlas-gen…")
        try await ProcessRunner.runStreaming(
            command: "cmake",
            arguments: [
                "--build", buildDirectoryURL.path,
                "--config", "Release",
                "--target", "msdf-atlas-gen-standalone",
            ],
            currentDirectoryURL: rootDirectoryURL,
            onLine: onLine
        )

        if let binaryURL = builtBinaryURL()
        {
            return binaryURL
        }

        throw ToolError("Built msdf-atlas-gen but could not locate the output binary")
    }

    public func generateAtlasStreaming(
        loadedConfig: LoadedAtlasConfig,
        charset: String,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws
    {
        let binaryURL = try await ensureBuiltStreaming(onLine: onLine)
        let encodedCharset = "\"" + escapeForCharsetArgument(charset) + "\""

        try await ProcessRunner.runStreaming(
            command: binaryURL.path,
            arguments: [
                "-font", loadedConfig.fontURL.path,
                "-chars", encodedCharset,
                "-type", loadedConfig.config.imageType,
                "-format", loadedConfig.config.imageFormat,
                "-dimensions", String(loadedConfig.config.atlasWidth), String(loadedConfig.config.atlasHeight),
                "-size", String(loadedConfig.config.emSize),
                "-pxrange", String(loadedConfig.config.pixelRange),
                "-pxpadding", String(loadedConfig.config.padding),
                "-yorigin", loadedConfig.config.yOrigin,
                "-imageout", loadedConfig.atlasImageURL.path,
                "-json", loadedConfig.metadataURL.path,
            ],
            currentDirectoryURL: rootDirectoryURL,
            onLine: onLine
        )
    }

    func generateAtlas(
        loadedConfig: LoadedAtlasConfig,
        charset: String
    ) throws
    {
        let binaryURL = try ensureBuilt()
        let encodedCharset = "\"" + escapeForCharsetArgument(charset) + "\""

        try ProcessRunner.run(
            command: binaryURL.path,
            arguments: [
                "-font", loadedConfig.fontURL.path,
                "-chars", encodedCharset,
                "-type", loadedConfig.config.imageType,
                "-format", loadedConfig.config.imageFormat,
                "-dimensions", String(loadedConfig.config.atlasWidth), String(loadedConfig.config.atlasHeight),
                "-size", String(loadedConfig.config.emSize),
                "-pxrange", String(loadedConfig.config.pixelRange),
                "-pxpadding", String(loadedConfig.config.padding),
                "-yorigin", loadedConfig.config.yOrigin,
                "-imageout", loadedConfig.atlasImageURL.path,
                "-json", loadedConfig.metadataURL.path,
            ],
            currentDirectoryURL: rootDirectoryURL
        )
    }

    private func builtBinaryURL() -> URL?
    {
        let candidatePaths = [
            buildDirectoryURL.appendingPathComponent("bin/msdf-atlas-gen"),
            buildDirectoryURL.appendingPathComponent("bin/Release/msdf-atlas-gen"),
        ]

        for candidateURL in candidatePaths
        {
            if FileManager.default.fileExists(atPath: candidateURL.path)
            {
                return candidateURL
            }
        }

        return nil
    }

    private func escapeForCharsetArgument(_ charset: String) -> String
    {
        var escaped = ""
        escaped.reserveCapacity(charset.count)

        for character in charset
        {
            switch character
            {
            case "\\":
                escaped.append("\\\\")
            case "\"":
                escaped.append("\\\"")
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
