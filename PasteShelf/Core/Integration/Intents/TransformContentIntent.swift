//
//  TransformContentIntent.swift
//  PasteShelf
//
//  App Intent for transforming text content.
//  Exposes transformation presets to Shortcuts.
//

import AppIntents
import Foundation

// MARK: - TransformContentIntent

/// Intent for transforming text using presets
@available(macOS 13.0, *)
struct TransformContentIntent: AppIntent {
    // MARK: - Intent Metadata

    static var title: LocalizedStringResource = "Transform Text"

    static var description = IntentDescription(
        "Transform text using one of the built-in transformation presets."
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Transform \(\.$text) using \(\.$transformation)")
    }

    // MARK: - Parameters

    @Parameter(
        title: "Text",
        description: "The text to transform"
    )
    var text: String

    @Parameter(
        title: "Transformation",
        description: "The transformation to apply"
    )
    var transformation: TransformationType

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Apply transformation
        let result = self.transformation.preset.transform(self.text)

        return .result(value: result)
    }
}

// MARK: - TransformationType

/// App Intent enum for transformation types
@available(macOS 13.0, *)
enum TransformationType: String, AppEnum, CaseIterable {
    // Case transformations
    case uppercase
    case lowercase
    case titleCase
    case sentenceCase

    // Whitespace transformations
    case trimWhitespace
    case removeNewlines
    case collapseSpaces

    // Line transformations
    case sortLines
    case uniqueLines
    case reverseLines

    // Encoding transformations
    case base64Encode
    case base64Decode
    case urlEncode
    case urlDecode

    // JSON transformations
    case formatJSON
    case minifyJSON

    // HTML transformations
    case escapeHTML
    case unescapeHTML
    case stripHTMLTags

    // Hash transformations
    case md5Hash
    case sha256Hash

    // MARK: Internal

    // MARK: - AppEnum Conformance

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Transformation")
    }

    static var caseDisplayRepresentations: [TransformationType: DisplayRepresentation] {
        [
            // Case transformations
            .uppercase: DisplayRepresentation(
                title: "UPPERCASE",
                subtitle: "Convert to uppercase",
                image: .init(systemName: "textformat")
            ),
            .lowercase: DisplayRepresentation(
                title: "lowercase",
                subtitle: "Convert to lowercase",
                image: .init(systemName: "textformat")
            ),
            .titleCase: DisplayRepresentation(
                title: "Title Case",
                subtitle: "Capitalize each word",
                image: .init(systemName: "textformat")
            ),
            .sentenceCase: DisplayRepresentation(
                title: "Sentence case",
                subtitle: "Capitalize first letter",
                image: .init(systemName: "textformat")
            ),

            // Whitespace transformations
            .trimWhitespace: DisplayRepresentation(
                title: "Trim Whitespace",
                subtitle: "Remove leading/trailing whitespace",
                image: .init(systemName: "text.alignleft")
            ),
            .removeNewlines: DisplayRepresentation(
                title: "Remove Newlines",
                subtitle: "Replace newlines with spaces",
                image: .init(systemName: "text.alignleft")
            ),
            .collapseSpaces: DisplayRepresentation(
                title: "Collapse Spaces",
                subtitle: "Multiple spaces to single",
                image: .init(systemName: "text.alignleft")
            ),

            // Line transformations
            .sortLines: DisplayRepresentation(
                title: "Sort Lines",
                subtitle: "Sort alphabetically",
                image: .init(systemName: "list.bullet")
            ),
            .uniqueLines: DisplayRepresentation(
                title: "Unique Lines",
                subtitle: "Remove duplicates",
                image: .init(systemName: "list.bullet")
            ),
            .reverseLines: DisplayRepresentation(
                title: "Reverse Lines",
                subtitle: "Reverse line order",
                image: .init(systemName: "list.bullet")
            ),

            // Encoding transformations
            .base64Encode: DisplayRepresentation(
                title: "Base64 Encode",
                subtitle: "Encode to Base64",
                image: .init(systemName: "01.square")
            ),
            .base64Decode: DisplayRepresentation(
                title: "Base64 Decode",
                subtitle: "Decode from Base64",
                image: .init(systemName: "01.square")
            ),
            .urlEncode: DisplayRepresentation(
                title: "URL Encode",
                subtitle: "Percent encoding",
                image: .init(systemName: "link")
            ),
            .urlDecode: DisplayRepresentation(
                title: "URL Decode",
                subtitle: "Decode percent encoding",
                image: .init(systemName: "link")
            ),

            // JSON transformations
            .formatJSON: DisplayRepresentation(
                title: "Format JSON",
                subtitle: "Pretty print JSON",
                image: .init(systemName: "curlybraces")
            ),
            .minifyJSON: DisplayRepresentation(
                title: "Minify JSON",
                subtitle: "Compact JSON",
                image: .init(systemName: "curlybraces")
            ),

            // HTML transformations
            .escapeHTML: DisplayRepresentation(
                title: "Escape HTML",
                subtitle: "Convert to entities",
                image: .init(systemName: "chevron.left.forwardslash.chevron.right")
            ),
            .unescapeHTML: DisplayRepresentation(
                title: "Unescape HTML",
                subtitle: "Convert from entities",
                image: .init(systemName: "chevron.left.forwardslash.chevron.right")
            ),
            .stripHTMLTags: DisplayRepresentation(
                title: "Strip HTML Tags",
                subtitle: "Remove HTML markup",
                image: .init(systemName: "chevron.left.forwardslash.chevron.right")
            ),

            // Hash transformations
            .md5Hash: DisplayRepresentation(
                title: "MD5 Hash",
                subtitle: "Generate MD5 hash",
                image: .init(systemName: "number")
            ),
            .sha256Hash: DisplayRepresentation(
                title: "SHA-256 Hash",
                subtitle: "Generate SHA-256 hash",
                image: .init(systemName: "number")
            ),
        ]
    }

    // MARK: - Preset Mapping

    /// Maps to TransformPreset
    var preset: TransformPreset {
        switch self {
        case .uppercase: .uppercase
        case .lowercase: .lowercase
        case .titleCase: .titleCase
        case .sentenceCase: .sentenceCase
        case .trimWhitespace: .trimWhitespace
        case .removeNewlines: .removeNewlines
        case .collapseSpaces: .collapseSpaces
        case .sortLines: .sortLines
        case .uniqueLines: .uniqueLines
        case .reverseLines: .reverseLines
        case .base64Encode: .base64Encode
        case .base64Decode: .base64Decode
        case .urlEncode: .urlEncode
        case .urlDecode: .urlDecode
        case .formatJSON: .formatJSON
        case .minifyJSON: .minifyJSON
        case .escapeHTML: .escapeHTML
        case .unescapeHTML: .unescapeHTML
        case .stripHTMLTags: .stripHTMLTags
        case .md5Hash: .md5Hash
        case .sha256Hash: .sha256Hash
        }
    }
}
