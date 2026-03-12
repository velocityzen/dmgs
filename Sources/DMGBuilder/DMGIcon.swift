import Foundation
import AppKit

/// Utilities for setting custom icons on DMG files
@MainActor
enum DMGIcon {
    /// Sets the DMG file icon by compositing the app icon onto a drive icon
    static func setIcon(dmgPath: String, appPath: String) -> DMGBuilderResult<Void> {
        let fileManager = FileManager.default
        let appURL = URL(filePath: appPath)
        let infoPlistPath = appURL.appending(path: "Contents/Info.plist").path()

        guard fileManager.fileExists(atPath: infoPlistPath) else {
            return .success(())
        }

        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
            let iconFileName = infoPlist["CFBundleIconFile"] as? String
        else {
            return .success(())
        }

        let iconName = iconFileName.hasSuffix(".icns") ? iconFileName : "\(iconFileName).icns"
        let iconPath = appURL.appending(path: "Contents/Resources/\(iconName)").path()

        guard fileManager.fileExists(atPath: iconPath),
            let appIcon = NSImage(contentsOfFile: iconPath)
        else {
            return .success(())
        }

        let compositeIcon = createCompositeIcon(appIcon: appIcon)

        guard NSWorkspace.shared.setIcon(compositeIcon, forFile: dmgPath) else {
            return .failure(.iconUpdateFailed(path: dmgPath))
        }

        return .success(())
    }

    /// Creates a composite icon by overlaying the app icon on a generic drive icon
    private static func createCompositeIcon(appIcon: NSImage) -> NSImage {
        let driveIcon: NSImage

        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) {
            let removableVolume = volumes.first { url in
                guard
                    let resourceValues = try? url.resourceValues(forKeys: [
                        .volumeIsRemovableKey, .volumeIsEjectableKey,
                    ])
                else {
                    return false
                }
                return resourceValues.volumeIsRemovable == true
                    || resourceValues.volumeIsEjectable == true
            }

            if let volume = removableVolume {
                driveIcon = NSWorkspace.shared.icon(forFile: volume.path)
            } else {
                driveIcon = NSWorkspace.shared.icon(forFile: "/")
            }
        } else {
            driveIcon = NSWorkspace.shared.icon(forFile: "/")
        }

        let size = NSSize(width: 512, height: 512)
        let compositeImage = NSImage(size: size, flipped: false) { rect in
            // Draw the drive icon as background
            driveIcon.draw(
                in: rect,
                from: NSRect(origin: .zero, size: driveIcon.size),
                operation: .copy,
                fraction: 1.0
            )

            // Calculate position and size for app icon overlay
            let appIconScale: CGFloat = 0.6
            let appIconSize = NSSize(
                width: size.width * appIconScale,
                height: size.height * appIconScale
            )

            let appIconOrigin = NSPoint(
                x: (size.width - appIconSize.width) / 2,
                y: (size.height - appIconSize.height) / 2 - 20
            )

            let appIconRect = NSRect(origin: appIconOrigin, size: appIconSize)

            // Draw shadow
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.shadowBlurRadius = 5
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.set()

            appIcon.draw(
                in: appIconRect,
                from: NSRect(origin: .zero, size: appIcon.size),
                operation: .sourceOver,
                fraction: 1.0
            )

            return true
        }

        return compositeImage
    }
}
