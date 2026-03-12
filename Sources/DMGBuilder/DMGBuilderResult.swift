import FP
import Foundation

public typealias DMGBuilderResult<Success> = Result<Success, DMGBuilderError>

public extension Result where Failure == DMGBuilderError {
    static func fromCatching(
        _ operation: () throws -> Success,
        mapError: (Error) -> DMGBuilderError
    ) -> Self {
        Result<Success, Error> {
            try operation()
        }
        .mapError(mapError)
    }

    static func fromAsyncCatching(
        _ operation: () async throws -> Success,
        mapError: @escaping (Error) -> DMGBuilderError
    ) async -> Self {
        await Result<Success, Error>.fromAsync(operation)
            .mapError(mapError)
    }
}
