//
//  GetClipboardHistoryIntent.swift
//  PasteShelf
//
//  App Intent for getting clipboard history.
//  Returns recent clipboard items for use in Shortcuts.
//

import AppIntents
import Foundation

/// Intent for getting recent clipboard history
@available(macOS 13.0, *)
struct GetClipboardHistoryIntent: AppIntent {
    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Get Clipboard History"

    static var description = IntentDescription(
        LocalizedStringResource("Get the most recent items from your clipboard history.")
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$count) recent clipboard items") {
            \.$favoritesOnly
        }
    }

    // MARK: - Parameters

    @Parameter(
        title: "Number of Items",
        description: "How many items to return",
        default: 10
    )
    var count: Int

    @Parameter(
        title: "Favorites Only",
        description: "Only return favorite items",
        default: false
    )
    var favoritesOnly: Bool

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<[ClipboardItemEntity]> {
        // Clamp count between 1 and 100
        let limitedCount = max(1, min(count, 100))

        // Fetch items
        let results: [ClipboardItemEntity]
        if favoritesOnly {
            results = await ClipboardItemEntity.fetchFavorites(limit: limitedCount)
        } else {
            results = await ClipboardItemEntity.fetchRecent(limit: limitedCount)
        }

        return .result(value: results)
    }

}
