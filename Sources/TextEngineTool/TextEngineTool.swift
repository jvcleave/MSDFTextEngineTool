import Foundation
import TextEngineToolCore

@main
struct TextEngineTool
{
    static func main()
    {
        let arguments = Array(CommandLine.arguments.dropFirst())

        do
        {
            let parsedArguments = try ToolArguments(arguments: arguments)
            try TextEngineToolRunner().run(arguments: parsedArguments)
        }
        catch let toolError as ToolError
        {
            FileHandle.standardError.write(Data((toolError.message + "\n").utf8))
            exit(toolError.exitCode)
        }
        catch
        {
            FileHandle.standardError.write(Data(("Unhandled error: \(error)\n").utf8))
            exit(1)
        }
    }
}
