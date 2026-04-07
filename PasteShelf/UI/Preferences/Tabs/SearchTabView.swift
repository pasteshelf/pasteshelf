//
//  SearchTabView.swift
//  PasteShelf
//
//  Search settings tab in preferences.
//  Includes semantic search toggle, indexing progress, and OCR settings.
//

import SwiftUI

// MARK: - SearchTabView

/// Search settings tab view
struct SearchTabView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        Form {
            // Search Settings Section
            Section {
                self.searchSettingsSection
            } header: {
                Text("Search Settings")
            }

            // Semantic Search Section
            Section {
                self.semanticSearchSection
            } header: {
                Text("Semantic Search")
            }

            // Indexing Status Section
            Section {
                self.indexingStatusSection
            } header: {
                Text("Search Index")
            }

            // OCR Search Section
            Section {
                self.ocrSearchSection
            } header: {
                Text("OCR Search")
            }

            // OCR Processing Status Section
            Section {
                self.ocrProcessingStatusSection
            } header: {
                Text("Image Text Extraction")
            }
        }
        .formStyle(.grouped)
        .task {
            await loadIndexedCount()
            await loadOCRProcessedCount()
        }
        .alert("Clear Search Index", isPresented: self.$showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearIndex()
            }
        } message: {
            Text("This will delete all cached embeddings. The index will be rebuilt automatically in the background.")
        }
        .alert("Clear OCR Cache", isPresented: self.$showingOCRClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearOCRCache()
            }
        } message: {
            Text(
                "This will delete all extracted text from images."
                    + " The cache will be rebuilt when you process images again."
            )
        }
    }

    // MARK: Private

    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var embeddingGenerator = EmbeddingGenerator.shared
    @ObservedObject private var ocrGenerator = OCRGenerator.shared

    @State private var showingClearConfirmation = false
    @State private var showingOCRClearConfirmation = false
    @State private var indexedCount: Int = 0
    @State private var ocrProcessedCount: Int = 0

    private var semanticSearchEnabled: Bool {
        self.settingsManager.search.semanticSearchEnabled
    }

    private var semanticThreshold: Double {
        self.settingsManager.search.semanticThreshold
    }

    private var ocrSearchEnabled: Bool {
        self.settingsManager.search.ocrSearchEnabled
    }

    private var ocrConfidenceThreshold: Double {
        self.settingsManager.search.ocrConfidenceThreshold
    }

    // MARK: - Search Settings Section

    @ViewBuilder private var searchSettingsSection: some View {
        // Fuzzy matching toggle
        Toggle("Enable Fuzzy Matching", isOn: Binding(
            get: { self.settingsManager.search.fuzzyMatchEnabled },
            set: { newValue in
                self.settingsManager.update { $0.search.fuzzyMatchEnabled = newValue }
            }
        ))

        Text("Fuzzy matching finds approximate matches even with typos or partial words.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Semantic Search Section

    @ViewBuilder private var semanticSearchSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable Semantic Search", isOn: Binding(
            get: { self.settingsManager.search.semanticSearchEnabled },
            set: { newValue in
                self.settingsManager.update { $0.search.semanticSearchEnabled = newValue }
                // AppDelegate.handleSettingsChange handles starting/cancelling indexing
            }
        ))

        // Description
        VStack(alignment: .leading, spacing: 4) {
            Text("Semantic search uses AI to understand the meaning of your queries, not just keywords.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                "Find items with natural language like \"that email from last week\" or \"code snippet with function\"."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        // Similarity Threshold
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Similarity Threshold")
                Spacer()
                Text(String(format: "%.0f%%", self.semanticThreshold * 100))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { self.settingsManager.search.semanticThreshold },
                    set: { newValue in self.settingsManager.update { $0.search.semanticThreshold = newValue } }
                ),
                in: 0.3 ... 0.8,
                step: 0.05
            )

            Text("Higher values show only more relevant matches. Lower values show more results.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!self.semanticSearchEnabled)
    }

    // MARK: - OCR Search Section

    @ViewBuilder private var ocrSearchSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable OCR Search", isOn: Binding(
            get: { self.settingsManager.search.ocrSearchEnabled },
            set: { newValue in
                self.settingsManager.update { $0.search.ocrSearchEnabled = newValue }
                // AppDelegate.handleSettingsChange handles starting/cancelling OCR processing
            }
        ))

        // Description
        VStack(alignment: .leading, spacing: 4) {
            Text("OCR search extracts text from images so you can search for content within screenshots and photos.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Find images containing specific text like \"error message\" or \"phone number\".")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        // Confidence Threshold
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Confidence Threshold")
                Spacer()
                Text(String(format: "%.0f%%", self.ocrConfidenceThreshold * 100))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { self.settingsManager.search.ocrConfidenceThreshold },
                    set: { newValue in self.settingsManager.update { $0.search.ocrConfidenceThreshold = newValue } }
                ),
                in: 0.3 ... 0.9,
                step: 0.05
            )

            Text("Higher values require more accurate text recognition. Lower values may include misread text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!self.ocrSearchEnabled)
    }

    // MARK: - OCR Processing Status Section

    @ViewBuilder private var ocrProcessingStatusSection: some View {
        // Processing Status
        HStack {
            Image(systemName: self.ocrGenerator.isProcessing ? "text.viewfinder" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(self.ocrGenerator.isProcessing ? .blue : .green)
                .symbolEffect(.pulse, isActive: self.ocrGenerator.isProcessing)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.ocrGenerator.isProcessing ? "Processing Images..." : "Ready")
                    .font(.headline)

                Text("\(self.ocrProcessedCount) images processed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if self.ocrGenerator.isProcessing {
                ProgressView(value: self.ocrGenerator.progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)

        // Progress Details (when processing)
        if self.ocrGenerator.isProcessing {
            HStack {
                Text("Progress")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(self.ocrGenerator.processedCount) / \(self.ocrGenerator.totalToProcess)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }

        // Actions
        HStack {
            Button(
                action: {
                    Task {
                        await startOCRProcessing()
                    }
                },
                label: {
                    Label("Process Images", systemImage: "text.viewfinder")
                }
            )
            .disabled(self.ocrGenerator.isProcessing || !self.ocrSearchEnabled)

            Spacer()

            Button(
                role: .destructive,
                action: {
                    self.showingOCRClearConfirmation = true
                },
                label: {
                    Label("Clear Cache", systemImage: "trash")
                }
            )
            .disabled(self.ocrGenerator.isProcessing)
        }
    }

    // MARK: - Indexing Status Section

    @ViewBuilder private var indexingStatusSection: some View {
        // Index Status
        HStack {
            Image(systemName: self.embeddingGenerator.isIndexing ? "brain" : "brain.filled.head.profile")
                .font(.title2)
                .foregroundStyle(self.embeddingGenerator.isIndexing ? .blue : .green)
                .symbolEffect(.pulse, isActive: self.embeddingGenerator.isIndexing)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.embeddingGenerator.isIndexing ? "Indexing..." : "Ready")
                    .font(.headline)

                Text("\(self.indexedCount) items indexed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if self.embeddingGenerator.isIndexing {
                ProgressView(value: self.embeddingGenerator.progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)

        // Progress Details (when indexing)
        if self.embeddingGenerator.isIndexing {
            HStack {
                Text("Progress")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(self.embeddingGenerator.indexedCount) / \(self.embeddingGenerator.totalToIndex)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }

        // Actions
        HStack {
            Button(
                action: {
                    Task {
                        await startIndexing()
                    }
                },
                label: {
                    Label("Rebuild Index", systemImage: "arrow.triangle.2.circlepath")
                }
            )
            .disabled(self.embeddingGenerator.isIndexing || !self.semanticSearchEnabled)

            Spacer()

            Button(
                role: .destructive,
                action: {
                    self.showingClearConfirmation = true
                },
                label: {
                    Label("Clear Index", systemImage: "trash")
                }
            )
            .disabled(self.embeddingGenerator.isIndexing)
        }
    }
}

// MARK: - SearchTabView Actions

private extension SearchTabView {
    func loadIndexedCount() async {
        self.indexedCount = await self.embeddingGenerator.indexedItemCount()
    }

    func loadOCRProcessedCount() async {
        self.ocrProcessedCount = await self.ocrGenerator.processedItemCount()
    }

    func startIndexing() async {
        await self.embeddingGenerator.clearOutdatedEmbeddings()
        _ = await self.embeddingGenerator.indexAllMissingEmbeddings()
        await self.loadIndexedCount()
    }

    func startOCRProcessing() async {
        await self.ocrGenerator.clearOutdatedOCR()
        _ = await self.ocrGenerator.processAllMissingOCR()
        await self.loadOCRProcessedCount()
    }

    func clearIndex() {
        Task {
            await self.embeddingGenerator.clearAllEmbeddings()
            self.indexedCount = 0
        }
    }

    func clearOCRCache() {
        Task {
            await self.ocrGenerator.clearAllOCR()
            self.ocrProcessedCount = 0
        }
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
