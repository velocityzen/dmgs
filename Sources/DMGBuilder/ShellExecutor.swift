import FP
import Foundation
import Subprocess

/// Protocol for executing shell commands (makes testing easier)
public protocol ShellExecuting: Sendable {
    func execute(_ command: String, arguments: [String]) async -> DMGBuilderResult<Void>
    func executeWithOutput(_ command: String, arguments: [String]) async -> DMGBuilderResult<String>
}

/// Default implementation using swift-subprocess
public struct ShellExecutor: ShellExecuting {
    public init() {}

    public func execute(_ command: String, arguments: [String]) async -> DMGBuilderResult<Void> {
        let commandDescription = Self.commandDescription(command: command, arguments: arguments)
        let result = await Result.fromAsync {
            try await Subprocess.run(
                .name(command),
                arguments: Arguments(arguments),
                output: .data(limit: 1024 * 1024),
                error: .data(limit: 1024 * 1024)
            )
        }
        .mapError {
            DMGBuilderError.commandFailed(
                command: commandDescription,
                output: $0.localizedDescription
            )
        }

        return result.flatMap { executionResult in
            guard executionResult.terminationStatus.isSuccess else {
                return .failure(
                    .commandFailed(
                        command: commandDescription,
                        output: Self.combinedOutput(from: executionResult)
                    )
                )
            }

            return .success(())
        }
    }

    public func executeWithOutput(
        _ command: String,
        arguments: [String]
    ) async -> DMGBuilderResult<String> {
        let commandDescription = Self.commandDescription(command: command, arguments: arguments)
        let result = await Result.fromAsync {
            try await Subprocess.run(
                .name(command),
                arguments: Arguments(arguments),
                output: .data(limit: 1024 * 1024),
                error: .data(limit: 1024 * 1024)
            )
        }
        .mapError {
            DMGBuilderError.commandFailed(
                command: commandDescription,
                output: $0.localizedDescription
            )
        }

        return result.flatMap { executionResult in
            let output = Self.combinedOutput(from: executionResult)

            guard executionResult.terminationStatus.isSuccess else {
                return .failure(
                    .commandFailed(
                        command: commandDescription,
                        output: output
                    )
                )
            }

            return .success(output)
        }
    }

    private static func commandDescription(command: String, arguments: [String]) -> String {
        ([command] + arguments).joined(separator: " ")
    }

    private static func combinedOutput<Output: OutputProtocol, ErrorOutput: OutputProtocol>(
        from result: CollectedResult<Output, ErrorOutput>
    ) -> String where Output.OutputType == Data, ErrorOutput.OutputType == Data {
        String(decoding: result.standardOutput + result.standardError, as: UTF8.self)
    }
}
