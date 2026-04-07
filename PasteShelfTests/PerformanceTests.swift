// swiftlint:disable single_test_class
//
//  PerformanceTests.swift
//  PasteShelfTests
//
//  Performance tests for critical operations.
//

@testable import PasteShelf
import XCTest

// MARK: - PerformanceTests

final class PerformanceTests: XCTestCase {
    // MARK: Internal

    // MARK: - Fuzzy Search Performance Tests

    func testFuzzySearchPerformance_smallDataset() {
        let matcher = FuzzyMatcher(threshold: 0.6)
        let items = generateTestItems(count: 100)

        measure {
            for item in items {
                _ = matcher.matches(item, query: "tset")
            }
        }
    }

    func testFuzzySearchPerformance_largeDataset() {
        let matcher = FuzzyMatcher(threshold: 0.6)
        let items = generateTestItems(count: 500)

        measure {
            for item in items {
                _ = matcher.matches(item, query: "clipbord")
            }
        }
    }

    // MARK: - Deduplication Performance Tests

    func testDeduplicationPerformance_hashComputation() {
        let deduplicator = Deduplicator()
        let items = generateTestItems(count: 1000)

        measure {
            for item in items {
                _ = deduplicator.computeHash(forText: item)
            }
        }
    }

    func testDeduplicationPerformance_duplicateCheck() {
        let deduplicator = Deduplicator()
        let existingHashes = (0 ..< 1000).map { _ in UUID().uuidString }
        let items = generateTestItems(count: 100)

        measure {
            autoreleasepool {
                for item in items {
                    var content = ClipboardContent(primaryType: .plainText)
                    content.plainText = item
                    _ = deduplicator.isDuplicate(content, comparing: existingHashes)
                }
            }
        }
    }

    // MARK: - Image Processing Performance Tests

    func testImageThumbnailGeneration_small() {
        let processor = ImageProcessor(thumbnailSize: 128)
        let testImage = createTestImage(size: NSSize(width: 200, height: 200))

        measure {
            for _ in 0 ..< 100 {
                _ = processor.generateThumbnail(testImage)
            }
        }
    }

    func testImageThumbnailGeneration_medium() {
        let processor = ImageProcessor(thumbnailSize: 256)
        let testImage = createTestImage(size: NSSize(width: 1000, height: 1000))

        measure {
            for _ in 0 ..< 50 {
                _ = processor.generateThumbnail(testImage)
            }
        }
    }

    func testImageThumbnailGeneration_large() {
        let processor = ImageProcessor(thumbnailSize: 256)
        let testImage = createTestImage(size: NSSize(width: 4000, height: 3000))

        measure {
            for _ in 0 ..< 10 {
                _ = processor.generateThumbnail(testImage)
            }
        }
    }

    // MARK: - Sensitive Data Detection Performance Tests

    func testSensitiveDataDetection_smallText() {
        let detector = SensitiveDataDetector()
        let texts = (0 ..< 100).map { _ in "This is a simple text without sensitive data \(UUID().uuidString)" }

        measure {
            for text in texts {
                _ = detector.analyze(text: text)
            }
        }
    }

    func testSensitiveDataDetection_largeText() {
        let detector = SensitiveDataDetector()
        let largeText = String(repeating: "This is some text with potential data 4532-1234-5678-9012 ", count: 100)

        measure {
            for _ in 0 ..< 50 {
                _ = detector.analyze(text: largeText)
            }
        }
    }

    // MARK: - Settings Performance Tests

    func testSettingsEncode() {
        let settings = AppSettings.default
        let encoder = JSONEncoder()

        measure {
            for _ in 0 ..< 1000 {
                _ = try? encoder.encode(settings)
            }
        }
    }

    func testSettingsDecode() throws {
        let settings = AppSettings.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let decoder = JSONDecoder()

        measure {
            for _ in 0 ..< 1000 {
                _ = try? decoder.decode(AppSettings.self, from: data)
            }
        }
    }

    // MARK: Private

    // MARK: - Helper Methods

    private func generateTestItems(count: Int) -> [String] {
        let words = [
            "clipboard", "manager", "paste", "copy", "test", "item",
            "search", "query", "result", "filter", "favorite", "history",
        ]

        return (0 ..< count).map { _ in
            let wordCount = Int.random(in: 5 ... 20)
            return (0 ..< wordCount)
                .compactMap { _ in words.randomElement() }
                .joined(separator: " ")
        }
    }

    private func createTestImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}

// MARK: - MemoryTests

final class MemoryTests: XCTestCase {
    /// Test that image processing doesn't leak memory
    func testImageProcessingMemoryUsage() {
        let processor = ImageProcessor(thumbnailSize: 256)

        for _ in 0 ..< 10 {
            autoreleasepool {
                let image = NSImage(size: NSSize(width: 1000, height: 1000))
                image.lockFocus()
                NSColor.red.setFill()
                NSRect(origin: .zero, size: image.size).fill()
                image.unlockFocus()

                _ = processor.generateThumbnail(image)
            }
        }
    }

    /// Test that clipboard content objects don't leak
    func testClipboardContentMemoryUsage() {
        for _ in 0 ..< 100 {
            autoreleasepool {
                var content = ClipboardContent(primaryType: .plainText)
                content.plainText = String(repeating: "x", count: 10000)

                // Create and discard - check plainText property
                _ = content.plainText
            }
        }
    }
}
