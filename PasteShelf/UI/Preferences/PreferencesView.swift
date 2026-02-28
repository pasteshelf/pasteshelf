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
        NavigationSplitView {
            List(PreferencesTab.allCases, selection: $viewModel.selectedTab) { tab in
                Label(tab.displayName, systemImage: tab.iconName)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            tabContent
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .general:
            GeneralTabView(viewModel: viewModel)
        case .privacy:
            PrivacyTabView(viewModel: viewModel)
        case .appearance:
            AppearanceTabView(viewModel: viewModel)
        case .shortcuts:
            ShortcutsTabView(viewModel: viewModel)
        case .search:
            SearchTabView()
        case .sync:
            SyncTabView()
        case .automation:
            AutomationTabView()
        case .enterprise:
            EnterpriseTabView()
        case .about:
            AboutTabView()
        }
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
