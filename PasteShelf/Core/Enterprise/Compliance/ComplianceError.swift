//
//  ComplianceError.swift
//  PasteShelf
//
//  Shared error type for compliance operations.
//

import Foundation

// MARK: - ComplianceError

/// Errors that can arise from compliance operations across HIPAA, GDPR, and SOC 2 subsystems.
enum ComplianceError: Error, LocalizedError {
    case notConfigured
    case featureUnavailable
    case exportFailed(underlying: Error)
    case deletionFailed(underlying: Error)
    case encryptionVerificationFailed(underlying: Error)
    case consentNotGranted(category: String)
    case reportGenerationFailed(String)
    case invalidConfiguration(String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Compliance tools are not configured"
        case .featureUnavailable:
            "Compliance features are not enabled"
        case let .exportFailed(error):
            "Data export failed: \(error.localizedDescription)"
        case let .deletionFailed(error):
            "Data deletion failed: \(error.localizedDescription)"
        case let .encryptionVerificationFailed(error):
            "Encryption verification failed: \(error.localizedDescription)"
        case let .consentNotGranted(cat):
            "Consent not granted for: \(cat)"
        case let .reportGenerationFailed(msg):
            "Report generation failed: \(msg)"
        case let .invalidConfiguration(msg):
            "Invalid configuration: \(msg)"
        }
    }
}
