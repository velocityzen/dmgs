import Foundation

/// Protocol for executing shell commands (makes testing easier)
public protocol ShellExecuting {
    func execute(_ command: String, arguments: [String]) throws
    func executeAppleScript(_ script: String) throws
}

/// Default implementation using Process
public struct ShellExecutor: ShellExecuting {
    public init() {}

    public func execute(_ command: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw DMGBuilderError.commandFailed(
                command: "\(command) \(arguments.joined(separator: " "))",
                output: output
            )
        }
    }

    public func executeAppleScript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw DMGBuilderError.appleScriptFailed(output: output)
        }
    }
}
