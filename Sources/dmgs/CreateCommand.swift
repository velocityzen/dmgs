import ArgumentParser
import Foundation
import DMGBuilder

extension DMGs {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a DMG installer (default command)"
        )

        @Argument(help: "Path to the .app bundle", transform: { URL(filePath: $0).path() })
        var appPath: String

        @Argument(
            help: "Path to the background image for the DMG",
            transform: { URL(filePath: $0).path() })
        var backgroundPath: String

        @Option(
            name: .shortAndLong,
            help: "Output directory for the DMG (defaults to current directory)")
        var output: String?

        @Option(help: "Icon size in the DMG window (default: 100)")
        var iconSize: Int = 100

        @Option(
            name: .long,
            help: "Code signing identity to sign the DMG (e.g., \"Developer ID Application\")")
        var sign: String?

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        func validate() throws {
            guard iconSize > 0 else {
                throw ValidationError("Icon size must be positive")
            }
        }

        mutating func run() async throws {
            let configuration = try await DMGConfiguration(
                appPath: appPath,
                backgroundPath: backgroundPath,
                outputDirectory: output ?? FileManager.default.currentDirectoryPath,
                iconSize: iconSize,
                signingIdentity: sign
            )

            let builder = DMGBuilder()

            if verbose {
                let stderr = FileHandle.standardError
                stderr.write(Data("Configuration:\n".utf8))
                stderr.write(Data("  App Name: \(configuration.appName)\n".utf8))
                stderr.write(Data("  App Path: \(appPath)\n".utf8))
                stderr.write(Data("  Background: \(backgroundPath)\n".utf8))
                stderr.write(Data("  Output: \(configuration.outputPath)\n".utf8))
                stderr.write(Data("  Icon Size: \(iconSize)\n".utf8))
                stderr.write(Data("  Window Bounds: \(configuration.windowBounds)\n".utf8))
                stderr.write(Data("  App Position: \(configuration.appPosition)\n".utf8))
                stderr.write(Data("  Applications Position: \(configuration.applicationsPosition)\n".utf8))
                if let identity = sign {
                    stderr.write(Data("  Signing Identity: \(identity)\n".utf8))
                }
                stderr.write(Data("\n".utf8))
            }

            FileHandle.standardError.write(Data("Creating DMG for \(configuration.appName)...\n".utf8))

            if verbose {
                FileHandle.standardError.write(Data("Validating configuration...\n".utf8))
            }
            try builder.validate(configuration: configuration)

            if verbose {
                FileHandle.standardError.write(Data("Building DMG...\n".utf8))
            }
            try await builder.build(configuration: configuration)

            FileHandle.standardError.write(Data("✓ Successfully created \(configuration.outputPath)\n".utf8))
        }
    }
}
