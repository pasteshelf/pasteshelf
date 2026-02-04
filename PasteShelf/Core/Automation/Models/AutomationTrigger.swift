//
//  AutomationTrigger.swift
//  PasteShelf
//
//  Defines trigger types for automation rules.
//  Triggers determine when an automation rule should be evaluated.
//

import Foundation

// MARK: - Automation Trigger

/// Trigger types that initiate automation rule evaluation
enum AutomationTrigger: Codable, Equatable, Sendable {
    /// Triggered when a new clipboard item is captured
    case onCapture

    /// Triggered before a paste action is executed
    case onPaste

    /// Triggered manually by user action
    case manual

    /// Triggered on a schedule based on cron expression
    case schedule(CronExpression)

    // MARK: - Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .onCapture:
            return String(localized: "When Captured")
        case .onPaste:
            return String(localized: "Before Paste")
        case .manual:
            return String(localized: "Manual")
        case .schedule:
            return String(localized: "Scheduled")
        }
    }

    /// Description of when the trigger fires
    var description: String {
        switch self {
        case .onCapture:
            return String(localized: "Run when a new clipboard item is captured")
        case .onPaste:
            return String(localized: "Run before pasting to the target application")
        case .manual:
            return String(localized: "Run only when manually triggered")
        case .schedule(let cron):
            return String(localized: "Run on schedule: \(cron.displayDescription)")
        }
    }

    /// SF Symbol icon for the trigger
    var iconName: String {
        switch self {
        case .onCapture:
            return "doc.on.clipboard"
        case .onPaste:
            return "doc.on.doc"
        case .manual:
            return "hand.tap"
        case .schedule:
            return "clock"
        }
    }

    /// Raw type string for CoreData storage
    var rawType: String {
        switch self {
        case .onCapture: return "onCapture"
        case .onPaste: return "onPaste"
        case .manual: return "manual"
        case .schedule: return "schedule"
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "onCapture":
            self = .onCapture
        case "onPaste":
            self = .onPaste
        case "manual":
            self = .manual
        case "schedule":
            let expression = try container.decode(CronExpression.self, forKey: .value)
            self = .schedule(expression)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown trigger type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawType, forKey: .type)

        if case .schedule(let expression) = self {
            try container.encode(expression, forKey: .value)
        }
    }
}

// MARK: - Cron Expression

/// A simplified cron expression for scheduling automation rules
struct CronExpression: Codable, Equatable, Sendable {
    /// Minute (0-59)
    var minute: Int

    /// Hour (0-23)
    var hour: Int

    /// Day of month (1-31, or nil for any)
    var dayOfMonth: Int?

    /// Month (1-12, or nil for any)
    var month: Int?

    /// Day of week (0-6, Sunday=0, or nil for any)
    var dayOfWeek: Int?

    // MARK: - Initialization

    init(
        minute: Int = 0,
        hour: Int = 0,
        dayOfMonth: Int? = nil,
        month: Int? = nil,
        dayOfWeek: Int? = nil
    ) {
        self.minute = min(max(minute, 0), 59)
        self.hour = min(max(hour, 0), 23)
        self.dayOfMonth = dayOfMonth.flatMap { min(max($0, 1), 31) }
        self.month = month.flatMap { min(max($0, 1), 12) }
        self.dayOfWeek = dayOfWeek.flatMap { min(max($0, 0), 6) }
    }

    // MARK: - Preset Schedules

    /// Run every hour at the specified minute
    static func hourly(at minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute)
    }

    /// Run daily at the specified time
    static func daily(at hour: Int, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour)
    }

    /// Run weekly on the specified day and time
    static func weekly(on dayOfWeek: Int, at hour: Int, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour, dayOfWeek: dayOfWeek)
    }

    /// Run monthly on the specified day and time
    static func monthly(on dayOfMonth: Int, at hour: Int, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour, dayOfMonth: dayOfMonth)
    }

    // MARK: - Display

    /// Human-readable description of the schedule
    var displayDescription: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        let timeString: String
        if let date = calendar.date(from: components) {
            timeString = timeFormatter.string(from: date)
        } else {
            timeString = String(format: "%02d:%02d", hour, minute)
        }

        if let dayOfWeek = dayOfWeek {
            let weekdaySymbols = calendar.weekdaySymbols
            let dayName = weekdaySymbols[dayOfWeek]
            return "Every \(dayName) at \(timeString)"
        } else if let dayOfMonth = dayOfMonth {
            let ordinal = ordinalSuffix(for: dayOfMonth)
            return "Monthly on the \(dayOfMonth)\(ordinal) at \(timeString)"
        } else if dayOfMonth == nil && dayOfWeek == nil {
            if hour == 0 && minute == 0 {
                return "Every hour"
            } else {
                return "Daily at \(timeString)"
            }
        }

        return "Custom schedule"
    }

    /// Standard cron expression string
    var cronString: String {
        let minuteStr = String(minute)
        let hourStr = String(hour)
        let dayOfMonthStr = dayOfMonth.map { String($0) } ?? "*"
        let monthStr = month.map { String($0) } ?? "*"
        let dayOfWeekStr = dayOfWeek.map { String($0) } ?? "*"

        return "\(minuteStr) \(hourStr) \(dayOfMonthStr) \(monthStr) \(dayOfWeekStr)"
    }

    // MARK: - Next Execution

    /// Calculates the next execution date from the given date
    func nextExecution(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        // Start from the next minute
        components.minute = (components.minute ?? 0) + 1
        components.second = 0

        guard var candidateDate = calendar.date(from: components) else {
            return nil
        }

        // Try up to 366 days ahead
        for _ in 0..<(366 * 24 * 60) {
            let candidateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .weekday],
                from: candidateDate
            )

            let matchesMinute = candidateComponents.minute == minute
            let matchesHour = candidateComponents.hour == hour
            let matchesDayOfMonth = dayOfMonth == nil ||
                candidateComponents.day == dayOfMonth
            let matchesMonth = month == nil || candidateComponents.month == month
            let matchesDayOfWeek = dayOfWeek == nil ||
                (candidateComponents.weekday.map { $0 - 1 } == dayOfWeek) // Convert to 0-indexed

            if matchesMinute && matchesHour && matchesDayOfMonth && matchesMonth && matchesDayOfWeek {
                return candidateDate
            }

            // Move to next minute
            guard let nextMinute = calendar.date(byAdding: .minute, value: 1, to: candidateDate) else {
                return nil
            }
            candidateDate = nextMinute
        }

        return nil
    }

    // MARK: - Private Helpers

    private func ordinalSuffix(for number: Int) -> String {
        let tens = number % 100
        let units = number % 10

        if tens >= 11 && tens <= 13 {
            return "th"
        }

        switch units {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

// MARK: - JSON Serialization

extension AutomationTrigger {
    /// Serializes the trigger to JSON string
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes a trigger from JSON string
    static func fromJSON(_ json: String?) -> AutomationTrigger? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AutomationTrigger.self, from: data)
    }
}
