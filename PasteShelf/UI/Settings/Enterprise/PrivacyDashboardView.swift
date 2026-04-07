//
//  PrivacyDashboardView.swift
//  PasteShelf
//
//  GDPR privacy dashboard showing data collected, storage, services, and consent.
//

import SwiftUI

// MARK: - PrivacyDashboardView

/// A comprehensive privacy overview for GDPR compliance.
///
/// Shows what data is collected, how long it's stored, which services are connected,
/// and the current consent state for each data processing category.
struct PrivacyDashboardView: View {
    // MARK: Internal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Label("Privacy Dashboard", systemImage: "eye.fill")
                        .font(.title2.bold())
                    Text("Overview of your data in PasteShelf")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isLoading {
                    ProgressView("Loading privacy data...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // Data Collected
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(viewModel.dataCategories.enumerated()), id: \.offset) { _, item in
                                HStack {
                                    Image(systemName: item.icon)
                                        .frame(width: 20)
                                    Text(item.name)
                                    Spacer()
                                    Text("\(item.count)")
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Data Collected", systemImage: "tray.full.fill")
                    }

                    // Storage Duration
                    GroupBox {
                        HStack {
                            Text("Retention Period:")
                            Spacer()
                            Text(viewModel.storageDuration)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Storage Duration", systemImage: "clock.fill")
                    }

                    // Connected Services
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(viewModel.connectedServices.enumerated()), id: \.offset) { _, service in
                                HStack {
                                    Image(systemName: service.icon)
                                        .frame(width: 20)
                                    Text(service.name)
                                    Spacer()
                                    Text(service.isActive ? "Active" : "Inactive")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(service.isActive ? Color.green.opacity(0.2) : Color.gray
                                            .opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Connected Services", systemImage: "network")
                    }

                    // Consent Status
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(GDPRConsentCategory.allCases, id: \.self) { category in
                                HStack {
                                    Image(systemName: category.iconName)
                                        .frame(width: 20)
                                    Text(category.displayName)
                                    Spacer()
                                    Text(consentManager.isConsentGranted(for: category) ? "Granted" : "Not Granted")
                                        .font(.caption)
                                        .foregroundStyle(consentManager
                                            .isConsentGranted(for: category) ? .green : .secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Consent Status", systemImage: "person.badge.shield.checkmark.fill")
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadDashboardData()
        }
    }

    // MARK: Private

    @StateObject private var viewModel = PrivacyDashboardViewModel()
    @ObservedObject private var consentManager = GDPRConsentManager.shared
}
