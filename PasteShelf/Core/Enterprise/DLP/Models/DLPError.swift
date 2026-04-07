//
//  DLPError.swift
//  PasteShelf
//
//  Error types for DLP subsystem operations, following the AuditError pattern.
//

import Foundation

// MARK: - DLPError

/// Errors that may be thrown during Data Loss Prevention operations.
///
/// `DLPError` follows the same `LocalizedError` pattern established by `AuditError`
/// in `AuditProtocols.swift`, providing human-readable descriptions, failure reasons,
/// and recovery suggestions for each error case.
enum DLPError: Error, LocalizedError, Sendable {
    /// The DLP feature is not currently enabled.
    case featureUnavailable

    /// The regex pattern string for a DLP rule could not be compiled.
    ///
    /// The associated `String` contains the invalid pattern that caused the failure.
    case invalidPattern(String)

    /// A CoreData read or write operation in the DLP storage layer failed.
    ///
    /// The associated `String` is the underlying `NSError` description.
    case storageFailure(String)

    /// A rule with the specified UUID was not found in storage.
    ///
    /// The associated `UUID` is the identifier that was requested.
    case ruleNotFound(UUID)

    /// The DLP evaluation pass failed due to an unexpected error.
    ///
    /// The associated `String` provides the reason for the failure.
    case evaluationFailed(String)

    // MARK: Internal

    // MARK: - LocalizedError

    /// A short, user-visible description of the error.
    var errorDescription: String? {
        switch self {
        case .featureUnavailable:
            "Data Loss Prevention is not enabled."
        case let .invalidPattern(pattern):
            "The DLP rule pattern could not be compiled: \"\(pattern)\"."
        case let .storageFailure(reason):
            "A storage error occurred in the DLP subsystem: \(reason)"
        case let .ruleNotFound(id):
            "No DLP rule was found with identifier \(id.uuidString)."
        case let .evaluationFailed(reason):
            "DLP content evaluation failed: \(reason)"
        }
    }

    /// A detailed explanation of why the error occurred.
    var failureReason: String? {
        switch self {
        case .featureUnavailable:
            "The DLP feature is not currently available."
        case let .invalidPattern(pattern):
            "The regular expression \"\(pattern)\" is syntactically invalid and cannot be compiled by NSRegularExpression."
        case let .storageFailure(reason):
            reason
        case let .ruleNotFound(id):
            "The DLP rule store does not contain a record with id \(id.uuidString)."
        case let .evaluationFailed(reason):
            reason
        }
    }

    /// A suggestion for how the user or administrator can resolve the error.
    var recoverySuggestion: String? {
        switch self {
        case .featureUnavailable:
            "Enable Data Loss Prevention in Enterprise settings."
        case .invalidPattern:
            "Review the regular expression syntax and correct the pattern in the DLP rule editor."
        case .storageFailure:
            "Restart the application. If the problem continues, check available disk space or re-enroll the device."
        case .ruleNotFound:
            "Refresh the DLP rule list from the admin console. The rule may have been deleted."
        case .evaluationFailed:
            "Try again. If the issue persists, review the DLP rule patterns for errors and contact your IT administrator."
        }
    }
}
