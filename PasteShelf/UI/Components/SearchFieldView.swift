//
//  SearchFieldView.swift
//  PasteShelf
//
//  A search text field with clear button for the floating panel.
//  Provides real-time search with focus management.
//

import SwiftUI

// MARK: - SearchFieldView

/// Search text field with clear button and keyboard handling
struct SearchFieldView: View {
    // MARK: Internal

    /// The search query text
    @Binding var text: String

    /// Placeholder text
    var placeholder: String = "Search clipboard..."

    /// Called when search is submitted (Enter pressed)
    var onSubmit: (() -> Void)?

    /// Called when the clear button is pressed
    var onClear: (() -> Void)?

    /// Whether the field should be focused on appear
    var autoFocus: Bool = true

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium))

            // Text field
            TextField(self.placeholder, text: self.$text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(self.$isFocused)
                .onSubmit {
                    self.onSubmit?()
                }

            // Clear button (visible when text is not empty)
            if !self.text.isEmpty {
                Button(action: self.clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    self.isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .onAppear {
            if self.autoFocus {
                // Delay focus to allow view to fully appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isFocused = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: self.text.isEmpty)
    }

    // MARK: Private

    // MARK: - State

    @FocusState private var isFocused: Bool

    private func clearSearch() {
        self.text = ""
        self.onClear?()
        self.isFocused = true
    }
}

// MARK: - Search Field Style Modifier

extension View {
    /// Applies standard search field styling
    func searchFieldStyle() -> some View {
        modifier(SearchFieldStyleModifier())
    }
}

// MARK: - SearchFieldStyleModifier

struct SearchFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - Preview

#if DEBUG
    struct SearchFieldView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            // MARK: Internal

            var body: some View {
                VStack(spacing: 16) {
                    Text("Empty State")
                        .font(.caption)
                    SearchFieldView(text: self.$searchText)

                    Text("With Content")
                        .font(.caption)
                    SearchFieldView(text: self.$searchTextWithContent)

                    Text("Custom Placeholder")
                        .font(.caption)
                    SearchFieldView(
                        text: self.$searchText,
                        placeholder: "Find items..."
                    )
                }
                .padding()
                .frame(width: 300)
            }

            // MARK: Private

            @State private var searchText = ""
            @State private var searchTextWithContent = "hello world"
        }

        static var previews: some View {
            PreviewWrapper()
        }
    }
#endif
