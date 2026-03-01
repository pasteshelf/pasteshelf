//
//  SearchTabView.swift
//  PasteShelf
//
//  Search settings tab in preferences.
//  Includes semantic search toggle, indexing progress, and OCR settings.
//

import SwiftUI

/// Search settings tab view
struct SearchTabView: View {
    // MARK: - Properties

    @ObservedObject private var embeddingGenerator = EmbeddingGenerator.shared
    @ObservedObject private var ocrGenerator = OCRGenerator.shared

    @State private var showingClearConfirmation = false
    @State private var showingOCRClearConfirmation = false
    @State private var indexedCount: Int = 0
    @State private var ocrProcessedCount: Int = 0
    @State private var semanticSearchEnabled: Bool = SettingsManager.shared.search.semanticSearchEnabled
    @State private var semanticThreshold: Double = SettingsManager.shared.search.semanticThreshold
    @State private var ocrSearchEnabled: Bool = SettingsManager.shared.search.ocrSearchEnabled
    @State private var ocrConfidenceThreshold: Double = SettingsManager.shared.search.ocrConfidenceThreshold

    // MARK: - Body

    var body: some View {
        Form {
            // Search Settings Section
            Section {
                searchSettingsSection
            } header: {
                Text("Search Settings")
            }

            // Semantic Search Section
            Section {
                semanticSearchSection
            } header: {
                Text("Semantic Search")
            }

            // Indexing Status Section
            Section {
                indexingStatusSection
            } header: {
                Text("Search Index")
            }

            // OCR Search Section
            Section {
                ocrSearchSection
            } header: {
                Text("OCR Search")
            }

            // OCR Processing Status Section
            Section {
                ocrProcessingStatusSection
            } header: {
                Text("Image Text Extraction")
            }
        }
        .formStyle(.grouped)
        .task {
            await loadIndexedCount()
            await loadOCRProcessedCount()
        }
        .alert("Clear Search Index", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearIndex()
            }
        } message: {
            Text("This will delete all cached embeddings. The index will be rebuilt automatically in the background.")
        }
        .alert("Clear OCR Cache", isPresented: $showingOCRClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearOCRCache()
            }
        } message: {
            Text("This will delete all extracted text from images. The cache will be rebuilt when you process images again.")
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
                semanticSearchEnabled = newValue
                SettingsManager.shared.update { $0.search.semanticSearchEnabled = newValue }
                if newValue {
                    Task {
                        await startIndexing()
                    }
                }
            }
        ))

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Similarity Threshold")
                Spacer()
                Text(String(format: "%.0f%%", semanticThreshold * 100))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $semanticThreshold, in: 0.3...0.8, step: 0.05) { _ in
                SettingsManager.shared.update { $0.search.semanticThreshold = semanticThreshold }
            }

            Text("Higher values show only more relevant matches. Lower values show more results.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!semanticSearchEnabled)
    }

    // MARK: - OCR Search Section

    @ViewBuilder
    private var ocrSearchSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable OCR Search", isOn: Binding(
            get: { ocrSearchEnabled },
            set: { newValue in
                ocrSearchEnabled = newValue
                SettingsManager.shared.update { $0.search.ocrSearchEnabled = newValue }
                if newValue {
                    Task {
                        await startOCRProcessing()
                    }
                }
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
                Text(String(format: "%.0f%%", ocrConfidenceThreshold * 100))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $ocrConfidenceThreshold, in: 0.3...0.9, step: 0.05) { _ in
                SettingsManager.shared.update { $0.search.ocrConfidenceThreshold = ocrConfidenceThreshold }
            }

            Text("Higher values require more accurate text recognition. Lower values may include misread text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!ocrSearchEnabled)
    }

    // MARK: - OCR Processing Status Section

    @ViewBuilder
    private var ocrProcessingStatusSection: some View {
        // Processing Status
        HStack {
            Image(systemName: ocrGenerator.isProcessing ? "text.viewfinder" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(ocrGenerator.isProcessing ? .blue : .green)
                .symbolEffect(.pulse, isActive: ocrGenerator.isProcessing)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ocrGenerator.isProcessing ? "Processing Images..." : "Ready")
                    .font(.headline)

                Text("\(ocrProcessedCount) images processed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if ocrGenerator.isProcessing {
                ProgressView(value: ocrGenerator.progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)

        // Progress Details (when processing)
        if ocrGenerator.isProcessing {
            HStack {
                Text("Progress")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(ocrGenerator.processedCount) / \(ocrGenerator.totalToProcess)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }

        // Actions
        HStack {
            Button(action: {
                Task {
                    await startOCRProcessing()
                }
            }) {
                Label("Process Images", systemImage: "text.viewfinder")
            }
            .disabled(ocrGenerator.isProcessing || !ocrSearchEnabled)

            Spacer()

            Button(role: .destructive, action: {
                showingOCRClearConfirmation = true
            }) {
                Label("Clear Cache", systemImage: "trash")
            }
            .disabled(ocrGenerator.isProcessing)
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

    // MARK: - Actions

    private func loadIndexedCount() async {
        indexedCount = await embeddingGenerator.indexedItemCount()
    }

    private func loadOCRProcessedCount() async {
        ocrProcessedCount = await ocrGenerator.processedItemCount()
    }

    private func startIndexing() async {
        await embeddingGenerator.clearOutdatedEmbeddings()
        _ = await embeddingGenerator.indexAllMissingEmbeddings()
        await loadIndexedCount()
    }

    private func startOCRProcessing() async {
        await ocrGenerator.clearOutdatedOCR()
        _ = await ocrGenerator.processAllMissingOCR()
        await loadOCRProcessedCount()
    }

    private func clearIndex() {
        Task {
            await embeddingGenerator.clearAllEmbeddings()
            indexedCount = 0
        }
    }

    private func clearOCRCache() {
        Task {
            await ocrGenerator.clearAllOCR()
            ocrProcessedCount = 0
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
