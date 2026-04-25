//
//  ComplianceError.swift
//  PasteShelf
//
//  Shared error type for compliance operations.
//

import Foundation

// MARK: - ComplianceError

/// Errors that can arise from compliance operations across HIPAA, GDPR, and SOC 2 subsystems.
enum ComplianceError: Error, LocalizedError, Sendable {
    case notConfigured
    case featureUnavailable
    case exportFailed(underlying: Error)
    case deletionFailed(underlying: Error)
    case encryptionVerificationFailed(underlying: Error)
    case consentNotGranted(category: String)
    case reportGenerationFailed(String)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Compliance tools are not configured")
        case .featureUnavailable:
            return String(localized: "Compliance features are not enabled")
        case .exportFailed(let error):
            return String(localized: "Data export failed: \(error.localizedDescription)")
        case .deletionFailed(let error):
            return String(localized: "Data deletion failed: \(error.localizedDescription)")
        case .encryptionVerificationFailed(let error):
            return String(localized: "Encryption verification failed: \(error.localizedDescription)")
        case .consentNotGranted(let cat):
            return String(localized: "Consent not granted for: \(cat)")
        case .reportGenerationFailed(let msg):
            return String(localized: "Report generation failed: \(msg)")
        case .invalidConfiguration(let msg):
            return String(localized: "Invalid configuration: \(msg)")
        }
    }
}
