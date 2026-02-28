//
//  SyncError.swift
//  PasteShelf
//
//  Error types for sync operations.
//

import CloudKit
import Foundation

/// Errors that can occur during sync operations
public enum SyncError: Error, Equatable, Sendable {
    // MARK: - Account Errors

    /// No iCloud account is configured
    case noAccount

    /// iCloud account is restricted (e.g., parental controls)
    case accountRestricted

    /// iCloud account temporarily unavailable
    case accountTemporarilyUnavailable

    /// User's iCloud quota exceeded
    case quotaExceeded

    // MARK: - Network Errors

    /// No network connection
    case networkUnavailable

    /// Network request timed out
    case timeout

    /// Server returned an error
    case serverError(code: Int)

    // MARK: - CloudKit Errors

    /// CloudKit zone not found (needs setup)
    case zoneNotFound

    /// Record not found in CloudKit
    case recordNotFound

    /// Record was modified by another device
    case serverRecordChanged

    /// Change token expired (need full sync)
    case changeTokenExpired

    /// CloudKit rate limited
    case rateLimited(retryAfter: TimeInterval?)

    /// Batch operation partially failed
    case partialFailure(errors: [String])

    // MARK: - Encryption Errors

    /// Encryption key not found
    case encryptionKeyMissing

    /// Failed to decrypt data
    case decryptionFailed

    /// Encryption key mismatch between devices
    case keyMismatch

    // MARK: - Data Errors

    /// Data validation failed
    case invalidData(reason: String)

    /// Record too large for CloudKit
    case recordTooLarge

    // MARK: - Self-Hosted Sync Errors

    /// Failed to connect to self-hosted sync server
    case serverConnectionFailed(message: String)

    /// Certificate pinning validation failed
    case certificatePinningFailed

    /// Server authentication token expired
    case authenticationTokenExpired

    /// Self-hosted server returned an error
    case selfHostedServerError(code: Int, message: String)

    // MARK: - Generic Errors

    /// Unknown error occurred
    case unknown(message: String)
}

// MARK: - LocalizedError Conformance

extension SyncError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noAccount:
            return String(localized: "No iCloud account configured. Please sign in to iCloud in System Settings.")

        case .accountRestricted:
            return String(localized: "iCloud access is restricted. Please check your account settings.")

        case .accountTemporarilyUnavailable:
            return String(localized: "iCloud is temporarily unavailable. Please try again later.")

        case .quotaExceeded:
            return String(localized: "Your iCloud storage is full. Please free up space or upgrade your plan.")

        case .networkUnavailable:
            return String(localized: "No network connection. Changes will sync when you're back online.")

        case .timeout:
            return String(localized: "The sync request timed out. Please try again.")

        case let .serverError(code):
            return String(localized: "Server error (code \(code)). Please try again later.")

        case .zoneNotFound:
            return String(localized: "Sync zone not found. Setting up sync...")

        case .recordNotFound:
            return String(localized: "Record not found in iCloud.")

        case .serverRecordChanged:
            return String(localized: "Record was modified on another device. Resolving conflict...")

        case .changeTokenExpired:
            return String(localized: "Sync state expired. Performing full sync...")

        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                return String(localized: "Too many requests. Please wait \(Int(seconds)) seconds.")
            }
            return String(localized: "Too many requests. Please try again later.")

        case let .partialFailure(errors):
            return String(localized: "Some items failed to sync: \(errors.joined(separator: ", "))")

        case .encryptionKeyMissing:
            return String(localized: "Encryption key not found. Please set up sync on this device.")

        case .decryptionFailed:
            return String(localized: "Failed to decrypt data. The encryption key may have changed.")

        case .keyMismatch:
            return String(localized: "Encryption key mismatch. Please re-authenticate on this device.")

        case let .invalidData(reason):
            return String(localized: "Invalid data: \(reason)")

        case .recordTooLarge:
            return String(localized: "Item is too large to sync. Maximum size is 1 MB.")

        case let .serverConnectionFailed(message):
            return String(localized: "Failed to connect to sync server: \(message)")

        case .certificatePinningFailed:
            return String(localized: "Server certificate validation failed. The server's identity could not be verified.")

        case .authenticationTokenExpired:
            return String(localized: "Your authentication has expired. Please sign in again.")

        case let .selfHostedServerError(code, message):
            return String(localized: "Sync server error (\(code)): \(message)")

        case let .unknown(message):
            return String(localized: "Sync error: \(message)")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noAccount:
            return String(localized: "Open System Settings > Apple ID > iCloud to sign in.")
        case .quotaExceeded:
            return String(localized: "Manage your iCloud storage in System Settings.")
        case .networkUnavailable:
            return String(localized: "Check your internet connection.")
        case .encryptionKeyMissing, .keyMismatch:
            return String(localized: "Go to Preferences > Sync > Reset Sync to reconfigure.")
        case .serverConnectionFailed:
            return String(localized: "Check the server URL and ensure the sync server is running.")
        case .certificatePinningFailed:
            return String(localized: "Verify the server certificate in Preferences > Sync > Self-Hosted.")
        case .authenticationTokenExpired:
            return String(localized: "Sign in again via Preferences > Sync > Self-Hosted.")
        default:
            return nil
        }
    }
}

// MARK: - CKError Conversion

extension SyncError {
    /// Create SyncError from CloudKit error
    public static func from(_ ckError: CKError) -> SyncError {
        switch ckError.code {
        case .notAuthenticated:
            return .noAccount
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .serviceUnavailable:
            return .accountTemporarilyUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .requestRateLimited:
            let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval
            return .rateLimited(retryAfter: retryAfter)
        case .zoneNotFound:
            return .zoneNotFound
        case .unknownItem:
            return .recordNotFound
        case .serverRecordChanged:
            return .serverRecordChanged
        case .changeTokenExpired:
            return .changeTokenExpired
        case .limitExceeded:
            return .recordTooLarge
        case .partialFailure:
            var errorMessages: [String] = []
            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                for (_, error) in partialErrors {
                    errorMessages.append(error.localizedDescription)
                }
            }
            return .partialFailure(errors: errorMessages)
        default:
            return .serverError(code: ckError.code.rawValue)
        }
    }
}

// MARK: - Equatable Conformance

extension SyncError {
    public static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        switch (lhs, rhs) {
        case (.noAccount, .noAccount),
             (.accountRestricted, .accountRestricted),
             (.accountTemporarilyUnavailable, .accountTemporarilyUnavailable),
             (.quotaExceeded, .quotaExceeded),
             (.networkUnavailable, .networkUnavailable),
             (.timeout, .timeout),
             (.zoneNotFound, .zoneNotFound),
             (.recordNotFound, .recordNotFound),
             (.serverRecordChanged, .serverRecordChanged),
             (.changeTokenExpired, .changeTokenExpired),
             (.encryptionKeyMissing, .encryptionKeyMissing),
             (.decryptionFailed, .decryptionFailed),
             (.keyMismatch, .keyMismatch),
             (.recordTooLarge, .recordTooLarge),
             (.certificatePinningFailed, .certificatePinningFailed),
             (.authenticationTokenExpired, .authenticationTokenExpired):
            return true
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        case let (.rateLimited(lhsRetry), .rateLimited(rhsRetry)):
            return lhsRetry == rhsRetry
        case let (.partialFailure(lhsErrors), .partialFailure(rhsErrors)):
            return lhsErrors == rhsErrors
        case let (.invalidData(lhsReason), .invalidData(rhsReason)):
            return lhsReason == rhsReason
        case let (.serverConnectionFailed(lhsMsg), .serverConnectionFailed(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.selfHostedServerError(lhsCode, lhsMsg), .selfHostedServerError(rhsCode, rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case let (.unknown(lhsMessage), .unknown(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
