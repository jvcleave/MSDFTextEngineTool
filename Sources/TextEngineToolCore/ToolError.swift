import Foundation

public struct ToolError: Error, LocalizedError, CustomStringConvertible
{
    public let message: String
    public let exitCode: Int32

    public init(_ message: String, exitCode: Int32 = 1)
    {
        self.message = message
        self.exitCode = exitCode
    }

    public var errorDescription: String?
    {
        message
    }

    public var failureReason: String?
    {
        message
    }

    public var description: String
    {
        message
    }
}
