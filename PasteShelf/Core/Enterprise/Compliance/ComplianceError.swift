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
            return "Compliance tools are not configured"
        case .featureUnavailable:
            return "Compliance features require an Enterprise license"
        case .exportFailed(let error):
            return "Data export failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Data deletion failed: \(error.localizedDescription)"
        case .encryptionVerificationFailed(let error):
            return "Encryption verification failed: \(error.localizedDescription)"
        case .consentNotGranted(let cat):
            return "Consent not granted for: \(cat)"
        case .reportGenerationFailed(let msg):
            return "Report generation failed: \(msg)"
        case .invalidConfiguration(let msg):
            return "Invalid configuration: \(msg)"
        }
    }
}
