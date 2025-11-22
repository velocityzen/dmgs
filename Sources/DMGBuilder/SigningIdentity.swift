import Foundation
import Subprocess

/// Utilities for working with code signing identities
public enum SigningIdentity {

    /// Retrieves all available code signing identities from the keychain
    /// - Returns: The output from security find-identity command
    /// - Throws: DMGBuilderError if the command fails
    public static func list() async throws -> String {
        let result = try await Subprocess.run(
            .name("security"),
            arguments: Arguments([
                "find-identity",
                "-v",
                "-p", "codesigning",
            ]),
            output: .data(limit: 1024 * 1024),
            error: .data(limit: 1024 * 1024)
        )

        guard result.terminationStatus.isSuccess else {
            throw DMGBuilderError.commandFailed(
                command: "security find-identity",
                output: "Failed to query available signing identities"
            )
        }

        return String(decoding: result.standardOutput, as: UTF8.self)
    }

    /// Validates that a signing identity exists in the keychain
    /// - Parameter identity: The signing identity to validate
    /// - Throws: DMGBuilderError if the identity is not found
    public static func validate(_ identity: String) async throws {
        let output = try await list()

        // Check if the identity exists in the output
        if !output.contains(identity) {
            throw DMGBuilderError.commandFailed(
                command: "security find-identity",
                output:
                    "Signing identity '\(identity)' not found in keychain. Available identities:\n\(output)"
            )
        }
    }
}
