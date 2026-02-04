//
//  CopyToClipboardIntent.swift
//  PasteShelf
//
//  App Intent for copying items to the system clipboard.
//  Allows Shortcuts to copy specific items from history.
//

import AppIntents
import AppKit
import CoreData
import Foundation

/// Intent for copying a clipboard item to the system clipboard
@available(macOS 13.0, *)
struct CopyToClipboardIntent: AppIntent {
    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Copy to Clipboard"

    static var description = IntentDescription(
        "Copy a clipboard item from your history to the system clipboard."
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Copy \(\.$item) to clipboard")
    }

    // MARK: - Parameters

    @Parameter(
        title: "Clipboard Item",
        description: "The item to copy to the clipboard"
    )
    var item: ClipboardItemEntity

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        // Check if automation/shortcuts feature is available
        guard await isFeatureAvailable() else {
            throw IntentError.featureNotAvailable
        }

        // Copy the item to clipboard
        let success = await copyItemToClipboard(id: item.id)

        if !success {
            throw IntentError.itemNotFound
        }

        return .result()
    }

    // MARK: - Helpers

    private func isFeatureAvailable() async -> Bool {
        await MainActor.run {
            LicenseManager.shared.isFeatureAvailable(.automation)
        }
    }

    private func copyItemToClipboard(id: UUID) async -> Bool {
        let context = await MainActor.run { StorageManager.shared.viewContext }

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                guard let item = try context.fetch(fetchRequest).first else {
                    return false
                }

                // Get the content
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()

                // Copy based on content type
                if let contentData = item.content {
                    // Try to copy text content
                    if let urlString = contentData.urlString {
                        pasteboard.setString(urlString, forType: .string)
                        return true
                    }

                    if let html = contentData.htmlContent {
                        pasteboard.setString(html, forType: .html)
                        // Also set as plain text fallback
                        if let plainText = item.plainTextPreview {
                            pasteboard.setString(plainText, forType: .string)
                        }
                        return true
                    }

                    if let rtfData = contentData.rtfData {
                        pasteboard.setData(rtfData, forType: .rtf)
                        // Also set as plain text fallback
                        if let plainText = item.plainTextPreview {
                            pasteboard.setString(plainText, forType: .string)
                        }
                        return true
                    }

                    if let imageData = contentData.imageData,
                       let image = NSImage(data: imageData)
                    {
                        pasteboard.writeObjects([image])
                        return true
                    }
                }

                // Fallback to plain text
                if let plainText = item.plainTextPreview {
                    pasteboard.setString(plainText, forType: .string)
                    return true
                }

                return false
            } catch {
                return false
            }
        }
    }
}

/// Intent for copying text directly to clipboard
@available(macOS 13.0, *)
struct CopyTextToClipboardIntent: AppIntent {
    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Copy Text to Clipboard"

    static var description = IntentDescription(
        "Copy the specified text to the system clipboard."
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Copy \(\.$text) to clipboard")
    }

    // MARK: - Parameters

    @Parameter(
        title: "Text",
        description: "The text to copy to the clipboard"
    )
    var text: String

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        // Check if automation/shortcuts feature is available
        guard await isFeatureAvailable() else {
            throw IntentError.featureNotAvailable
        }

        // Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        return .result()
    }

    // MARK: - Helpers

    private func isFeatureAvailable() async -> Bool {
        await MainActor.run {
            LicenseManager.shared.isFeatureAvailable(.automation)
        }
    }
}
