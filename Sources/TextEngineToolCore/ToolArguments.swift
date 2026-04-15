import Foundation

public struct ToolArguments: Equatable
{
    public enum Command: String, Equatable
    {
        case buildVendor = "build-vendor"
        case generateAtlas = "generate-atlas"
        case initConfig = "init-config"
        case printCharset = "print-charset"
        case plan
    }

    public let command: Command
    public let charsetPath: String?
    public let configPath: String?
    public let outputPath: String?

    public init(arguments: [String]) throws
    {
        if arguments.isEmpty
        {
            command = .plan
            charsetPath = nil
            configPath = nil
            outputPath = nil
            return
        }

        guard let parsedCommand = Command(rawValue: arguments[0])
        else
        {
            throw ToolError(
                """
                Unknown command '\(arguments[0])'.

                Available commands:
                  plan
                  build-vendor
                  generate-atlas --config <path>
                  init-config --output <path>
                  print-charset --charset <path>
                """
            )
        }

        command = parsedCommand

        var resolvedCharsetPath: String?
        var resolvedConfigPath: String?
        var resolvedOutputPath: String?
        var index = 1

        while index < arguments.count
        {
            let argument = arguments[index]

            switch argument
            {
            case "--config":
                index += 1
                guard index < arguments.count
                else
                {
                    throw ToolError("Missing value for --config")
                }
                resolvedConfigPath = arguments[index]

            case "--charset":
                index += 1
                guard index < arguments.count
                else
                {
                    throw ToolError("Missing value for --charset")
                }
                resolvedCharsetPath = arguments[index]

            case "--output":
                index += 1
                guard index < arguments.count
                else
                {
                    throw ToolError("Missing value for --output")
                }
                resolvedOutputPath = arguments[index]

            default:
                throw ToolError("Unknown argument '\(argument)'")
            }

            index += 1
        }

        charsetPath = resolvedCharsetPath
        configPath = resolvedConfigPath
        outputPath = resolvedOutputPath

        if command == .printCharset && charsetPath == nil
        {
            throw ToolError("print-charset requires --charset <path>")
        }

        if command == .initConfig && outputPath == nil
        {
            throw ToolError("init-config requires --output <path>")
        }

        if command == .generateAtlas && configPath == nil
        {
            throw ToolError("generate-atlas requires --config <path>")
        }
    }
}
