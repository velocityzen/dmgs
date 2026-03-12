import Testing
import Foundation
import AppKit
import DSStore
@testable import DMGBuilder

private func unwrapSuccess<Success>(_ result: DMGBuilderResult<Success>) -> Success? {
    switch result {
        case .success(let value):
            return value
        case .failure(let error):
            Issue.record("Unexpected failure: \(error.localizedDescription)")
            return nil
    }
}

@Suite("DMG Configuration Tests")
struct DMGConfigurationTests {
    // Helper to create a temporary test image
    @MainActor
    func createTestImage(width: Int, height: Int) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent("test-\(UUID().uuidString).png").path

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
    @MainActor
    func outputPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath,
                    outputDirectory: "/tmp",
                    windowBounds: (100, 100, 600, 400),
                    appPosition: (150, 200),
                    applicationsPosition: (450, 200)
                )
            )
        else {
            return
        }

        #expect(config.outputPath == "/tmp/TestApp.dmg")
    }

    @Test("Configuration generates correct temporary DMG path")
    @MainActor
    func tempDMGPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath,
                    outputDirectory: "/tmp",
                    windowBounds: (100, 100, 600, 400),
                    appPosition: (150, 200),
                    applicationsPosition: (450, 200)
                )
            )
        else {
            return
        }

        #expect(config.tempDMGPath == "/tmp/TestApp-temp.dmg")
    }

    @Test("Configuration generates correct volume mount path")
    @MainActor
    func volumeMountPath() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath,
                    windowBounds: (100, 100, 600, 400),
                    appPosition: (150, 200),
                    applicationsPosition: (450, 200)
                )
            )
        else {
            return
        }

        #expect(config.volumeMountPath == "/Volumes/TestApp")
    }

    @Test("Configuration uses custom settings when provided")
    @MainActor
    func customSettings() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "CustomApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath,
                    outputDirectory: "/output",
                    volumeSize: "500m",
                    iconSize: 150,
                    windowBounds: (100, 200, 800, 600),
                    appPosition: (200, 300),
                    applicationsPosition: (500, 300)
                )
            )
        else {
            return
        }

        #expect(config.volumeSize == "500m")
        #expect(config.iconSize == 150)
        #expect(config.windowBounds.left == 100)
        #expect(config.appPosition.x == 200)
        #expect(config.applicationsPosition.x == 500)
    }

    @Test("Configuration calculates window bounds from image size")
    @MainActor
    func autoWindowBounds() async throws {
        let imagePath = try createTestImage(width: 600, height: 400)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath
                )
            )
        else {
            return
        }

        // Should be (400, 100, 400+600, 100+400+22) = (400, 100, 1000, 522)
        #expect(config.windowBounds.left == 400)
        #expect(config.windowBounds.top == 100)
        #expect(config.windowBounds.right == 1000)
        #expect(config.windowBounds.bottom == 522)
    }

    @Test("Configuration calculates app position from image size")
    @MainActor
    func autoAppPosition() async throws {
        let imagePath = try createTestImage(width: 800, height: 600)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath
                )
            )
        else {
            return
        }

        #expect(config.appPosition.x == 200)
        #expect(config.appPosition.y == 290)
    }

    @Test("Configuration calculates Applications position from image size")
    @MainActor
    func autoApplicationsPosition() async throws {
        let imagePath = try createTestImage(width: 800, height: 600)
        let appPath = try createTestApp(name: "TestApp")
        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
            try? FileManager.default.removeItem(atPath: appPath)
        }

        guard
            let config = unwrapSuccess(
                await DMGConfiguration.make(
                    appPath: appPath,
                    backgroundPath: imagePath
                )
            )
        else {
            return
        }

        #expect(config.applicationsPosition.x == 600)
        #expect(config.applicationsPosition.y == 290)
    }

    @Test("Configuration sanitizes app name with path separators")
    func sanitizeName() {
        #expect(DMGConfiguration.sanitizeName("My/App") == "My-App")
        #expect(DMGConfiguration.sanitizeName("My:App") == "My-App")
        #expect(DMGConfiguration.sanitizeName("Normal App") == "Normal App")
    }
}

@Suite("DMG Configuration Static Functions")
struct DMGConfigurationStaticTests {
    @Test("Calculate window bounds from image size")
    func calculateWindowBounds() {
        let bounds = DMGConfiguration.calculateWindowBounds(imageSize: (width: 600, height: 400))

        #expect(bounds.left == 400)
        #expect(bounds.top == 100)
        #expect(bounds.right == 1000)  // 400 + 600
        #expect(bounds.bottom == 522)  // 100 + 400 + 22 (title bar)
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
        let result = await DMGConfiguration.make(
            appPath: "/nonexistent/Test.app",
            backgroundPath: "/nonexistent/bg.png"
        )

        switch result {
            case .failure(.appNotFound(let path)):
                #expect(path == "/nonexistent/Test.app")
            case .failure(let error):
                Issue.record("Expected appNotFound error, got \(error.localizedDescription)")
            case .success:
                Issue.record("Expected configuration creation to fail")
        }
    }
}

@Suite("DSStore Configuration Tests")
struct DSStoreConfiguratorTests {
    @MainActor
    private func createTestImage(width: Int, height: Int) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent("test-\(UUID().uuidString).png").path

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

    @Test("Writes window and icon records for mounted volume")
    @MainActor
    func writesFinderRecords() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        let volume = root.appending(path: "TestVolume", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        let backgroundDirectory = volume.appending(path: ".background", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: backgroundDirectory,
            withIntermediateDirectories: true
        )
        let backgroundPath = try createTestImage(width: 600, height: 400)
        try FileManager.default.copyItem(
            at: URL(filePath: backgroundPath),
            to: backgroundDirectory.appending(path: "background.png")
        )
        defer { try? FileManager.default.removeItem(at: root) }
        defer { try? FileManager.default.removeItem(atPath: backgroundPath) }

        guard
            unwrapSuccess(
                DSStoreConfigurator.configure(
                    volumeURL: volume,
                    appFileName: "Test.app",
                    backgroundFileName: "background.png",
                    iconSize: 100,
                    windowBounds: (left: 400, top: 100, right: 1000, bottom: 522),
                    appPosition: (x: 200, y: 290),
                    applicationsPosition: (x: 600, y: 290)
                )
            ) != nil
        else {
            return
        }

        let target = try DSStoreFolderTarget.resolve(folderURL: volume).get()
        let store = try target.readStore().get()
        let recordName = target.recordName

        #expect(store.windowFrame(for: recordName)?.x == 400)
        #expect(store.windowFrame(for: recordName)?.y == 100)
        #expect(store.windowFrame(for: recordName)?.width == 600)
        #expect(store.windowFrame(for: recordName)?.height == 422)
        #expect(store.windowFrame(for: recordName)?.view == "icnv")

        let windowSettings = store.windowSettings(for: recordName)
        #expect(windowSettings?.showSidebar == false)
        #expect(windowSettings?.showStatusBar == false)
        #expect(windowSettings?.showToolbar == false)

        let iconViewEntry = store.entries.first {
            $0.filename == recordName && $0.structureID == "icvo"
        }
        #expect(iconViewEntry != nil)
        if case .blob(let iconViewData)? = iconViewEntry?.value {
            #expect(iconViewData.prefix(4) == Data([0x69, 0x63, 0x76, 0x34]))
            #expect(iconViewData[4...5] == Data([0x00, 0x64]))
            #expect(iconViewData[6...9] == Data("none".utf8))
        } else {
            Issue.record("Expected icvo blob record")
        }

        let appLocation = store.entries.first {
            $0.filename == "Test.app" && $0.structureID == "Iloc"
        }
        let applicationsLocation = store.entries.first {
            $0.filename == "Applications" && $0.structureID == "Iloc"
        }
        #expect(appLocation != nil)
        #expect(applicationsLocation != nil)
        if case .blob(let appLocationData)? = appLocation?.value {
            #expect(
                appLocationData.prefix(8) == Data([0x00, 0x00, 0x00, 0xC8, 0x00, 0x00, 0x01, 0x22]))
        } else {
            Issue.record("Expected app Iloc blob record")
        }
        if case .blob(let applicationsLocationData)? = applicationsLocation?.value {
            #expect(
                applicationsLocationData.prefix(8)
                    == Data([0x00, 0x00, 0x02, 0x58, 0x00, 0x00, 0x01, 0x22]))
        } else {
            Issue.record("Expected Applications Iloc blob record")
        }

        let iconViewPlistEntry = store.entries.first {
            $0.filename == recordName && $0.structureID == "icvp"
        }
        #expect(iconViewPlistEntry != nil)
        if case .blob(let iconViewPlistData)? = iconViewPlistEntry?.value {
            let plist =
                try PropertyListSerialization.propertyList(
                    from: iconViewPlistData,
                    format: nil
                ) as? [String: Any]
            #expect(plist?["backgroundType"] as? Int == 2)
            #expect(plist?["arrangeBy"] as? String == "none")
            #expect((plist?["backgroundImageAlias"] as? Data)?.isEmpty == false)
        } else {
            Issue.record("Expected icvp blob record")
        }

        let backgroundBookmarkEntry = store.entries.first {
            $0.filename == recordName && $0.structureID == "pBBk"
        }
        #expect(backgroundBookmarkEntry != nil)
        if case .blob(let backgroundBookmarkData)? = backgroundBookmarkEntry?.value {
            #expect(backgroundBookmarkData.prefix(4) == Data("book".utf8))
        } else {
            Issue.record("Expected pBBk blob record")
        }
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

    @Test("Invalid background image error has descriptive message")
    func invalidBackgroundImageMessage() {
        let error = DMGBuilderError.invalidBackgroundImage(path: "/test/corrupt.png")
        #expect(error.localizedDescription.contains("/test/corrupt.png"))
    }

    @Test("Command failed error includes command and output")
    func commandFailedMessage() {
        let error = DMGBuilderError.commandFailed(command: "hdiutil create", output: "error output")
        let message = error.localizedDescription
        #expect(message.contains("hdiutil create"))
        #expect(message.contains("error output"))
    }
}
