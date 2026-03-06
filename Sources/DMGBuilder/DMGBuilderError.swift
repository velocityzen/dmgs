import Foundation

/// Errors that can occur during DMG creation
public enum DMGBuilderError: LocalizedError {
    case appNotFound(path: String)
    case backgroundNotFound(path: String)
    case invalidBackgroundImage(path: String)
    case commandFailed(command: String, output: String)
    case appleScriptFailed(output: String)
    case volumeNotMounted(path: String)

    public var errorDescription: String? {
        switch self {
            case .appNotFound(let path):
                "App file not found at path: \(path)"
            case .backgroundNotFound(let path):
                "Background image not found at path: \(path)"
            case .invalidBackgroundImage(let path):
                "Unable to read background image at path: \(path)"
            case .commandFailed(let command, let output):
                "Command failed: \(command)\n\(output)"
            case .appleScriptFailed(let output):
                "AppleScript failed: \(output)"
            case .volumeNotMounted(let path):
                "Volume not mounted at path: \(path)"
        }
    }
}
