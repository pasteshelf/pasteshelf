//
//  ImageProcessor.swift
//  PasteShelf
//
//  Handles image processing for clipboard content including
//  thumbnail generation and compression for large images.
//

import AppKit
import Foundation
import os.log

/// Processes images for efficient storage and display
final class ImageProcessor: ImageProcessing, Sendable {
    // MARK: - Properties

    /// Maximum storage size in bytes (default 10MB)
    let maxStorageSize: Int

    /// Maximum dimension for thumbnails in pixels (default 256)
    let thumbnailSize: CGFloat

    /// JPEG compression quality for large images (0.0-1.0)
    let compressionQuality: CGFloat

    // MARK: - Initialization

    /// Creates an ImageProcessor with custom settings
    /// - Parameters:
    ///   - maxStorageSize: Maximum size in bytes before compression (default 10MB)
    ///   - thumbnailSize: Maximum thumbnail dimension (default 256px)
    ///   - compressionQuality: JPEG quality factor (default 0.8)
    init(
        maxStorageSize: Int = 10_000_000,
        thumbnailSize: CGFloat = 256,
        compressionQuality: CGFloat = 0.8
    ) {
        self.maxStorageSize = maxStorageSize
        self.thumbnailSize = thumbnailSize
        self.compressionQuality = compressionQuality
    }

    // MARK: - ImageProcessing

    func process(_ image: NSImage) -> ProcessedImage {
        var result = ProcessedImage()

        // Get original dimensions
        let pixelSize = image.pixelSize
        result.width = pixelSize.width
        result.height = pixelSize.height

        // Generate thumbnail
        result.thumbnail = generateThumbnail(image)

        // Get image data and compress if needed
        if let tiffData = image.tiffRepresentation {
            let (processedData, wasCompressed) = compressIfNeeded(tiffData)
            result.data = processedData
            result.isCompressed = wasCompressed

            if wasCompressed {
                Logger.clipboard.debug(
                    "Image compressed: \(tiffData.count) -> \(processedData.count) bytes"
                )
            }
        }

        return result
    }

    func generateThumbnail(_ image: NSImage) -> Data? {
        let originalSize = image.size

        // Don't upscale small images
        if originalSize.width <= thumbnailSize && originalSize.height <= thumbnailSize {
            return image.pngData
        }

        // Calculate aspect-fit size
        let ratio = min(
            thumbnailSize / originalSize.width,
            thumbnailSize / originalSize.height
        )
        let newSize = CGSize(
            width: floor(originalSize.width * ratio),
            height: floor(originalSize.height * ratio)
        )

        // Create thumbnail
        let thumbnail = NSImage(size: newSize)

        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()

        // Return as PNG for best quality at small sizes
        return thumbnail.pngData
    }

    func compressIfNeeded(_ imageData: Data) -> (data: Data, isCompressed: Bool) {
        // If under limit, convert to PNG and return
        if imageData.count <= maxStorageSize {
            if let pngData = convertToPNG(imageData), pngData.count <= maxStorageSize {
                return (pngData, false)
            }
            // PNG is larger, try to return original if it's already an acceptable format
            return (imageData, false)
        }

        // Compress to JPEG
        guard let compressed = compressToJPEG(imageData, quality: compressionQuality) else {
            Logger.clipboard.warning("Failed to compress image, using original")
            return (imageData, false)
        }

        // If still too large, try progressively lower quality
        if compressed.count > maxStorageSize {
            for quality in [0.6, 0.4, 0.2] as [CGFloat] {
                if let moreCompressed = compressToJPEG(imageData, quality: quality),
                   moreCompressed.count <= maxStorageSize {
                    return (moreCompressed, true)
                }
            }
        }

        return (compressed, true)
    }

    // MARK: - Private Helpers

    /// Converts image data to PNG format
    private func convertToPNG(_ imageData: Data) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: imageData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Compresses image data to JPEG with specified quality
    private func compressToJPEG(_ imageData: Data, quality: CGFloat) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: imageData) else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }
}

// MARK: - NSImage Extensions

extension NSImage {
    /// Returns the image's pixel dimensions (not points)
    var pixelSize: (width: Int, height: Int) {
        guard let rep = representations.first else {
            return (Int(size.width), Int(size.height))
        }
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    /// Creates NSImage from raw image data (TIFF, PNG, JPEG, etc.)
    convenience init?(imageData: Data) {
        self.init(data: imageData)
    }

    /// Converts the image to PNG data
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Converts the image to JPEG data with specified quality
    /// - Parameter quality: Compression quality (0.0-1.0)
    func jpegData(quality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }
}

// MARK: - ProcessedImage Extensions

extension ProcessedImage {
    /// Returns the image dimensions as a formatted string
    var dimensionsString: String? {
        guard width > 0, height > 0 else { return nil }
        return "\(width) × \(height)"
    }

    /// Returns the aspect ratio (width/height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.0 }
        return CGFloat(width) / CGFloat(height)
    }

    /// Returns whether the image is portrait orientation
    var isPortrait: Bool {
        height > width
    }

    /// Returns whether the image is landscape orientation
    var isLandscape: Bool {
        width > height
    }

    /// Returns the data size in a human-readable format
    var formattedSize: String? {
        guard let data = data else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
}
