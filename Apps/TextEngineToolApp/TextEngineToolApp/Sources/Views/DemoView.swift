import SwiftUI

struct DemoView: View
{
    @Environment(AppState.self) private var appState

    var body: some View
    {
        @Bindable var state = appState

        if let atlasBundle = appState.lastExportAtlasBundle
        {
            VStack(alignment: .leading, spacing: 0)
            {
                // ── Live MSDF preview ─────────────────────────────────────────
                MSDFTextPreviewView(
                    atlasBundle: atlasBundle,
                    text: appState.demoText.isEmpty ? " " : appState.demoText,
                    fontSize: CGFloat(appState.demoFontSize),
                    opacity: appState.demoOpacity,
                    foregroundColor: appState.demoForegroundColor,
                    backgroundColor: appState.demoBackgroundColor
                )
                .frame(minHeight: 180)
                .overlay(alignment: .bottomTrailing)
                {
                    Text("MSDF")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(6)
                }

                Divider()

                // ── Controls ──────────────────────────────────────────────────
                Form
                {
                    Section("Example Renderer")
                    {
                        LabeledContent("Structure")
                        {
                            Text("MSDFAtlasBundleLoader → MSDFAtlasBundle → MSDFExampleTextRenderer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Text")
                        {
                            TextField("Type here…", text: $state.demoText)
                                .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Font size")
                        {
                            HStack
                            {
                                Slider(value: $state.demoFontSize, in: 12 ... 256, step: 1)
                                Text("\(Int(appState.demoFontSize)) px")
                                    .monospacedDigit()
                                    .frame(width: 52, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Opacity")
                        {
                            HStack
                            {
                                Slider(value: $state.demoOpacity, in: 0 ... 1)
                                Text(String(format: "%.0f%%", appState.demoOpacity * 100))
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Foreground")
                        {
                            ColorPicker("", selection: $state.demoForegroundColor, supportsOpacity: false)
                                .labelsHidden()
                        }

                        LabeledContent("Background")
                        {
                            ColorPicker("", selection: $state.demoBackgroundColor, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                    atlasInfoSection(atlasBundle)

                    Section("Reference Files")
                    {
                        LabeledContent("Renderer", value: "Data/MSDFExampleTextRenderer.swift")
                        LabeledContent("Shader", value: "Data/MSDFExampleTextRenderer.metal")
                        LabeledContent("Bundle", value: "Data/MSDFAtlasBundle.swift")
                        LabeledContent("Loader", value: "Data/MSDFAtlasBundleLoader.swift")
                    }
                }
                .formStyle(.grouped)

                if let outputDirectoryURL = appState.lastExportOutputDirectoryURL
                {
                    HStack
                    {
                        Button("Reveal Output in Finder")
                        {
                            NSWorkspace.shared.open(outputDirectoryURL)
                        }
                        .buttonStyle(.borderless)
                        .padding()

                        Spacer()
                    }
                }
            }
        }
        else
        {
            ContentUnavailableView(
                "No Export Yet",
                systemImage: "wand.and.stars",
                description: Text("Complete the Export step to preview the generated atlas.")
            )
        }
    }
    // MARK: – Sections

    @ViewBuilder
    private func atlasInfoSection(_ atlasBundle: MSDFAtlasBundle) -> some View
    {
        let metadata = atlasBundle.metadata

        Section("Atlas")
        {
            LabeledContent("File")
            {
                Text(atlasBundle.atlasImageURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let image = NSImage(contentsOfFile: atlasBundle.atlasImageURL.path)
            {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .border(Color.secondary.opacity(0.2))
            }

            LabeledContent("Glyphs", value: "\(metadata.glyphs.count)")
            LabeledContent("Size", value: "\(metadata.atlas.width) × \(metadata.atlas.height)")
            LabeledContent("Em size", value: String(format: "%.0f px", metadata.atlas.emSize))
            LabeledContent("Pixel range", value: String(format: "%.0f", metadata.atlas.pixelRange))
            LabeledContent("Type", value: metadata.atlas.type)

            if let charset = atlasBundle.charset, !charset.isEmpty
            {
                LabeledContent("Characters")
                {
                    Text(charset)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
