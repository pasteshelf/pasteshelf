#if !APP_STORE
//
    //  NotionPlugin.swift
    //  PasteShelf
//
    //  Built-in Notion integration plugin.
    //  Sends clipboard content to Notion pages/databases.
//

    import AppKit
    import Foundation
    import SwiftUI

    /// Notion plugin - sends content to Notion
    @objc(NotionIntegration)
    public final class NotionPlugin: NSObject, PasteShelfPlugin, PasteShelfPluginWithSettings {
        // MARK: Public

        public func didLoad(with context: any PluginContext) {
            self.context = context
            storage = context.storage
            network = context.network
            context.logger.info("Notion loaded")

            Task { @MainActor in
                registerActions()
            }
        }

        public func willUnload() {
            context?.logger.info("Notion unloading")

            Task { @MainActor in
                PluginUIAPI.shared.unregisterMenuItems(for: Self.identifier)
                PluginActionRegistry.shared.unregisterActions(for: Self.identifier)
            }
        }

        // MARK: - Menu Items

        public func menuItems() -> [PluginMenuItem] {
            [
                PluginMenuItem(
                    title: "Send to Notion",
                    iconName: "doc.text.fill",
                    shortcutKey: "N+command+shift"
                ) { [weak self] content in
                    try await self?.sendToNotion(content)
                },
            ]
        }

        // MARK: - Settings View

        public func settingsView() -> AnyView? {
            AnyView(NotionSettingsView(storage: storage))
        }

        // MARK: Internal

        // MARK: - Plugin Metadata

        static let identifier = "com.pasteshelf.plugins.notion"
        static let name = "Notion"
        static let version = "1.0.0"
        static let supportedTypes: [ContentType] = [.plainText, .url]

        // MARK: - Internal Transform

        /// Transforms content (used internally by plugin system)
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            try await sendToNotion(content)
        }

        /// Checks if content type is supported (used internally by plugin system)
        func supports(contentType: ContentType) -> Bool {
            Self.supportedTypes.contains(contentType)
        }

        // MARK: Private

        // MARK: - State

        private var context: (any PluginContext)?
        private var storage: (any PluginStorage)?
        private var network: (any PluginNetwork)?

        // MARK: - Settings

        private var apiKey: String? {
            storage?.string(forKey: "apiKey")
        }

        private var defaultPageId: String? {
            storage?.string(forKey: "defaultPageId")
        }

        // MARK: - Action Registration

        @MainActor
        private func registerActions() {
            PluginActionRegistry.shared.registerAction(
                pluginId: Self.identifier,
                name: "Send to Notion",
                description: "Add content to a Notion page",
                iconName: "doc.text.fill",
                supportedTypes: [.plainText, .url]
            ) { [weak self] content in
                try await self?.sendToNotion(content)
            }
        }

        // MARK: - Notion Integration

        private func sendToNotion(_ content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            guard let apiKey, !apiKey.isEmpty else {
                throw NotionError.noApiKey
            }

            guard let pageId = defaultPageId, !pageId.isEmpty else {
                throw NotionError.noPageId
            }

            guard let network else {
                throw NotionError.networkPermissionRequired
            }

            // Build content blocks
            let blocks = buildBlocks(from: content)

            // Append blocks to page
            let requestBody = NotionAppendRequest(children: blocks)

            var request = URLRequest(url: URL(string: "https://api.notion.com/v1/blocks/\(pageId)/children")!)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await network.request(request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(NotionErrorResponse.self, from: data) {
                    throw NotionError.apiError(errorResponse.message)
                }
                throw NotionError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // Return success indication
            let result = PluginClipboardContent(text: "Content added to Notion")
            result.metadata["notionPageId"] = pageId
            result.metadata["sentAt"] = ISO8601DateFormatter().string(from: Date())
            return result
        }

        private func buildBlocks(from content: PluginClipboardContent) -> [NotionBlock] {
            var blocks: [NotionBlock] = []

            // Add timestamp header
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            blocks.append(NotionBlock(
                type: "heading_3",
                heading3: NotionHeading(
                    richText: [NotionRichText(text: NotionText(content: "Added from PasteShelf - \(timestamp)"))]
                )
            ))

            // Add main content
            if let text = content.text, !text.isEmpty {
                // Split into paragraphs
                let paragraphs = text.components(separatedBy: "\n\n")
                for paragraph in paragraphs where !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                    blocks.append(NotionBlock(
                        type: "paragraph",
                        paragraph: NotionParagraph(richText: [NotionRichText(text: NotionText(content: paragraph))])
                    ))
                }
            }

            // Add URL if present
            if let url = content.url {
                blocks.append(NotionBlock(
                    type: "bookmark",
                    bookmark: NotionBookmark(url: url.absoluteString)
                ))
            }

            // Add divider
            blocks.append(NotionBlock(type: "divider", divider: NotionDivider()))

            return blocks
        }
    }

    // MARK: - API Models

    private struct NotionAppendRequest: Codable {
        let children: [NotionBlock]
    }

    private struct NotionBlock: Codable {
        enum CodingKeys: String, CodingKey {
            case type
            case heading3 = "heading_3"
            case paragraph
            case bookmark
            case divider
        }

        let type: String
        var heading3: NotionHeading?
        var paragraph: NotionParagraph?
        var bookmark: NotionBookmark?
        var divider: NotionDivider?
    }

    private struct NotionHeading: Codable {
        enum CodingKeys: String, CodingKey {
            case richText = "rich_text"
        }

        let richText: [NotionRichText]
    }

    private struct NotionParagraph: Codable {
        enum CodingKeys: String, CodingKey {
            case richText = "rich_text"
        }

        let richText: [NotionRichText]
    }

    private struct NotionRichText: Codable {
        let text: NotionText
    }

    private struct NotionText: Codable {
        let content: String
    }

    private struct NotionBookmark: Codable {
        let url: String
    }

    private struct NotionDivider: Codable {}

    private struct NotionErrorResponse: Codable {
        let message: String
    }

    // MARK: - Errors

    enum NotionError: Error, LocalizedError {
        case noApiKey
        case noPageId
        case networkPermissionRequired
        case invalidResponse
        case apiError(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .noApiKey:
                "Notion API key not configured. Add your integration token in plugin settings."
            case .noPageId:
                "Default page ID not configured. Add a page ID in plugin settings."
            case .networkPermissionRequired:
                "Network permission is required"
            case .invalidResponse:
                "Invalid response from Notion API"
            case let .apiError(message):
                "Notion API error: \(message)"
            }
        }
    }

    // MARK: - Settings View

    private struct NotionSettingsView: View {
        // MARK: Internal

        let storage: (any PluginStorage)?

        var body: some View {
            Form {
                Section("API Configuration") {
                    HStack {
                        Group {
                            if showApiKey {
                                TextField("Integration Token", text: $apiKey)
                            } else {
                                SecureField("Integration Token", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            showApiKey.toggle()
                        } label: {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    .onChange(of: apiKey) { _, newValue in
                        storage?.setString(newValue, forKey: "apiKey")
                    }

                    Link(
                        "Create an integration at notion.so/my-integrations",
                        destination: URL(string: "https://www.notion.so/my-integrations")!
                    )
                    .font(.caption)
                }

                Section("Default Page") {
                    TextField("Page ID", text: $pageId)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: pageId) { _, newValue in
                            storage?.setString(newValue, forKey: "defaultPageId")
                        }

                    Text("Find the page ID in the URL after opening a page (the 32-character string).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("Make sure to share the page with your integration in Notion.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                apiKey = storage?.string(forKey: "apiKey") ?? ""
                pageId = storage?.string(forKey: "defaultPageId") ?? ""
            }
        }

        // MARK: Private

        @State private var apiKey: String = ""
        @State private var pageId: String = ""
        @State private var showApiKey: Bool = false
    }

#endif
