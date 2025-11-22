import Foundation

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
    public func build(configuration: DMGConfiguration) throws {
        try validate(configuration: configuration)
        try cleanupExistingFiles(configuration: configuration)
        try createTemporaryDMG(configuration: configuration)
        try mountDMG(configuration: configuration)
        try populateDMG(configuration: configuration)
        try customizeDMG(configuration: configuration)
        try unmountDMG(configuration: configuration)
        try convertToFinalDMG(configuration: configuration)
        try setDMGIcon(configuration: configuration)
        try cleanupTemporaryFiles(configuration: configuration)
    }

    // MARK: - Private Methods

    private func cleanupExistingFiles(configuration: DMGConfiguration) throws {
        try? fileManager.removeItem(atPath: configuration.outputPath)
        try? fileManager.removeItem(atPath: configuration.tempDMGPath)
    }

    private func createTemporaryDMG(configuration: DMGConfiguration) throws {
        try shellExecutor.execute(
            "hdiutil",
            arguments: [
                "create",
                "-size", configuration.volumeSize,
                "-fs", "APFS",
                "-volname", configuration.appName,
                configuration.tempDMGPath,
            ])
    }

    private func mountDMG(configuration: DMGConfiguration) throws {
        try shellExecutor.execute(
            "hdiutil",
            arguments: [
                "attach",
                configuration.tempDMGPath,
            ])

        // Wait for mount to complete
        Thread.sleep(forTimeInterval: 1)

        guard fileManager.fileExists(atPath: configuration.volumeMountPath) else {
            throw DMGBuilderError.volumeNotMounted(path: configuration.volumeMountPath)
        }
    }

    private func populateDMG(configuration: DMGConfiguration) throws {
        let appFileName = URL(fileURLWithPath: configuration.appPath).lastPathComponent
        let appDestination = "\(configuration.volumeMountPath)/\(appFileName)"

        // Copy app
        try shellExecutor.execute(
            "cp",
            arguments: [
                "-R",
                configuration.appPath,
                appDestination,
            ])

        // Create Applications symlink
        try shellExecutor.execute(
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

    private func customizeDMG(configuration: DMGConfiguration) throws {
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

        try shellExecutor.executeAppleScript(script)

        // Wait for Finder to apply changes
        Thread.sleep(forTimeInterval: 2)
    }

    private func unmountDMG(configuration: DMGConfiguration) throws {
        try shellExecutor.execute(
            "hdiutil",
            arguments: [
                "detach",
                configuration.volumeMountPath,
            ])
    }

    private func convertToFinalDMG(configuration: DMGConfiguration) throws {
        try shellExecutor.execute(
            "hdiutil",
            arguments: [
                "convert",
                configuration.tempDMGPath,
                "-format", "UDZO",
                "-o", configuration.outputPath,
            ])
    }

    private func setDMGIcon(configuration: DMGConfiguration) throws {
        try DMGIconSetter.setIcon(
            dmgPath: configuration.outputPath,
            appPath: configuration.appPath,
            fileManager: fileManager
        )
    }

    private func cleanupTemporaryFiles(configuration: DMGConfiguration) throws {
        try fileManager.removeItem(atPath: configuration.tempDMGPath)
    }
}
