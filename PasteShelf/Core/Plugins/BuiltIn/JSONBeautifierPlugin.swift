#if !APP_STORE
//
    //  JSONBeautifierPlugin.swift
    //  PasteShelf
//
    //  Built-in JSON Beautifier plugin.
    //  Formats, minifies, and validates JSON content.
//

    import AppKit
    import Foundation
    import SwiftUI

    /// JSON Beautifier plugin - formats and minifies JSON
    @objc(JSONBeautifier)
    public final class JSONBeautifierPlugin: NSObject, PasteShelfPlugin, PasteShelfPluginWithSettings {
        // MARK: Public

        public func didLoad(with context: any PluginContext) {
            self.context = context
            self.storage = context.storage
            context.logger.info("JSON Beautifier loaded")

            // Register transformers
            Task { @MainActor in
                self.registerTransformers()
            }
        }

        public func willUnload() {
            self.context?.logger.info("JSON Beautifier unloading")

            // Unregister transformers
            Task { @MainActor in
                PluginTransformAPI.shared.unregisterTransformers(for: Self.identifier)
                PluginUIAPI.shared.unregisterMenuItems(for: Self.identifier)
            }
        }

        // MARK: - Menu Items

        public func menuItems() -> [PluginMenuItem] {
            [
                PluginMenuItem(
                    title: "Format JSON",
                    iconName: "curlybraces",
                    shortcutKey: "J+command+shift"
                ) { [weak self] content in
                    try await self?.formatJSON(content)
                },
                PluginMenuItem(
                    title: "Minify JSON",
                    iconName: "arrow.down.right.and.arrow.up.left"
                ) { [weak self] content in
                    try await self?.minifyJSON(content)
                },
                PluginMenuItem(
                    title: "Validate JSON",
                    iconName: "checkmark.circle"
                ) { [weak self] content in
                    try await self?.validateJSON(content)
                },
            ]
        }

        // MARK: - Settings View

        public func settingsView() -> AnyView? {
            AnyView(JSONBeautifierSettingsView(storage: self.storage))
        }

        // MARK: Internal

        // MARK: - Plugin Metadata

        static let identifier = "com.pasteshelf.plugins.jsonbeautifier"
        static let name = "JSON Beautifier"
        static let version = "1.0.0"
        static let supportedTypes: [ContentType] = [.plainText]

        // MARK: - Internal Transform

        /// Transforms content (used internally by plugin system)
        @MainActor
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            try self.formatJSON(content)
        }

        /// Checks if content type is supported (used internally by plugin system)
        func supports(contentType: ContentType) -> Bool {
            Self.supportedTypes.contains(contentType)
        }

        // MARK: Private

        // MARK: - State

        private var context: (any PluginContext)?
        private var storage: (any PluginStorage)?

        // MARK: - Settings

        private var indentSize: Int {
            let size = self.storage?.integer(forKey: "indentSize") ?? 4
            return size > 0 ? size : 4
        }

        private var sortKeys: Bool {
            self.storage?.bool(forKey: "sortKeys") ?? true
        }

        // MARK: - Transformer Registration

        @MainActor
        private func registerTransformers() {
            // Format JSON transformer
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "Format JSON",
                description: "Pretty-print JSON with indentation",
                supportedTypes: [.plainText],
                iconName: "curlybraces"
            ) { [weak self] content in
                try await self?.formatJSON(content)
            }

            // Minify JSON transformer
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "Minify JSON",
                description: "Remove whitespace from JSON",
                supportedTypes: [.plainText],
                iconName: "arrow.down.right.and.arrow.up.left"
            ) { [weak self] content in
                try await self?.minifyJSON(content)
            }

            // Validate JSON transformer
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "Validate JSON",
                description: "Check if content is valid JSON",
                supportedTypes: [.plainText],
                iconName: "checkmark.circle"
            ) { [weak self] content in
                try await self?.validateJSON(content)
            }
        }

        // MARK: - JSON Operations

        @MainActor
        private func formatJSON(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            guard let text = content.text else {
                return nil
            }

            let data = Data(text.utf8)
            let json: Any
            do {
                json = try JSONSerialization.jsonObject(with: data)
            } catch {
                return PluginClipboardContent(text: "Invalid JSON: \(error.localizedDescription)")
            }

            var options: JSONSerialization.WritingOptions = [.prettyPrinted]
            if self.sortKeys {
                options.insert(.sortedKeys)
            }

            let formatted = try JSONSerialization.data(withJSONObject: json, options: options)

            guard var formattedString = String(data: formatted, encoding: .utf8) else {
                return nil
            }

            // Apply custom indent size if not 2
            if self.indentSize != 2 {
                formattedString = self.adjustIndentation(formattedString, size: self.indentSize)
            }

            let result = PluginClipboardContent(text: formattedString)
            result.metadata["jsonFormatted"] = true
            return result
        }

        @MainActor
        private func minifyJSON(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            guard let text = content.text else {
                return nil
            }

            let data = Data(text.utf8)
            let json: Any
            do {
                json = try JSONSerialization.jsonObject(with: data)
            } catch {
                return PluginClipboardContent(text: "Invalid JSON: \(error.localizedDescription)")
            }
            let minified = try JSONSerialization.data(withJSONObject: json)

            guard let minifiedString = String(data: minified, encoding: .utf8) else {
                return nil
            }

            let result = PluginClipboardContent(text: minifiedString)
            result.metadata["jsonMinified"] = true
            return result
        }

        @MainActor
        private func validateJSON(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            guard let text = content.text else {
                return nil
            }

            let data = Data(text.utf8)

            do {
                _ = try JSONSerialization.jsonObject(with: data)
                let result = PluginClipboardContent(text: "Valid JSON")
                result.metadata["jsonValid"] = true
                return result
            } catch {
                let result = PluginClipboardContent(text: "Invalid JSON: \(error.localizedDescription)")
                result.metadata["jsonValid"] = false
                return result
            }
        }

        // MARK: - Helpers

        private func adjustIndentation(_ json: String, size: Int) -> String {
            let lines = json.components(separatedBy: .newlines)
            return lines
                .map { line in
                    // Count leading spaces
                    let leadingSpaces = line.prefix { $0 == " " }.count
                    let indentLevel = leadingSpaces / 2 // Default is 2 spaces
                    let newIndent = String(repeating: " ", count: indentLevel * size)
                    return newIndent + line.dropFirst(leadingSpaces)
                }
                .joined(separator: "\n")
        }
    }

    // MARK: - Errors

    enum JSONPluginError: Error, LocalizedError {
        case invalidJSON(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .invalidJSON(reason):
                "Invalid JSON: \(reason)"
            }
        }
    }

    // MARK: - Settings View

    private struct JSONBeautifierSettingsView: View {
        // MARK: Internal

        let storage: (any PluginStorage)?

        var body: some View {
            Form {
                Picker("Indent Size", selection: self.$indentSize) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("Tab").tag(0)
                }
                .onChange(of: self.indentSize) { _, newValue in
                    self.storage?.setInteger(newValue, forKey: "indentSize")
                }

                Toggle("Sort Keys Alphabetically", isOn: self.$sortKeys)
                    .onChange(of: self.sortKeys) { _, newValue in
                        self.storage?.setBool(newValue, forKey: "sortKeys")
                    }
            }
            .onAppear {
                self.indentSize = self.storage?.integer(forKey: "indentSize") ?? 2
                if self.indentSize == 0 {
                    self.indentSize = 2
                }
                self.sortKeys = self.storage?.bool(forKey: "sortKeys") ?? true
            }
        }

        // MARK: Private

        @State private var indentSize: Int = 2
        @State private var sortKeys: Bool = true
    }

#endif
