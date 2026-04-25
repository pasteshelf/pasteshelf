//
//  EmptyStateView.swift
//  PasteShelf
//
//  A reusable empty state component with icon, title, message, and action.
//

import SwiftUI

/// A reusable empty state view
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon with subtle animation
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Presets

extension EmptyStateView {
    /// Empty clipboard state
    static func noClipboardItems(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "clipboard",
            title: String(localized: "No clipboard items"),
            message: String(localized: "Copy something to see it here"),
            actionTitle: nil,
            action: action
        )
    }

    /// No search results state
    static func noSearchResults(onClearSearch: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: String(localized: "No matching items"),
            message: String(localized: "Try a different search term"),
            actionTitle: String(localized: "Clear Search"),
            action: onClearSearch
        )
    }

    /// No filtered results state
    static func noFilteredResults(onClearFilters: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "line.3.horizontal.decrease.circle",
            title: String(localized: "No matching items"),
            message: String(localized: "Try different filter settings"),
            actionTitle: String(localized: "Clear Filters"),
            action: onClearFilters
        )
    }

    /// Error loading state
    static func loadingError(message: String, onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: String(localized: "Unable to load"),
            message: message,
            actionTitle: String(localized: "Try Again"),
            action: onRetry
        )
    }
}

// MARK: - Preview

#if DEBUG
    struct EmptyStateView_Previews: PreviewProvider {
        static var previews: some View {
            VStack {
                EmptyStateView.noClipboardItems()
                    .frame(height: 300)

                Divider()

                EmptyStateView.noSearchResults {}
                    .frame(height: 300)
            }
            .frame(width: 400)
        }
    }
#endif
