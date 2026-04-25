//
//  TransformPreset.swift
//  PasteShelf
//
//  Built-in text transformation presets for automation actions.
//  Each preset provides a specific text manipulation function.
//

import AppKit
import CryptoKit
import Foundation

// MARK: - Transform Preset

/// Built-in text transformation presets
enum TransformPreset: String, Codable, CaseIterable, Sendable {
    // MARK: - Case Transformations

    /// Convert to UPPERCASE
    case uppercase = "UPPERCASE"

    /// Convert to lowercase
    case lowercase = "lowercase"

    /// Convert to Title Case
    case titleCase = "Title Case"

    /// Convert to Sentence case
    case sentenceCase = "Sentence case"

    // MARK: - Whitespace Transformations

    /// Remove leading/trailing whitespace
    case trimWhitespace = "Trim Whitespace"

    /// Remove all newlines
    case removeNewlines = "Remove Newlines"

    /// Collapse multiple spaces to single
    case collapseSpaces = "Collapse Spaces"

    /// Remove all whitespace
    case removeAllWhitespace = "Remove All Whitespace"

    // MARK: - Line Transformations

    /// Sort lines alphabetically
    case sortLines = "Sort Lines"

    /// Remove duplicate lines
    case uniqueLines = "Unique Lines"

    /// Reverse line order
    case reverseLines = "Reverse Lines"

    /// Shuffle lines randomly
    case shuffleLines = "Shuffle Lines"

    // MARK: - Encoding Transformations

    /// Encode to Base64
    case base64Encode = "Base64 Encode"

    /// Decode from Base64
    case base64Decode = "Base64 Decode"

    /// URL encode (percent encoding)
    case urlEncode = "URL Encode"

    /// URL decode
    case urlDecode = "URL Decode"

    // MARK: - JSON Transformations

    /// Pretty-print JSON
    case formatJSON = "Format JSON"

    /// Minify JSON (remove whitespace)
    case minifyJSON = "Minify JSON"

    // MARK: - HTML Transformations

    /// Escape HTML entities
    case escapeHTML = "Escape HTML"

    /// Unescape HTML entities
    case unescapeHTML = "Unescape HTML"

    /// Strip HTML tags
    case stripHTMLTags = "Strip HTML Tags"

    // MARK: - Hash Transformations

    /// Generate MD5 hash
    case md5Hash = "MD5 Hash"

    /// Generate SHA-256 hash
    case sha256Hash = "SHA-256 Hash"

    // MARK: - Properties

    /// Human-readable display name (English; used for logs and tests)
    var displayName: String {
        rawValue
    }

    /// Localized display name key (use in SwiftUI views)
    var displayNameKey: LocalizedStringResource {
        switch self {
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .sentenceCase: return "Sentence case"
        case .trimWhitespace: return "Trim Whitespace"
        case .removeNewlines: return "Remove Newlines"
        case .collapseSpaces: return "Collapse Spaces"
        case .removeAllWhitespace: return "Remove All Whitespace"
        case .sortLines: return "Sort Lines"
        case .uniqueLines: return "Unique Lines"
        case .reverseLines: return "Reverse Lines"
        case .shuffleLines: return "Shuffle Lines"
        case .base64Encode: return "Base64 Encode"
        case .base64Decode: return "Base64 Decode"
        case .urlEncode: return "URL Encode"
        case .urlDecode: return "URL Decode"
        case .formatJSON: return "Format JSON"
        case .minifyJSON: return "Minify JSON"
        case .escapeHTML: return "Escape HTML"
        case .unescapeHTML: return "Unescape HTML"
        case .stripHTMLTags: return "Strip HTML Tags"
        case .md5Hash: return "MD5 Hash"
        case .sha256Hash: return "SHA-256 Hash"
        }
    }

    /// Description of the transformation
    var description: String {
        switch self {
        case .uppercase:
            return String(localized: "Convert all letters to uppercase")
        case .lowercase:
            return String(localized: "Convert all letters to lowercase")
        case .titleCase:
            return String(localized: "Capitalize the first letter of each word")
        case .sentenceCase:
            return String(localized: "Capitalize the first letter of each sentence")
        case .trimWhitespace:
            return String(localized: "Remove leading and trailing whitespace")
        case .removeNewlines:
            return String(localized: "Replace all newlines with spaces")
        case .collapseSpaces:
            return String(localized: "Replace multiple spaces with a single space")
        case .removeAllWhitespace:
            return String(localized: "Remove all whitespace characters")
        case .sortLines:
            return String(localized: "Sort all lines alphabetically")
        case .uniqueLines:
            return String(localized: "Remove duplicate lines")
        case .reverseLines:
            return String(localized: "Reverse the order of lines")
        case .shuffleLines:
            return String(localized: "Randomize the order of lines")
        case .base64Encode:
            return String(localized: "Encode text to Base64 format")
        case .base64Decode:
            return String(localized: "Decode text from Base64 format")
        case .urlEncode:
            return String(localized: "URL-encode special characters")
        case .urlDecode:
            return String(localized: "Decode URL-encoded characters")
        case .formatJSON:
            return String(localized: "Format JSON with proper indentation")
        case .minifyJSON:
            return String(localized: "Remove whitespace from JSON")
        case .escapeHTML:
            return String(localized: "Convert HTML special characters to entities")
        case .unescapeHTML:
            return String(localized: "Convert HTML entities to characters")
        case .stripHTMLTags:
            return String(localized: "Remove all HTML tags from text")
        case .md5Hash:
            return String(localized: "Generate MD5 hash of the text")
        case .sha256Hash:
            return String(localized: "Generate SHA-256 hash of the text")
        }
    }

    /// SF Symbol icon for the transformation
    var iconName: String {
        switch self {
        case .uppercase, .lowercase, .titleCase, .sentenceCase:
            return "textformat"
        case .trimWhitespace, .removeNewlines, .collapseSpaces, .removeAllWhitespace:
            return "text.alignleft"
        case .sortLines, .uniqueLines, .reverseLines, .shuffleLines:
            return "list.bullet"
        case .base64Encode, .base64Decode:
            return "01.square"
        case .urlEncode, .urlDecode:
            return "link"
        case .formatJSON, .minifyJSON:
            return "curlybraces"
        case .escapeHTML, .unescapeHTML, .stripHTMLTags:
            return "chevron.left.forwardslash.chevron.right"
        case .md5Hash, .sha256Hash:
            return "number"
        }
    }

    /// Category for grouping in UI
    var category: TransformCategory {
        switch self {
        case .uppercase, .lowercase, .titleCase, .sentenceCase:
            return .caseConversion
        case .trimWhitespace, .removeNewlines, .collapseSpaces, .removeAllWhitespace:
            return .whitespace
        case .sortLines, .uniqueLines, .reverseLines, .shuffleLines:
            return .lines
        case .base64Encode, .base64Decode, .urlEncode, .urlDecode:
            return .encoding
        case .formatJSON, .minifyJSON:
            return .json
        case .escapeHTML, .unescapeHTML, .stripHTMLTags:
            return .html
        case .md5Hash, .sha256Hash:
            return .hashing
        }
    }

    // MARK: - Transformation

    /// Apply the transformation to the input text
    /// - Parameter input: The text to transform
    /// - Returns: The transformed text, or original if transformation fails
    func transform(_ input: String) -> String {
        switch self {
        // Case transformations
        case .uppercase:
            return input.uppercased()

        case .lowercase:
            return input.lowercased()

        case .titleCase:
            return input.capitalized

        case .sentenceCase:
            return transformToSentenceCase(input)

        // Whitespace transformations
        case .trimWhitespace:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)

        case .removeNewlines:
            return input.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

        case .collapseSpaces:
            return collapseMultipleSpaces(input)

        case .removeAllWhitespace:
            return input.components(separatedBy: .whitespacesAndNewlines).joined()

        // Line transformations
        case .sortLines:
            return input.components(separatedBy: .newlines).sorted().joined(separator: "\n")

        case .uniqueLines:
            return uniqueLines(input)

        case .reverseLines:
            return input.components(separatedBy: .newlines).reversed().joined(separator: "\n")

        case .shuffleLines:
            return input.components(separatedBy: .newlines).shuffled().joined(separator: "\n")

        // Encoding transformations
        case .base64Encode:
            return Data(input.utf8).base64EncodedString()

        case .base64Decode:
            return decodeBase64(input) ?? input

        case .urlEncode:
            return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input

        case .urlDecode:
            return input.removingPercentEncoding ?? input

        // JSON transformations
        case .formatJSON:
            return formatJSON(input) ?? input

        case .minifyJSON:
            return minifyJSON(input) ?? input

        // HTML transformations
        case .escapeHTML:
            return escapeHTML(input)

        case .unescapeHTML:
            return unescapeHTML(input)

        case .stripHTMLTags:
            return stripHTMLTags(input)

        // Hash transformations
        case .md5Hash:
            return md5Hash(input)

        case .sha256Hash:
            return sha256Hash(input)
        }
    }

    // MARK: - Private Helpers

    private func transformToSentenceCase(_ input: String) -> String {
        let sentences = input.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var result: [String] = []

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let first = trimmed.prefix(1).uppercased()
                let rest = trimmed.dropFirst().lowercased()
                result.append(first + rest)
            }
        }

        // Reconstruct with original separators
        var output = ""
        var index = 0
        for char in input {
            if ".!?".contains(char) {
                if index < result.count {
                    output += result[index]
                    index += 1
                }
                output.append(char)
            }
        }

        // Add any remaining sentence
        if index < result.count {
            output += result[index]
        }

        return output.isEmpty ? input : output
    }

    private func collapseMultipleSpaces(_ input: String) -> String {
        var result = input
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }

    private func uniqueLines(_ input: String) -> String {
        var seen = Set<String>()
        var result: [String] = []

        for line in input.components(separatedBy: .newlines) {
            if !seen.contains(line) {
                seen.insert(line)
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    private func decodeBase64(_ input: String) -> String? {
        guard let data = Data(base64Encoded: input) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func formatJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(
                  withJSONObject: json,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let result = String(data: formatted, encoding: .utf8)
        else {
            return nil
        }
        return result
    }

    private func minifyJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let minified = try? JSONSerialization.data(withJSONObject: json, options: []),
              let result = String(data: minified, encoding: .utf8)
        else {
            return nil
        }
        return result
    }

    private func escapeHTML(_ input: String) -> String {
        var result = input
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }

    private func unescapeHTML(_ input: String) -> String {
        var result = input
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }

    private func stripHTMLTags(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return input }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback: regex-based stripping
        return input.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }

    private func md5Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Transform Category

/// Categories for grouping transform presets in UI
enum TransformCategory: String, CaseIterable, Sendable {
    case caseConversion = "Case Conversion"
    case whitespace = "Whitespace"
    case lines = "Lines"
    case encoding = "Encoding"
    case json = "JSON"
    case html = "HTML"
    case hashing = "Hashing"

    /// Display name for the category
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon for the category
    var iconName: String {
        switch self {
        case .caseConversion: return "textformat.abc"
        case .whitespace: return "space"
        case .lines: return "list.bullet"
        case .encoding: return "doc.text"
        case .json: return "curlybraces"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .hashing: return "number"
        }
    }

    /// All presets in this category
    var presets: [TransformPreset] {
        TransformPreset.allCases.filter { $0.category == self }
    }
}
