import ArgumentParser
import Foundation
import DMGBuilder

extension DMGs {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a DMG installer (default command)"
        )

        @Argument(help: "Path to the .app bundle", transform: { URL(fileURLWithPath: $0).path })
        var appPath: String

        @Argument(
            help: "Path to the background image for the DMG",
            transform: { URL(fileURLWithPath: $0).path })
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

        mutating func run() async throws {
            do {
                let configuration = try await DMGConfiguration(
                    appPath: appPath,
                    backgroundPath: backgroundPath,
                    outputDirectory: output ?? FileManager.default.currentDirectoryPath,
                    iconSize: iconSize,
                    signingIdentity: sign
                )

                let builder = DMGBuilder()

                if verbose {
                    print("Configuration:")
                    print("  App Name: \(configuration.appName)")
                    print("  App Path: \(appPath)")
                    print("  Background: \(backgroundPath)")
                    print("  Output: \(configuration.outputPath)")
                    print("  Icon Size: \(iconSize)")
                    print("  Window Bounds: \(configuration.windowBounds)")
                    print("  App Position: \(configuration.appPosition)")
                    print("  Applications Position: \(configuration.applicationsPosition)")
                    if let identity = sign {
                        print("  Signing Identity: \(identity)")
                    }
                    print()
                }

                print("Creating DMG for \(configuration.appName)...")

                if verbose { print("Validating configuration...") }
                try builder.validate(configuration: configuration)

                if verbose { print("Building DMG...") }
                try await builder.build(configuration: configuration)

                print("✓ Successfully created \(configuration.outputPath)")
            } catch {
                throw ValidationError(error.localizedDescription)
            }
        }
    }
}
