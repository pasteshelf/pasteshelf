//
//  SearchClipboardIntent.swift
//  PasteShelf
//
//  App Intent for searching clipboard history.
//  Exposes search functionality to Shortcuts.
//

import AppIntents
import Foundation

/// Intent for searching clipboard history
@available(macOS 13.0, *)
struct SearchClipboardIntent: AppIntent {
    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Search Clipboard History"

    static var description = IntentDescription(
        "Search your clipboard history for items matching a query."
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Search clipboard for \(\.$query)") {
            \.$limit
        }
    }

    // MARK: - Parameters

    @Parameter(
        title: "Search Query",
        description: "The text to search for in clipboard history"
    )
    var query: String

    @Parameter(
        title: "Maximum Results",
        description: "Maximum number of results to return",
        default: 10
    )
    var limit: Int

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<[ClipboardItemEntity]> {
        // Check if automation/shortcuts feature is available
        guard await isFeatureAvailable() else {
            throw IntentError.featureNotAvailable
        }

        // Validate query
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IntentError.invalidQuery
        }

        // Search clipboard history
        let results = await ClipboardItemEntity.search(
            query: query,
            limit: max(1, min(limit, 50)) // Clamp between 1 and 50
        )

        return .result(value: results)
    }

    // MARK: - Helpers

    private func isFeatureAvailable() async -> Bool {
        await MainActor.run {
            LicenseManager.shared.isFeatureAvailable(.automation)
        }
    }
}

// MARK: - Intent Errors

@available(macOS 13.0, *)
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case featureNotAvailable
    case invalidQuery
    case itemNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .featureNotAvailable:
            return "This feature requires PasteShelf Pro."
        case .invalidQuery:
            return "Please provide a valid search query."
        case .itemNotFound:
            return "The clipboard item was not found."
        }
    }
}
