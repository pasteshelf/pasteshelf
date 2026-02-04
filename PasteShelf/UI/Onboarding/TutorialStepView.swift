//
//  TutorialStepView.swift
//  PasteShelf
//
//  Quick tutorial step showing key features and usage.
//

import SwiftUI

/// Tutorial step view with visual feature demonstrations
struct TutorialStepView: View {
    // MARK: - Properties

    @State private var currentTip = 0
    private let tips: [TutorialTip] = TutorialTip.allCases

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Quick Tour")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            // Tip carousel
            tipCarouselView

            // Page indicators
            pageIndicatorsView

            Spacer()

            // Tips list
            allTipsListView

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Tip Carousel

    private var tipCarouselView: some View {
        TabView(selection: $currentTip) {
            ForEach(tips) { tip in
                tipCardView(tip)
                    .tag(tip.rawValue)
            }
        }
        .tabViewStyle(.automatic)
        .frame(height: 200)
    }

    private func tipCardView(_ tip: TutorialTip) -> some View {
        VStack(spacing: 16) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(tip.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: tip.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(tip.color)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(tip.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(tip.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Page Indicators

    private var pageIndicatorsView: some View {
        HStack(spacing: 8) {
            ForEach(tips) { tip in
                Circle()
                    .fill(currentTip == tip.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentTip)
            }
        }
    }

    // MARK: - All Tips List

    private var allTipsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Shortcuts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(keys: "⌘ ⇧ V", description: "Open clipboard panel")
                shortcutRow(keys: "↑ ↓", description: "Navigate items")
                shortcutRow(keys: "⏎", description: "Paste selected item")
                shortcutRow(keys: "⌘ F", description: "Search clipboard")
                shortcutRow(keys: "⌘ S", description: "Toggle favorite")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func shortcutRow(keys: String, description: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 70, alignment: .leading)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Tutorial Tip

private enum TutorialTip: Int, CaseIterable, Identifiable {
    case floatingPanel
    case search
    case favorites
    case menuBar

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .floatingPanel:
            return "rectangle.stack"
        case .search:
            return "magnifyingglass"
        case .favorites:
            return "star.fill"
        case .menuBar:
            return "menubar.rectangle"
        }
    }

    var title: String {
        switch self {
        case .floatingPanel:
            return "Floating Panel"
        case .search:
            return "Instant Search"
        case .favorites:
            return "Favorites"
        case .menuBar:
            return "Menu Bar"
        }
    }

    var description: String {
        switch self {
        case .floatingPanel:
            return "Press your hotkey to open the clipboard panel. Use arrow keys to navigate and Enter to paste."
        case .search:
            return "Start typing to search through your clipboard history. Use filters to narrow down results."
        case .favorites:
            return "Press ⌘S to mark items as favorites. They'll be preserved even when auto-cleanup runs."
        case .menuBar:
            return "Click the menu bar icon to quickly access recent items or open preferences."
        }
    }

    var color: Color {
        switch self {
        case .floatingPanel:
            return .blue
        case .search:
            return .purple
        case .favorites:
            return .yellow
        case .menuBar:
            return .green
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct TutorialStepView_Previews: PreviewProvider {
        static var previews: some View {
            TutorialStepView()
                .frame(width: 500, height: 600)
        }
    }
#endif
