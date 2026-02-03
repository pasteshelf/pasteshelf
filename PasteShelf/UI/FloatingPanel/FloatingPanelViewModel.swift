//
//  FloatingPanelViewModel.swift
//  PasteShelf
//
//  State management for the floating clipboard history panel.
//  Handles item loading, selection, keyboard navigation, and paste actions.
//

import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for the floating panel displaying clipboard history
@MainActor
final class FloatingPanelViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Clipboard items to display
    @Published private(set) var items: [ClipboardItemDisplayModel] = []

    /// Currently selected item index (-1 for no selection)
    @Published var selectedIndex: Int = -1

    /// Whether the panel is currently visible
    @Published var isVisible: Bool = false

    /// Loading state
    @Published private(set) var isLoading: Bool = false

    /// Error message if something went wrong
    @Published var errorMessage: String?

    // MARK: - Dependencies

    /// Storage manager for fetching items
    private let storageManager: StorageManager

    /// Clipboard monitor for pause/resume during paste
    weak var clipboardMonitor: ClipboardMonitor?

    /// Paste simulator for Cmd+V simulation
    private let pasteSimulator = PasteSimulator()

    // MARK: - Configuration

    /// Maximum number of items to display
    private let maxItems = 50

    // MARK: - Private Properties

    /// Logger for viewmodel operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "panel-vm"
    )

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
    }

    // MARK: - Data Loading

    /// Loads clipboard items from storage
    func loadItems() async {
        isLoading = true
        errorMessage = nil

        let clipboardItems = await storageManager.fetchRecentItems(limit: maxItems)
        items = ClipboardItemDisplayModel.from(clipboardItems)

        // Reset selection if needed
        if selectedIndex >= items.count {
            selectedIndex = items.isEmpty ? -1 : 0
        } else if selectedIndex < 0, !items.isEmpty {
            selectedIndex = 0
        }

        isLoading = false
        logger.debug("Loaded \(self.items.count) items")
    }

    /// Refreshes the items list
    func refresh() async {
        await loadItems()
    }

    // MARK: - Selection

    /// Currently selected item, if any
    var selectedItem: ClipboardItemDisplayModel? {
        guard selectedIndex >= 0, selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }

    /// Selects the previous item in the list
    func selectPrevious() {
        guard !items.isEmpty else { return }

        if selectedIndex <= 0 {
            selectedIndex = items.count - 1 // Wrap to bottom
        } else {
            selectedIndex -= 1
        }
    }

    /// Selects the next item in the list
    func selectNext() {
        guard !items.isEmpty else { return }

        if selectedIndex >= items.count - 1 {
            selectedIndex = 0 // Wrap to top
        } else {
            selectedIndex += 1
        }
    }

    /// Selects an item at a specific index
    func select(at index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
    }

    /// Clears the current selection
    func clearSelection() {
        selectedIndex = -1
    }

    // MARK: - Paste Actions

    /// Pastes the currently selected item
    func pasteSelected() async {
        guard let item = selectedItem else {
            logger.warning("No item selected for paste")
            return
        }
        await paste(item: item)
    }

    /// Pastes a specific item by ID
    func paste(itemId: UUID) async {
        guard let item = items.first(where: { $0.id == itemId }) else {
            logger.warning("Item not found: \(itemId)")
            return
        }
        await paste(item: item)
    }

    /// Pastes the specified item
    func paste(item: ClipboardItemDisplayModel) async {
        logger.info("Pasting item: \(item.id)")

        // Step 1: Pause clipboard monitoring to avoid re-capture
        clipboardMonitor?.pause()

        // Step 2: Copy item content to clipboard
        let success = await copyToClipboard(item: item)
        guard success else {
            clipboardMonitor?.resume()
            errorMessage = "Failed to copy item to clipboard"
            return
        }

        // Step 3: Hide the panel
        isVisible = false

        // Step 4: Simulate paste after a short delay
        try? await Task.sleep(for: .milliseconds(100))
        pasteSimulator.simulatePaste()

        // Step 5: Resume monitoring after paste completes
        try? await Task.sleep(for: .milliseconds(300))
        clipboardMonitor?.resume()

        logger.info("Paste completed for item: \(item.id)")
    }

    /// Copies the item content to the system clipboard
    private func copyToClipboard(item: ClipboardItemDisplayModel) async -> Bool {
        // Fetch the full item from storage to get the actual content
        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let contentData = clipboardItem.content
        else {
            logger.error("Failed to fetch item content: \(item.id)")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write content based on type
        switch item.contentType {
        case .plainText:
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            if let rtfData = contentData.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Also write plain text fallback
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .html:
            if let htmlData = contentData.htmlData {
                pasteboard.setData(htmlData, forType: .html)
            }
            // Also write plain text fallback
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .png, .jpeg, .tiff:
            if let imageData = contentData.imageData,
               let image = NSImage(data: imageData)
            {
                pasteboard.writeObjects([image])
            }
        case .url:
            if let urlString = contentData.textContent,
               let url = URL(string: urlString)
            {
                pasteboard.writeObjects([url as NSURL])
            }
        case .fileURL:
            if let urlString = contentData.textContent,
               let url = URL(string: urlString)
            {
                pasteboard.writeObjects([url as NSURL])
            }
        case .pdf:
            if let pdfData = contentData.pdfData {
                pasteboard.setData(pdfData, forType: .pdf)
            }
        }

        return true
    }

    // MARK: - Visibility

    /// Shows the panel and loads items
    func show() async {
        isVisible = true
        await loadItems()
        if !items.isEmpty, selectedIndex < 0 {
            selectedIndex = 0
        }
    }

    /// Hides the panel
    func hide() {
        isVisible = false
        clearSelection()
    }

    /// Toggles panel visibility
    func toggle() async {
        if isVisible {
            hide()
        } else {
            await show()
        }
    }

    // MARK: - Favorites

    /// Toggles favorite status for the selected item
    func toggleFavorite() async {
        guard let item = selectedItem else { return }

        let result = await storageManager.toggleFavorite(itemId: item.id)
        if result != nil {
            // Update local model
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                // Reload items to get updated state
                await loadItems()
                selectedIndex = index
            }
        }
    }

    // MARK: - Deletion

    /// Deletes the selected item
    func deleteSelected() async {
        guard let item = selectedItem else { return }

        let success = await storageManager.deleteItem(byId: item.id)
        if success {
            // Remove from local list
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
                // Adjust selection
                if selectedIndex >= items.count {
                    selectedIndex = max(0, items.count - 1)
                }
            }
        }
    }
}
