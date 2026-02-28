//
//  EnterpriseTabView.swift
//  PasteShelf
//
//  Container view for the Enterprise preferences tab.
//  Hosts SSO, MDM, and Admin Console settings as sub-tabs within the Enterprise section.
//

import SwiftUI

// MARK: - EnterpriseTabView

/// Top-level container for the Enterprise preferences tab.
///
/// Hosts `SSOSettingsView`, `MDMSettingsView`, and `AdminSettingsView` as sub-tabs
/// using a `TabView`. This view is displayed when the user selects the "Enterprise"
/// item in the preferences sidebar.
struct EnterpriseTabView: View {

    // MARK: - Body

    var body: some View {
        TabView {
            SSOSettingsView()
                .tabItem { Label("SSO", systemImage: "key.fill") }

            MDMSettingsView()
                .tabItem { Label("MDM", systemImage: "lock.shield") }

            AdminSettingsView()
                .tabItem { Label("Admin", systemImage: "server.rack") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
    struct EnterpriseTabView_Previews: PreviewProvider {
        static var previews: some View {
            EnterpriseTabView()
                .frame(width: 700, height: 460)
        }
    }
#endif
