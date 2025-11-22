import Foundation

/// Errors that can occur during DMG creation
public enum DMGBuilderError: LocalizedError {
    case appNotFound(path: String)
    case backgroundNotFound(path: String)
    case commandFailed(command: String, output: String)
    case appleScriptFailed(output: String)
    case volumeNotMounted(path: String)

    public var errorDescription: String? {
        switch self {
            case .appNotFound(let path):
                return "App file not found at path: \(path)"
            case .backgroundNotFound(let path):
                return "Background image not found at path: \(path)"
            case .commandFailed(let command, let output):
                return "Command failed: \(command)\n\(output)"
            case .appleScriptFailed(let output):
                return "AppleScript failed: \(output)"
            case .volumeNotMounted(let path):
                return "Volume not mounted at path: \(path)"
        }
    }
}
