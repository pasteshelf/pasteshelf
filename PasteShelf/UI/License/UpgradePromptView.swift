//
//  UpgradePromptView.swift
//  PasteShelf
//
//  View shown when users attempt to access Pro/Enterprise features.
//  Displays feature benefits and upgrade call-to-action.
//

import SwiftUI

/// Upgrade prompt view shown when accessing locked features
struct UpgradePromptView: View {
    // MARK: - Properties

    /// The feature being accessed
    let feature: LicensedFeature

    /// Required tier for the feature
    var requiredTier: LicenseTier {
        feature.requiredTier
    }

    /// Dismiss action
    var onDismiss: (() -> Void)?

    /// Open license preferences
    var onOpenPreferences: (() -> Void)?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerView

            // Feature info
            featureInfoView

            // Benefits
            benefitsView

            // Actions
            actionsView
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tierGradient)
                    .frame(width: 80, height: 80)

                Image(systemName: feature.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            Text("Upgrade to \(requiredTier.displayName)")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var tierGradient: LinearGradient {
        switch requiredTier {
        case .pro:
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .enterprise:
            return LinearGradient(
                colors: [.purple, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .community:
            return LinearGradient(
                colors: [.gray, .secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var featureInfoView: some View {
        VStack(spacing: 8) {
            Text(feature.displayName)
                .font(.headline)

            Text(feature.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you get with \(requiredTier.displayName):")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(benefits, id: \.self) { benefit in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text(benefit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var benefits: [String] {
        switch requiredTier {
        case .pro:
            return [
                "iCloud sync across all your devices",
                "Semantic search with natural language",
                "OCR text extraction from images",
                "Smart collections and automation",
                "Third-party plugin support",
            ]
        case .enterprise:
            return [
                "Everything in Pro edition",
                "SSO/SAML integration",
                "MDM deployment support",
                "Data Loss Prevention policies",
                "Comprehensive audit logging",
            ]
        case .community:
            return []
        }
    }

    private var actionsView: some View {
        VStack(spacing: 12) {
            Button {
                openPurchasePage()
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Upgrade Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 16) {
                Button("Enter License Key") {
                    onOpenPreferences?()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Button("Not Now") {
                    onDismiss?()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if requiredTier == .pro {
                Text("Starting at $29/year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func openPurchasePage() {
        let urlString: String
        switch requiredTier {
        case .pro:
            urlString = "https://pasteshelf.app/pro"
        case .enterprise:
            urlString = "https://pasteshelf.app/enterprise"
        case .community:
            return
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Compact Upgrade Prompt

/// Inline upgrade prompt for embedding in other views
struct CompactUpgradePrompt: View {
    let feature: LicensedFeature
    var onUpgrade: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(feature.displayName) requires \(feature.requiredTier.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Upgrade") {
                onUpgrade?()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Feature Gate View

/// Wrapper view that shows content or upgrade prompt based on license
struct FeatureGateView<Content: View>: View {
    let feature: LicensedFeature
    let content: () -> Content

    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showUpgradePrompt = false

    var body: some View {
        if licenseManager.isFeatureAvailable(feature) {
            content()
        } else {
            CompactUpgradePrompt(feature: feature) {
                showUpgradePrompt = true
            }
            .sheet(isPresented: $showUpgradePrompt) {
                UpgradePromptView(feature: feature)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct UpgradePromptView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                UpgradePromptView(feature: .cloudSync)
                    .previewDisplayName("Pro Feature")

                UpgradePromptView(feature: .ssoIntegration)
                    .previewDisplayName("Enterprise Feature")

                CompactUpgradePrompt(feature: .semanticSearch)
                    .frame(width: 400)
                    .padding()
                    .previewDisplayName("Compact Prompt")
            }
        }
    }
#endif
