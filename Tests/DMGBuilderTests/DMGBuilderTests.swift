import Testing
import Foundation
import AppKit
@testable import DMGBuilder

@Suite("DMG Configuration Tests")
struct DMGConfigurationTests {
    // Helper to create a temporary test image
    func createTestImage(width: Int, height: Int) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent("test-\(UUID().uuidString).png").path

        // Create a simple bitmap image with white background
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )

        guard let bitmap = bitmapRep else {
            throw NSError(
                domain: "TestError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap"])
        }

        // Fill with white
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "TestError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }

        try pngData.write(to: URL(fileURLWithPath: imagePath))
        return imagePath
    }

    // Helper to create a temporary test app bundle with Info.plist
    func createTestApp(name: String = "TestApp") throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let appPath = tempDir.appendingPathComponent("\(name)-\(UUID().uuidString).app").path
        let contentsPath = "\(appPath)/Contents"

        try FileManager.default.createDirectory(
            atPath: contentsPath,
            withIntermediateDirectories: true
        )

        let infoPlistPath = "\(contentsPath)/Info.plist"
        let plistDict: NSDictionary = [
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundleIdentifier": "com.test.\(name)",
            "CFBundleVersion": "1.0",
        ]

        plistDict.write(toFile: infoPlistPath, atomically: true)
        return appPath
    }

    @Test("Configuration generates correct output path")
    func outputPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath,
            outputDirectory: "/tmp",
            windowBounds: (100, 100, 600, 400),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(config.outputPath == "/tmp/TestApp.dmg")
    }

    @Test("Configuration generates correct temporary DMG path")
    func tempDMGPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath,
            outputDirectory: "/tmp",
            windowBounds: (100, 100, 600, 400),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(config.tempDMGPath == "/tmp/TestApp-temp.dmg")
    }

    @Test("Configuration generates correct volume mount path")
    func volumeMountPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath,
            windowBounds: (100, 100, 600, 400),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(config.volumeMountPath == "/Volumes/TestApp")
    }

    @Test("Configuration uses custom settings when provided")
    func customSettings() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "CustomApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath,
            outputDirectory: "/output",
            volumeSize: "500m",
            iconSize: 150,
            windowBounds: (100, 200, 800, 600),
            appPosition: (200, 300),
            applicationsPosition: (500, 300)
        )

        #expect(config.volumeSize == "500m")
        #expect(config.iconSize == 150)
        #expect(config.windowBounds.x == 100)
        #expect(config.appPosition.x == 200)
        #expect(config.applicationsPosition.x == 500)
    }

    @Test("Configuration calculates window bounds from image size")
    func autoWindowBounds() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath
        )

        // Should be (400, 100, 400+600, 100+400+22) = (400, 100, 1000, 522)
        // The +22 accounts for the window title bar
        #expect(config.windowBounds.x == 400)
        #expect(config.windowBounds.y == 100)
        #expect(config.windowBounds.width == 1000)
        #expect(config.windowBounds.height == 522)
    }

    @Test("Configuration calculates app position from image size")
    func autoAppPosition() async throws {
        let imagePath = try createTestImage(width: 800, height: 600)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath
        )

        // Should be at 1/4 width, 1/2 height - 10 = (200, 290)
        #expect(config.appPosition.x == 200)
        #expect(config.appPosition.y == 290)
    }

    @Test("Configuration calculates Applications position from image size")
    func autoApplicationsPosition() async throws {
        let imagePath = try createTestImage(width: 800, height: 600)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        let config = try await DMGConfiguration(
            appPath: appPath,
            backgroundPath: imagePath
        )

        // Should be at 3/4 width, 1/2 height - 10 = (600, 290)
        #expect(config.applicationsPosition.x == 600)
        #expect(config.applicationsPosition.y == 290)
    }
}

@Suite("DMG Configuration Static Functions")
struct DMGConfigurationStaticTests {
    @Test("Calculate window bounds from image size")
    func calculateWindowBounds() {
        let bounds = DMGConfiguration.calculateWindowBounds(imageSize: (width: 600, height: 400))

        #expect(bounds.x == 400)
        #expect(bounds.y == 100)
        #expect(bounds.width == 1000)  // 400 + 600
        #expect(bounds.height == 522)  // 100 + 400 + 22 (title bar)
    }

    @Test("Calculate app position from image size")
    func calculateAppPosition() {
        let position = DMGConfiguration.calculateAppPosition(imageSize: (width: 800, height: 600))

        #expect(position.x == 200)  // 800 / 4
        #expect(position.y == 290)  // 600 / 2 - 10
    }

    @Test("Calculate Applications position from image size")
    func calculateApplicationsPosition() {
        let position = DMGConfiguration.calculateApplicationsPosition(
            imageSize: (width: 800, height: 600))

        #expect(position.x == 600)  // 800 * 3 / 4
        #expect(position.y == 290)  // 600 / 2 - 10
    }
}

@Suite("DMG Builder Validation Tests")
struct DMGBuilderValidationTests {
    @Test("Validation fails when app file doesn't exist")
    func appNotFound() async {
        await #expect(throws: Error.self) {
            try await DMGConfiguration(
                appPath: "/nonexistent/Test.app",
                backgroundPath: "/nonexistent/bg.png"
            )
        }
    }
}

@Suite("AppleScript Generation Tests")
struct AppleScriptGenerationTests {
    @Test("Generates script with volume name")
    func containsVolumeName() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "Test.app",
            backgroundFileName: "background.png",
            iconSize: 100,
            windowBounds: (400, 100, 1000, 550),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(script.contains("TestApp"))
        #expect(script.contains("tell disk \"TestApp\""))
    }

    @Test("Generates script with app filename")
    func containsAppFilename() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "MyCustomApp.app",
            backgroundFileName: "background.png",
            iconSize: 100,
            windowBounds: (400, 100, 1000, 550),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(script.contains("MyCustomApp.app"))
        #expect(script.contains("position of item \"MyCustomApp.app\""))
    }

    @Test("Generates script with background filename")
    func containsBackgroundFilename() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "Test.app",
            backgroundFileName: "custom-bg.jpg",
            iconSize: 100,
            windowBounds: (400, 100, 1000, 550),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(script.contains("custom-bg.jpg"))
        #expect(script.contains(".background:custom-bg.jpg"))
    }

    @Test("Generates script with custom icon size")
    func containsIconSize() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "Test.app",
            backgroundFileName: "background.png",
            iconSize: 150,
            windowBounds: (400, 100, 1000, 550),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(script.contains("icon size of viewOptions to 150"))
    }

    @Test("Generates script with window bounds")
    func containsWindowBounds() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "Test.app",
            backgroundFileName: "background.png",
            iconSize: 100,
            windowBounds: (100, 200, 800, 600),
            appPosition: (150, 200),
            applicationsPosition: (450, 200)
        )

        #expect(script.contains("bounds of container window to {100, 200, 800, 600}"))
    }

    @Test("Generates script with item positions")
    func containsItemPositions() {
        let script = AppleScriptGenerator.generateCustomizationScript(
            volumeName: "TestApp",
            appFileName: "Test.app",
            backgroundFileName: "background.png",
            iconSize: 100,
            windowBounds: (400, 100, 1000, 550),
            appPosition: (200, 300),
            applicationsPosition: (500, 400)
        )

        #expect(script.contains("position of item \"Test.app\" of container window to {200, 300}"))
        #expect(
            script.contains("position of item \"Applications\" of container window to {500, 400}"))
    }
}

@Suite("DMGBuilder Error Tests")
struct DMGBuilderErrorTests {
    @Test("App not found error has descriptive message")
    func appNotFoundMessage() {
        let error = DMGBuilderError.appNotFound(path: "/test/path.app")
        #expect(error.localizedDescription.contains("/test/path.app"))
    }

    @Test("Background not found error has descriptive message")
    func backgroundNotFoundMessage() {
        let error = DMGBuilderError.backgroundNotFound(path: "/test/bg.png")
        #expect(error.localizedDescription.contains("/test/bg.png"))
    }

    @Test("Command failed error includes command and output")
    func commandFailedMessage() {
        let error = DMGBuilderError.commandFailed(command: "hdiutil create", output: "error output")
        let message = error.localizedDescription
        #expect(message.contains("hdiutil create"))
        #expect(message.contains("error output"))
    }
}
