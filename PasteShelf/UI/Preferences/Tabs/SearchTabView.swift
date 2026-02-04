//
//  SearchTabView.swift
//  PasteShelf
//
//  Search settings tab in preferences.
//  Includes semantic search toggle and indexing progress (Pro feature).
//

import SwiftUI

/// Search settings tab view
struct SearchTabView: View {
    // MARK: - Properties

    @StateObject private var embeddingGenerator = EmbeddingGenerator.shared
    @ObservedObject private var licenseManager = LicenseManager.shared

    @State private var showingUpgradePrompt = false
    @State private var showingClearConfirmation = false
    @State private var indexedCount: Int = 0
    @State private var semanticSearchEnabled: Bool = UserDefaults.standard.bool(forKey: "semanticSearchEnabled")
    @State private var semanticThreshold: Double = UserDefaults.standard.double(forKey: "semanticThreshold") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "semanticThreshold")

    // MARK: - Body

    var body: some View {
        Form {
            // Search Settings Section
            Section {
                searchSettingsSection
            } header: {
                Text("Search Settings")
            }

            // Semantic Search Section (Pro)
            Section {
                semanticSearchSection
            } header: {
                HStack {
                    Text("Semantic Search")
                    ProBadge()
                }
            }

            // Indexing Status Section
            if licenseManager.isFeatureAvailable(.semanticSearch) {
                Section {
                    indexingStatusSection
                } header: {
                    Text("Search Index")
                }
            }

            // Pro Feature Notice (if not licensed)
            if !licenseManager.isFeatureAvailable(.semanticSearch) {
                Section {
                    proFeatureNotice
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await loadIndexedCount()
        }
        .alert("Clear Search Index", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearIndex()
            }
        } message: {
            Text("This will delete all cached embeddings. The index will be rebuilt automatically in the background.")
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(feature: .semanticSearch)
        }
    }

    // MARK: - Search Settings Section

    @ViewBuilder
    private var searchSettingsSection: some View {
        // Fuzzy matching toggle (available to all)
        Toggle("Enable Fuzzy Matching", isOn: .constant(true))
            .disabled(true) // Always enabled for now

        Text("Fuzzy matching finds approximate matches even with typos or partial words.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Semantic Search Section

    @ViewBuilder
    private var semanticSearchSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable Semantic Search", isOn: Binding(
            get: { semanticSearchEnabled },
            set: { newValue in
                if newValue, !licenseManager.isFeatureAvailable(.semanticSearch) {
                    showingUpgradePrompt = true
                } else {
                    semanticSearchEnabled = newValue
                    UserDefaults.standard.set(newValue, forKey: "semanticSearchEnabled")
                    if newValue {
                        Task {
                            await startIndexing()
                        }
                    }
                }
            }
        ))
        .disabled(!licenseManager.isFeatureAvailable(.semanticSearch))

        // Description
        VStack(alignment: .leading, spacing: 4) {
            Text("Semantic search uses AI to understand the meaning of your queries, not just keywords.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Find items with natural language like \"that email from last week\" or \"code snippet with function\".")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        // Similarity Threshold
        if licenseManager.isFeatureAvailable(.semanticSearch) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Similarity Threshold")
                    Spacer()
                    Text(String(format: "%.0f%%", semanticThreshold * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $semanticThreshold, in: 0.3...0.8, step: 0.05) { _ in
                    UserDefaults.standard.set(semanticThreshold, forKey: "semanticThreshold")
                }

                Text("Higher values show only more relevant matches. Lower values show more results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!semanticSearchEnabled)
        }
    }

    // MARK: - Indexing Status Section

    @ViewBuilder
    private var indexingStatusSection: some View {
        // Index Status
        HStack {
            Image(systemName: embeddingGenerator.isIndexing ? "brain" : "brain.filled.head.profile")
                .font(.title2)
                .foregroundStyle(embeddingGenerator.isIndexing ? .blue : .green)
                .symbolEffect(.pulse, isActive: embeddingGenerator.isIndexing)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(embeddingGenerator.isIndexing ? "Indexing..." : "Ready")
                    .font(.headline)

                Text("\(indexedCount) items indexed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if embeddingGenerator.isIndexing {
                ProgressView(value: embeddingGenerator.progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)

        // Progress Details (when indexing)
        if embeddingGenerator.isIndexing {
            HStack {
                Text("Progress")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(embeddingGenerator.indexedCount) / \(embeddingGenerator.totalToIndex)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }

        // Actions
        HStack {
            Button(action: {
                Task {
                    await startIndexing()
                }
            }) {
                Label("Rebuild Index", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(embeddingGenerator.isIndexing || !semanticSearchEnabled)

            Spacer()

            Button(role: .destructive, action: {
                showingClearConfirmation = true
            }) {
                Label("Clear Index", systemImage: "trash")
            }
            .disabled(embeddingGenerator.isIndexing)
        }
    }

    // MARK: - Pro Feature Notice

    @ViewBuilder
    private var proFeatureNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro Feature")
                        .font(.headline)

                    Text("Semantic Search is available with PasteShelf Pro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Upgrade to Pro to search your clipboard history using natural language. Find what you're looking for even if you don't remember the exact words.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Upgrade to Pro") {
                showingUpgradePrompt = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func loadIndexedCount() async {
        indexedCount = await embeddingGenerator.indexedItemCount()
    }

    private func startIndexing() async {
        await embeddingGenerator.clearOutdatedEmbeddings()
        _ = await embeddingGenerator.indexAllMissingEmbeddings()
        await loadIndexedCount()
    }

    private func clearIndex() {
        Task {
            await embeddingGenerator.clearAllEmbeddings()
            indexedCount = 0
        }
    }
}

// MARK: - Pro Badge

/// Small badge indicating a Pro feature
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.2))
            .foregroundStyle(.purple)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
    struct SearchTabView_Previews: PreviewProvider {
        static var previews: some View {
            SearchTabView()
                .frame(width: 450, height: 400)
        }
    }
#endif
