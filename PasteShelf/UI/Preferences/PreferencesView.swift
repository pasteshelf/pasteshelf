//
//  PreferencesView.swift
//  PasteShelf
//
//  Main preferences window view with sidebar navigation.
//

import SwiftUI

/// Main preferences window view
struct PreferencesView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            GeneralTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.general.displayNameKey, systemImage: PreferencesTab.general.iconName) }
                .tag(PreferencesTab.general)

            PrivacyTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.privacy.displayNameKey, systemImage: PreferencesTab.privacy.iconName) }
                .tag(PreferencesTab.privacy)

            AppearanceTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.appearance.displayNameKey, systemImage: PreferencesTab.appearance.iconName) }
                .tag(PreferencesTab.appearance)

            ShortcutsTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.shortcuts.displayNameKey, systemImage: PreferencesTab.shortcuts.iconName) }
                .tag(PreferencesTab.shortcuts)

            SearchTabView()
                .tabItem { Label(PreferencesTab.search.displayNameKey, systemImage: PreferencesTab.search.iconName) }
                .tag(PreferencesTab.search)

            SyncTabView()
                .tabItem { Label(PreferencesTab.sync.displayNameKey, systemImage: PreferencesTab.sync.iconName) }
                .tag(PreferencesTab.sync)

            AutomationTabView()
                .tabItem { Label(PreferencesTab.automation.displayNameKey, systemImage: PreferencesTab.automation.iconName) }
                .tag(PreferencesTab.automation)

            #if !APP_STORE
            PluginSettingsView()
                .tabItem { Label(PreferencesTab.plugins.displayNameKey, systemImage: PreferencesTab.plugins.iconName) }
                .tag(PreferencesTab.plugins)
            #endif

            #if !APP_STORE
            EnterpriseTabView()
                .tabItem { Label(PreferencesTab.enterprise.displayNameKey, systemImage: PreferencesTab.enterprise.iconName) }
                .tag(PreferencesTab.enterprise)
            #endif

            AboutTabView()
                .tabItem { Label(PreferencesTab.about.displayNameKey, systemImage: PreferencesTab.about.iconName) }
                .tag(PreferencesTab.about)
        }
        .frame(minWidth: 500, minHeight: 700)
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#if DEBUG
    struct PreferencesView_Previews: PreviewProvider {
        static var previews: some View {
            PreferencesView(viewModel: PreferencesViewModel())
        }
    }
#endif
