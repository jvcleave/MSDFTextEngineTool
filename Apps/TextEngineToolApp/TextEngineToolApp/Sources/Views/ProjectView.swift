import SwiftUI

struct CharsetPickerView: View
{
    @Environment(AppState.self) private var appState

    var body: some View
    {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 0)
        {
            Form
            {
                Section("Character Sets")
                {
                    Toggle("A–Z  (upper + lower)", isOn: $state.includeUpperLower)
                    Toggle("0–9  (digits)", isOn: $state.includeDigits)
                    Toggle("Space", isOn: $state.includeSpace)
                    Toggle("Punctuation   . , ! ? : ; - ' \" ( )", isOn: $state.includePunctuation)
                    Toggle("Symbols   @ # $ % & * + = / \\ < >", isOn: $state.includeSymbols)
                }

                Section("Additional Characters")
                {
                    TextField("Type any extra characters…", text: $state.additionalCharacters)
                        .font(.system(.body, design: .monospaced))
                }

                Section
                {
                    LabeledContent("Character count")
                    {
                        Text("\(appState.resolvedCharset.count)")
                            .foregroundStyle(appState.resolvedCharset.isEmpty ? .red : .primary)
                            .fontWeight(.semibold)
                    }

                    if !appState.resolvedCharset.isEmpty
                    {
                        LabeledContent("Preview")
                        {
                            Text(appState.resolvedCharset)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
