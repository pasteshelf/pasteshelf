//
//  Deduplicator.swift
//  PasteShelf
//
//  SHA256-based content hashing for clipboard deduplication.
//  Prevents duplicate entries in clipboard history.
//

import CryptoKit
import Foundation

/// Handles content hashing and deduplication using SHA256
final class Deduplicator: Deduplicating, Sendable {
    // MARK: - Deduplicating

    func computeHash(for content: ClipboardContent) -> String {
        var hasher = SHA256()
        hashContent(content, into: &hasher)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Hashes content based on its primary type
    private func hashContent(_ content: ClipboardContent, into hasher: inout SHA256) {
        switch content.primaryType {
        case .plainText:
            hashPlainText(content, into: &hasher)

        case .richText:
            hashRichText(content, into: &hasher)

        case .html:
            hashHTML(content, into: &hasher)

        case .png, .jpeg, .tiff:
            hashImage(content, into: &hasher)

        case .pdf:
            hashPDF(content, into: &hasher)

        case .fileURL:
            hashFileURLs(content, into: &hasher)

        case .url:
            hashURL(content, into: &hasher)
        }
    }

    private func hashPlainText(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let text = content.plainText {
            hashText(text, into: &hasher)
        }
    }

    private func hashRichText(_ content: ClipboardContent, into hasher: inout SHA256) {
        // For RTF, hash the plain text representation for semantic comparison
        if let plainText = content.plainText {
            hashText(plainText, into: &hasher)
        } else if let rtfData = content.rtfData {
            hasher.update(data: rtfData)
        }
    }

    private func hashHTML(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let plainText = content.plainText {
            hashText(plainText, into: &hasher)
        } else if let html = content.html {
            hasher.update(data: Data(html.utf8))
        }
    }

    private func hashImage(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let imageData = content.imageData {
            hasher.update(data: imageData)
        }
    }

    private func hashPDF(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let pdfData = content.pdfData {
            hasher.update(data: pdfData)
        }
    }

    private func hashFileURLs(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let urls = content.fileURLs {
            let paths = urls.map(\.path).sorted().joined(separator: "\n")
            hasher.update(data: Data(paths.utf8))
        }
    }

    private func hashURL(_ content: ClipboardContent, into hasher: inout SHA256) {
        if let url = content.url {
            let normalized = normalizeURL(url)
            hasher.update(data: Data(normalized.utf8))
        }
    }

    func computeHash(forText text: String) -> String {
        var hasher = SHA256()
        hashText(text, into: &hasher)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func isDuplicate(_ content: ClipboardContent, comparing recentHashes: [String]) -> Bool {
        let hash = computeHash(for: content)
        return recentHashes.contains(hash)
    }

    // MARK: - Private Helpers

    /// Hashes text with normalization for consistent comparison
    private func hashText(_ text: String, into hasher: inout SHA256) {
        // Normalize text for consistent hashing
        let normalized = normalizeText(text)
        hasher.update(data: Data(normalized.utf8))
    }

    /// Normalizes text for consistent comparison
    /// - Trims whitespace
    /// - Normalizes line endings to \n
    /// - Applies Unicode normalization (NFC)
    private func normalizeText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCanonicalMapping // NFC normalization
    }

    /// Normalizes URL for consistent hashing
    /// - Lowercases scheme and host
    /// - Removes trailing slashes
    /// - Removes default ports
    private func normalizeURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        // Lowercase scheme and host
        components?.scheme = components?.scheme?.lowercased()
        components?.host = components?.host?.lowercased()

        // Remove default ports
        if let port = components?.port {
            let scheme = components?.scheme ?? ""
            if (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
                components?.port = nil
            }
        }

        // Remove trailing slash from path (except for root)
        if var path = components?.path, path.hasSuffix("/"), path != "/" {
            path.removeLast()
            components?.path = path
        }

        return components?.string ?? url.absoluteString
    }
}

// MARK: - Hash Comparison Options

/// Options for customizing deduplication behavior
struct DeduplicationOptions: Sendable {
    /// Whether to consider whitespace differences as unique content
    var whitespaceSignificant: Bool = false

    /// Whether to consider case differences as unique content
    var caseSensitive: Bool = true

    /// Whether to consider RTF formatting as part of uniqueness
    var formattingSignificant: Bool = false

    /// Default options - semantic comparison only
    static let `default` = DeduplicationOptions()

    /// Strict options - all differences matter
    static let strict = DeduplicationOptions(
        whitespaceSignificant: true,
        caseSensitive: true,
        formattingSignificant: true
    )
}

// MARK: - Configurable Deduplicator

/// Deduplicator with configurable comparison options
final class ConfigurableDeduplicator: Deduplicating, Sendable {
    private let options: DeduplicationOptions
    private let baseDeduplicator = Deduplicator()

    init(options: DeduplicationOptions = .default) {
        self.options = options
    }

    func computeHash(for content: ClipboardContent) -> String {
        // For non-text content, use standard hashing
        guard content.primaryType.isTextType else {
            return baseDeduplicator.computeHash(for: content)
        }

        // Apply options for text content
        guard var text = content.plainText else {
            return baseDeduplicator.computeHash(for: content)
        }

        // Apply transformations based on options
        if !options.whitespaceSignificant {
            // Collapse whitespace
            text = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        if !options.caseSensitive {
            text = text.lowercased()
        }

        return computeHash(forText: text)
    }

    func computeHash(forText text: String) -> String {
        var processedText = text

        if !options.whitespaceSignificant {
            processedText = processedText.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        if !options.caseSensitive {
            processedText = processedText.lowercased()
        }

        return baseDeduplicator.computeHash(forText: processedText)
    }

    func isDuplicate(_ content: ClipboardContent, comparing recentHashes: [String]) -> Bool {
        let hash = computeHash(for: content)
        return recentHashes.contains(hash)
    }
}
