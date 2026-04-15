import SwiftUI

struct LogScrollView: View
{
    let lines: [String]

    var body: some View
    {
        ScrollViewReader
        { proxy in
            ScrollView(.vertical)
            {
                LazyVStack(alignment: .leading, spacing: 1)
                {
                    if lines.isEmpty
                    {
                        Text("Log")
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                    else
                    {
                        ForEach(Array(lines.enumerated()), id: \.offset)
                        { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .id(index)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: lines.count)
            { _, count in
                guard count > 0 else { return }
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }
}
