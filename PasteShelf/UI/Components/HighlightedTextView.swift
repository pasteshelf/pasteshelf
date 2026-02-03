//
//  HighlightedTextView.swift
//  PasteShelf
//
//  Text view that highlights search match ranges.
//  Used to display clipboard item previews with search matches highlighted.
//

import SwiftUI

/// Displays text with highlighted match ranges
struct HighlightedTextView: View {
    // MARK: - Properties

    /// The full text to display
    let text: String

    /// Ranges to highlight
    let matchRanges: [MatchRange]

    /// Maximum number of lines to display
    var lineLimit: Int = 2

    /// Font for the text
    var font: Font = .system(size: 12)

    /// Color for highlighted text background
    var highlightColor: Color = .accentColor.opacity(0.3)

    /// Color for highlighted text foreground
    var highlightForegroundColor: Color? = nil

    // MARK: - Body

    var body: some View {
        if matchRanges.isEmpty {
            // No highlights - simple text
            Text(text)
                .font(font)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        } else {
            // Build attributed string with highlights
            Text(attributedString)
                .font(font)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
    }

    // MARK: - Attributed String

    private var attributedString: AttributedString {
        var result = AttributedString(text)

        // Sort ranges by position (descending) to avoid index shifting
        let sortedRanges = matchRanges.sorted { $0.start > $1.start }

        for range in sortedRanges {
            guard let attrRange = range.attributedStringRange(in: result) else {
                continue
            }

            // Apply highlight background
            result[attrRange].backgroundColor = highlightColor

            // Apply highlight foreground if specified
            if let fgColor = highlightForegroundColor {
                result[attrRange].foregroundColor = fgColor
            }
        }

        return result
    }
}

// MARK: - Convenience Initializers

extension HighlightedTextView {
    /// Creates a highlighted text view from a search result
    init(text: String, searchResult: SearchResult, lineLimit: Int = 2) {
        self.text = text
        matchRanges = searchResult.matchRanges
        self.lineLimit = lineLimit
        font = .system(size: 12)
        highlightColor = .accentColor.opacity(0.3)
        highlightForegroundColor = nil
    }

    /// Creates a highlighted text view with a search query
    /// Automatically finds match ranges in the text
    init(text: String, query: String, lineLimit: Int = 2) {
        self.text = text
        matchRanges = text.findWordMatchRanges(for: query)
        self.lineLimit = lineLimit
        font = .system(size: 12)
        highlightColor = .accentColor.opacity(0.3)
        highlightForegroundColor = nil
    }
}

// MARK: - Static Helpers

extension HighlightedTextView {
    /// Creates an AttributedString with highlights for use in Text views
    static func attributedString(
        for text: String,
        matchRanges: [MatchRange],
        highlightColor: Color = .accentColor.opacity(0.3)
    ) -> AttributedString {
        var result = AttributedString(text)

        let sortedRanges = matchRanges.sorted { $0.start > $1.start }

        for range in sortedRanges {
            guard let attrRange = range.attributedStringRange(in: result) else {
                continue
            }
            result[attrRange].backgroundColor = highlightColor
        }

        return result
    }

    /// Creates an AttributedString with search query highlights
    static func attributedString(
        for text: String,
        query: String,
        highlightColor: Color = .accentColor.opacity(0.3)
    ) -> AttributedString {
        let ranges = text.findWordMatchRanges(for: query)
        return attributedString(for: text, matchRanges: ranges, highlightColor: highlightColor)
    }
}

// MARK: - Preview

#if DEBUG
    struct HighlightedTextView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(alignment: .leading, spacing: 16) {
                // No highlights
                VStack(alignment: .leading) {
                    Text("No Highlights:")
                        .font(.caption).foregroundStyle(.secondary)
                    HighlightedTextView(
                        text: "Hello world, this is a test string.",
                        matchRanges: []
                    )
                }

                // Single highlight
                VStack(alignment: .leading) {
                    Text("Single Match:")
                        .font(.caption).foregroundStyle(.secondary)
                    HighlightedTextView(
                        text: "Hello world, this is a test string.",
                        matchRanges: [
                            MatchRange(start: 6, length: 5, matchedText: "world"),
                        ]
                    )
                }

                // Multiple highlights
                VStack(alignment: .leading) {
                    Text("Multiple Matches:")
                        .font(.caption).foregroundStyle(.secondary)
                    HighlightedTextView(
                        text: "Hello world, this is a test string with hello again.",
                        matchRanges: [
                            MatchRange(start: 0, length: 5, matchedText: "Hello"),
                            MatchRange(start: 38, length: 5, matchedText: "hello"),
                        ]
                    )
                }

                // Query-based highlighting
                VStack(alignment: .leading) {
                    Text("Query-Based (\"hello\"):")
                        .font(.caption).foregroundStyle(.secondary)
                    HighlightedTextView(
                        text: "Hello world, hello again, HELLO!",
                        query: "hello"
                    )
                }

                // Long text with truncation
                VStack(alignment: .leading) {
                    Text("Long Text (2 lines):")
                        .font(.caption).foregroundStyle(.secondary)
                    HighlightedTextView(
                        text: """
                        This is a very long text that spans multiple lines. \
                        It contains the word test multiple times. \
                        Test here and test there, tests everywhere!
                        """,
                        query: "test",
                        lineLimit: 2
                    )
                }
            }
            .padding()
            .frame(width: 350)
        }
    }
#endif
