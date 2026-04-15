import Foundation
import SwiftUI

struct ExportView: View
{
    @Environment(AppState.self) private var appState

    var body: some View
    {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 0)
        {
            Form
            {
                Section("Project")
                {
                    LabeledContent("Font")
                    {
                        Text(appState.selectedFontLabel)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Characters")
                    {
                        Text("\(appState.resolvedCharset.count) characters")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Project name")
                    {
                        TextField("", text: $state.projectName)
                    }
                }

                Section("Output")
                {
                    if let outputURL = appState.defaultOutputDirectoryURL
                    {
                        LabeledContent("Folder")
                        {
                            HStack(spacing: 8)
                            {
                                Text(outputURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Button("Choose Folder…")
                                {
                                    pickOutputAndExport()
                                }
                                .buttonStyle(.borderless)
                                .disabled(!appState.canExport)
                            }
                        }
                    }

                    if let outputDirectoryURL = appState.lastExportOutputDirectoryURL
                    {
                        Button("Reveal in Finder")
                        {
                            NSWorkspace.shared.open(outputDirectoryURL)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Advanced")
                {
                    Button(appState.showAdvancedOptions ? "Hide Advanced Options" : "Show Advanced Options")
                    {
                        state.showAdvancedOptions.toggle()
                    }
                    .buttonStyle(.borderless)

                    if appState.showAdvancedOptions
                    {
                        LabeledContent("Atlas width")
                        {
                            HStack
                            {
                                Stepper("", value: $state.atlasWidth, in: 128 ... 8192, step: 64)
                                    .labelsHidden()
                                Text("\(appState.atlasWidth)")
                                    .monospacedDigit()
                                    .frame(width: 64, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Atlas height")
                        {
                            HStack
                            {
                                Stepper("", value: $state.atlasHeight, in: 128 ... 8192, step: 64)
                                    .labelsHidden()
                                Text("\(appState.atlasHeight)")
                                    .monospacedDigit()
                                    .frame(width: 64, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Em size")
                        {
                            HStack
                            {
                                Slider(value: $state.emSize, in: 8 ... 256, step: 1)
                                Text("\(Int(appState.emSize))")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Pixel range")
                        {
                            HStack
                            {
                                Slider(value: $state.pixelRange, in: 1 ... 16, step: 0.5)
                                Text(String(format: "%.1f", appState.pixelRange))
                                    .monospacedDigit()
                                    .frame(width: 52, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Padding")
                        {
                            HStack
                            {
                                Stepper("", value: $state.padding, in: 0 ... 64, step: 1)
                                    .labelsHidden()
                                Text("\(appState.padding)")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Y origin")
                        {
                            Picker("", selection: $state.yOrigin)
                            {
                                Text("Top").tag("top")
                                Text("Bottom").tag("bottom")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            LogScrollView(lines: appState.logLines)

            Divider()

            HStack(spacing: 12)
            {
                if !appState.vendorIsBuilt
                {
                    Label(
                        appState.toolRootDetected
                            ? "Run `swift run TextEngineTool build-vendor` first"
                            : "TextEngineTool package root not found",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Spacer()

                Button(appState.isWorking ? "Exporting…" : "Export")
                {
                    appState.startExportToDefaultDirectory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.canExport || appState.defaultOutputDirectoryURL == nil)
            }
            .padding()
        }
    }

    private func pickOutputAndExport()
    {
        guard appState.canExport else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Here"
        panel.message = "Choose a base folder. A subfolder named after your project will be created inside it."
        panel.directoryURL = appState.defaultOutputDirectoryURL?.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url
        {
            appState.startExportToBaseDirectory(url)
        }
    }
}
