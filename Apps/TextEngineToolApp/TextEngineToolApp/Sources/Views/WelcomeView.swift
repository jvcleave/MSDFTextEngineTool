import CoreText
import SwiftUI
import TextEngineToolCore
import UniformTypeIdentifiers

private struct FontLocation
{
    let label: String
    let icon: String
    let url: URL
}

private let fontLocations: [FontLocation] = [
    FontLocation(
        label: "User Fonts",
        icon: "person",
        url: URL(fileURLWithPath: NSString("~/Library/Fonts").expandingTildeInPath)
    ),
    FontLocation(
        label: "System Fonts",
        icon: "apple.logo",
        url: URL(fileURLWithPath: "/System/Library/Fonts")
    ),
    FontLocation(
        label: "Library Fonts",
        icon: "building.columns",
        url: URL(fileURLWithPath: "/Library/Fonts")
    ),
    FontLocation(
        label: "Network Fonts",
        icon: "network",
        url: URL(fileURLWithPath: "/Network/Library/Fonts")
    ),
]

private struct InstalledFontFamily: Identifiable
{
    let name: String
    let postScriptNames: [String]
    var id: String { name }
}

private func loadInstalledFontFamilies() -> [InstalledFontFamily]
{
    let collection = CTFontCollectionCreateFromAvailableFonts(nil)
    let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection)
        as? [CTFontDescriptor] ?? []
    var groups: [String: [String]] = [:]

    for descriptor in descriptors
    {
        guard
            let family = CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontFamilyNameAttribute
            ) as? String,
            let psName = CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontNameAttribute
            ) as? String
        else { continue }

        groups[family, default: []].append(psName)
    }

    return groups.keys.sorted().map
    { family in
        InstalledFontFamily(name: family, postScriptNames: groups[family]!.sorted())
    }
}

private struct InstalledFontPickerSheet: View
{
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var families: [InstalledFontFamily] = []

    private var filteredFamilies: [InstalledFontFamily]
    {
        guard !searchText.isEmpty else { return families }
        return families.filter
        { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack
            {
                Text("Installed Fonts")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            TextField("Search families…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            if families.isEmpty
            {
                ProgressView("Loading fonts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if filteredFamilies.isEmpty
            {
                Text("No families matching \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else
            {
                List
                {
                    ForEach(filteredFamilies)
                    { family in
                        Section(family.name)
                        {
                            ForEach(family.postScriptNames, id: \.self)
                            { psName in
                                Button
                                {
                                    appState.selectInstalledFont(postScriptName: psName)
                                    dismiss()
                                }
                                label:
                                {
                                    Text(psName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 420, height: 520)
        .task
        {
            let loaded = await Task.detached(priority: .userInitiated)
            {
                loadInstalledFontFamilies()
            }.value
            families = loaded
        }
    }
}

struct FontPickerView: View
{
    @Environment(AppState.self) private var appState
    @State private var showInstalledFontPicker = false

    var body: some View
    {
        VStack(spacing: 28)
        {
            Image(systemName: "textformat")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text("Choose a Font")
                .font(.title2)
                .fontWeight(.semibold)

            if let fontInput = appState.fontInput
            {
                selectedFontRow(fontInput)
            }
            else
            {
                fontPickerButtons
            }

            Text("Supports .ttf  .otf  .ttc  .otc")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var fontPickerButtons: some View
    {
        VStack(spacing: 12)
        {
            // Quick-access location buttons
            HStack(spacing: 8)
            {
                ForEach(fontLocations, id: \.label)
                { location in
                    Button
                    {
                        pickFont(startingAt: location.url)
                    }
                    label:
                    {
                        Label(location.label, systemImage: location.icon)
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!FileManager.default.fileExists(atPath: location.url.path))
                }
            }

            // Divider with label
            HStack
            {
                VStack { Divider() }
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                VStack { Divider() }
            }
            .frame(maxWidth: 320)

            HStack(spacing: 12)
            {
                Button("Browse…")
                {
                    pickFont(startingAt: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Installed Fonts…")
                {
                    showInstalledFontPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .sheet(isPresented: $showInstalledFontPicker)
        {
            InstalledFontPickerSheet()
                .environment(appState)
        }
    }

    @ViewBuilder
    private func selectedFontRow(_ fontInput: TextAtlasFontInput) -> some View
    {
        VStack(spacing: 12)
        {
            HStack(spacing: 12)
            {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2)
                {
                    switch fontInput
                    {
                    case let .fontFile(url):
                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                    case let .installedFont(postScriptName):
                        Text(postScriptName)
                            .fontWeight(.medium)
                        Text("Installed font")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case let .fontFileFace(url, postScriptName):
                        Text(postScriptName)
                            .fontWeight(.medium)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 420)

            // Quick-change row
            HStack(spacing: 6)
            {
                ForEach(fontLocations, id: \.label)
                { location in
                    Button(location.label)
                    {
                        pickFont(startingAt: location.url)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .disabled(!FileManager.default.fileExists(atPath: location.url.path))
                }

                Text("·")
                    .foregroundStyle(.tertiary)
                    .font(.caption)

                Button("Browse…")
                {
                    pickFont(startingAt: nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Text("·")
                    .foregroundStyle(.tertiary)
                    .font(.caption)

                Button("Installed…")
                {
                    showInstalledFontPicker = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    private func pickFont(startingAt directory: URL?)
    {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ttf"),
            UTType(filenameExtension: "otf"),
            UTType(filenameExtension: "ttc"),
            UTType(filenameExtension: "otc"),
        ].compactMap { $0 }
        panel.prompt = "Choose Font"
        panel.message = "Select a font file for atlas generation"

        if let directory
        {
            panel.directoryURL = directory
        }
        else if case let .fontFile(existing) = appState.fontInput
        {
            panel.directoryURL = existing.deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let url = panel.url
        {
            appState.selectFontFile(url: url)
        }
    }
}
