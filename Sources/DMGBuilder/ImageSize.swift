import FP
import Foundation
import AppKit

/// Utilities for reading image dimensions
@MainActor
public enum ImageSize {
    /// Get the size of an image file
    public static func getImageSize(at path: String) -> DMGBuilderResult<(width: Int, height: Int)>
    {
        Result.fromOptional(
            NSImage(contentsOfFile: path),
            error: .invalidBackgroundImage(path: path)
        )
        .map { image in
            let size = image.size
            return (width: Int(size.width), height: Int(size.height))
        }
    }
}
