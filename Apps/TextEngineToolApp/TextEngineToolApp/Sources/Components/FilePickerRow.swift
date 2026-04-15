import SwiftUI

struct FilePickerRow: View
{
    let label: String
    @Binding var path: String
    let prompt: String
    var allowedTypes: [String] = []

    var body: some View
    {
        LabeledContent(label)
        {
            HStack
            {
                TextField(prompt, text: $path)
                Button("Browse…")
                {
                    pickFile()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func pickFile()
    {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if !allowedTypes.isEmpty
        {
            panel.allowedFileTypes = allowedTypes
        }

        if !path.isEmpty
        {
            let existing = URL(fileURLWithPath: path)
            panel.directoryURL = existing.deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let url = panel.url
        {
            path = url.path
        }
    }
}
