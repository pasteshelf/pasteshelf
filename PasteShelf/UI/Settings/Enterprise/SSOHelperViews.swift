//
//  SSOHelperViews.swift
//  PasteShelf
//
//  Helper views used by SSOSettingsView for provider list rows and badges.
//

import SwiftUI

// MARK: - ProviderListRow

struct ProviderListRow: View {
    // MARK: Internal

    let provider: IdentityProvider
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: provider.type == .saml ? "key.fill" : "lock.shield.fill")
                .font(.body)
                .foregroundStyle(provider.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.body)
                    .lineLimit(1)

                ProviderTypeBadge(type: provider.type)
            }

            Spacer()

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .help(statusHelp)
        }
        .padding(.vertical, 3)
    }

    // MARK: Private

    private var statusColor: Color {
        if !provider.isConfigured {
            return .orange
        }
        return provider.isEnabled ? .green : .secondary
    }

    private var statusHelp: String {
        if !provider.isConfigured {
            return "Incomplete configuration"
        }
        return provider.isEnabled ? "Active" : "Disabled"
    }
}

// MARK: - ProviderTypeBadge

struct ProviderTypeBadge: View {
    // MARK: Internal

    let type: IdentityProviderType

    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    // MARK: Private

    private var badgeColor: Color {
        switch type {
        case .saml: .blue
        case .oidc: .purple
        }
    }
}

// MARK: - ConnectionStatusBadge

struct ConnectionStatusBadge: View {
    // MARK: Internal

    let isEnabled: Bool
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private var dotColor: Color {
        if !isConfigured {
            return .orange
        }
        return isEnabled ? .green : .secondary
    }

    private var label: String {
        if !isConfigured {
            return "Incomplete"
        }
        return isEnabled ? "Active" : "Disabled"
    }
}

// MARK: - SAMLNameIDFormat Display Helper

extension SAMLNameIDFormat {
    var shortDisplayName: String {
        switch self {
        case .emailAddress: "Email Address"
        case .persistent: "Persistent"
        case .transient: "Transient"
        case .entity: "Entity"
        case .kerberos: "Kerberos"
        case .windowsDomainQualifiedName: "Windows Domain"
        case .x509SubjectName: "X.509 Subject"
        case .unspecified: "Unspecified"
        }
    }
}
