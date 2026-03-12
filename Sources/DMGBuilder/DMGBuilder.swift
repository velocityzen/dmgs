import Foundation
import DSStore
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

        // Ensure volume is unmounted on failure after mounting
        try await mountDMG(configuration: configuration)
        do {
            try await populateDMG(configuration: configuration)
            try await customizeDMG(configuration: configuration)
        } catch {
            try? await unmountDMG(configuration: configuration)
            throw error
        }
        try await unmountDMG(configuration: configuration)

        try await convertToFinalDMG(configuration: configuration)
        try await setDMGIcon(configuration: configuration)
        try await signDMG(configuration: configuration)

        // Cleanup is best-effort — don't fail the build if temp removal fails
        try? fileManager.removeItem(atPath: configuration.tempDMGPath)
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

        // Poll for mount readiness instead of fixed sleep
        for _ in 0..<10 {
            if fileManager.fileExists(atPath: configuration.volumeMountPath) {
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        throw DMGBuilderError.volumeNotMounted(path: configuration.volumeMountPath)
    }

    private func populateDMG(configuration: DMGConfiguration) async throws {
        let appFileName = URL(filePath: configuration.appPath).lastPathComponent
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

        let backgroundFileName = URL(filePath: configuration.backgroundPath)
            .lastPathComponent
        let backgroundDestination = "\(backgroundDir)/\(backgroundFileName)"
        try fileManager.copyItem(
            atPath: configuration.backgroundPath,
            toPath: backgroundDestination
        )
    }

    private func customizeDMG(configuration: DMGConfiguration) async throws {
        let appFileName = URL(filePath: configuration.appPath).lastPathComponent
        let backgroundFileName = URL(filePath: configuration.backgroundPath)
            .lastPathComponent

        try DSStoreConfigurator.configure(
            volumeURL: URL(filePath: configuration.volumeMountPath),
            appFileName: appFileName,
            backgroundFileName: backgroundFileName,
            iconSize: configuration.iconSize,
            windowBounds: configuration.windowBounds,
            appPosition: configuration.appPosition,
            applicationsPosition: configuration.applicationsPosition
        )
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

    private func setDMGIcon(configuration: DMGConfiguration) async throws {
        let dmgPath = configuration.outputPath
        let appPath = configuration.appPath
        try await MainActor.run {
            try DMGIcon.setIcon(dmgPath: dmgPath, appPath: appPath)
        }
    }

    private func signDMG(configuration: DMGConfiguration) async throws {
        guard let identity = configuration.signingIdentity else {
            return
        }

        try await shellExecutor.execute(
            "codesign",
            arguments: [
                "--sign", identity,
                "--force",
                "--verbose",
                configuration.outputPath,
            ]
        )

        try await verifySignature(configuration: configuration)
    }

    private func verifySignature(configuration: DMGConfiguration) async throws {
        let output = try await shellExecutor.executeWithOutput(
            "codesign",
            arguments: [
                "--display",
                "--verbose=4",
                configuration.outputPath,
            ]
        )

        if !output.contains("\nAuthority=") && !output.hasPrefix("Authority=") {
            throw DMGBuilderError.commandFailed(
                command: "codesign --display",
                output: "No Authority flag found in signature. Output:\n\(output)"
            )
        }
    }
}
