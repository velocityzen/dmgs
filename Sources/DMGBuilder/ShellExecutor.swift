import Foundation
import Subprocess

/// Protocol for executing shell commands (makes testing easier)
public protocol ShellExecuting {
    func execute(_ command: String, arguments: [String]) async throws
    func executeAppleScript(_ script: String) async throws
}

/// Default implementation using swift-subprocess
public struct ShellExecutor: ShellExecuting {
    public init() {}

    public func execute(_ command: String, arguments: [String]) async throws {
        let result = try await Subprocess.run(
            .name(command),
            arguments: Arguments(arguments),
            output: .data(limit: 1024 * 1024),
            error: .data(limit: 1024 * 1024)
        )

        guard result.terminationStatus.isSuccess else {
            let output = String(
                decoding: result.standardOutput + result.standardError, as: UTF8.self)
            throw DMGBuilderError.commandFailed(
                command: "\(command) \(arguments.joined(separator: " "))",
                output: output
            )
        }
    }

    public func executeAppleScript(_ script: String) async throws {
        let result = try await Subprocess.run(
            .name("osascript"),
            arguments: Arguments(["-e", script]),
            output: .data(limit: 1024 * 1024),
            error: .data(limit: 1024 * 1024)
        )

        guard result.terminationStatus.isSuccess else {
            let output = String(
                decoding: result.standardOutput + result.standardError, as: UTF8.self)
            throw DMGBuilderError.appleScriptFailed(output: output)
        }
    }
}
