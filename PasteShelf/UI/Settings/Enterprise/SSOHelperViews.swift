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
            Image(systemName: self.provider.type == .saml ? "key.fill" : "lock.shield.fill")
                .font(.body)
                .foregroundStyle(self.provider.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.provider.name)
                    .font(.body)
                    .lineLimit(1)

                ProviderTypeBadge(type: self.provider.type)
            }

            Spacer()

            // Status dot
            Circle()
                .fill(self.statusColor)
                .frame(width: 8, height: 8)
                .help(self.statusHelp)
        }
        .padding(.vertical, 3)
    }

    // MARK: Private

    private var statusColor: Color {
        if !self.provider.isConfigured {
            return .orange
        }
        return self.provider.isEnabled ? .green : .secondary
    }

    private var statusHelp: String {
        if !self.provider.isConfigured {
            return "Incomplete configuration"
        }
        return self.provider.isEnabled ? "Active" : "Disabled"
    }
}

// MARK: - ProviderTypeBadge

struct ProviderTypeBadge: View {
    // MARK: Internal

    let type: IdentityProviderType

    var body: some View {
        Text(self.type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(self.badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(self.badgeColor)
    }

    // MARK: Private

    private var badgeColor: Color {
        switch self.type {
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
                .fill(self.dotColor)
                .frame(width: 7, height: 7)
            Text(self.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Private

    private var dotColor: Color {
        if !self.isConfigured {
            return .orange
        }
        return self.isEnabled ? .green : .secondary
    }

    private var label: String {
        if !self.isConfigured {
            return "Incomplete"
        }
        return self.isEnabled ? "Active" : "Disabled"
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
