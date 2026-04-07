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

// MARK: - TransformPreset

/// Built-in text transformation presets
enum TransformPreset: String, Codable, CaseIterable { // swiftlint:disable:this type_body_length
    // MARK: - Case Transformations

    /// Convert to UPPERCASE
    case uppercase = "UPPERCASE"

    /// Convert to lowercase
    case lowercase

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

    // MARK: Internal

    /// Human-readable display name
    var displayName: String {
        rawValue
    }

    /// Description of the transformation
    var description: String {
        switch self {
        case .uppercase:
            String(localized: "Convert all letters to uppercase")
        case .lowercase:
            String(localized: "Convert all letters to lowercase")
        case .titleCase:
            String(localized: "Capitalize the first letter of each word")
        case .sentenceCase:
            String(localized: "Capitalize the first letter of each sentence")
        case .trimWhitespace:
            String(localized: "Remove leading and trailing whitespace")
        case .removeNewlines:
            String(localized: "Replace all newlines with spaces")
        case .collapseSpaces:
            String(localized: "Replace multiple spaces with a single space")
        case .removeAllWhitespace:
            String(localized: "Remove all whitespace characters")
        case .sortLines:
            String(localized: "Sort all lines alphabetically")
        case .uniqueLines:
            String(localized: "Remove duplicate lines")
        case .reverseLines:
            String(localized: "Reverse the order of lines")
        case .shuffleLines:
            String(localized: "Randomize the order of lines")
        case .base64Encode:
            String(localized: "Encode text to Base64 format")
        case .base64Decode:
            String(localized: "Decode text from Base64 format")
        case .urlEncode:
            String(localized: "URL-encode special characters")
        case .urlDecode:
            String(localized: "Decode URL-encoded characters")
        case .formatJSON:
            String(localized: "Format JSON with proper indentation")
        case .minifyJSON:
            String(localized: "Remove whitespace from JSON")
        case .escapeHTML:
            String(localized: "Convert HTML special characters to entities")
        case .unescapeHTML:
            String(localized: "Convert HTML entities to characters")
        case .stripHTMLTags:
            String(localized: "Remove all HTML tags from text")
        case .md5Hash:
            String(localized: "Generate MD5 hash of the text")
        case .sha256Hash:
            String(localized: "Generate SHA-256 hash of the text")
        }
    }

    /// SF Symbol icon for the transformation
    var iconName: String {
        switch self {
        case .uppercase,
             .lowercase,
             .titleCase,
             .sentenceCase:
            "textformat"
        case .trimWhitespace,
             .removeNewlines,
             .collapseSpaces,
             .removeAllWhitespace:
            "text.alignleft"
        case .sortLines,
             .uniqueLines,
             .reverseLines,
             .shuffleLines:
            "list.bullet"
        case .base64Encode,
             .base64Decode:
            "01.square"
        case .urlEncode,
             .urlDecode:
            "link"
        case .formatJSON,
             .minifyJSON:
            "curlybraces"
        case .escapeHTML,
             .unescapeHTML,
             .stripHTMLTags:
            "chevron.left.forwardslash.chevron.right"
        case .md5Hash,
             .sha256Hash:
            "number"
        }
    }

    /// Category for grouping in UI
    var category: TransformCategory {
        switch self {
        case .uppercase,
             .lowercase,
             .titleCase,
             .sentenceCase:
            .caseConversion
        case .trimWhitespace,
             .removeNewlines,
             .collapseSpaces,
             .removeAllWhitespace:
            .whitespace
        case .sortLines,
             .uniqueLines,
             .reverseLines,
             .shuffleLines:
            .lines
        case .base64Encode,
             .base64Decode,
             .urlEncode,
             .urlDecode:
            .encoding
        case .formatJSON,
             .minifyJSON:
            .json
        case .escapeHTML,
             .unescapeHTML,
             .stripHTMLTags:
            .html
        case .md5Hash,
             .sha256Hash:
            .hashing
        }
    }

    // MARK: - Transformation

    /// Apply the transformation to the input text
    /// - Parameter input: The text to transform
    /// - Returns: The transformed text, or original if transformation fails
    func transform(_ input: String) -> String { // swiftlint:disable:this cyclomatic_complexity
        switch self {
        // Case transformations
        case .uppercase:
            input.uppercased()

        case .lowercase:
            input.lowercased()

        case .titleCase:
            input.capitalized

        case .sentenceCase:
            transformToSentenceCase(input)

        // Whitespace transformations
        case .trimWhitespace:
            input.trimmingCharacters(in: .whitespacesAndNewlines)

        case .removeNewlines:
            input.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

        case .collapseSpaces:
            collapseMultipleSpaces(input)

        case .removeAllWhitespace:
            input.components(separatedBy: .whitespacesAndNewlines).joined()

        // Line transformations
        case .sortLines:
            input.components(separatedBy: .newlines).sorted().joined(separator: "\n")

        case .uniqueLines:
            uniqueLines(input)

        case .reverseLines:
            input.components(separatedBy: .newlines).reversed().joined(separator: "\n")

        case .shuffleLines:
            input.components(separatedBy: .newlines).shuffled().joined(separator: "\n")

        // Encoding transformations
        case .base64Encode:
            Data(input.utf8).base64EncodedString()

        case .base64Decode:
            decodeBase64(input) ?? input

        case .urlEncode:
            input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input

        case .urlDecode:
            input.removingPercentEncoding ?? input

        // JSON transformations
        case .formatJSON:
            formatJSON(input) ?? input

        case .minifyJSON:
            minifyJSON(input) ?? input

        // HTML transformations
        case .escapeHTML:
            escapeHTML(input)

        case .unescapeHTML:
            unescapeHTML(input)

        case .stripHTMLTags:
            stripHTMLTags(input)

        // Hash transformations
        case .md5Hash:
            md5Hash(input)

        case .sha256Hash:
            sha256Hash(input)
        }
    }

    // MARK: Private

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
        for char in input where ".!?".contains(char) {
            if index < result.count {
                output += result[index]
                index += 1
            }
            output.append(char)
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

        for line in input.components(separatedBy: .newlines) where !seen.contains(line) {
            seen.insert(line)
            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    private func decodeBase64(_ input: String) -> String? {
        guard let data = Data(base64Encoded: input) else {
            return nil
        }
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
        guard let data = input.data(using: .utf8) else {
            return input
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
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

// MARK: - TransformCategory

/// Categories for grouping transform presets in UI
enum TransformCategory: String, CaseIterable {
    case caseConversion = "Case Conversion"
    case whitespace = "Whitespace"
    case lines = "Lines"
    case encoding = "Encoding"
    case json = "JSON"
    case html = "HTML"
    case hashing = "Hashing"

    // MARK: Internal

    /// Display name for the category
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon for the category
    var iconName: String {
        switch self {
        case .caseConversion: "textformat.abc"
        case .whitespace: "space"
        case .lines: "list.bullet"
        case .encoding: "doc.text"
        case .json: "curlybraces"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .hashing: "number"
        }
    }

    /// All presets in this category
    var presets: [TransformPreset] {
        TransformPreset.allCases.filter { $0.category == self }
    }
}
