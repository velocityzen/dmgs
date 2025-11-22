import Foundation
import AppKit

/// Helper to set custom icons on files
enum DMGIconSetter {
    /// Sets the DMG file icon by compositing the app icon onto a drive icon
    static func setIcon(dmgPath: String, appPath: String, fileManager: FileManager) throws {
        let appURL = URL(fileURLWithPath: appPath)
        let infoPlistPath = appURL.appendingPathComponent("Contents/Info.plist").path

        guard fileManager.fileExists(atPath: infoPlistPath) else {
            // No Info.plist, skip icon setting
            return
        }

        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
            let iconFileName = infoPlist["CFBundleIconFile"] as? String
        else {
            // No icon specified
            return
        }

        let iconName = iconFileName.hasSuffix(".icns") ? iconFileName : "\(iconFileName).icns"
        let iconPath = appURL.appendingPathComponent("Contents/Resources/\(iconName)").path

        guard fileManager.fileExists(atPath: iconPath),
            let appIcon = NSImage(contentsOfFile: iconPath)
        else {
            return
        }

        let compositeIcon = createCompositeIcon(appIcon: appIcon)
        let workspace = NSWorkspace.shared
        workspace.setIcon(compositeIcon, forFile: dmgPath)
    }

    /// Creates a composite icon by overlaying the app icon on a generic drive icon
    private static func createCompositeIcon(appIcon: NSImage) -> NSImage {
        // Get the generic removable disk icon
        // We need to get it from an actual volume since there's no direct API
        // Try to get icon from any mounted volume, fallback to generic volume icon
        let driveIcon: NSImage

        // Get icon from a removable/ejectable volume using proper resource keys
        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) {
            // Find a removable or ejectable volume to get its icon
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
                // No removable volumes found, use root volume icon as fallback
                driveIcon = NSWorkspace.shared.icon(forFile: "/")
            }
        } else {
            // Fallback to root volume icon
            driveIcon = NSWorkspace.shared.icon(forFile: "/")
        }

        let iconSize = NSSize(width: 512, height: 512)
        let compositeImage = NSImage(size: iconSize)
        compositeImage.lockFocus()

        // Draw the drive icon as background (full size)
        driveIcon.draw(
            in: NSRect(origin: .zero, size: iconSize),
            from: NSRect(origin: .zero, size: driveIcon.size),
            operation: .copy,
            fraction: 1.0
        )

        // Calculate position and size for app icon overlay
        let appIconScale: CGFloat = 0.6
        let appIconSize = NSSize(
            width: iconSize.width * appIconScale,
            height: iconSize.height * appIconScale
        )

        // Center the app icon
        let appIconOrigin = NSPoint(
            x: (iconSize.width - appIconSize.width) / 2,
            y: (iconSize.height - appIconSize.height) / 2 + 20  // Slight offset upward
        )

        let appIconRect = NSRect(origin: appIconOrigin, size: appIconSize)

        // Draw the app icon on top with a subtle shadow
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

        compositeImage.unlockFocus()

        return compositeImage
    }
}
