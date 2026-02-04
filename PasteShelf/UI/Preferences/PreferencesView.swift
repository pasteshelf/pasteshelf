//
//  PreferencesView.swift
//  PasteShelf
//
//  Main preferences window view with tabbed interface.
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
                .tabItem {
                    Label(PreferencesTab.general.displayName, systemImage: PreferencesTab.general.iconName)
                }
                .tag(PreferencesTab.general)

            PrivacyTabView(viewModel: viewModel)
                .tabItem {
                    Label(PreferencesTab.privacy.displayName, systemImage: PreferencesTab.privacy.iconName)
                }
                .tag(PreferencesTab.privacy)

            AppearanceTabView(viewModel: viewModel)
                .tabItem {
                    Label(
                        PreferencesTab.appearance.displayName,
                        systemImage: PreferencesTab.appearance.iconName
                    )
                }
                .tag(PreferencesTab.appearance)

            ShortcutsTabView(viewModel: viewModel)
                .tabItem {
                    Label(
                        PreferencesTab.shortcuts.displayName,
                        systemImage: PreferencesTab.shortcuts.iconName
                    )
                }
                .tag(PreferencesTab.shortcuts)

            LicenseTabView(viewModel: LicenseViewModel())
                .tabItem {
                    Label(
                        PreferencesTab.license.displayName,
                        systemImage: PreferencesTab.license.iconName
                    )
                }
                .tag(PreferencesTab.license)

            AboutTabView()
                .tabItem {
                    Label(PreferencesTab.about.displayName, systemImage: PreferencesTab.about.iconName)
                }
                .tag(PreferencesTab.about)
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
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
