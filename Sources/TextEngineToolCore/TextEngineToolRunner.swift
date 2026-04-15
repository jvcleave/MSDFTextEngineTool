import CoreText
import Foundation

public struct TextEngineToolRunner
{
    public init() {}

    public func run(arguments: ToolArguments) throws
    {
        switch arguments.command
        {
        case .plan:
            print(
                """
                TextEngineTool is ready to vendor and drive msdf-atlas-gen.

                Current commands:
                  plan
                  build-vendor
                  generate-atlas --config <path>
                  init-config --output <path>
                  list-fonts [--family <name>]
                  print-charset --charset <path>

                Vendored generator:
                  Vendor/msdf-atlas-gen

                Primary workflow:
                  1. init-config
                  2. edit fontPath or fontPostScriptName in the config
                  3. build-vendor
                  4. generate-atlas
                """
            )

        case .buildVendor:
            let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let vendoredMSDFAtlasGen = VendoredMSDFAtlasGen(
                rootDirectoryURL: currentDirectoryURL
            )
            let binaryURL = try vendoredMSDFAtlasGen.ensureBuilt()
            print("Vendored msdf-atlas-gen binary is ready at \(binaryURL.path)")

        case .generateAtlas:
            guard let configPath = arguments.configPath
            else
            {
                throw ToolError("generate-atlas requires --config <path>")
            }

            let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let configFileURL = AtlasConfig.resolvePath(
                configPath,
                relativeTo: currentDirectoryURL
            )
            let configData = try Data(contentsOf: configFileURL)
            let config = try JSONDecoder().decode(AtlasConfig.self, from: configData)
            let baseDirectoryURL = configFileURL.deletingLastPathComponent()
            let loadedConfig = try AtlasConfig.loadResolved(
                from: configPath,
                relativeTo: currentDirectoryURL
            )
            defer
            {
                if let temporaryFontURL = loadedConfig.temporaryFontURL
                {
                    try? FileManager.default.removeItem(at: temporaryFontURL)
                }
            }
            let textAtlasEngine = TextAtlasEngine(
                rootDirectoryURL: currentDirectoryURL
            )
            _ = try textAtlasEngine.generateAtlas(
                config: config,
                relativeTo: baseDirectoryURL
            )

            print("Generated atlas image at \(loadedConfig.atlasImageURL.path)")
            print("Generated atlas metadata at \(loadedConfig.metadataURL.path)")
            print("Generated runtime metadata at \(loadedConfig.runtimeMetadataURL.path)")
            print("Wrote charset manifest to \(loadedConfig.charsetManifestURL.path)")

        case .initConfig:
            guard let outputPath = arguments.outputPath
            else
            {
                throw ToolError("init-config requires --output <path>")
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let configData = try encoder.encode(AtlasConfig())
            let outputURL = URL(fileURLWithPath: outputPath)
            try configData.write(to: outputURL, options: .atomic)
            print("Wrote sample config to \(outputURL.path)")

        case .listFonts:
            let descriptors: [CTFontDescriptor]

            if let familyName = arguments.familyName
            {
                let queryAttributes = [
                    kCTFontFamilyNameAttribute as String: familyName,
                ] as CFDictionary
                let queryDescriptor = CTFontDescriptorCreateWithAttributes(queryAttributes)
                descriptors = CTFontDescriptorCreateMatchingFontDescriptors(
                    queryDescriptor,
                    nil
                ) as? [CTFontDescriptor] ?? []
            }
            else
            {
                let collection = CTFontCollectionCreateFromAvailableFonts(nil)
                descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection)
                    as? [CTFontDescriptor] ?? []
            }

            var familyGroups: [String: [String]] = [:]

            for descriptor in descriptors
            {
                guard
                    let family = CTFontDescriptorCopyAttribute(
                        descriptor,
                        kCTFontFamilyNameAttribute
                    ) as? String,
                    let postScriptName = CTFontDescriptorCopyAttribute(
                        descriptor,
                        kCTFontNameAttribute
                    ) as? String
                else
                {
                    continue
                }

                familyGroups[family, default: []].append(postScriptName)
            }

            if familyGroups.isEmpty
            {
                if let familyName = arguments.familyName
                {
                    print("No fonts found for family '\(familyName)'.")
                }
                else
                {
                    print("No fonts found.")
                }
            }
            else
            {
                for family in familyGroups.keys.sorted()
                {
                    print(family)
                    for postScriptName in familyGroups[family]!.sorted()
                    {
                        print("  \(postScriptName)")
                    }
                }
            }

        case .printCharset:
            guard let charsetPath = arguments.charsetPath
            else
            {
                throw ToolError("print-charset requires --charset <path>")
            }

            let charset = try CharsetLoader.loadCharset(from: charsetPath)
            print("Character count: \(charset.count)")
            print(charset)
        }
    }
}
