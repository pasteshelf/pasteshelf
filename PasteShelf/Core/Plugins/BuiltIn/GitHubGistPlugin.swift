#if !APP_STORE
//
    //  GitHubGistPlugin.swift
    //  PasteShelf
//
    //  Built-in GitHub Gist plugin.
    //  Creates gists from clipboard content.
//

    import AppKit
    import Foundation
    import SwiftUI

    /// GitHub Gist plugin - creates gists from clipboard content
    @objc(GitHubGist)
    public final class GitHubGistPlugin: NSObject, PasteShelfPlugin, PasteShelfPluginWithSettings {
        // MARK: Public

        public func didLoad(with context: any PluginContext) {
            self.context = context
            self.storage = context.storage
            self.network = context.network
            context.logger.info("GitHub Gist loaded")

            Task { @MainActor in
                self.registerActions()
            }
        }

        public func willUnload() {
            self.context?.logger.info("GitHub Gist unloading")

            Task { @MainActor in
                PluginUIAPI.shared.unregisterMenuItems(for: Self.identifier)
                PluginActionRegistry.shared.unregisterActions(for: Self.identifier)
            }
        }

        // MARK: - Menu Items

        public func menuItems() -> [PluginMenuItem] {
            [
                PluginMenuItem(
                    title: "Create Gist",
                    iconName: "square.and.arrow.up",
                    shortcutKey: "G+command+shift"
                ) { [weak self] content in
                    try await self?.createGist(content)
                },
                PluginMenuItem(
                    title: "Create Public Gist",
                    iconName: "globe"
                ) { [weak self] content in
                    try await self?.createGist(content, isPublic: true)
                },
            ]
        }

        // MARK: - Settings View

        public func settingsView() -> AnyView? {
            AnyView(GitHubGistSettingsView(storage: self.storage))
        }

        // MARK: Internal

        // MARK: - Plugin Metadata

        static let identifier = "com.pasteshelf.plugins.githubgist"
        static let name = "GitHub Gist"
        static let version = "1.0.0"
        static let supportedTypes: [ContentType] = [.plainText]

        // MARK: - Internal Transform

        /// Transforms content (used internally by plugin system)
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            try await self.createGist(content)
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

        private var githubToken: String? {
            self.storage?.string(forKey: "githubToken")
        }

        private var defaultPublic: Bool {
            self.storage?.bool(forKey: "defaultPublic") ?? false
        }

        // MARK: - Action Registration

        @MainActor
        private func registerActions() {
            PluginActionRegistry.shared.registerAction(
                pluginId: Self.identifier,
                name: "Create Gist",
                description: "Create a GitHub Gist from clipboard content",
                iconName: "square.and.arrow.up",
                supportedTypes: [.plainText]
            ) { [weak self] content in
                try await self?.createGist(content)
            }
        }

        // MARK: - Gist Creation

        private func createGist(_ content: PluginClipboardContent,
                                isPublic: Bool? = nil) async throws -> PluginClipboardContent?
        {
            guard let text = content.text, !text.isEmpty else {
                throw GitHubGistError.noContent
            }

            guard let token = githubToken, !token.isEmpty else {
                throw GitHubGistError.noToken
            }

            guard let network else {
                throw GitHubGistError.networkPermissionRequired
            }

            // Detect file extension from content
            let filename = self.detectFilename(from: text)

            // Build request
            let gistRequest = GistCreateRequest(
                description: "Created with PasteShelf",
                isPublic: isPublic ?? self.defaultPublic,
                files: [filename: GistFile(content: text)]
            )

            guard let gistAPIURL = URL(string: "https://api.github.com/gists") else {
                return nil
            }
            var request = URLRequest(url: gistAPIURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(gistRequest)

            let (data, response) = try await network.request(request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubGistError.invalidResponse
            }

            guard httpResponse.statusCode == 201 else {
                if let errorResponse = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data) {
                    throw GitHubGistError.apiError(errorResponse.message)
                }
                throw GitHubGistError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let gistResponse = try JSONDecoder().decode(GistCreateResponse.self, from: data)

            // Return URL to the created gist
            guard let gistURL = URL(string: gistResponse.htmlURL) else {
                return nil
            }
            let result = PluginClipboardContent(url: gistURL)
            result.text = gistResponse.htmlURL
            result.metadata["gistId"] = gistResponse.id
            result.metadata["originalContent"] = text
            return result
        }

        private func detectFilename(from content: String) -> String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to detect programming language
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                if (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil {
                    return "data.json"
                }
            }

            if trimmed.contains("func ") || trimmed.contains("import Foundation") || trimmed.contains("struct ") {
                return "code.swift"
            }

            if trimmed.contains("def ") || trimmed.contains("import ") {
                return "code.py"
            }

            if trimmed.contains("function ") || trimmed.contains("const ") || trimmed.contains("let ") {
                return "code.js"
            }

            if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
                return "page.html"
            }

            if trimmed.hasPrefix("#") || trimmed.contains("```") {
                return "document.md"
            }

            return "snippet.txt"
        }
    }

    // MARK: - API Models

    private struct GistCreateRequest: Codable {
        enum CodingKeys: String, CodingKey {
            case description
            case isPublic = "public"
            case files
        }

        let description: String
        let isPublic: Bool
        let files: [String: GistFile]
    }

    private struct GistFile: Codable {
        let content: String
    }

    private struct GistCreateResponse: Codable {
        enum CodingKeys: String, CodingKey {
            case id
            case htmlURL = "html_url"
        }

        let id: String
        let htmlURL: String
    }

    private struct GitHubErrorResponse: Codable {
        let message: String
    }

    // MARK: - Errors

    enum GitHubGistError: Error, LocalizedError {
        case noContent
        case noToken
        case networkPermissionRequired
        case invalidResponse
        case apiError(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .noContent:
                "No text content to create gist from"
            case .noToken:
                "GitHub token not configured. Add your token in plugin settings."
            case .networkPermissionRequired:
                "Network permission is required"
            case .invalidResponse:
                "Invalid response from GitHub API"
            case let .apiError(message):
                "GitHub API error: \(message)"
            }
        }
    }

    // MARK: - Settings View

    private struct GitHubGistSettingsView: View {
        // MARK: Internal

        let storage: (any PluginStorage)?

        var body: some View {
            Form {
                Section {
                    HStack {
                        Group {
                            if self.showToken {
                                TextField("Personal Access Token", text: self.$token)
                            } else {
                                SecureField("Personal Access Token", text: self.$token)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            self.showToken.toggle()
                        } label: {
                            Image(systemName: self.showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    .onChange(of: self.token) { _, newValue in
                        self.storage?.setString(newValue, forKey: "githubToken")
                    }

                    Link(
                        "Create a token with 'gist' scope",
                        destination: URL(
                            string: "https://github.com/settings/tokens/new?scopes=gist&description=PasteShelf"
                        )! // swiftlint:disable:this force_unwrapping
                    )
                    .font(.caption)
                }

                Section {
                    Toggle("Create public gists by default", isOn: self.$defaultPublic)
                        .onChange(of: self.defaultPublic) { _, newValue in
                            self.storage?.setBool(newValue, forKey: "defaultPublic")
                        }
                }
            }
            .onAppear {
                self.token = self.storage?.string(forKey: "githubToken") ?? ""
                self.defaultPublic = self.storage?.bool(forKey: "defaultPublic") ?? false
            }
        }

        // MARK: Private

        @State private var token: String = ""
        @State private var defaultPublic: Bool = false
        @State private var showToken: Bool = false
    }

#endif
