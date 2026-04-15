import Foundation

private final class LineBuffer: @unchecked Sendable
{
    var buffer = ""

    func consume(_ chunk: String, emit: (String) -> Void)
    {
        buffer += chunk
        while let range = buffer.range(of: "\n")
        {
            emit(String(buffer[..<range.lowerBound]))
            buffer = String(buffer[range.upperBound...])
        }
    }

    func flush(emit: (String) -> Void)
    {
        guard !buffer.isEmpty else { return }
        emit(buffer)
        buffer = ""
    }
}

public enum ProcessRunner
{
    @discardableResult
    static func run(
        command: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) throws -> String
    {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputText = String(decoding: outputData, as: UTF8.self)
        let errorText = String(decoding: errorData, as: UTF8.self)
        let combinedOutput = [outputText, errorText]
            .filter { !$0.isEmpty }
            .joined(separator: outputText.isEmpty || errorText.isEmpty ? "" : "\n")

        if process.terminationStatus != 0
        {
            throw ToolError(
                """
                Command failed: \(command) \(arguments.joined(separator: " "))
                \(combinedOutput)
                """.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: process.terminationStatus
            )
        }

        return combinedOutput
    }

    public static func runStreaming(
        command: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws
    {
        try await withCheckedThrowingContinuation
        { (continuation: CheckedContinuation<Void, Error>) in
            do
            {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [command] + arguments
                process.currentDirectoryURL = currentDirectoryURL
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                let stdoutBuffer = LineBuffer()
                let stderrBuffer = LineBuffer()

                outputPipe.fileHandleForReading.readabilityHandler =
                { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    stdoutBuffer.consume(String(decoding: data, as: UTF8.self), emit: onLine)
                }

                errorPipe.fileHandleForReading.readabilityHandler =
                { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    stderrBuffer.consume(String(decoding: data, as: UTF8.self), emit: onLine)
                }

                process.terminationHandler =
                { process in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    stdoutBuffer.flush(emit: onLine)
                    stderrBuffer.flush(emit: onLine)

                    if process.terminationStatus != 0
                    {
                        continuation.resume(throwing: ToolError(
                            "Command failed: \(command) \(arguments.joined(separator: " "))",
                            exitCode: process.terminationStatus
                        ))
                    }
                    else
                    {
                        continuation.resume()
                    }
                }

                try process.run()
            }
            catch
            {
                continuation.resume(throwing: error)
            }
        }
    }
}
