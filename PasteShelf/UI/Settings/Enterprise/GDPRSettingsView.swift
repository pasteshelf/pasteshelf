//
//  GDPRSettingsView.swift
//  PasteShelf
//
//  GDPR settings: consent management, data export, data deletion.
//

import AppKit
import SwiftUI

// MARK: - GDPRSettingsView

/// Settings view for GDPR compliance tools.
struct GDPRSettingsView: View {

    @ObservedObject var viewModel: ComplianceSettingsViewModel
    @ObservedObject private var consentManager = GDPRConsentManager.shared

    @State private var showDeleteConfirmation = false
    @State private var showPrivacyDashboard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Consent Management
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(GDPRConsentCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                    .frame(width: 20)
                                VStack(alignment: .leading) {
                                    Text(category.displayName)
                                    Text(category.purposeDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { consentManager.isConsentGranted(for: category) },
                                    set: { granted in
                                        Task {
                                            if granted {
                                                await consentManager.grantConsent(for: category)
                                            } else {
                                                await consentManager.revokeConsent(for: category)
                                            }
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            if category != GDPRConsentCategory.allCases.last {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Consent Management", systemImage: "person.badge.shield.checkmark.fill")
                }

                // Data Rights
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        // Export
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Export My Data")
                                    .fontWeight(.medium)
                                Text("Download all your data in a portable format (Article 20).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await exportData() }
                            } label: {
                                if viewModel.isGDPRExporting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                            }
                            .disabled(viewModel.isGDPRExporting)
                        }

                        Divider()

                        // Delete
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Delete My Data")
                                    .fontWeight(.medium)
                                Text("Permanently erase all data from PasteShelf (Article 17).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                if viewModel.isGDPRDeleting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Delete All", systemImage: "trash")
                                }
                            }
                            .disabled(viewModel.isGDPRDeleting)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Data Rights", systemImage: "hand.raised.fill")
                }

                // Privacy Dashboard Link
                GroupBox {
                    Button {
                        showPrivacyDashboard = true
                    } label: {
                        HStack {
                            Label("Open Privacy Dashboard", systemImage: "eye.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Privacy Dashboard", systemImage: "chart.bar.doc.horizontal.fill")
                }
            }
            .padding()
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await viewModel.deleteAllGDPRData() }
            }
        } message: {
            Text("This will permanently delete all clipboard items, tags, folders, collections, audit logs, and encryption keys. This action cannot be undone.")
        }
        .sheet(isPresented: $showPrivacyDashboard) {
            PrivacyDashboardView()
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    // MARK: - Actions

    private func exportData() async {
        if let url = await viewModel.exportGDPRData() {
            NSWorkspace.shared.open(url)
        }
    }
}
