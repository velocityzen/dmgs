import ArgumentParser
import Foundation
import DMGBuilder

@main
struct DMGs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dmgs",
        abstract: "Create a DMG installer for macOS applications",
        discussion: """
            Creates a professional DMG installer with a custom background image,
            proper icon positioning, and an Applications folder symlink.
            """
    )

    @Argument(help: "Name for the DMG file (without .dmg extension)")
    var appName: String

    @Argument(help: "Path to the .app bundle", transform: { URL(fileURLWithPath: $0).path })
    var appPath: String

    @Argument(
        help: "Path to the background image for the DMG",
        transform: { URL(fileURLWithPath: $0).path })
    var backgroundPath: String

    @Option(
        name: .shortAndLong, help: "Output directory for the DMG (defaults to current directory)")
    var output: String?

    @Option(name: .shortAndLong, help: "DMG volume size (default: 200m)")
    var size: String = "200m"

    @Option(help: "Icon size in the DMG window (default: 100)")
    var iconSize: Int = 100

    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    mutating func run() throws {
        do {
            let configuration = try DMGConfiguration(
                appName: appName,
                appPath: appPath,
                backgroundPath: backgroundPath,
                outputDirectory: output ?? FileManager.default.currentDirectoryPath,
                volumeSize: size,
                iconSize: iconSize
            )

            let builder = DMGBuilder()

            if verbose {
                print("Configuration:")
                print("  App Name: \(appName)")
                print("  App Path: \(appPath)")
                print("  Background: \(backgroundPath)")
                print("  Output: \(configuration.outputPath)")
                print("  Volume Size: \(size)")
                print("  Icon Size: \(iconSize)")
                print("  Window Bounds: \(configuration.windowBounds)")
                print("  App Position: \(configuration.appPosition)")
                print("  Applications Position: \(configuration.applicationsPosition)")
                print()
            }

            print("Creating DMG for \(appName)...")

            if verbose { print("Validating configuration...") }
            try builder.validate(configuration: configuration)

            if verbose { print("Building DMG...") }
            try builder.build(configuration: configuration)

            print("✓ Successfully created \(configuration.outputPath)")
        } catch {
            throw ValidationError(error.localizedDescription)
        }
    }
}
