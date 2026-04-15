import Foundation

public enum CharsetLoader
{
    public static func loadCharset(from url: URL) throws -> String
    {
        return try loadCharset(from: url.path)
    }

    public static func loadCharset(from path: String) throws -> String
    {
        let url = URL(fileURLWithPath: path)
        let rawContents = try String(contentsOf: url, encoding: .utf8)

        var output = ""
        for rawLine in rawContents.components(separatedBy: .newlines)
        {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#")
            {
                continue
            }

            if trimmedLine == "<SPACE>"
            {
                output.append(" ")
            }
            else
            {
                output.append(contentsOf: trimmedLine)
            }
        }

        return output
    }
}
