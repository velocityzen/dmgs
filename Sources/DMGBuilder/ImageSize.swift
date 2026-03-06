import Foundation
import AppKit

/// Utilities for reading image dimensions
@MainActor
public enum ImageSize {
    /// Get the size of an image file
    public static func getImageSize(at path: String) throws -> (width: Int, height: Int) {
        guard let image = NSImage(contentsOfFile: path) else {
            throw DMGBuilderError.invalidBackgroundImage(path: path)
        }

        let size = image.size
        return (width: Int(size.width), height: Int(size.height))
    }
}
