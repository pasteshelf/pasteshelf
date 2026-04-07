//
//  NaturalLanguageQueryParser.swift
//  PasteShelf
//
//  Parses natural language queries to extract structured search parameters.
//  Handles time references ("last week"), content hints ("image", "code"),
//  and app hints ("from Safari").
//

import Foundation

// MARK: - ParsedQuery

/// Parsed query containing extracted filters and the semantic search text
struct ParsedQuery: Equatable {
    /// Date range extracted from time references
    let dateRange: DateRange?

    /// Content type hints extracted from the query
    let contentTypeHints: Set<ContentType>

    /// Source app name hints extracted from the query
    let sourceAppHints: [String]

    /// The remaining text for semantic search (without filter phrases)
    let semanticText: String

    /// Original query text
    let originalQuery: String

    /// Whether any filters were extracted
    var hasFilters: Bool {
        dateRange != nil || !contentTypeHints.isEmpty || !sourceAppHints.isEmpty
    }
}

// MARK: - NaturalLanguageQueryParser

/// Parses natural language queries to extract search filters
enum NaturalLanguageQueryParser {
    // MARK: Internal

    // MARK: - Parsing

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Parses a natural language query into structured components
    /// - Parameter query: The raw query string
    /// - Returns: A ParsedQuery with extracted filters and semantic text
    static func parse(_ query: String) -> ParsedQuery {
        let lowercaseQuery = query.lowercased()
        var remainingText = query
        var dateRange: DateRange?
        var contentTypeHints: Set<ContentType> = []
        var sourceAppHints: [String] = []

        // Extract time references
        for (pattern, rangeFn) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseQuery.startIndex..., in: lowercaseQuery)
                if let match = regex.firstMatch(in: lowercaseQuery, options: [], range: range) {
                    dateRange = rangeFn()

                    // Handle numeric patterns (e.g., "last 3 days")
                    if match.numberOfRanges > 2 {
                        if let numRange = Range(match.range(at: 2), in: lowercaseQuery) {
                            if let num = Int(lowercaseQuery[numRange]) {
                                if pattern.contains("days") {
                                    dateRange = lastNDays(num)
                                } else if pattern.contains("hours") {
                                    dateRange = lastNHours(num)
                                }
                            }
                        }
                    }

                    // Remove matched phrase from remaining text
                    if let matchRange = Range(match.range, in: remainingText) {
                        remainingText.removeSubrange(matchRange)
                    }
                    break // Only use first time reference
                }
            }
        }

        // Extract content type hints
        for (keyword, types) in contentTypeKeywords {
            let keywordPattern = "\\b\(keyword)s?\\b"
            if let regex = try? NSRegularExpression(pattern: keywordPattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseQuery.startIndex..., in: lowercaseQuery)
                if regex.firstMatch(in: lowercaseQuery, options: [], range: range) != nil {
                    contentTypeHints.formUnion(types)
                    // Don't remove content type keywords - they're useful for semantic search
                }
            }
        }

        // Extract app references
        for pattern in appPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseQuery.startIndex..., in: lowercaseQuery)
                regex.enumerateMatches(in: lowercaseQuery, options: [], range: range) { match, _, _ in
                    guard let match,
                          match.numberOfRanges > 1,
                          let appRange = Range(match.range(at: 1), in: lowercaseQuery)
                    else {
                        return
                    }

                    let appName = String(lowercaseQuery[appRange])

                    // Map common names to actual app names
                    if let mappings = appNameMappings[appName] {
                        sourceAppHints.append(contentsOf: mappings)
                    } else {
                        // Use as-is with capitalization
                        sourceAppHints.append(appName.capitalized)
                    }

                    // Remove the "from [app]" phrase from remaining text
                    if let fullMatchRange = Range(match.range, in: remainingText) {
                        remainingText.removeSubrange(fullMatchRange)
                    }
                }
            }
        }

        // Clean up remaining text
        let semanticText = remainingText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return ParsedQuery(
            dateRange: dateRange,
            contentTypeHints: contentTypeHints,
            sourceAppHints: Array(Set(sourceAppHints)), // Remove duplicates
            semanticText: semanticText,
            originalQuery: query
        )
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    // MARK: Private

    // MARK: - Time Reference Patterns

    /// Pattern matches for time references
    private static let timePatterns: [(pattern: String, dateRange: () -> DateRange)] = [
        // Today/yesterday
        ("\\btoday\\b", { .today }),
        ("\\byesterday\\b", { yesterday() }),

        // Relative days
        ("\\b(last|past)\\s+(\\d+)\\s+days?\\b", { lastNDays(7) }), // Default handled in regex
        ("\\bthis\\s+week\\b", { thisWeek() }),
        ("\\blast\\s+week\\b", { .lastWeek }),
        ("\\bpast\\s+week\\b", { .lastWeek }),

        // Relative months
        ("\\bthis\\s+month\\b", { thisMonth() }),
        ("\\blast\\s+month\\b", { .lastMonth }),
        ("\\bpast\\s+month\\b", { .lastMonth }),

        // Hour-based
        ("\\b(last|past)\\s+hour\\b", { lastNHours(1) }),
        ("\\b(last|past)\\s+(\\d+)\\s+hours?\\b", { lastNHours(1) }), // Default handled in regex
    ]

    // MARK: - Content Type Patterns

    /// Keywords that indicate content types
    private static let contentTypeKeywords: [String: Set<ContentType>] = [
        // Text types
        "text": [.plainText],
        "code": [.plainText],
        "snippet": [.plainText],
        "script": [.plainText],
        "function": [.plainText],

        // Rich text
        "email": [.richText, .html, .plainText],
        "document": [.richText, .html, .plainText],
        "formatted": [.richText],

        // Images
        "image": [.png, .jpeg, .tiff],
        "photo": [.png, .jpeg, .tiff],
        "picture": [.png, .jpeg, .tiff],
        "screenshot": [.png, .jpeg, .tiff],

        // URLs
        "link": [.url],
        "url": [.url],
        "website": [.url],

        // Files
        "file": [.fileURL],
        "folder": [.fileURL],
        "path": [.fileURL],

        // PDF
        "pdf": [.pdf],
    ]

    // MARK: - App Reference Patterns

    /// Pattern for "from [App]" references
    private static let appPatterns: [String] = [
        "\\bfrom\\s+(\\w+)\\b",
        "\\bin\\s+(\\w+)\\b",
        "\\bcopied\\s+from\\s+(\\w+)\\b",
    ]

    /// Common app name mappings
    private static let appNameMappings: [String: [String]] = [
        "safari": ["Safari", "com.apple.Safari"],
        "chrome": ["Google Chrome", "com.google.Chrome"],
        "firefox": ["Firefox", "org.mozilla.firefox"],
        "vscode": ["Visual Studio Code", "com.microsoft.VSCode"],
        "code": ["Visual Studio Code", "com.microsoft.VSCode"],
        "xcode": ["Xcode", "com.apple.dt.Xcode"],
        "slack": ["Slack", "com.tinyspeck.slackmacgap"],
        "notes": ["Notes", "com.apple.Notes"],
        "mail": ["Mail", "com.apple.mail"],
        "terminal": ["Terminal", "com.apple.Terminal"],
        "finder": ["Finder", "com.apple.finder"],
        "notion": ["Notion", "notion.id"],
        "teams": ["Microsoft Teams", "com.microsoft.teams"],
        "discord": ["Discord", "com.hnc.Discord"],
    ]

    // MARK: - Date Range Helpers

    private static func yesterday() -> DateRange {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: today)
            ?? today
        return DateRange(start: yesterdayDate, end: today)
    }

    private static func thisWeek() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? now
        return DateRange(start: weekStart, end: now)
    }

    private static func thisMonth() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now
        return DateRange(start: monthStart, end: now)
    }

    private static func lastNDays(_ dayCount: Int) -> DateRange {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -dayCount, to: end)
            ?? end
        return DateRange(start: start, end: end)
    }

    private static func lastNHours(_ hourCount: Int) -> DateRange {
        let end = Date()
        let start = Date(timeIntervalSinceNow: TimeInterval(-hourCount * 3600))
        return DateRange(start: start, end: end)
    }
}
