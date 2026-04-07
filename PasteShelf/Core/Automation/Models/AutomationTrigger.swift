//
//  AutomationTrigger.swift
//  PasteShelf
//
//  Defines trigger types for automation rules.
//  Triggers determine when an automation rule should be evaluated.
//

import Foundation

// MARK: - AutomationTrigger

/// Trigger types that initiate automation rule evaluation
enum AutomationTrigger: Codable, Equatable, Hashable, Sendable {
    /// Triggered when a new clipboard item is captured
    case onCapture

    /// Triggered before a paste action is executed
    case onPaste

    /// Triggered manually by user action
    case manual

    /// Triggered on a schedule based on cron expression
    case schedule(CronExpression)

    // MARK: Lifecycle

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

    // MARK: Internal

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .onCapture:
            String(localized: "When Captured")
        case .onPaste:
            String(localized: "Before Paste")
        case .manual:
            String(localized: "Manual")
        case .schedule:
            String(localized: "Scheduled")
        }
    }

    /// Description of when the trigger fires
    var description: String {
        switch self {
        case .onCapture:
            String(localized: "Run when a new clipboard item is captured")
        case .onPaste:
            String(localized: "Run before pasting to the target application")
        case .manual:
            String(localized: "Run only when manually triggered")
        case let .schedule(cron):
            String(localized: "Run on schedule: \(cron.displayDescription)")
        }
    }

    /// SF Symbol icon for the trigger
    var iconName: String {
        switch self {
        case .onCapture:
            "doc.on.clipboard"
        case .onPaste:
            "doc.on.doc"
        case .manual:
            "hand.tap"
        case .schedule:
            "clock"
        }
    }

    /// Raw type string for CoreData storage
    var rawType: String {
        switch self {
        case .onCapture: "onCapture"
        case .onPaste: "onPaste"
        case .manual: "manual"
        case .schedule: "schedule"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawType, forKey: .type)

        if case let .schedule(expression) = self {
            try container.encode(expression, forKey: .value)
        }
    }

    // MARK: Private

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }
}

// MARK: - CronExpression

/// A simplified cron expression for scheduling automation rules
struct CronExpression: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

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

    /// Initialize from a cron expression string
    /// - Parameter expression: Cron expression string (e.g., "0 9 * * *")
    init(expression: String) {
        let parts = expression.split(separator: " ").map { String($0) }

        // Parse with defaults for missing parts
        let parsedMinute = !parts.isEmpty ? Int(parts[0]) ?? 0 : 0
        let parsedHour = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let parsedDayOfMonth = parts.count > 2 && parts[2] != "*" ? Int(parts[2]) : nil
        let parsedMonth = parts.count > 3 && parts[3] != "*" ? Int(parts[3]) : nil
        let parsedDayOfWeek = parts.count > 4 && parts[4] != "*" ? Int(parts[4]) : nil

        self.init(
            minute: parsedMinute,
            hour: parsedHour,
            dayOfMonth: parsedDayOfMonth,
            month: parsedMonth,
            dayOfWeek: parsedDayOfWeek
        )
    }

    // MARK: Internal

    // MARK: - Default Presets (for UI picker compatibility)

    /// Default hourly schedule (on the hour)
    static var hourly: CronExpression {
        hourly()
    }

    /// Default daily schedule (9 AM)
    static var daily: CronExpression {
        daily()
    }

    /// Default weekly schedule (Monday 9 AM)
    static var weekly: CronExpression {
        weekly()
    }

    /// Default monthly schedule (1st of month at 9 AM)
    static var monthly: CronExpression {
        monthly()
    }

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

    // MARK: - Display

    /// Human-readable description of the schedule
    var displayDescription: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        let timeString: String = if let date = calendar.date(from: components) {
            timeFormatter.string(from: date)
        } else {
            String(format: "%02d:%02d", hour, minute)
        }

        if let dayOfWeek {
            let weekdaySymbols = calendar.weekdaySymbols
            let dayName = weekdaySymbols[dayOfWeek]
            return "Every \(dayName) at \(timeString)"
        } else if let dayOfMonth {
            let ordinal = ordinalSuffix(for: dayOfMonth)
            return "Monthly on the \(dayOfMonth)\(ordinal) at \(timeString)"
        } else if dayOfMonth == nil, dayOfWeek == nil {
            if hour == 0, minute == 0 {
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

    /// Alias for cronString for UI compatibility
    var expression: String {
        cronString
    }

    // MARK: - Preset Schedules

    /// Run every hour at the specified minute
    static func hourly(at minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute)
    }

    /// Run daily at the specified time
    static func daily(at hour: Int = 9, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour)
    }

    /// Run weekly on the specified day and time
    static func weekly(on dayOfWeek: Int = 1, at hour: Int = 9, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour, dayOfWeek: dayOfWeek)
    }

    /// Run monthly on the specified day and time
    static func monthly(on dayOfMonth: Int = 1, at hour: Int = 9, minute: Int = 0) -> CronExpression {
        CronExpression(minute: minute, hour: hour, dayOfMonth: dayOfMonth)
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
        for _ in 0 ..< (366 * 24 * 60) {
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

            if matchesMinute, matchesHour, matchesDayOfMonth, matchesMonth, matchesDayOfWeek {
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

    // MARK: Private

    // MARK: - Private Helpers

    private func ordinalSuffix(for number: Int) -> String {
        let tens = number % 100
        let units = number % 10

        if tens >= 11, tens <= 13 {
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
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes a trigger from JSON string
    static func fromJSON(_ json: String?) -> AutomationTrigger? {
        guard let json, let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AutomationTrigger.self, from: data)
    }
}
