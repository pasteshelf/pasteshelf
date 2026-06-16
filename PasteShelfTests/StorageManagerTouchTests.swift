//
//  StorageManagerTouchTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager move-to-top (touchItem) operations.
//

@testable import PasteShelf
import CoreData
import XCTest

final class StorageManagerTouchTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = await MainActor.run { StorageManager.forTesting() }
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Saves an item with an explicit id, hash, and timestamp.
    @discardableResult
    private func saveItem(id: UUID = UUID(), hash: String, secondsAgo: TimeInterval, text: String = "text") async -> UUID {
        let content = ClipboardContent(
            id: id,
            timestamp: Date(timeIntervalSinceNow: -secondsAgo),
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: text,
            contentHash: hash
        )
        _ = await storageManager.save(content: content, from: nil)
        return id
    }

    private func fetchOrderedIds() async -> [UUID] {
        let items = await storageManager.fetchRecentItems(limit: 50)
        return items.compactMap(\.id)
    }

    // MARK: - touchItem(byHash:)

    func testTouchByHashMovesItemToTop() async {
        let oldId = await saveItem(hash: "old", secondsAgo: 10_000, text: "oldest")
        await saveItem(hash: "mid", secondsAgo: 5_000, text: "middle")
        await saveItem(hash: "new", secondsAgo: 1_000, text: "newest")

        // Sanity: oldest is last before touching.
        var ordered = await fetchOrderedIds()
        XCTAssertEqual(ordered.last, oldId)

        let updated = await storageManager.touchItem(byHash: "old")
        XCTAssertTrue(updated)

        // After touch, the oldest item should sort to the top.
        ordered = await fetchOrderedIds()
        XCTAssertEqual(ordered.first, oldId)
    }

    func testTouchByHashUpdatesSourceApp() async {
        let id = await saveItem(hash: "h", secondsAgo: 1_000)

        // Originally captured with no source app.
        let before = await storageManager.fetchItem(byId: id)
        XCTAssertNil(before?.sourceAppBundleId)

        let browser = SourceApp(bundleId: "com.apple.Safari", name: "Safari")
        let updated = await storageManager.touchItem(byHash: "h", sourceApp: browser)
        XCTAssertTrue(updated)

        let after = await storageManager.fetchItem(byId: id)
        XCTAssertEqual(after?.sourceAppBundleId, "com.apple.Safari")
        XCTAssertEqual(after?.sourceAppName, "Safari")
    }

    func testTouchByHashWithoutSourceLeavesSourceUnchanged() async {
        let terminal = SourceApp(bundleId: "com.apple.Terminal", name: "Terminal")
        let id = UUID()
        let content = ClipboardContent(
            id: id,
            timestamp: Date(timeIntervalSinceNow: -1_000),
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "text",
            contentHash: "keep"
        )
        _ = await storageManager.save(content: content, from: terminal)

        // No sourceApp passed → source must be preserved.
        _ = await storageManager.touchItem(byHash: "keep")

        let after = await storageManager.fetchItem(byId: id)
        XCTAssertEqual(after?.sourceAppBundleId, "com.apple.Terminal")
    }

    func testTouchByHashReturnsFalseForUnknownHash() async {
        await saveItem(hash: "exists", secondsAgo: 1_000)

        let updated = await storageManager.touchItem(byHash: "does-not-exist")
        XCTAssertFalse(updated)
    }

    func testTouchByHashRefreshesTimestamp() async {
        let id = await saveItem(hash: "stale", secondsAgo: 10_000)

        let before = await storageManager.fetchItem(byId: id)?.timestamp
        XCTAssertNotNil(before)

        _ = await storageManager.touchItem(byHash: "stale")

        let after = await storageManager.fetchItem(byId: id)?.timestamp
        XCTAssertNotNil(after)
        XCTAssertGreaterThan(after!, before!)
    }

    // MARK: - touchItem(byId:)

    func testTouchByIdMovesItemToTop() async {
        let oldId = await saveItem(hash: "a", secondsAgo: 10_000, text: "a")
        await saveItem(hash: "b", secondsAgo: 5_000, text: "b")
        await saveItem(hash: "c", secondsAgo: 1_000, text: "c")

        let updated = await storageManager.touchItem(byId: oldId)
        XCTAssertTrue(updated)

        let ordered = await fetchOrderedIds()
        XCTAssertEqual(ordered.first, oldId)
    }

    func testTouchByIdReturnsFalseForUnknownId() async {
        await saveItem(hash: "a", secondsAgo: 1_000)

        let updated = await storageManager.touchItem(byId: UUID())
        XCTAssertFalse(updated)
    }

    func testTouchDoesNotCreateDuplicate() async {
        let id = await saveItem(hash: "only", secondsAgo: 1_000)

        let countBefore = await storageManager.totalItemCount()
        _ = await storageManager.touchItem(byId: id)
        let countAfter = await storageManager.totalItemCount()

        XCTAssertEqual(countBefore, countAfter, "Touching an item must not add a record")
    }
}
