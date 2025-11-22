import Foundation

/// Generates AppleScript for DMG customization
public enum AppleScriptGenerator {
    public static func generateCustomizationScript(
        volumeName: String,
        appFileName: String,
        backgroundFileName: String,
        iconSize: Int,
        windowBounds: (x: Int, y: Int, width: Int, height: Int),
        appPosition: (x: Int, y: Int),
        applicationsPosition: (x: Int, y: Int)
    ) -> String {
        """
        tell application "Finder"
            tell disk "\(volumeName)"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {\(windowBounds.x), \(windowBounds.y), \(windowBounds.width), \(windowBounds.height)}
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to \(iconSize)
                set background picture of viewOptions to file ".background:\(backgroundFileName)"
                set position of item "\(appFileName)" of container window to {\(appPosition.x), \(appPosition.y)}
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
