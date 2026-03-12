import Foundation
import Subprocess

/// Protocol for executing shell commands (makes testing easier)
public protocol ShellExecuting: Sendable {
    func execute(_ command: String, arguments: [String]) async throws
    func executeWithOutput(_ command: String, arguments: [String]) async throws -> String
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

    public func executeWithOutput(_ command: String, arguments: [String]) async throws -> String {
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

        // Combine stdout and stderr (codesign writes to stderr)
        return String(
            decoding: result.standardOutput + result.standardError, as: UTF8.self)
    }
}
