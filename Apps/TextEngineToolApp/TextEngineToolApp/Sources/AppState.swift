import Foundation
import Observation
import SwiftUI
import TextEngineToolCore

@MainActor
@Observable
final class AppState
{
    let stepTitles = ["Font", "Characters", "Export", "Example"]
    var currentStep: Int = 0

    // Step 1 — Font
    var fontInput: TextAtlasFontInput?

    // Step 2 — Characters
    var includeUpperLower: Bool = true
    var includeDigits: Bool = true
    var includeSpace: Bool = true
    var includePunctuation: Bool = false
    var includeSymbols: Bool = false
    var additionalCharacters: String = ""

    // Step 3 — Export
    var projectName: String = ""
    var logLines: [String] = []
    var isWorking: Bool = false
    var lastExportOutputDirectoryURL: URL?
    var lastExportAtlasBundle: MSDFAtlasBundle?
    var showAdvancedOptions: Bool = false
    var atlasWidth: Int = 1024
    var atlasHeight: Int = 1024
    var emSize: Double = 64
    var pixelRange: Double = 4
    var padding: Int = 8
    var yOrigin: String = "top"
    var exportRawGeneratorJSON: Bool = false

    // Step 4 — Example
    var demoText: String = "HELLO"
    var demoFontSize: Double = 64
    var demoOpacity: Double = 1.0
    var demoForegroundColor: Color = .white
    var demoBackgroundColor: Color = Color(NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1))

    // Auto-detected at compile time. AppState.swift is 5 levels below the
    // TextEngineTool package root:
    //   TextEngineTool/Apps/TextEngineToolApp/TextEngineToolApp/TextEngineToolApp/AppState.swift
    private static let toolRootURL: URL? =
    {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 { url = url.deletingLastPathComponent() }
        let vendorDir = url.appendingPathComponent("Vendor/msdf-atlas-gen")
        return FileManager.default.fileExists(atPath: vendorDir.path) ? url : nil
    }()

    private static let fallbackOutputBaseDirectoryURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents")
        .appendingPathComponent("TextEngineToolExports")

    private static let runtimeWorkingDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

    var generatorBinaryURL: URL?
    {
        VendoredMSDFAtlasGen.defaultBundledBinaryURL()
    }

    var generatorIsReady: Bool
    {
        let runtimeRootURL = Self.toolRootURL ?? Self.runtimeWorkingDirectoryURL
        let generator = VendoredMSDFAtlasGen(
            rootDirectoryURL: runtimeRootURL,
            preferredBinaryURL: generatorBinaryURL,
            canAutoBuild: Self.toolRootURL != nil
        )
        return generator.isBuilt
    }

    var generatorRequirementMessage: String
    {
        if toolRootDetected
        {
            return "Generator missing. Run `swift run TextEngineTool build-vendor` or bundle `msdf-atlas-gen` in app resources/bin."
        }

        return "Bundled generator missing at `Contents/Resources/bin/msdf-atlas-gen`."
    }

    var resolvedCharset: String
    {
        var chars = ""
        if includeUpperLower { chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" }
        if includeDigits { chars += "0123456789" }
        if includeSpace { chars += " " }
        if includePunctuation { chars += ".,!?:;-'\"()" }
        if includeSymbols { chars += "@#$%&*+=/\\<>" }
        chars += additionalCharacters
        var seen = Set<Character>()
        return String(chars.filter { seen.insert($0).inserted })
    }

    var canExport: Bool
    {
        fontInput != nil
            && !resolvedCharset.isEmpty
            && !projectName.trimmingCharacters(in: .whitespaces).isEmpty
            && atlasWidth > 0
            && atlasHeight > 0
            && emSize > 0
            && pixelRange > 0
            && padding >= 0
            && generatorIsReady
            && !isWorking
    }

    /// True when the TextEngineTool root was found at compile-time path resolution.
    var toolRootDetected: Bool { Self.toolRootURL != nil }

    var selectedFontLabel: String
    {
        switch fontInput
        {
        case let .fontFile(url): return url.lastPathComponent
        case let .installedFont(name): return name
        case let .fontFileFace(_, name): return name
        case nil: return "—"
        }
    }

    var canAdvance: Bool
    {
        switch currentStep
        {
        case 0: return fontInput != nil
        case 1: return !resolvedCharset.isEmpty
        case 2: return lastExportAtlasBundle != nil
        default: return true
        }
    }

    /// Default output:
    /// - dev/source-tree mode: TextEngineTool/Generated/{projectName}
    /// - bundled app mode: ~/Documents/TextEngineToolExports/{projectName}
    var defaultOutputDirectoryURL: URL?
    {
        let name = projectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let baseDirectoryURL: URL
        if let root = Self.toolRootURL
        {
            baseDirectoryURL = root.appendingPathComponent("Generated")
        }
        else
        {
            baseDirectoryURL = Self.fallbackOutputBaseDirectoryURL
        }

        return baseDirectoryURL.appendingPathComponent(name)
    }

    func selectFontFile(url: URL)
    {
        fontInput = .fontFile(url)
        projectName = sanitizedProjectName(from: url)
    }

    func selectInstalledFont(postScriptName: String)
    {
        fontInput = .installedFont(postScriptName: postScriptName)
        projectName = sanitizedName(postScriptName)
    }

    func goToNextStep()
    {
        if canAdvance, currentStep < stepTitles.count - 1
        {
            currentStep += 1
        }
    }

    func goToPreviousStep()
    {
        if currentStep > 0
        {
            currentStep -= 1
        }
    }

    func startExportToDefaultDirectory()
    {
        if let outputURL = defaultOutputDirectoryURL
        {
            Task { await export(to: outputURL) }
        }
    }

    func startExportToBaseDirectory(_ baseDirectoryURL: URL)
    {
        let name = projectName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty
        {
            let outputURL = baseDirectoryURL.appendingPathComponent(name)
            Task { await export(to: outputURL) }
        }
    }

    func export(to outputDirectoryURL: URL) async
    {
        if isWorking { return }
        guard let fontInput else { return }
        guard generatorIsReady else
        {
            logLines = ["Error: \(generatorRequirementMessage)"]
            return
        }

        let runtimeRootURL = Self.toolRootURL ?? Self.runtimeWorkingDirectoryURL
        let charset = resolvedCharset
        guard !charset.isEmpty else { return }

        isWorking = true
        logLines = []
        lastExportOutputDirectoryURL = nil
        lastExportAtlasBundle = nil

        let engine = TextAtlasEngine(
            rootDirectoryURL: runtimeRootURL,
            generatorRootDirectoryURL: runtimeRootURL,
            generatorBinaryURL: generatorBinaryURL,
            allowGeneratorBuild: Self.toolRootURL != nil
        )
        let config = engine.makeAtlasConfig(
            fontInput: fontInput,
            charsetPath: "",
            outputDirectory: outputDirectoryURL.path,
            atlasImageName: "\(projectName)-atlas.bmp",
            charsetManifestName: "\(projectName)-charset.txt",
            metadataFileName: "\(projectName)-atlas.json",
            runtimeMetadataFileName: "\(projectName)-atlas-runtime.json",
            atlasWidth: atlasWidth,
            atlasHeight: atlasHeight,
            emSize: emSize,
            pixelRange: pixelRange,
            padding: padding,
            yOrigin: yOrigin
        )

        do
        {
            logLines.append("Generating atlas…")

            let bundle = try await engine.generateAtlasStreaming(
                config: config,
                relativeTo: outputDirectoryURL,
                charset: charset
            )
            { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.logLines.append(line)
                }
            }

            logLines.append("✓ \(bundle.loadedConfig.atlasImageURL.lastPathComponent)")
            logLines.append("✓ \(bundle.loadedConfig.runtimeMetadataURL.lastPathComponent)")
            logLines.append("✓ \(bundle.loadedConfig.charsetManifestURL.lastPathComponent)")

            if exportRawGeneratorJSON
            {
                logLines.append("✓ \(bundle.loadedConfig.metadataURL.lastPathComponent)")
            }
            else if FileManager.default.fileExists(atPath: bundle.loadedConfig.metadataURL.path)
            {
                do
                {
                    try FileManager.default.removeItem(at: bundle.loadedConfig.metadataURL)
                    logLines.append("Removed raw generator JSON (runtime JSON kept).")
                }
                catch
                {
                    logLines.append(
                        "Warning: Failed to remove raw generator JSON: \(bundle.loadedConfig.metadataURL.lastPathComponent)"
                    )
                }
            }

            lastExportOutputDirectoryURL = bundle.loadedConfig.outputDirectoryURL

            do
            {
                let atlasBundle = try MSDFAtlasBundleLoader.shared.loadBundle(
                    folderURL: bundle.loadedConfig.outputDirectoryURL
                )
                lastExportAtlasBundle = atlasBundle
                logLines.append("✓ Preview bundle loaded from exported folder")
            }
            catch
            {
                logLines.append("Error: Failed to load exported atlas bundle for preview")
                logLines.append("Error: \(error.localizedDescription)")
            }

            logLines.append("Export complete.")
        }
        catch
        {
            logLines.append("Error: \(error.localizedDescription)")
        }

        isWorking = false
    }

    private func sanitizedProjectName(from url: URL) -> String
    {
        sanitizedName(url.deletingPathExtension().lastPathComponent)
    }

    private func sanitizedName(_ string: String) -> String
    {
        let sanitized = string
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "-" }
            .reduce("") { $0 + String($1) }

        return sanitized
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
