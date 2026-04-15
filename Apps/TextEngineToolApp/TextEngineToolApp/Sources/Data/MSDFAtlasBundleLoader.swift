import Foundation

enum MSDFAtlasBundleLoaderError: Error
{
    case runtimeMetadataNotFound(String)
    case runtimeMetadataDecodeFailed(String)
}

/// Loads an MSDF atlas from exported on-disk files and validates required inputs.
final class MSDFAtlasBundleLoader
{
    static let shared = MSDFAtlasBundleLoader()

    private init() {}

    /// Loads runtime metadata + atlas image path + optional charset manifest from a folder.
    func loadBundle(folderURL: URL) throws -> MSDFAtlasBundle
    {
        let standardizedFolderURL = folderURL.standardizedFileURL
        let runtimeMetadataURL = try resolveRuntimeMetadataURL(folderURL: standardizedFolderURL)
        let runtimeMetadataData = try Data(contentsOf: runtimeMetadataURL)
        let metadata: MSDFAtlasMetadata
        do
        {
            metadata = try JSONDecoder().decode(
                MSDFAtlasMetadata.self,
                from: runtimeMetadataData
            )
        }
        catch
        {
            throw MSDFAtlasBundleLoaderError.runtimeMetadataDecodeFailed(
                "Failed to decode runtime metadata: \(runtimeMetadataURL.path)"
            )
        }

        let atlasImageURL = standardizedFolderURL.appendingPathComponent(
            metadata.atlas.imageFileName
        )
        let charsetManifestURL = standardizedFolderURL.appendingPathComponent(
            metadata.atlas.charsetFileName
        )
        let charset: String?
        if FileManager.default.fileExists(atPath: charsetManifestURL.path)
        {
            charset = try String(contentsOf: charsetManifestURL, encoding: .utf8)
        }
        else
        {
            charset = nil
        }

        return MSDFAtlasBundle(
            metadata: metadata,
            runtimeMetadataURL: runtimeMetadataURL,
            atlasImageURL: atlasImageURL,
            charset: charset
        )
    }

    func hasRequiredFiles(bundle: MSDFAtlasBundle) -> Bool
    {
        return missingRequiredFilePaths(bundle: bundle).isEmpty
    }

    func missingRequiredFilePaths(bundle: MSDFAtlasBundle) -> [String]
    {
        var missingPaths: [String] = []
        if !FileManager.default.fileExists(atPath: bundle.runtimeMetadataURL.path)
        {
            missingPaths.append(bundle.runtimeMetadataURL.path)
        }
        if !FileManager.default.fileExists(atPath: bundle.atlasImageURL.path)
        {
            missingPaths.append(bundle.atlasImageURL.path)
        }
        return missingPaths
    }

    /// Resolves runtime metadata with fallback for project-prefixed file names.
    private func resolveRuntimeMetadataURL(folderURL: URL) throws -> URL
    {
        let defaultMetadataURL = folderURL.appendingPathComponent("atlas-runtime.json")
        if FileManager.default.fileExists(atPath: defaultMetadataURL.path)
        {
            return defaultMetadataURL
        }

        let folderContents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        )
        let runtimeMetadataFiles = folderContents.filter
        { folderFileURL in
            folderFileURL.lastPathComponent.hasSuffix("-atlas-runtime.json")
        }

        if runtimeMetadataFiles.count == 1, let runtimeMetadataURL = runtimeMetadataFiles.first
        {
            return runtimeMetadataURL
        }

        throw MSDFAtlasBundleLoaderError.runtimeMetadataNotFound(
            "Could not resolve runtime metadata JSON in folder \(folderURL.path)"
        )
    }
}
