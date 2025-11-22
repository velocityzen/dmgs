import Foundation

/// Configuration for creating a DMG
public struct DMGConfiguration {
    public let appName: String
    public let appPath: String
    public let backgroundPath: String
    public let outputDirectory: String
    public let volumeSize: String
    public let iconSize: Int
    public let windowBounds: (x: Int, y: Int, width: Int, height: Int)
    public let appPosition: (x: Int, y: Int)
    public let applicationsPosition: (x: Int, y: Int)

    public init(
        appName: String,
        appPath: String,
        backgroundPath: String,
        outputDirectory: String = FileManager.default.currentDirectoryPath,
        volumeSize: String = "200m",
        iconSize: Int = 100,
        windowBounds: (x: Int, y: Int, width: Int, height: Int)? = nil,
        appPosition: (x: Int, y: Int)? = nil,
        applicationsPosition: (x: Int, y: Int)? = nil
    ) throws {
        self.appName = appName
        self.appPath = appPath
        self.backgroundPath = backgroundPath
        self.outputDirectory = outputDirectory
        self.volumeSize = volumeSize
        self.iconSize = iconSize

        // Get image size once
        let imageSize = try ImageSize.getImageSize(at: backgroundPath)

        // Resolve all positions and bounds
        self.windowBounds = windowBounds ?? Self.calculateWindowBounds(imageSize: imageSize)
        self.appPosition = appPosition ?? Self.calculateAppPosition(imageSize: imageSize)
        self.applicationsPosition =
            applicationsPosition ?? Self.calculateApplicationsPosition(imageSize: imageSize)
    }

    /// Calculate window bounds from image size
    /// Returns bounds as (left, top, right, bottom) for AppleScript
    /// Adds extra height for the window title bar (approximately 22 pixels)
    public static func calculateWindowBounds(imageSize: (width: Int, height: Int)) -> (
        x: Int, y: Int, width: Int, height: Int
    ) {
        let titleBarHeight = 22
        let left = 400
        let top = 100
        let right = left + imageSize.width
        let bottom = top + imageSize.height + titleBarHeight
        return (x: left, y: top, width: right, height: bottom)
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
