//
//  FloatingPanelView.swift
//  PasteShelf
//
//  SwiftUI root view for the floating clipboard history panel.
//  Displays list of clipboard items with keyboard navigation support.
//

import SwiftUI

/// Main view for the floating clipboard history panel
struct FloatingPanelView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: FloatingPanelViewModel

    /// Focus state for keyboard handling
    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.items.isEmpty {
                emptyStateView
            } else {
                itemListView
            }
        }
        .frame(width: 400, height: 500)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(keys: [.downArrow]) { _ in
            viewModel.selectNext()
            return .handled
        }
        .onKeyPress(keys: [.upArrow]) { _ in
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(keys: [.return]) { _ in
            Task {
                await viewModel.pasteSelected()
            }
            return .handled
        }
        .onKeyPress(keys: [.escape]) { _ in
            viewModel.hide()
            return .handled
        }
        .onKeyPress(keys: [.delete]) { _ in
            Task {
                await viewModel.deleteSelected()
            }
            return .handled
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(viewModel.items.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No clipboard items")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Copy something to see it here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .padding()
    }

    // MARK: - Item List

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: viewModel.selectedIndex == index,
                            onSelect: {
                                viewModel.select(at: index)
                            },
                            onPaste: {
                                Task {
                                    await viewModel.paste(item: item)
                                }
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < viewModel.items.count else { return }
                let itemId = viewModel.items[newIndex].id
                withAnimation {
                    proxy.scrollTo(itemId, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct FloatingPanelView_Previews: PreviewProvider {
        static var previews: some View {
            let viewModel = FloatingPanelViewModel()

            // Manually set items for preview
            FloatingPanelView(viewModel: viewModel)
                .onAppear {
                    // Simulate some items in preview
                }
        }
    }
#endif
