//
//  DLPPatternCategory.swift
//  PasteShelf
//
//  Categories for DLP rule patterns, used to classify the type of sensitive data a rule targets.
//

import Foundation

// MARK: - DLPPatternCategory

/// The category of sensitive data that a DLP rule pattern targets.
///
/// Categories group rules by the type of sensitive information they protect.
/// Administrators can use categories to filter the DLP rule list and to understand
/// the scope of their data protection policies at a glance.
///
/// The raw `String` value is persisted in CoreData and displayed in the admin UI.
enum DLPPatternCategory: String, Codable, Sendable, CaseIterable {

    /// Payment card numbers matching common credit and debit card formats.
    case creditCard = "credit_card"

    /// US Social Security Numbers in standard or compact format.
    case ssn = "ssn"

    /// API keys, secret tokens, and similar programmatic credentials.
    case apiKey = "api_key"

    /// Personally Identifiable Information such as names, addresses, email addresses, and phone numbers.
    case pii = "pii"

    /// Health-related data including diagnoses, medication names, or insurance identifiers.
    case healthData = "health_data"

    /// A user-defined pattern that does not belong to any of the built-in categories.
    case custom = "custom"

    // MARK: - Display

    /// A human-readable label (English; used for logs and tests).
    var displayName: String {
        switch self {
        case .creditCard:
            return "Credit Card"
        case .ssn:
            return "Social Security Number"
        case .apiKey:
            return "API Key / Credential"
        case .pii:
            return "Personally Identifiable Information"
        case .healthData:
            return "Health Data"
        case .custom:
            return "Custom"
        }
    }

    /// Localized display name key (use in SwiftUI views)
    var displayNameKey: LocalizedStringResource {
        switch self {
        case .creditCard:
            return "Credit Card"
        case .ssn:
            return "Social Security Number"
        case .apiKey:
            return "API Key / Credential"
        case .pii:
            return "Personally Identifiable Information"
        case .healthData:
            return "Health Data"
        case .custom:
            return "Custom"
        }
    }
}
