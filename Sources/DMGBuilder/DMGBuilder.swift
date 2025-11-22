import Foundation
import Subprocess

/// Main DMG builder that orchestrates the creation process
public struct DMGBuilder {
    private let fileManager: FileManager
    private let shellExecutor: ShellExecuting

    public init(
        fileManager: FileManager = .default,
        shellExecutor: ShellExecuting = ShellExecutor()
    ) {
        self.fileManager = fileManager
        self.shellExecutor = shellExecutor
    }

    /// Validates the configuration before building
    public func validate(configuration: DMGConfiguration) throws {
        guard fileManager.fileExists(atPath: configuration.appPath) else {
            throw DMGBuilderError.appNotFound(path: configuration.appPath)
        }

        guard fileManager.fileExists(atPath: configuration.backgroundPath) else {
            throw DMGBuilderError.backgroundNotFound(path: configuration.backgroundPath)
        }
    }

    /// Builds the DMG with the given configuration
    public func build(configuration: DMGConfiguration) async throws {
        try validate(configuration: configuration)
        try cleanupExistingFiles(configuration: configuration)
        try await createTemporaryDMG(configuration: configuration)
        try await mountDMG(configuration: configuration)
        try await populateDMG(configuration: configuration)
        try await customizeDMG(configuration: configuration)
        try await unmountDMG(configuration: configuration)
        try await convertToFinalDMG(configuration: configuration)
        try setDMGIcon(configuration: configuration)
        try await signDMG(configuration: configuration)
        try cleanupTemporaryFiles(configuration: configuration)
    }

    // MARK: - Private Methods

    private func cleanupExistingFiles(configuration: DMGConfiguration) throws {
        try? fileManager.removeItem(atPath: configuration.outputPath)
        try? fileManager.removeItem(atPath: configuration.tempDMGPath)
    }

    private func createTemporaryDMG(configuration: DMGConfiguration) async throws {
        try await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "create",
                "-size", configuration.volumeSize,
                "-fs", "APFS",
                "-volname", configuration.appName,
                configuration.tempDMGPath,
            ])
    }

    private func mountDMG(configuration: DMGConfiguration) async throws {
        try await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "attach",
                configuration.tempDMGPath,
            ])

        // Wait for mount to complete
        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard fileManager.fileExists(atPath: configuration.volumeMountPath) else {
            throw DMGBuilderError.volumeNotMounted(path: configuration.volumeMountPath)
        }
    }

    private func populateDMG(configuration: DMGConfiguration) async throws {
        let appFileName = URL(fileURLWithPath: configuration.appPath).lastPathComponent
        let appDestination = "\(configuration.volumeMountPath)/\(appFileName)"

        // Copy app
        try await shellExecutor.execute(
            "cp",
            arguments: [
                "-R",
                configuration.appPath,
                appDestination,
            ])

        // Create Applications symlink
        try await shellExecutor.execute(
            "ln",
            arguments: [
                "-s",
                "/Applications",
                "\(configuration.volumeMountPath)/Applications",
            ])

        // Setup background
        let backgroundDir = "\(configuration.volumeMountPath)/.background"
        try fileManager.createDirectory(
            atPath: backgroundDir,
            withIntermediateDirectories: true
        )

        let backgroundFileName = URL(fileURLWithPath: configuration.backgroundPath)
            .lastPathComponent
        let backgroundDestination = "\(backgroundDir)/\(backgroundFileName)"
        try fileManager.copyItem(
            atPath: configuration.backgroundPath,
            toPath: backgroundDestination
        )
    }

    private func customizeDMG(configuration: DMGConfiguration) async throws {
        let appFileName = URL(fileURLWithPath: configuration.appPath).lastPathComponent
        let backgroundFileName = URL(fileURLWithPath: configuration.backgroundPath)
            .lastPathComponent

        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: configuration.appName,
            appFileName: appFileName,
            backgroundFileName: backgroundFileName,
            iconSize: configuration.iconSize,
            windowBounds: configuration.windowBounds,
            appPosition: configuration.appPosition,
            applicationsPosition: configuration.applicationsPosition
        )

        try await shellExecutor.executeAppleScript(script)

        // Wait for Finder to apply changes
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }

    private func unmountDMG(configuration: DMGConfiguration) async throws {
        try await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "detach",
                configuration.volumeMountPath,
            ])
    }

    private func convertToFinalDMG(configuration: DMGConfiguration) async throws {
        try await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "convert",
                configuration.tempDMGPath,
                "-format", "UDZO",
                "-o", configuration.outputPath,
            ])
    }

    private func setDMGIcon(configuration: DMGConfiguration) throws {
        try DMGIcon.setIcon(
            dmgPath: configuration.outputPath,
            appPath: configuration.appPath,
            fileManager: fileManager
        )
    }

    private func signDMG(configuration: DMGConfiguration) async throws {
        guard let identity = configuration.signingIdentity else {
            // No signing requested
            return
        }

        // Sign the DMG using codesign
        try await shellExecutor.execute(
            "codesign",
            arguments: [
                "--sign", identity,
                "--force",
                "--verbose",
                configuration.outputPath,
            ]
        )

        // Verify the signature
        try await verifySignature(configuration: configuration)
    }

    private func verifySignature(configuration: DMGConfiguration) async throws {
        // Use codesign --display --verbose to check the signature
        let result = try await Subprocess.run(
            .name("codesign"),
            arguments: Arguments([
                "--display",
                "--verbose=4",
                configuration.outputPath,
            ]),
            output: .data(limit: 1024 * 1024),
            error: .data(limit: 1024 * 1024)
        )

        guard result.terminationStatus.isSuccess else {
            throw DMGBuilderError.commandFailed(
                command: "codesign --display",
                output: "Failed to verify signature"
            )
        }

        // Check that Authority is present in the output (codesign writes to stderr)
        let output = String(decoding: result.standardError, as: UTF8.self)

        if !output.contains("Authority=") {
            throw DMGBuilderError.commandFailed(
                command: "codesign --display",
                output: "No Authority flag found in signature. Output:\n\(output)"
            )
        }
    }

    private func cleanupTemporaryFiles(configuration: DMGConfiguration) throws {
        try fileManager.removeItem(atPath: configuration.tempDMGPath)
    }
}
