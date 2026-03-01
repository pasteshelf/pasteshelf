//
//  PrivacyTabView.swift
//  PasteShelf
//
//  Privacy settings tab for preferences window.
//

import AppKit
import SwiftUI

/// Privacy settings tab view
struct PrivacyTabView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PreferencesViewModel
    @State private var showClearHistoryAlert = false
    @State private var showAppPicker = false

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Toggle("Pause clipboard monitoring", isOn: $viewModel.isMonitoringPaused)
                    .accessibilityLabel("Pause clipboard monitoring")
                    .accessibilityHint("When enabled, clipboard contents will not be captured")

                Toggle("Exclude private/incognito browsing", isOn: $viewModel.excludePrivateBrowsing)
                    .accessibilityLabel("Exclude private browsing")
                    .accessibilityHint("When enabled, content from private browser windows will not be captured")
                    .managedSetting(.excludePrivateBrowsing)
            } header: {
                Text("Monitoring")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Excluded Applications")
                        Spacer()
                        Button(action: { showAppPicker = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Add excluded application")
                    }

                    if viewModel.excludedAppBundleIds.isEmpty {
                        Text("No applications excluded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        AppExclusionListView(
                            bundleIds: viewModel.excludedAppBundleIds,
                            onRemove: { bundleId in
                                viewModel.removeExcludedApp(bundleId)
                            }
                        )
                    }
                }
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("Clipboard content from these applications will not be captured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Auto-delete old items", isOn: $viewModel.autoDeleteEnabled)
                    .accessibilityLabel("Auto-delete old items")
                    .accessibilityHint("When enabled, items older than the specified period will be automatically deleted")
                    .managedSetting(.maxHistoryDays)

                if viewModel.autoDeleteEnabled {
                    Picker("Delete items older than", selection: $viewModel.autoDeleteDays) {
                        ForEach(PrivacySettings.autoDeleteOptions, id: \.self) { days in
                            Text(formatDays(days)).tag(days)
                        }
                    }
                    .accessibilityLabel("Auto-delete period")
                }
            } header: {
                Text("Auto Cleanup")
            } footer: {
                if viewModel.autoDeleteEnabled {
                    Text("Favorites are never automatically deleted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearHistoryAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All History")
                    }
                }
                .accessibilityLabel("Clear all history")
                .accessibilityHint("Permanently deletes all clipboard items except favorites")
            } header: {
                Text("Data")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clear History?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard items. Favorites will be preserved. This action cannot be undone.")
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(
                excludedBundleIds: viewModel.excludedAppBundleIds,
                onSelect: { bundleId in
                    viewModel.addExcludedApp(bundleId)
                }
            )
        }
    }

    // MARK: - Helpers

    private func formatDays(_ days: Int) -> String {
        if days < 30 {
            return "\(days) days"
        } else if days < 365 {
            let months = days / 30
            return months == 1 ? "1 month" : "\(months) months"
        } else {
            let years = days / 365
            return years == 1 ? "1 year" : "\(years) years"
        }
    }

    private func clearHistory() {
        Task {
            await StorageManager.shared.deleteAllItems(keepFavorites: true)
        }
    }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let excludedBundleIds: [String]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""

    var filteredApps: [InstalledApp] {
        let nonExcluded = installedApps.filter { !excludedBundleIds.contains($0.bundleId) }
        if searchText.isEmpty {
            return nonExcluded
        }
        return nonExcluded.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Application")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            TextField("Search applications...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredApps) { app in
                Button {
                    onSelect(app.bundleId)
                    dismiss()
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 24, height: 24)
                        }
                        Text(app.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadInstalledApps()
        }
    }

    private func loadInstalledApps() {
        let workspace = NSWorkspace.shared
        let urls = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
            + FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)

        var apps: [InstalledApp] = []
        for url in urls {
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) {
                for appURL in contents where appURL.pathExtension == "app" {
                    if let bundle = Bundle(url: appURL),
                       let bundleId = bundle.bundleIdentifier,
                       let name = bundle.infoDictionary?["CFBundleName"] as? String
                           ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                           ?? appURL.deletingPathExtension().lastPathComponent as String?
                    {
                        let icon = workspace.icon(forFile: appURL.path)
                        apps.append(InstalledApp(bundleId: bundleId, name: name, icon: icon))
                    }
                }
            }
        }

        installedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Installed App

struct InstalledApp: Identifiable {
    let bundleId: String
    let name: String
    let icon: NSImage?

    var id: String { bundleId }
}

// MARK: - Preview

#if DEBUG
    struct PrivacyTabView_Previews: PreviewProvider {
        static var previews: some View {
            PrivacyTabView(viewModel: PreferencesViewModel())
                .frame(width: 500, height: 500)
        }
    }
#endif
