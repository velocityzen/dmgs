import ArgumentParser
import DMGBuilder
import Foundation

extension DMGs {
    struct Identities: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available code signing identities"
        )

        mutating func run() async throws {
            try await listIdentities().commandValue()
        }

        private func listIdentities() async -> Result<Void, DMGsCommandError> {
            await SigningIdentity.list()
                .mapError(DMGsCommandError.builder)
                .tap { output in
                    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || output.contains("0 valid identities found")
                    {
                        print("No code signing identities found in keychain.")
                        print()
                        print("To sign DMGs, you need a valid code signing certificate.")
                        print("Visit https://developer.apple.com/account for more information.")
                        return
                    }

                    print("Available code signing identities:")
                    print()
                    print(output)
                }
                .map { _ in () }
        }
    }
}
