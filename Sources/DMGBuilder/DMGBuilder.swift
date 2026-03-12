import FP
import Foundation

/// Main DMG builder that orchestrates the creation process
public struct DMGBuilder {
    private let fileManager: FileManager
    private let shellExecutor: any ShellExecuting

    public init(
        fileManager: FileManager = .default,
        shellExecutor: any ShellExecuting = ShellExecutor()
    ) {
        self.fileManager = fileManager
        self.shellExecutor = shellExecutor
    }

    /// Validates the configuration before building
    public func validate(configuration: DMGConfiguration) -> DMGBuilderResult<Void> {
        guard fileManager.fileExists(atPath: configuration.appPath) else {
            return .failure(.appNotFound(path: configuration.appPath))
        }

        guard fileManager.fileExists(atPath: configuration.backgroundPath) else {
            return .failure(.backgroundNotFound(path: configuration.backgroundPath))
        }

        return .success(())
    }

    /// Builds the DMG with the given configuration
    public func build(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        let initialResult = Result<Void, DMGBuilderError>.success(())
        let validatedResult =
            initialResult
            .tap { validate(configuration: configuration) }
        let cleanupResult =
            validatedResult
            .tap { cleanupExistingFiles(configuration: configuration) }
        let temporaryDMGResult =
            await cleanupResult
            .tapAsync { await createTemporaryDMG(configuration: configuration) }
        let mountedResult =
            await temporaryDMGResult
            .tapAsync { await mountDMG(configuration: configuration) }
        let customizedResult =
            await mountedResult
            .tapAsync { await populateAndCustomizeMountedDMG(configuration: configuration) }
        let convertedResult =
            await customizedResult
            .tapAsync { await convertToFinalDMG(configuration: configuration) }
        let iconResult =
            await convertedResult
            .tapAsync { await setDMGIcon(configuration: configuration) }
        let signedResult =
            await iconResult
            .tapAsync { await signDMG(configuration: configuration) }

        return signedResult.tap {
            _ = cleanupTemporaryDMG(configuration: configuration)
        }
    }

    // MARK: - Private Methods

    private func cleanupExistingFiles(configuration: DMGConfiguration) -> DMGBuilderResult<Void> {
        Result<Void, DMGBuilderError>.success(())
            .tap { removeItemIfExists(atPath: configuration.outputPath) }
            .tap { removeItemIfExists(atPath: configuration.tempDMGPath) }
    }

    private func cleanupTemporaryDMG(configuration: DMGConfiguration) -> DMGBuilderResult<Void> {
        removeItemIfExists(atPath: configuration.tempDMGPath)
    }

    private func createTemporaryDMG(configuration: DMGConfiguration) async -> DMGBuilderResult<Void>
    {
        await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "create",
                "-size", configuration.volumeSize,
                "-fs", "APFS",
                "-volname", configuration.appName,
                configuration.tempDMGPath,
            ]
        )
    }

    private func mountDMG(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        let attachResult = await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "attach",
                configuration.tempDMGPath,
            ]
        )

        guard case .success = attachResult else {
            return attachResult
        }

        for _ in 0..<10 {
            if fileManager.fileExists(atPath: configuration.volumeMountPath) {
                return .success(())
            }

            let sleepResult = await DMGBuilderResult<Void>.fromAsyncCatching(
                {
                    try await Task.sleep(nanoseconds: 500_000_000)
                },
                mapError: {
                    .operationFailed(
                        operation: "waiting for mounted volume",
                        reason: $0.localizedDescription
                    )
                }
            )

            guard case .success = sleepResult else {
                return sleepResult
            }
        }

        return .failure(.volumeNotMounted(path: configuration.volumeMountPath))
    }

    private func populateDMG(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        let appFileName = URL(filePath: configuration.appPath).lastPathComponent
        let appDestination = "\(configuration.volumeMountPath)/\(appFileName)"
        let backgroundDir = "\(configuration.volumeMountPath)/.background"
        let backgroundFileName = URL(filePath: configuration.backgroundPath).lastPathComponent
        let backgroundDestination = "\(backgroundDir)/\(backgroundFileName)"

        return await Result<Void, DMGBuilderError>.success(())
            .tapAsync {
                await shellExecutor.execute(
                    "cp",
                    arguments: [
                        "-R",
                        configuration.appPath,
                        appDestination,
                    ]
                )
            }
            .tapAsync {
                await shellExecutor.execute(
                    "ln",
                    arguments: [
                        "-s",
                        "/Applications",
                        "\(configuration.volumeMountPath)/Applications",
                    ]
                )
            }
            .tap {
                createDirectory(atPath: backgroundDir)
            }
            .tap {
                copyItem(
                    atPath: configuration.backgroundPath,
                    toPath: backgroundDestination
                )
            }
    }

    private func customizeDMG(configuration: DMGConfiguration) -> DMGBuilderResult<Void> {
        let appFileName = URL(filePath: configuration.appPath).lastPathComponent
        let backgroundFileName = URL(filePath: configuration.backgroundPath).lastPathComponent

        return DSStoreConfigurator.configure(
            volumeURL: URL(filePath: configuration.volumeMountPath),
            appFileName: appFileName,
            backgroundFileName: backgroundFileName,
            iconSize: configuration.iconSize,
            windowBounds: configuration.windowBounds,
            appPosition: configuration.appPosition,
            applicationsPosition: configuration.applicationsPosition
        )
    }

    private func populateAndCustomizeMountedDMG(
        configuration: DMGConfiguration
    ) async -> DMGBuilderResult<Void> {
        let customizationResult = await Result<Void, DMGBuilderError>.success(())
            .tapAsync { await populateDMG(configuration: configuration) }
            .tap { customizeDMG(configuration: configuration) }

        switch customizationResult {
            case .success:
                return await unmountDMG(configuration: configuration)
            case .failure(let error):
                _ = await unmountDMG(configuration: configuration)
                return .failure(error)
        }
    }

    private func unmountDMG(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "detach",
                configuration.volumeMountPath,
            ]
        )
    }

    private func convertToFinalDMG(
        configuration: DMGConfiguration
    ) async -> DMGBuilderResult<Void> {
        await shellExecutor.execute(
            "hdiutil",
            arguments: [
                "convert",
                configuration.tempDMGPath,
                "-format", "UDZO",
                "-o", configuration.outputPath,
            ]
        )
    }

    private func setDMGIcon(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        await MainActor.run {
            DMGIcon.setIcon(
                dmgPath: configuration.outputPath,
                appPath: configuration.appPath
            )
        }
    }

    private func signDMG(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        guard let identity = configuration.signingIdentity else {
            return .success(())
        }

        return await shellExecutor.execute(
            "codesign",
            arguments: [
                "--sign", identity,
                "--force",
                "--verbose",
                configuration.outputPath,
            ]
        )
        .tapAsync { _ in
            await verifySignature(configuration: configuration)
        }
    }

    private func verifySignature(configuration: DMGConfiguration) async -> DMGBuilderResult<Void> {
        await shellExecutor.executeWithOutput(
            "codesign",
            arguments: [
                "--display",
                "--verbose=4",
                configuration.outputPath,
            ]
        )
        .flatMap { output in
            guard output.contains("\nAuthority=") || output.hasPrefix("Authority=") else {
                return .failure(
                    .commandFailed(
                        command: "codesign --display",
                        output: "No Authority flag found in signature. Output:\n\(output)"
                    )
                )
            }

            return .success(())
        }
    }

    private func removeItemIfExists(atPath path: String) -> DMGBuilderResult<Void> {
        guard fileManager.fileExists(atPath: path) else {
            return .success(())
        }

        return DMGBuilderResult<Void>.fromCatching(
            {
                try fileManager.removeItem(atPath: path)
            },
            mapError: {
                .fileOperationFailed(
                    operation: "removing",
                    path: path,
                    reason: $0.localizedDescription
                )
            }
        )
    }

    private func createDirectory(atPath path: String) -> DMGBuilderResult<Void> {
        DMGBuilderResult<Void>.fromCatching(
            {
                try fileManager.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true
                )
            },
            mapError: {
                .fileOperationFailed(
                    operation: "creating directory",
                    path: path,
                    reason: $0.localizedDescription
                )
            }
        )
    }

    private func copyItem(atPath sourcePath: String, toPath destinationPath: String)
        -> DMGBuilderResult<Void>
    {
        DMGBuilderResult<Void>.fromCatching(
            {
                try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
            },
            mapError: {
                .fileOperationFailed(
                    operation: "copying",
                    path: destinationPath,
                    reason: $0.localizedDescription
                )
            }
        )
    }
}
