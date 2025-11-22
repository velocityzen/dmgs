import ArgumentParser
import Foundation
import DMGBuilder

extension DMGs {
    struct Identities: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available code signing identities"
        )

        mutating func run() async throws {
            do {
                let output = try await SigningIdentity.list()

                if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || output.contains("0 valid identities found")
                {
                    print("No code signing identities found in keychain.")
                    print()
                    print("To sign DMGs, you need a valid code signing certificate.")
                    print(
                        "Visit https://developer.apple.com/account for more information.")
                } else {
                    print("Available code signing identities:")
                    print()
                    print(output)
                }
            } catch {
                throw ValidationError(error.localizedDescription)
            }
        }
    }
}
