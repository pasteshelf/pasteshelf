//
//  LicensedFeature.swift
//  PasteShelf
//
//  Defines features that are gated by license tier.
//  Maps features to their minimum required tier.
//

import Foundation

/// Features that require a specific license tier
enum LicensedFeature: String, Codable, Sendable, CaseIterable {
    // MARK: - Pro Features

    /// iCloud sync across devices
    case cloudSync = "cloud_sync"

    /// AI-powered semantic search
    case semanticSearch = "semantic_search"

    /// OCR text extraction from images
    case ocrSearch = "ocr_search"

    /// Smart collections with auto-organization
    case smartCollections = "smart_collections"

    /// Automation rules and triggers
    case automation = "automation"

    /// Third-party plugin support
    case plugins = "plugins"

    // MARK: - Enterprise Features

    /// SSO/SAML integration
    case ssoIntegration = "sso_integration"

    /// MDM deployment support
    case mdmSupport = "mdm_support"

    /// Data Loss Prevention policies
    case dlpPolicies = "dlp_policies"

    /// Comprehensive audit logging
    case auditLogs = "audit_logs"

    /// Self-hosted sync server
    case selfHostedSync = "self_hosted_sync"

    /// Centralized admin console
    case adminConsole = "admin_console"

    /// Team/organization sharing
    case teamSharing = "team_sharing"

    // MARK: - Properties

    /// Minimum tier required for this feature
    var requiredTier: LicenseTier {
        switch self {
        // Pro features
        case .cloudSync, .semanticSearch, .ocrSearch,
             .smartCollections, .automation, .plugins:
            return .pro

        // Enterprise features
        case .ssoIntegration, .mdmSupport, .dlpPolicies,
             .auditLogs, .selfHostedSync, .adminConsole, .teamSharing:
            return .enterprise
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .cloudSync:
            return String(localized: "iCloud Sync")
        case .semanticSearch:
            return String(localized: "Semantic Search")
        case .ocrSearch:
            return String(localized: "OCR Search")
        case .smartCollections:
            return String(localized: "Smart Collections")
        case .automation:
            return String(localized: "Automation")
        case .plugins:
            return String(localized: "Plugins")
        case .ssoIntegration:
            return String(localized: "SSO Integration")
        case .mdmSupport:
            return String(localized: "MDM Support")
        case .dlpPolicies:
            return String(localized: "DLP Policies")
        case .auditLogs:
            return String(localized: "Audit Logs")
        case .selfHostedSync:
            return String(localized: "Self-Hosted Sync")
        case .adminConsole:
            return String(localized: "Admin Console")
        case .teamSharing:
            return String(localized: "Team Sharing")
        }
    }

    /// Description of the feature
    var description: String {
        switch self {
        case .cloudSync:
            return String(localized: "Sync clipboard history across all your devices via iCloud")
        case .semanticSearch:
            return String(localized: "Find items using natural language queries")
        case .ocrSearch:
            return String(localized: "Extract and search text from images")
        case .smartCollections:
            return String(localized: "Auto-organize items with rule-based collections")
        case .automation:
            return String(localized: "Create rules to automatically process clipboard items")
        case .plugins:
            return String(localized: "Extend functionality with third-party plugins")
        case .ssoIntegration:
            return String(localized: "Single sign-on with SAML 2.0 or OIDC")
        case .mdmSupport:
            return String(localized: "Deploy and configure via MDM solutions")
        case .dlpPolicies:
            return String(localized: "Prevent sensitive data leakage with policies")
        case .auditLogs:
            return String(localized: "Track all clipboard operations for compliance")
        case .selfHostedSync:
            return String(localized: "Use your own sync server for data sovereignty")
        case .adminConsole:
            return String(localized: "Centralized management for your organization")
        case .teamSharing:
            return String(localized: "Share clipboard items with team members")
        }
    }

    /// SF Symbol name for the feature icon
    var iconName: String {
        switch self {
        case .cloudSync:
            return "icloud.fill"
        case .semanticSearch:
            return "brain"
        case .ocrSearch:
            return "text.viewfinder"
        case .smartCollections:
            return "folder.badge.gearshape"
        case .automation:
            return "gearshape.2.fill"
        case .plugins:
            return "puzzlepiece.extension.fill"
        case .ssoIntegration:
            return "key.fill"
        case .mdmSupport:
            return "desktopcomputer"
        case .dlpPolicies:
            return "shield.lefthalf.filled"
        case .auditLogs:
            return "list.clipboard.fill"
        case .selfHostedSync:
            return "server.rack"
        case .adminConsole:
            return "gearshape.fill"
        case .teamSharing:
            return "person.3.fill"
        }
    }

    /// All features for a given tier
    static func features(for tier: LicenseTier) -> [LicensedFeature] {
        allCases.filter { $0.requiredTier <= tier }
    }

    /// Pro-only features
    static var proFeatures: [LicensedFeature] {
        allCases.filter { $0.requiredTier == .pro }
    }

    /// Enterprise-only features
    static var enterpriseFeatures: [LicensedFeature] {
        allCases.filter { $0.requiredTier == .enterprise }
    }
}
