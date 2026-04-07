//
//  ExamplePlugin.swift
//  ExamplePlugin
//
//  A complete example plugin demonstrating the PasteShelfPluginKit SDK.
//  Use this as a template for creating your own plugins.
//
//  Copyright © 2026 PasteShelf. All rights reserved.
//

import AppKit
import Foundation
import PasteShelfPluginKit
import SwiftUI

// MARK: - ExamplePlugin

/// Example plugin that demonstrates common plugin patterns.
///
/// This plugin provides:
/// - Text transformation (reverse text)
/// - Network integration example
/// - Settings view
/// - Menu item registration
///
/// To use as a template:
/// 1. Rename the class and @objc attribute
/// 2. Update the static metadata
/// 3. Replace transformation logic
/// 4. Update Info.plist accordingly
@objc(ExamplePlugin)
public final class ExamplePlugin: NSObject, PasteShelfPlugin, PasteShelfPluginExtended, PasteShelfPluginWithSettings {
    // MARK: Public

    // MARK: - Plugin Metadata

    /// Unique identifier for this plugin (reverse-DNS format)
    public static let identifier = "com.pasteshelf.plugins.example"

    /// Display name shown in UI
    public static let name = "Example Plugin"

    /// Semantic version
    public static let version = "1.0.0"

    /// Content types this plugin can handle
    public static let supportedTypes: [ContentType] = [.plainText]

    /// Called when PasteShelf loads this plugin.
    ///
    /// Store the context reference and perform any initialization here.
    public func didLoad(with context: any PluginContext) {
        self.context = context

        // Log that we loaded successfully
        context.logger.info("\(Self.name) v\(Self.version) loaded")
        context.logger.debug("Host version: \(context.hostVersion)")

        // Initialize default settings if needed
        self.initializeDefaultSettings()
    }

    /// Called before PasteShelf unloads this plugin.
    ///
    /// Clean up any resources here.
    public func willUnload() {
        self.context?.logger.info("\(Self.name) unloading")

        // Cancel any pending operations
        // Release any resources
    }

    // MARK: - Menu Items

    /// Returns menu items for the PasteShelf UI.
    ///
    /// These appear in the plugin menu and context menus.
    public func menuItems() -> [PluginMenuItem] {
        [
            // Main action with keyboard shortcut
            PluginMenuItem(
                title: "Reverse Text",
                iconName: "arrow.left.arrow.right",
                shortcutKey: "R+command+shift"
            ) { [weak self] content in
                try await self?.transform(content: content)
            },

            // Secondary action without shortcut
            PluginMenuItem(
                title: "Reverse Without Prefix",
                iconName: "arrow.left.arrow.right"
            ) { [weak self] content in
                try await self?.reverseText(content, addPrefix: false)
            },
        ]
    }

    // MARK: - Settings View

    /// Returns the SwiftUI settings view for this plugin.
    public func settingsView() -> AnyView? {
        AnyView(ExamplePluginSettingsView(storage: self.storage))
    }

    // MARK: - Transform Protocol

    /// Main transformation method.
    ///
    /// This is called when the user invokes the plugin's primary action.
    public func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
        try await self.reverseText(content, addPrefix: self.addPrefix)
    }

    /// Check if we support the given content type.
    public func supports(contentType: ContentType) -> Bool {
        Self.supportedTypes.contains(contentType)
    }

    // MARK: Private

    // MARK: - State

    /// Reference to the plugin context (stored from didLoad)
    private var context: (any PluginContext)?

    /// Convenience accessor for storage
    private var storage: (any PluginStorage)? {
        self.context?.storage
    }

    // MARK: - Settings

    /// User preference: whether to add prefix to output
    private var addPrefix: Bool {
        self.storage?.bool(forKey: "addPrefix") ?? true
    }

    /// User preference: custom prefix text
    private var prefixText: String {
        self.storage?.string(forKey: "prefixText") ?? "[Reversed] "
    }

    // MARK: - Settings Initialization

    private func initializeDefaultSettings() {
        // Only set defaults if they haven't been set before
        guard let storage else {
            return
        }

        if storage.string(forKey: "prefixText") == nil {
            storage.setString("[Reversed] ", forKey: "prefixText")
        }
    }

    // MARK: - Core Logic

    /// Reverses the text content.
    private func reverseText(_ content: PluginClipboardContent,
                             addPrefix: Bool) async throws -> PluginClipboardContent?
    {
        // Validate input
        guard let text = content.text, !text.isEmpty else {
            self.context?.logger.warning("No text content to reverse")
            throw ExamplePluginError.noContent
        }

        self.context?.logger.debug("Reversing text of length \(text.count)")

        // Perform the transformation
        let reversed = String(text.reversed())

        // Build result with optional prefix
        let outputText = addPrefix ? "\(prefixText)\(reversed)" : reversed

        // Create result content
        let result = PluginClipboardContent(text: outputText)

        // Add metadata for debugging/tracking
        result.metadata["originalLength"] = text.count
        result.metadata["transformedBy"] = Self.identifier
        result.metadata["transformedAt"] = ISO8601DateFormatter().string(from: Date())

        self.context?.logger.info("Text reversed successfully")
        return result
    }
}

// MARK: - ExamplePluginError

/// Errors that can occur in this plugin.
enum ExamplePluginError: Error, LocalizedError {
    case noContent
    case transformationFailed(String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .noContent:
            "No text content to process. Copy some text first."
        case let .transformationFailed(reason):
            "Transformation failed: \(reason)"
        }
    }
}

// MARK: - ExamplePluginSettingsView

/// SwiftUI settings view for the plugin.
private struct ExamplePluginSettingsView: View {
    // MARK: Internal

    let storage: (any PluginStorage)?

    var body: some View {
        Form {
            Section("Output Options") {
                Toggle("Add prefix to output", isOn: self.$addPrefix)
                    .onChange(of: self.addPrefix) { _, newValue in
                        self.storage?.setBool(newValue, forKey: "addPrefix")
                    }

                if self.addPrefix {
                    TextField("Prefix text", text: self.$prefixText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: self.prefixText) { _, newValue in
                            self.storage?.setString(newValue, forKey: "prefixText")
                        }
                }
            }

            Section {
                Text("This example plugin reverses text content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            self.loadSettings()
        }
    }

    // MARK: Private

    @State private var addPrefix: Bool = true
    @State private var prefixText: String = "[Reversed] "

    private func loadSettings() {
        self.addPrefix = self.storage?.bool(forKey: "addPrefix") ?? true
        self.prefixText = self.storage?.string(forKey: "prefixText") ?? "[Reversed] "
    }
}

// MARK: - Preview

#if DEBUG
    struct ExamplePluginSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            ExamplePluginSettingsView(storage: nil)
                .frame(width: 400)
                .padding()
        }
    }
#endif
