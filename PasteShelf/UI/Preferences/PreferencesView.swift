//
//  PreferencesView.swift
//  PasteShelf
//
//  Main preferences window view with sidebar navigation.
//

import SwiftUI

// MARK: - PreferencesView

/// Main preferences window view
struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            GeneralTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.general.displayName, systemImage: PreferencesTab.general.iconName) }
                .tag(PreferencesTab.general)

            PrivacyTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.privacy.displayName, systemImage: PreferencesTab.privacy.iconName) }
                .tag(PreferencesTab.privacy)

            AppearanceTabView(viewModel: viewModel)
                .tabItem {
                    Label(PreferencesTab.appearance.displayName, systemImage: PreferencesTab.appearance.iconName)
                }
                .tag(PreferencesTab.appearance)

            ShortcutsTabView(viewModel: viewModel)
                .tabItem { Label(PreferencesTab.shortcuts.displayName, systemImage: PreferencesTab.shortcuts.iconName) }
                .tag(PreferencesTab.shortcuts)

            SearchTabView()
                .tabItem { Label(PreferencesTab.search.displayName, systemImage: PreferencesTab.search.iconName) }
                .tag(PreferencesTab.search)

            SyncTabView()
                .tabItem { Label(PreferencesTab.sync.displayName, systemImage: PreferencesTab.sync.iconName) }
                .tag(PreferencesTab.sync)

            AutomationTabView()
                .tabItem {
                    Label(PreferencesTab.automation.displayName, systemImage: PreferencesTab.automation.iconName)
                }
                .tag(PreferencesTab.automation)

            #if !APP_STORE
                PluginSettingsView()
                    .tabItem { Label(PreferencesTab.plugins.displayName, systemImage: PreferencesTab.plugins.iconName) }
                    .tag(PreferencesTab.plugins)
            #endif

            #if !APP_STORE
                EnterpriseTabView()
                    .tabItem { Label(
                        PreferencesTab.enterprise.displayName,
                        systemImage: PreferencesTab.enterprise.iconName
                    ) }
                    .tag(PreferencesTab.enterprise)
            #endif

            AboutTabView()
                .tabItem { Label(PreferencesTab.about.displayName, systemImage: PreferencesTab.about.iconName) }
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
