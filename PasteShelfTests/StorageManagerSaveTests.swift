//
//  StorageManagerSaveTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager save operations.
//

@testable import PasteShelf
import CoreData
import XCTest

final class StorageManagerSaveTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = await MainActor.run { StorageManager.forTesting() }
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Clipboard Content Save Tests

    func testSaveClipboardContent() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Hello, World!",
            contentHash: "abc123"
        )

        let result = await storageManager.save(content: content, from: nil)
        XCTAssertTrue(result)

        let count = await storageManager.totalItemCount()
        XCTAssertEqual(count, 1)
    }

    func testSaveClipboardContentWithSourceApp() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "From Safari",
            contentHash: "safari123"
        )
        let sourceApp = SourceApp(bundleId: "com.apple.Safari", name: "Safari")

        let result = await storageManager.save(content: content, from: sourceApp)
        XCTAssertTrue(result)

        let items = await storageManager.fetchRecentItems(limit: 1)
        XCTAssertEqual(items.first?.sourceAppBundleId, "com.apple.Safari")
        XCTAssertEqual(items.first?.sourceAppName, "Safari")
    }

    func testSaveSensitiveContent() async {
        var content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "password123",
            contentHash: "sensitive123"
        )
        content.isSensitive = true

        let result = await storageManager.save(content: content, from: nil)
        XCTAssertTrue(result)

        let items = await storageManager.fetchRecentItems(limit: 1)
        XCTAssertTrue(items.first?.isSensitive ?? false)
    }

    // MARK: - Tag Save Tests

    func testSaveTag() async {
        let tag = await storageManager.saveTag(name: "Important", color: "#FF0000")

        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.name, "Important")
        XCTAssertEqual(tag?.color, "#FF0000")
    }

    func testSaveMultipleTags() async {
        let tags = await storageManager.saveTags([
            (name: "Work", color: "#0000FF"),
            (name: "Personal", color: "#00FF00")
        ])

        XCTAssertEqual(tags.count, 2)
    }

    // MARK: - Folder Save Tests

    func testSaveFolder() async {
        let folder = await storageManager.saveFolder(name: "Projects", icon: "folder.fill")

        XCTAssertNotNil(folder)
        XCTAssertEqual(folder?.name, "Projects")
        XCTAssertEqual(folder?.icon, "folder.fill")
    }

    func testSaveNestedFolder() async {
        let parent = await storageManager.saveFolder(name: "Parent")
        XCTAssertNotNil(parent)

        let child = await storageManager.saveFolder(name: "Child", icon: nil, parent: parent)
        XCTAssertNotNil(child)

        let folders = await storageManager.fetchFolders()
        // Only root folders are returned
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Parent")
    }

    // MARK: - Application Save Tests

    func testSaveApplication() async {
        let app = await storageManager.saveApplication(
            bundleId: "com.example.app",
            name: "Example App",
            isExcluded: true
        )

        XCTAssertNotNil(app)
        XCTAssertEqual(app?.bundleId, "com.example.app")
        XCTAssertTrue(app?.isExcluded ?? false)
    }

    func testUpdateApplicationExclusion() async {
        _ = await storageManager.saveApplication(
            bundleId: "com.example.app",
            name: "Example App",
            isExcluded: false
        )

        // Update the same app
        let updated = await storageManager.saveApplication(
            bundleId: "com.example.app",
            name: "Example App",
            isExcluded: true
        )

        XCTAssertTrue(updated?.isExcluded ?? false)
    }

    // MARK: - Fetch Recent Hashes Tests

    func testFetchRecentHashes() async {
        let content1 = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "First",
            contentHash: "hash_first"
        )
        let content2 = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Second",
            contentHash: "hash_second"
        )

        _ = await storageManager.save(content: content1, from: nil)
        _ = await storageManager.save(content: content2, from: nil)

        let hashes = await storageManager.fetchRecentHashes(limit: 10)
        XCTAssertEqual(hashes.count, 2)
        XCTAssertTrue(hashes.contains("hash_first"))
        XCTAssertTrue(hashes.contains("hash_second"))
    }

    func testFetchRecentHashesRespectLimit() async {
        for i in 1...10 {
            let content = ClipboardContent(
                primaryType: .plainText,
                availableTypes: [.plainText],
                plainText: "Item \(i)",
                contentHash: "hash_\(i)"
            )
            _ = await storageManager.save(content: content, from: nil)
        }

        let hashes = await storageManager.fetchRecentHashes(limit: 5)
        XCTAssertEqual(hashes.count, 5)
    }
}
