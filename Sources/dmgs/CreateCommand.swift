import ArgumentParser
import DMGBuilder
import FP
import Foundation

extension DMGs {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a DMG installer (default command)"
        )

        @Argument(help: "Path to the .app bundle", transform: { URL(filePath: $0).path() })
        var appPath: String

        @Argument(
            help: "Path to the background image for the DMG",
            transform: { URL(filePath: $0).path() }
        )
        var backgroundPath: String

        @Option(
            name: .shortAndLong,
            help: "Output directory for the DMG (defaults to current directory)"
        )
        var output: String?

        @Option(help: "Icon size in the DMG window (default: 100)")
        var iconSize: Int = 100

        @Option(
            name: .long,
            help: "Code signing identity to sign the DMG (e.g., \"Developer ID Application\")"
        )
        var sign: String?

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        func validate() throws {
            try validateOptions().commandValue()
        }

        mutating func run() async throws {
            try await createDMG().commandValue()
        }

        private func createDMG() async -> Result<Void, DMGsCommandError> {
            let builder = DMGBuilder()
            let validationResult = validateOptions()
            let configurationResult = await validationResult.flatMapAsync { _ in
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: backgroundPath,
                    outputDirectory: output ?? FileManager.default.currentDirectoryPath,
                    iconSize: iconSize,
                    signingIdentity: sign
                )
                .mapError(DMGsCommandError.builder)
            }
            let verboseConfigurationResult =
                configurationResult
                .tap { configuration in
                    writeVerboseConfiguration(configuration)
                }
            let startedResult =
                verboseConfigurationResult
                .tap { configuration in
                    writeStandardError("Creating DMG for \(configuration.appName)...\n")
                }
            let validationMessageResult =
                startedResult
                .tap { _ in
                    guard verbose else {
                        return
                    }
                    writeStandardError("Validating configuration...\n")
                }
            let validatedBuilderResult =
                validationMessageResult
                .tap { configuration in
                    builder.validate(configuration: configuration)
                        .mapError(DMGsCommandError.builder)
                }
            let buildMessageResult =
                validatedBuilderResult
                .tap { _ in
                    guard verbose else {
                        return
                    }
                    writeStandardError("Building DMG...\n")
                }
            let builtResult = await buildMessageResult.tapAsync { configuration in
                await builder.build(configuration: configuration)
                    .mapError(DMGsCommandError.builder)
            }

            return
                builtResult
                .tap { configuration in
                    writeStandardError("✓ Successfully created \(configuration.outputPath)\n")
                }
                .map { _ in () }
        }

        private func validateOptions() -> Result<Void, DMGsCommandError> {
            guard iconSize > 0 else {
                return .failure(.invalidArgument(message: "Icon size must be positive"))
            }

            return .success(())
        }

        private func writeVerboseConfiguration(_ configuration: DMGConfiguration) {
            guard verbose else {
                return
            }

            writeStandardError("Configuration:\n")
            writeStandardError("  App Name: \(configuration.appName)\n")
            writeStandardError("  App Path: \(appPath)\n")
            writeStandardError("  Background: \(backgroundPath)\n")
            writeStandardError("  Output: \(configuration.outputPath)\n")
            writeStandardError("  Icon Size: \(iconSize)\n")
            writeStandardError("  Window Bounds: \(configuration.windowBounds)\n")
            writeStandardError("  App Position: \(configuration.appPosition)\n")
            writeStandardError("  Applications Position: \(configuration.applicationsPosition)\n")

            if let sign {
                writeStandardError("  Signing Identity: \(sign)\n")
            }

            writeStandardError("\n")
        }

        private func writeStandardError(_ message: String) {
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}
