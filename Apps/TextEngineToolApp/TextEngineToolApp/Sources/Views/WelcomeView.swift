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

struct FontPickerView: View
{
    @Environment(AppState.self) private var appState

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

            Button("Browse…")
            {
                pickFont(startingAt: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
