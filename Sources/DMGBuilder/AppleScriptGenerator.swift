import Foundation

/// Generates AppleScript for DMG customization
public enum AppleScriptGenerator {
    /// Escapes a string for safe use inside AppleScript double-quoted strings
    static func escapeForAppleScript(_ value: String) -> String {
        value
            .replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
    }

    public static func generateCustomizationScript(
        volumeName: String,
        appFileName: String,
        backgroundFileName: String,
        iconSize: Int,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int),
        appPosition: (x: Int, y: Int),
        applicationsPosition: (x: Int, y: Int)
    ) -> String {
        let safeVolumeName = escapeForAppleScript(volumeName)
        let safeAppFileName = escapeForAppleScript(appFileName)
        let safeBackgroundFileName = escapeForAppleScript(backgroundFileName)

        return """
            tell application "Finder"
                tell disk "\(safeVolumeName)"
                    open
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    set the bounds of container window to {\(windowBounds.left), \(windowBounds.top), \(windowBounds.right), \(windowBounds.bottom)}
                    set viewOptions to the icon view options of container window
                    set arrangement of viewOptions to not arranged
                    set icon size of viewOptions to \(iconSize)
                    set background picture of viewOptions to file ".background:\(safeBackgroundFileName)"
                    set position of item "\(safeAppFileName)" of container window to {\(appPosition.x), \(appPosition.y)}
                    set position of item "Applications" of container window to {\(applicationsPosition.x), \(applicationsPosition.y)}
                    close
                    open
                    update without registering applications
                    delay 2
                end tell
            end tell
            """
    }
}
