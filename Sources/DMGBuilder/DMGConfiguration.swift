import FP
import Foundation

/// Configuration for creating a DMG
public struct DMGConfiguration: Sendable {
    public let appName: String
    public let appPath: String
    public let backgroundPath: String
    public let outputDirectory: String
    public let volumeSize: String
    public let iconSize: Int
    public let windowBounds: (left: Int, top: Int, right: Int, bottom: Int)
    public let appPosition: (x: Int, y: Int)
    public let applicationsPosition: (x: Int, y: Int)
    public let signingIdentity: String?

    private init(
        appName: String,
        appPath: String,
        backgroundPath: String,
        outputDirectory: String,
        volumeSize: String,
        iconSize: Int,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int),
        appPosition: (x: Int, y: Int),
        applicationsPosition: (x: Int, y: Int),
        signingIdentity: String?
    ) {
        self.appName = appName
        self.appPath = appPath
        self.backgroundPath = backgroundPath
        self.outputDirectory = outputDirectory
        self.volumeSize = volumeSize
        self.iconSize = iconSize
        self.windowBounds = windowBounds
        self.appPosition = appPosition
        self.applicationsPosition = applicationsPosition
        self.signingIdentity = signingIdentity
    }

    public static func make(
        appPath: String,
        backgroundPath: String,
        outputDirectory: String = FileManager.default.currentDirectoryPath,
        volumeSize: String = "200m",
        iconSize: Int = 100,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int)? = nil,
        appPosition: (x: Int, y: Int)? = nil,
        applicationsPosition: (x: Int, y: Int)? = nil,
        signingIdentity: String? = nil
    ) async -> DMGBuilderResult<Self> {
        await Result<Void, DMGBuilderError>.success(())
            .tap { validateAppPath(appPath) }
            .tap { validateBackgroundPath(backgroundPath) }
            .flatMap { _ in extractAppName(from: appPath).map(Self.sanitizeName) }
            .bindAsync { _ in await resolveSigningIdentity(signingIdentity) }
            .bindAsync { _, _ in await backgroundImageSize(at: backgroundPath) }
            .map { appName, resolvedSigningIdentity, imageSize in
                Self(
                    appName: appName,
                    appPath: appPath,
                    backgroundPath: backgroundPath,
                    outputDirectory: outputDirectory,
                    volumeSize: volumeSize,
                    iconSize: iconSize,
                    windowBounds: windowBounds ?? Self.calculateWindowBounds(imageSize: imageSize),
                    appPosition: appPosition ?? Self.calculateAppPosition(imageSize: imageSize),
                    applicationsPosition:
                        applicationsPosition
                        ?? Self.calculateApplicationsPosition(imageSize: imageSize),
                    signingIdentity: resolvedSigningIdentity
                )
            }
    }

    /// Extract app name from the app bundle's Info.plist
    private static func extractAppName(from appPath: String) -> DMGBuilderResult<String> {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"

        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else {
            return .success(URL(filePath: appPath).deletingPathExtension().lastPathComponent)
        }

        if let displayName = infoPlist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
            return .success(displayName)
        }

        if let bundleName = infoPlist["CFBundleName"] as? String, !bundleName.isEmpty {
            return .success(bundleName)
        }

        return .success(URL(filePath: appPath).deletingPathExtension().lastPathComponent)
    }

    /// Removes path separators and other unsafe characters from the app name
    static func sanitizeName(_ name: String) -> String {
        name.replacing("/", with: "-")
            .replacing(":", with: "-")
            .replacing("\0", with: "")
    }

    private static func validateAppPath(_ appPath: String) -> DMGBuilderResult<Void> {
        FileManager.default.fileExists(atPath: appPath)
            ? .success(())
            : .failure(.appNotFound(path: appPath))
    }

    private static func validateBackgroundPath(_ backgroundPath: String) -> DMGBuilderResult<Void> {
        FileManager.default.fileExists(atPath: backgroundPath)
            ? .success(())
            : .failure(.backgroundNotFound(path: backgroundPath))
    }

    private static func resolveSigningIdentity(
        _ signingIdentity: String?
    ) async -> DMGBuilderResult<String?> {
        guard let signingIdentity else {
            return .success(nil)
        }

        return await SigningIdentity.validate(signingIdentity)
            .map { signingIdentity }
    }

    private static func backgroundImageSize(
        at backgroundPath: String
    ) async -> DMGBuilderResult<(width: Int, height: Int)> {
        await MainActor.run {
            ImageSize.getImageSize(at: backgroundPath)
        }
    }

    /// Calculate window bounds from image size
    /// Returns bounds as (left, top, right, bottom) for AppleScript
    /// Adds extra height for the window title bar (approximately 22 pixels)
    public static func calculateWindowBounds(imageSize: (width: Int, height: Int)) -> (
        left: Int, top: Int, right: Int, bottom: Int
    ) {
        let titleBarHeight = 22
        let left = 400
        let top = 100
        let right = left + imageSize.width
        let bottom = top + imageSize.height + titleBarHeight
        return (left: left, top: top, right: right, bottom: bottom)
    }

    /// Calculate app icon position from image size
    /// Default position is 1/4 from left, centered vertically
    public static func calculateAppPosition(imageSize: (width: Int, height: Int)) -> (
        x: Int, y: Int
    ) {
        let x = imageSize.width / 4
        let y = imageSize.height / 2 - 10
        return (x: x, y: y)
    }

    /// Calculate Applications folder position from image size
    /// Default position is 3/4 from left, centered vertically
    public static func calculateApplicationsPosition(imageSize: (width: Int, height: Int)) -> (
        x: Int, y: Int
    ) {
        let x = (imageSize.width * 3) / 4
        let y = imageSize.height / 2 - 10
        return (x: x, y: y)
    }

    public var outputPath: String {
        "\(outputDirectory)/\(appName).dmg"
    }

    public var tempDMGPath: String {
        "\(outputDirectory)/\(appName)-temp.dmg"
    }

    public var volumeMountPath: String {
        "/Volumes/\(appName)"
    }
}
