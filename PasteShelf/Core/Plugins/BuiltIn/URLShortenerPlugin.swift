//
//  URLShortenerPlugin.swift
//  PasteShelf
//
//  Built-in URL Shortener plugin.
//  Shortens URLs using various services.
//

import AppKit
import Foundation
import SwiftUI

/// URL Shortener plugin - shortens URLs via external APIs
@objc(URLShortener)
public final class URLShortenerPlugin: NSObject, PasteShelfPlugin, PasteShelfPluginWithSettings {
    // MARK: - Plugin Metadata

    static let identifier = "com.pasteshelf.plugins.urlshortener"
    static let name = "URL Shortener"
    static let version = "1.0.0"
    static let supportedTypes: [ContentType] = [.plainText, .url]

    // MARK: - State

    private var context: (any PluginContext)?
    private var storage: (any PluginStorage)?
    private var network: (any PluginNetwork)?

    // MARK: - Settings

    private var selectedService: URLShortenerService {
        let raw = storage?.string(forKey: "service") ?? URLShortenerService.isgd.rawValue
        return URLShortenerService(rawValue: raw) ?? .isgd
    }

    // MARK: - Lifecycle

    public func didLoad(with context: any PluginContext) {
        self.context = context
        self.storage = context.storage
        self.network = context.network
        context.logger.info("URL Shortener loaded")

        Task { @MainActor in
            registerTransformers()
        }
    }

    public func willUnload() {
        context?.logger.info("URL Shortener unloading")

        Task { @MainActor in
            PluginTransformAPI.shared.unregisterTransformers(for: Self.identifier)
            PluginUIAPI.shared.unregisterMenuItems(for: Self.identifier)
        }
    }

    // MARK: - Transformer Registration

    @MainActor
    private func registerTransformers() {
        PluginTransformAPI.shared.registerTransformer(
            pluginId: Self.identifier,
            name: "Shorten URL",
            description: "Shorten a URL using \(selectedService.displayName)",
            supportedTypes: [.plainText, .url],
            iconName: "link.badge.plus"
        ) { [weak self] content in
            try await self?.shortenURL(content)
        }
    }

    // MARK: - Menu Items

    public func menuItems() -> [PluginMenuItem] {
        [
            PluginMenuItem(
                title: "Shorten URL",
                iconName: "link.badge.plus",
                shortcutKey: "L+command+shift"
            ) { [weak self] content in
                try await self?.shortenURL(content)
            }
        ]
    }

    // MARK: - Settings View

    public func settingsView() -> AnyView? {
        AnyView(URLShortenerSettingsView(storage: storage))
    }

    // MARK: - Internal Transform

    /// Transforms content (used internally by plugin system)
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
        try await shortenURL(content)
    }

    /// Checks if content type is supported (used internally by plugin system)
    func supports(contentType: ContentType) -> Bool {
        Self.supportedTypes.contains(contentType)
    }

    // MARK: - URL Shortening

    private func shortenURL(_ content: PluginClipboardContent) async throws -> PluginClipboardContent? {
        // Get URL from content
        let urlString: String
        if let url = content.url {
            urlString = url.absoluteString
        } else if let text = content.text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            urlString = url.absoluteString
        } else {
            throw URLShortenerError.noURLFound
        }

        // Validate URL
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https"
        else {
            throw URLShortenerError.invalidURL
        }

        // Check network permission
        guard let network else {
            throw URLShortenerError.networkPermissionRequired
        }

        // Shorten using selected service
        let shortenedURL = try await shortenWithService(url: url, service: selectedService, network: network)

        let result = PluginClipboardContent(url: shortenedURL)
        result.text = shortenedURL.absoluteString
        result.metadata["originalURL"] = urlString
        result.metadata["shortenerService"] = selectedService.rawValue
        return result
    }

    private func shortenWithService(url: URL, service: URLShortenerService, network: any PluginNetwork) async throws -> URL {
        let request = try service.buildRequest(for: url)
        let (data, response) = try await network.request(request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw URLShortenerError.serviceError("Service returned an error")
        }

        return try service.parseResponse(data: data)
    }
}

// MARK: - Shortener Services

enum URLShortenerService: String, Codable, CaseIterable {
    case isgd = "is.gd"
    case vgd = "v.gd"
    case tinyurl = "tinyurl"

    var displayName: String {
        switch self {
        case .isgd: return "is.gd"
        case .vgd: return "v.gd"
        case .tinyurl: return "TinyURL"
        }
    }

    var apiURL: URL {
        switch self {
        case .isgd:
            return URL(string: "https://is.gd/create.php")!
        case .vgd:
            return URL(string: "https://v.gd/create.php")!
        case .tinyurl:
            return URL(string: "https://tinyurl.com/api-create.php")!
        }
    }

    func buildRequest(for url: URL) throws -> URLRequest {
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!

        switch self {
        case .isgd, .vgd:
            components.queryItems = [
                URLQueryItem(name: "format", value: "simple"),
                URLQueryItem(name: "url", value: url.absoluteString)
            ]
        case .tinyurl:
            components.queryItems = [
                URLQueryItem(name: "url", value: url.absoluteString)
            ]
        }

        guard let finalURL = components.url else {
            throw URLShortenerError.invalidURL
        }

        return URLRequest(url: finalURL)
    }

    func parseResponse(data: Data) throws -> URL {
        guard let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let shortURL = URL(string: responseString)
        else {
            throw URLShortenerError.parseError
        }
        return shortURL
    }
}

// MARK: - Errors

enum URLShortenerError: Error, LocalizedError {
    case noURLFound
    case invalidURL
    case networkPermissionRequired
    case serviceError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noURLFound:
            return "No URL found in clipboard content"
        case .invalidURL:
            return "Invalid URL format"
        case .networkPermissionRequired:
            return "Network permission is required for URL shortening"
        case .serviceError(let message):
            return "Shortener service error: \(message)"
        case .parseError:
            return "Failed to parse shortened URL from response"
        }
    }
}

// MARK: - Settings View

private struct URLShortenerSettingsView: View {
    let storage: (any PluginStorage)?

    @State private var selectedService: URLShortenerService = .isgd

    var body: some View {
        Form {
            Picker("Shortener Service", selection: $selectedService) {
                ForEach(URLShortenerService.allCases, id: \.self) { service in
                    Text(service.displayName).tag(service)
                }
            }
            .onChange(of: selectedService) { _, newValue in
                storage?.setString(newValue.rawValue, forKey: "service")
            }

            Text("URLs are shortened using free public services.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if let raw = storage?.string(forKey: "service"),
               let service = URLShortenerService(rawValue: raw)
            {
                selectedService = service
            }
        }
    }
}
