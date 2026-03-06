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

    public init(
        appPath: String,
        backgroundPath: String,
        outputDirectory: String = FileManager.default.currentDirectoryPath,
        volumeSize: String = "200m",
        iconSize: Int = 100,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int)? = nil,
        appPosition: (x: Int, y: Int)? = nil,
        applicationsPosition: (x: Int, y: Int)? = nil,
        signingIdentity: String? = nil
    ) async throws {
        // Extract app name from Info.plist and sanitize for path safety
        self.appName = Self.sanitizeName(try Self.extractAppName(from: appPath))
        self.appPath = appPath
        self.backgroundPath = backgroundPath
        self.outputDirectory = outputDirectory
        self.volumeSize = volumeSize
        self.iconSize = iconSize

        // Validate signing identity if provided
        if let identity = signingIdentity {
            try await Self.validateSigningIdentity(identity)
        }
        self.signingIdentity = signingIdentity

        // Get image size once
        let imageSize = try await MainActor.run {
            try ImageSize.getImageSize(at: backgroundPath)
        }

        // Resolve all positions and bounds
        self.windowBounds = windowBounds ?? Self.calculateWindowBounds(imageSize: imageSize)
        self.appPosition = appPosition ?? Self.calculateAppPosition(imageSize: imageSize)
        self.applicationsPosition =
            applicationsPosition ?? Self.calculateApplicationsPosition(imageSize: imageSize)
    }

    /// Extract app name from the app bundle's Info.plist
    private static func extractAppName(from appPath: String) throws -> String {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"

        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else {
            let bundleName = URL(filePath: appPath).deletingPathExtension().lastPathComponent
            return bundleName
        }

        if let displayName = infoPlist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
            return displayName
        } else if let bundleName = infoPlist["CFBundleName"] as? String, !bundleName.isEmpty {
            return bundleName
        } else {
            return URL(filePath: appPath).deletingPathExtension().lastPathComponent
        }
    }

    /// Removes path separators and other unsafe characters from the app name
    static func sanitizeName(_ name: String) -> String {
        name.replacing("/", with: "-")
            .replacing(":", with: "-")
            .replacing("\0", with: "")
    }

    /// Validate that the signing identity exists in the keychain
    private static func validateSigningIdentity(_ identity: String) async throws {
        try await SigningIdentity.validate(identity)
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
