import ArgumentParser
import Foundation
import DMGBuilder

enum DMGsCommandError: LocalizedError {
    case builder(DMGBuilderError)
    case fileNotFound(path: String)
    case invalidArgument(message: String)
    case inputReadFailed(path: String, reason: String)
    case standardInputReadFailed(reason: String)
    case outputWriteFailed(path: String, reason: String)

    var errorDescription: String? {
        switch self {
            case .builder(let error):
                error.localizedDescription
            case .fileNotFound(let path):
                "File not found at path: \(path)"
            case .invalidArgument(let message):
                message
            case .inputReadFailed(let path, let reason):
                "Unable to read input file at path '\(path)': \(reason)"
            case .standardInputReadFailed(let reason):
                "Unable to read from standard input: \(reason)"
            case .outputWriteFailed(let path, let reason):
                "Unable to write output file at path '\(path)': \(reason)"
        }
    }
}

extension Result where Failure == DMGsCommandError {
    func commandValue() throws -> Success {
        switch self {
            case .success(let value):
                value
            case .failure(let error):
                throw ValidationError(error.localizedDescription)
        }
    }
}
