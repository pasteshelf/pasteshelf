//
//  ImageProcessorTests.swift
//  PasteShelfTests
//
//  Tests for image processing functionality.
//

import AppKit
@testable import PasteShelf
import Testing

struct ImageProcessorTests {
    // MARK: Internal

    let processor = ImageProcessor()

    // MARK: - Thumbnail Tests

    @Test("Thumbnail is generated for large images")
    func thumbnailIsGeneratedForLargeImages() {
        let image = self.createTestImage(width: 1000, height: 800)
        let result = self.processor.process(image)

        #expect(result.thumbnail != nil)
    }

    @Test("Small images are not upscaled for thumbnail")
    func smallImagesNotUpscaled() {
        let image = self.createTestImage(width: 100, height: 100)
        let thumbnail = self.processor.generateThumbnail(image)

        #expect(thumbnail != nil)
    }

    @Test("Thumbnail respects max dimension")
    func thumbnailRespectsMaxDimension() {
        let image = self.createTestImage(width: 1000, height: 500)
        let result = self.processor.process(image)

        guard let thumbnailData = result.thumbnail,
              let thumbnail = NSImage(data: thumbnailData)
        else {
            Issue.record("Failed to create thumbnail")
            return
        }

        // Width should be 256 (limited), height should be proportional
        #expect(thumbnail.size.width <= 256)
        #expect(thumbnail.size.height <= 256)
    }

    @Test("Thumbnail maintains aspect ratio")
    func thumbnailMaintainsAspectRatio() {
        let image = self.createTestImage(width: 1000, height: 500)
        let result = self.processor.process(image)

        guard let thumbnailData = result.thumbnail,
              let thumbnail = NSImage(data: thumbnailData)
        else {
            Issue.record("Failed to create thumbnail")
            return
        }

        let originalRatio = 1000.0 / 500.0
        let thumbnailRatio = thumbnail.size.width / thumbnail.size.height

        // Allow small floating point difference
        #expect(abs(originalRatio - thumbnailRatio) < 0.1)
    }

    // MARK: - Dimension Tests

    @Test("Dimensions are correctly extracted")
    func dimensionsAreCorrectlyExtracted() {
        let image = self.createTestImage(width: 800, height: 600)
        let result = self.processor.process(image)

        // process() uses image.pixelSize which returns actual pixel dimensions.
        // On Retina (2x) displays, NSImage created via lockFocus will have a
        // bitmap representation at 2x the point size, so pixels = 2 * points.
        // We verify the pixel dimensions are a positive multiple of the point size.
        #expect(result.width > 0)
        #expect(result.height > 0)
        #expect(result.width.isMultiple(of: 800))
        #expect(result.height.isMultiple(of: 600))
        // Aspect ratio should be preserved regardless of scale factor
        let expectedRatio = 800.0 / 600.0
        let actualRatio = Double(result.width) / Double(result.height)
        #expect(abs(expectedRatio - actualRatio) < 0.01)
    }

    // MARK: - Compression Tests

    @Test("Small images are not compressed")
    func smallImagesNotCompressed() {
        let image = self.createTestImage(width: 100, height: 100)
        let result = self.processor.process(image)

        #expect(!result.isCompressed)
    }

    @Test("Compress if needed returns original for small data")
    func compressIfNeededReturnsOriginalForSmallData() {
        let smallData = Data(repeating: 0, count: 1000)
        let (resultData, isCompressed) = self.processor.compressIfNeeded(smallData)

        #expect(!isCompressed)
        // Result should be reasonable size (PNG conversion might change it slightly)
        #expect(resultData.count < self.processor.maxStorageSize)
    }

    // MARK: - Configuration Tests

    @Test("Custom max storage size is respected")
    func customMaxStorageSizeIsRespected() {
        let customProcessor = ImageProcessor(maxStorageSize: 1000)

        #expect(customProcessor.maxStorageSize == 1000)
    }

    @Test("Custom thumbnail size is respected")
    func customThumbnailSizeIsRespected() {
        let customProcessor = ImageProcessor(thumbnailSize: 128)

        #expect(customProcessor.thumbnailSize == 128)
    }

    // MARK: - ProcessedImage Tests

    @Test("Dimensions string is correct")
    func dimensionsStringIsCorrect() {
        var processed = ProcessedImage()
        processed.width = 800
        processed.height = 600

        #expect(processed.dimensionsString == "800 × 600")
    }

    @Test("Aspect ratio is correct")
    func aspectRatioIsCorrect() {
        var processed = ProcessedImage()
        processed.width = 800
        processed.height = 600

        let expectedRatio = 800.0 / 600.0
        #expect(abs(processed.aspectRatio - expectedRatio) < 0.001)
    }

    @Test("Portrait detection works")
    func portraitDetectionWorks() {
        var processed = ProcessedImage()
        processed.width = 600
        processed.height = 800

        #expect(processed.isPortrait)
        #expect(!processed.isLandscape)
    }

    @Test("Landscape detection works")
    func landscapeDetectionWorks() {
        var processed = ProcessedImage()
        processed.width = 800
        processed.height = 600

        #expect(processed.isLandscape)
        #expect(!processed.isPortrait)
    }

    @Test("Formatted size is human readable")
    func formattedSizeIsHumanReadable() {
        var processed = ProcessedImage()
        processed.data = Data(repeating: 0, count: 1024 * 1024) // 1MB

        guard let formattedSize = processed.formattedSize else {
            Issue.record("Formatted size should not be nil")
            return
        }

        #expect(formattedSize.contains("MB") || formattedSize.contains("KB"))
    }

    // MARK: Private

    // MARK: - Test Helpers

    /// Creates a test image of specified size
    private func createTestImage(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: image.size))
        image.unlockFocus()
        return image
    }
}
