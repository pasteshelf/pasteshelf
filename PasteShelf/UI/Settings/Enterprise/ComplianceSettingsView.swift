//
//  ComplianceSettingsView.swift
//  PasteShelf
//
//  Container view for compliance settings, hosting HIPAA, GDPR, and SOC 2 sub-sections.
//

import SwiftUI

// MARK: - ComplianceSettingsView

/// Container view for the Compliance settings tab within Enterprise preferences.
///
/// Hosts `HIPAASettingsView`, `GDPRSettingsView`, and `SOC2SettingsView` as sub-tabs.
struct ComplianceSettingsView: View {

    @StateObject private var viewModel = ComplianceSettingsViewModel()

    // MARK: - Body

    var body: some View {
        TabView {
            HIPAASettingsView(viewModel: viewModel)
                .tabItem { Label("HIPAA", systemImage: "cross.case.fill") }

            GDPRSettingsView(viewModel: viewModel)
                .tabItem { Label("GDPR", systemImage: "person.badge.shield.checkmark.fill") }

            SOC2SettingsView(viewModel: viewModel)
                .tabItem { Label("SOC 2", systemImage: "checkmark.seal.fill") }
        }
        .task { viewModel.loadConfiguration() }
    }
}

// MARK: - Previews

#if DEBUG
struct ComplianceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ComplianceSettingsView()
            .frame(width: 600, height: 500)
    }
}
#endif
