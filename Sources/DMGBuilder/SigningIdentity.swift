import Foundation

/// Utilities for working with code signing identities
public enum SigningIdentity {

    /// Retrieves all available code signing identities from the keychain
    /// - Returns: The output from security find-identity command
    public static func list(
        shellExecutor: any ShellExecuting = ShellExecutor()
    ) async -> DMGBuilderResult<String> {
        await shellExecutor.executeWithOutput(
            "security",
            arguments: [
                "find-identity",
                "-v",
                "-p", "codesigning",
            ]
        )
    }

    /// Validates that a signing identity exists in the keychain
    /// - Parameter identity: The signing identity to validate
    public static func validate(
        _ identity: String,
        shellExecutor: any ShellExecuting = ShellExecutor()
    ) async -> DMGBuilderResult<Void> {
        await list(shellExecutor: shellExecutor)
            .flatMap { output in
                guard output.contains(identity) else {
                    return .failure(
                        .signingIdentityNotFound(
                            identity: identity,
                            availableIdentities: output
                        )
                    )
                }

                return .success(())
            }
    }
}
