//
//  DateGroup.swift
//  PasteShelf
//
//  Represents date groupings for organizing clipboard items.
//  Used for section headers in the floating panel.
//

import Foundation

// MARK: - DateGroup

/// Represents a date-based grouping category
enum DateGroup: String, CaseIterable, Identifiable, Comparable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case older

    // MARK: Internal

    var id: String {
        rawValue
    }

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .lastWeek: "Last Week"
        case .thisMonth: "This Month"
        case .older: "Older"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .today: "clock"
        case .yesterday: "arrow.counterclockwise"
        case .thisWeek,
             .lastWeek: "calendar"
        case .thisMonth: "calendar.circle"
        case .older: "archivebox"
        }
    }

    // MARK: - Sorting

    /// Sort order (0 = most recent)
    var sortOrder: Int {
        switch self {
        case .today: 0
        case .yesterday: 1
        case .thisWeek: 2
        case .lastWeek: 3
        case .thisMonth: 4
        case .older: 5
        }
    }

    static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    // MARK: - Date Classification

    /// Determines the date group for a given date
    /// - Parameter date: The date to classify
    /// - Returns: The appropriate DateGroup
    static func from(_ date: Date) -> DateGroup {
        let calendar = Calendar.current
        let now = Date()

        // Today
        if calendar.isDateInToday(date) {
            return .today
        }

        // Yesterday
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }

        // This week (but not today/yesterday)
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return .thisWeek
        }

        // Last week
        if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
           calendar.isDate(date, equalTo: lastWeekStart, toGranularity: .weekOfYear)
        {
            return .lastWeek
        }

        // This month (but not this/last week)
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return .thisMonth
        }

        // Older
        return .older
    }

    /// Checks if a date falls within this group
    /// - Parameter date: The date to check
    /// - Returns: True if the date belongs to this group
    func contains(_ date: Date) -> Bool {
        DateGroup.from(date) == self
    }
}

// MARK: - DateGroupedSection

/// A section of items grouped by date
struct DateGroupedSection<Item: Identifiable>: Identifiable {
    let group: DateGroup
    let items: [Item]

    var id: String {
        self.group.id
    }

    var isEmpty: Bool {
        self.items.isEmpty
    }

    var count: Int {
        self.items.count
    }
}

// MARK: - Array Extension

extension [ClipboardItemDisplayModel] {
    /// Groups items by date
    /// - Returns: Array of DateGroupedSection sorted by date (most recent first)
    func groupedByDate() -> [DateGroupedSection<ClipboardItemDisplayModel>] {
        let grouped = Dictionary(grouping: self) { item in
            DateGroup.from(item.timestamp)
        }

        return DateGroup.allCases
            .compactMap { group -> DateGroupedSection<ClipboardItemDisplayModel>? in
                guard let items = grouped[group], !items.isEmpty else {
                    return nil
                }
                // Sort items within group by timestamp (most recent first)
                let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
                return DateGroupedSection(group: group, items: sortedItems)
            }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension DateGroup {
        /// Sample dates for each group
        static var sampleDates: [DateGroup: Date] {
            let calendar = Calendar.current
            let now = Date()
            return [
                .today: now,
                .yesterday: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                .thisWeek: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                .lastWeek: calendar.date(byAdding: .day, value: -8, to: now) ?? now,
                .thisMonth: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                .older: calendar.date(byAdding: .month, value: -2, to: now) ?? now,
            ]
        }
    }
#endif
