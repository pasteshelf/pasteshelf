//
//  LicenseTier.swift
//  PasteShelf
//
//  Defines the license tiers for PasteShelf's open-core model.
//  Community (free), Pro ($29/year), and Enterprise (custom pricing).
//

import Foundation

/// License tiers for PasteShelf's open-core model
enum LicenseTier: String, Codable, Sendable, CaseIterable {
    /// Free, open source core functionality (AGPL-3.0)
    case community = "community"

    /// Pro edition with iCloud sync, semantic search, OCR, plugins ($29/year)
    case pro = "pro"

    /// Enterprise edition with SSO, MDM, audit logs, DLP policies (custom pricing)
    case enterprise = "enterprise"

    // MARK: - Display Properties

    /// Human-readable display name for the tier
    var displayName: String {
        switch self {
        case .community:
            return String(localized: "Community Edition")
        case .pro:
            return String(localized: "Pro Edition")
        case .enterprise:
            return String(localized: "Enterprise Edition")
        }
    }

    /// Short description of the tier
    var description: String {
        switch self {
        case .community:
            return String(localized: "Free, open source core functionality")
        case .pro:
            return String(localized: "iCloud sync, semantic search, OCR, plugins")
        case .enterprise:
            return String(localized: "SSO, MDM, audit logs, DLP policies")
        }
    }

    /// SF Symbol name for the tier icon
    var iconName: String {
        switch self {
        case .community:
            return "person.fill"
        case .pro:
            return "star.fill"
        case .enterprise:
            return "building.2.fill"
        }
    }

    /// Whether this tier is a paid tier
    var isPaid: Bool {
        self != .community
    }
}

// MARK: - Comparable

extension LicenseTier: Comparable {
    /// Compare tiers by their level (community < pro < enterprise)
    static func < (lhs: LicenseTier, rhs: LicenseTier) -> Bool {
        let order: [LicenseTier] = [.community, .pro, .enterprise]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs)
        else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - License Type

/// Types of license agreements
enum LicenseType: String, Codable, Sendable {
    /// Time-limited trial (14 or 30 days)
    case trial

    /// Annual subscription (auto-renewing)
    case subscription

    /// One-time purchase (lifetime access)
    case lifetime

    /// Enterprise agreement (custom terms)
    case enterprise

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .trial:
            return String(localized: "Trial")
        case .subscription:
            return String(localized: "Subscription")
        case .lifetime:
            return String(localized: "Lifetime")
        case .enterprise:
            return String(localized: "Enterprise Agreement")
        }
    }

    /// Whether the license can expire
    var canExpire: Bool {
        switch self {
        case .trial, .subscription:
            return true
        case .lifetime, .enterprise:
            return false
        }
    }
}
