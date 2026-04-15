import SwiftUI
import AppKit

struct ContentView: View
{
    @State private var atlasBundle: MSDFAtlasBundle?
    @State private var statusText: String = "Select an exported atlas folder."
    @State private var fontSize: Double = 92
    @State private var opacity: Double = 1.0
    @State private var foregroundColor: Color = .white
    @State private var backgroundColor: Color = Color(red: 0.1, green: 0.1, blue: 0.12)

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Button("LOAD EXPORT")
            {
                loadExport()
            }
            .buttonStyle(.borderedProminent)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            VStack(alignment: .leading, spacing: 8)
            {
                HStack
                {
                    Text("Font Size")
                    Slider(value: $fontSize, in: 16 ... 180, step: 1)
                    Text("\(Int(fontSize))")
                        .frame(width: 44, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack
                {
                    Text("Opacity")
                    Slider(value: $opacity, in: 0 ... 1, step: 0.01)
                    Text(String(format: "%.2f", opacity))
                        .frame(width: 44, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack
                {
                    ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: true)
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: true)
                }
            }

            if let atlasBundle
            {
                MSDFTextPreviewView(
                    atlasBundle: atlasBundle,
                    text: "HELLO MSDF",
                    fontSize: fontSize,
                    opacity: opacity,
                    foregroundColor: foregroundColor,
                    backgroundColor: backgroundColor
                )
                .frame(minHeight: 420)
            }
            else
            {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        Text("Load an exported folder to preview.")
                            .foregroundStyle(.secondary)
                    )
                    .frame(minHeight: 420)
            }
        }
        .padding()
    }

    private func loadExport()
    {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load Export"
        panel.message = "Choose a folder containing atlas runtime JSON and atlas image."

        if panel.runModal() == .OK, let folderURL = panel.url
        {
            do
            {
                let loadedBundle = try MSDFAtlasBundleLoader.shared.loadBundle(folderURL: folderURL)
                atlasBundle = loadedBundle
                statusText = "Loaded: \(folderURL.path)"
            }
            catch
            {
                atlasBundle = nil
                statusText = "Load failed: \(String(describing: error))"
            }
        }
    }
}

#Preview
{
    ContentView()
}
