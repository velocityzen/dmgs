import Foundation

/// Errors that can occur during DMG creation
public enum DMGBuilderError: LocalizedError {
    case appNotFound(path: String)
    case backgroundNotFound(path: String)
    case fileOperationFailed(operation: String, path: String, reason: String)
    case invalidBackgroundImage(path: String)
    case iconUpdateFailed(path: String)
    case operationFailed(operation: String, reason: String)
    case commandFailed(command: String, output: String)
    case dsStoreFailed(output: String)
    case signingIdentityNotFound(identity: String, availableIdentities: String)
    case volumeNotMounted(path: String)

    public var errorDescription: String? {
        switch self {
            case .appNotFound(let path):
                "App file not found at path: \(path)"
            case .backgroundNotFound(let path):
                "Background image not found at path: \(path)"
            case .fileOperationFailed(let operation, let path, let reason):
                "File operation failed while \(operation) '\(path)': \(reason)"
            case .invalidBackgroundImage(let path):
                "Unable to read background image at path: \(path)"
            case .iconUpdateFailed(let path):
                "Unable to set a custom icon for DMG at path: \(path)"
            case .operationFailed(let operation, let reason):
                "Operation failed while \(operation): \(reason)"
            case .commandFailed(let command, let output):
                "Command failed: \(command)\n\(output)"
            case .dsStoreFailed(let output):
                "DS_Store update failed: \(output)"
            case .signingIdentityNotFound(let identity, let availableIdentities):
                """
                Signing identity '\(identity)' not found in keychain.
                Available identities:
                \(availableIdentities)
                """
            case .volumeNotMounted(let path):
                "Volume not mounted at path: \(path)"
        }
    }
}
