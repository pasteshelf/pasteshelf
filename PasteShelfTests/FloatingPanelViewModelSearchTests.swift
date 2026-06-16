//
//  FloatingPanelViewModelSearchTests.swift
//  PasteShelfTests
//
//  Regression tests for floating-panel search scope: search must span the
//  whole history, not just the recently-loaded window of items.
//

import Foundation
import Testing
@testable import PasteShelf

@MainActor
struct FloatingPanelViewModelSearchTests {
    /// Number of items the panel loads eagerly. Search must reach beyond this.
    private static let recentWindow = 50

    private func makeViewModel() -> (FloatingPanelViewModel, StorageManager) {
        let storage = StorageManager.forTesting()
        let viewModel = FloatingPanelViewModel(storageManager: storage)
        return (viewModel, storage)
    }

    @discardableResult
    private func save(_ storage: StorageManager, text: String, hash: String, secondsAgo: TimeInterval) async -> UUID {
        let id = UUID()
        let content = ClipboardContent(
            id: id,
            timestamp: Date(timeIntervalSinceNow: -secondsAgo),
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: text,
            contentHash: hash
        )
        _ = await storage.save(content: content, from: nil)
        return id
    }

    @Test("Search finds a match older than the recently-loaded window")
    func searchFindsItemOutsideRecentWindow() async {
        let (viewModel, storage) = makeViewModel()

        // One distinctive item, far in the past so it falls outside the window.
        let oldId = await save(storage, text: "zzzuniquemarker needle", hash: "needle", secondsAgo: 1_000_000)

        // Flood with newer filler items so the distinctive one is not loaded.
        for index in 1...(Self.recentWindow + 5) {
            await save(storage, text: "filler item \(index)", hash: "filler_\(index)", secondsAgo: TimeInterval(index))
        }

        // Load the eager window (excludes the old distinctive item).
        await viewModel.loadItems()
        #expect(!viewModel.items.contains { $0.id == oldId }, "Old item should not be in the eager window")

        // Searching must still surface the older match.
        await viewModel.performSearch(query: "zzzuniquemarker")

        #expect(viewModel.items.contains { $0.id == oldId }, "Search should find matches beyond the recent window")
        #expect(viewModel.searchResult(for: oldId) != nil)
    }

    @Test("Search returns only matching items")
    func searchReturnsOnlyMatches() async {
        let (viewModel, storage) = makeViewModel()

        let matchId = await save(storage, text: "alpha distinctword beta", hash: "match", secondsAgo: 500_000)
        for index in 1...10 {
            await save(storage, text: "unrelated \(index)", hash: "u_\(index)", secondsAgo: TimeInterval(index))
        }

        await viewModel.loadItems()
        await viewModel.performSearch(query: "distinctword")

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.id == matchId)
    }

    @Test("Empty query restores all loaded items")
    func emptyQueryRestoresItems() async {
        let (viewModel, storage) = makeViewModel()

        for index in 1...5 {
            await save(storage, text: "item \(index)", hash: "h_\(index)", secondsAgo: TimeInterval(index))
        }

        await viewModel.loadItems()
        let loadedCount = viewModel.items.count
        #expect(loadedCount == 5)

        await viewModel.performSearch(query: "item")
        #expect(!viewModel.items.isEmpty)

        await viewModel.performSearch(query: "")
        #expect(viewModel.items.count == loadedCount)
    }
}
