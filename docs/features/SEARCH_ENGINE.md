# Search Engine

> **Last Updated**: 2026-02-03 | **Reading Time**: 18 minutes

Complete documentation for PasteShelf's search capabilities.

---

## Table of Contents

- [Overview](#overview)
- [Search Modes](#search-modes)
- [Full-Text Search](#full-text-search)
- [Semantic Search](#semantic-search)
- [OCR Search](#ocr-search)
- [Search Index](#search-index)
- [Query Syntax](#query-syntax)
- [Performance](#performance)

---

## Overview

PasteShelf provides multiple search modes to help you find clipboard items quickly:

| Mode | Description |
|------|-------------|
| Full-Text | Traditional text matching |
| Fuzzy | Approximate matching with typo tolerance |
| Filter | Filter by type, date, app |
| Semantic | AI-powered natural language search |
| OCR | Search text within images |

### Search Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Search Architecture                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   User Query                                                             │
│       │                                                                  │
│       ▼                                                                  │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Query Parser                                  │   │
│   │                                                                  │   │
│   │   "meeting notes from:safari type:text last:week"               │   │
│   │        │              │            │         │                   │   │
│   │        ▼              ▼            ▼         ▼                   │   │
│   │    keywords       filter       filter    filter                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│       │                                                                  │
│       ▼                                                                  │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                  Search Dispatcher                               │   │
│   │                                                                  │   │
│   │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────┐ │   │
│   │   │ Full-Text  │ │  Fuzzy      │ │ Semantic    │ │  OCR     │ │   │
│   │   │   Search    │ │   Search    │ │   Search    │ │  Search  │ │   │
│   │   └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └─────┬────┘ │   │
│   │          │               │               │              │       │   │
│   │          └───────────────┴───────┬───────┴──────────────┘       │   │
│   └──────────────────────────────────┼───────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Result Merger & Ranker                        │   │
│   │                                                                  │   │
│   │   • Combine results from all search modes                        │   │
│   │   • Apply relevance scoring                                      │   │
│   │   • Remove duplicates                                            │   │
│   │   • Sort by score + recency                                      │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│                              Search Results                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Search Modes

### Full-Text Search

Traditional text matching with support for:
- Exact phrase matching
- Prefix matching
- Case-insensitive search
- Unicode normalization

```swift
class FullTextSearchEngine {
    func search(query: String, in items: [ClipboardItem]) -> [SearchResult] {
        let normalizedQuery = query.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        return items.compactMap { item in
            guard let text = item.textContent else { return nil }

            let normalizedText = text.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)

            // Check for match
            if let range = normalizedText.range(of: normalizedQuery) {
                let score = calculateScore(
                    query: normalizedQuery,
                    text: normalizedText,
                    matchRange: range
                )
                return SearchResult(item: item, score: score, matchRanges: [range])
            }

            return nil
        }
        .sorted { $0.score > $1.score }
    }

    private func calculateScore(query: String, text: String, matchRange: Range<String.Index>) -> Double {
        var score = 1.0

        // Boost exact matches
        if text == query {
            score *= 2.0
        }

        // Boost matches at start
        if matchRange.lowerBound == text.startIndex {
            score *= 1.5
        }

        // Boost shorter content (more specific)
        score *= min(1.0, 100.0 / Double(text.count))

        return score
    }
}
```

### Fuzzy Search

Tolerates typos and minor variations:

```swift
class FuzzySearchEngine {
    private let maxEditDistance = 2

    func search(query: String, in items: [ClipboardItem]) -> [SearchResult] {
        return items.compactMap { item in
            guard let text = item.textContent else { return nil }

            // Find best matching substring
            let words = text.components(separatedBy: .whitespacesAndNewlines)

            var bestMatch: (word: String, distance: Int)?

            for word in words {
                let distance = levenshteinDistance(query.lowercased(), word.lowercased())
                if distance <= maxEditDistance {
                    if bestMatch == nil || distance < bestMatch!.distance {
                        bestMatch = (word, distance)
                    }
                }
            }

            guard let match = bestMatch else { return nil }

            // Score inversely proportional to edit distance
            let score = 1.0 - (Double(match.distance) / Double(maxEditDistance + 1))

            return SearchResult(item: item, score: score, matchType: .fuzzy)
        }
        .sorted { $0.score > $1.score }
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[m][n]
    }
}
```

---

## Semantic Search

AI-powered search using natural language understanding.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Semantic Search Pipeline                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Natural Language Query: "that email about the project deadline"        │
│                                     │                                    │
│                                     ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │              NLEmbedding (Apple NaturalLanguage)                 │   │
│   │                                                                  │   │
│   │   Query → 512-dim vector: [0.23, -0.45, 0.12, ...]             │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                     │                                    │
│                                     ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                  Vector Similarity Search                        │   │
│   │                                                                  │
│   │   Compare query vector to pre-computed item embeddings           │   │
│   │   using cosine similarity                                        │   │
│   │                                                                  │   │
│   │   Item 1: [0.21, -0.43, 0.14, ...] → similarity: 0.95           │   │
│   │   Item 2: [0.05, 0.82, -0.33, ...] → similarity: 0.23           │   │
│   │   Item 3: [0.19, -0.41, 0.10, ...] → similarity: 0.87           │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                     │                                    │
│                                     ▼                                    │
│                          Ranked Results                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
import NaturalLanguage

class SemanticSearchEngine {
    private let embedding: NLEmbedding?

    init() {
        // Load word embedding model
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    func search(query: String, in items: [ClipboardItem]) async -> [SearchResult] {
        guard let embedding = embedding else {
            Logger.search.warning("Semantic search unavailable - no embedding model")
            return []
        }

        // Get query embedding
        guard let queryVector = computeDocumentEmbedding(query, embedding: embedding) else {
            return []
        }

        // Compare with item embeddings
        return items.compactMap { item in
            guard let itemVector = item.semanticEmbedding ?? computeEmbedding(for: item) else {
                return nil
            }

            let similarity = cosineSimilarity(queryVector, itemVector)

            // Threshold for relevance
            guard similarity > 0.5 else { return nil }

            return SearchResult(
                item: item,
                score: similarity,
                matchType: .semantic
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func computeDocumentEmbedding(_ text: String, embedding: NLEmbedding) -> [Double]? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var vectors: [[Double]] = []

        for word in words {
            if let vector = embedding.vector(for: word.lowercased()) {
                vectors.append(vector)
            }
        }

        guard !vectors.isEmpty else { return nil }

        // Average word vectors
        let dimensions = vectors[0].count
        var avgVector = [Double](repeating: 0, count: dimensions)

        for vector in vectors {
            for i in 0..<dimensions {
                avgVector[i] += vector[i]
            }
        }

        for i in 0..<dimensions {
            avgVector[i] /= Double(vectors.count)
        }

        return avgVector
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}
```

### Semantic Search Examples

| Query | Finds |
|-------|-------|
| "meeting notes" | Items containing "meeting", "notes", "agenda", "minutes" |
| "that code snippet" | Code-related content, syntax-highlighted text |
| "email about project" | Email content, project discussions |
| "phone number from yesterday" | Phone numbers copied recently |

---

## OCR Search

Search text within images using Vision framework.

### OCR Processing

```swift
import Vision

class OCRSearchEngine {
    private var ocrCache: [UUID: String] = [:]

    func extractText(from item: ClipboardItem) async throws -> String? {
        // Check cache first
        if let cached = ocrCache[item.id] {
            return cached
        }

        guard let imageData = item.content?.imageData,
              let cgImage = NSImage(data: imageData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "de-DE", "fr-FR", "es-ES"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    guard let observations = request.results else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")

                    // Cache the result
                    self.ocrCache[item.id] = text

                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func search(query: String, in imageItems: [ClipboardItem]) async -> [SearchResult] {
        var results: [SearchResult] = []

        for item in imageItems where item.contentType.isImage {
            if let ocrText = try? await extractText(from: item) {
                // Search within OCR text
                if ocrText.localizedCaseInsensitiveContains(query) {
                    results.append(SearchResult(
                        item: item,
                        score: 0.8,
                        matchType: .ocr,
                        ocrText: ocrText
                    ))
                }
            }
        }

        return results
    }
}
```

### OCR Settings

```
┌─────────────────────────────────────────────────────────────┐
│                      OCR Settings                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Preferences → Search → OCR:                                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ☑ Enable OCR for image search                       │    │
│  │                                                      │    │
│  │  Recognition level:                                  │    │
│  │  ○ Fast (lower accuracy, faster)                    │    │
│  │  ● Accurate (higher accuracy, slower)               │    │
│  │                                                      │    │
│  │  Languages:                                          │    │
│  │  ☑ English                                          │    │
│  │  ☑ German                                           │    │
│  │  ☐ French                                           │    │
│  │  ☐ Spanish                                          │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  ☑ Index images on capture (recommended)             │    │
│  │  ☐ Index images on demand only                      │    │
│  │                                                      │    │
│  │  [Re-index All Images]                               │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Search Index

### Index Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Search Index Structure                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Full-Text Index                               │   │
│   │                                                                  │   │
│   │   Implementation: NSUserActivity + Spotlight                     │   │
│   │                                                                  │   │
│   │   Indexed fields:                                                │   │
│   │   • textContent (full text, searchable)                          │   │
│   │   • title (if set)                                               │   │
│   │   • sourceApp (app name)                                         │   │
│   │                                                                  │   │
│   │   Features:                                                      │   │
│   │   • Tokenization                                                 │   │
│   │   • Stemming                                                     │   │
│   │   • Stop word removal                                            │   │
│   │   • System-wide search integration                               │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Semantic Index                                 │   │
│   │                                                                  │   │
│   │   Implementation: In-memory vector store                         │   │
│   │                                                                  │   │
│   │   Stored data:                                                   │   │
│   │   • Item ID → 512-dim embedding vector                           │   │
│   │   • Normalized for fast cosine similarity                        │   │
│   │                                                                  │   │
│   │   Size: ~2KB per item                                            │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      OCR Index                                    │   │
│   │                                                                  │   │
│   │   Implementation: CoreData + full-text                           │   │
│   │                                                                  │   │
│   │   Stored data:                                                   │   │
│   │   • Item ID → extracted text                                     │   │
│   │   • Bounding boxes for highlighting                              │   │
│   │                                                                  │   │
│   │   Processed: On capture or on-demand                             │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Index Updates

```swift
class SearchIndexManager {
    private let spotlight = SpotlightIndexer()
    private let semanticIndex = SemanticIndexer()
    private let ocrIndex = OCRIndexer()

    /// Index a new clipboard item
    func indexItem(_ item: ClipboardItem) async {
        // Full-text index (always)
        await spotlight.index(item)

        // Semantic index
        if options.enableSemanticSearch {
            await semanticIndex.index(item)
        }

        // OCR index for images
        if options.enableOCRSearch && item.contentType.isImage {
            await ocrIndex.index(item)
        }
    }

    /// Remove item from all indexes
    func removeItem(_ itemId: UUID) async {
        await spotlight.remove(itemId)
        await semanticIndex.remove(itemId)
        await ocrIndex.remove(itemId)
    }

    /// Rebuild all indexes
    func rebuildIndexes() async {
        let allItems = await StorageManager.shared.fetchAll()

        for item in allItems {
            await indexItem(item)
        }
    }
}
```

---

## Query Syntax

### Basic Queries

| Query | Behavior |
|-------|----------|
| `hello` | Items containing "hello" |
| `hello world` | Items containing both "hello" AND "world" |
| `"hello world"` | Items containing exact phrase "hello world" |

### Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `type:` | `type:image` | Filter by content type |
| `from:` | `from:safari` | Filter by source app |
| `in:` | `in:favorites` | Filter by folder/collection |
| `is:` | `is:pinned` | Filter by status |

### Date Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `date:` | `date:today` | Items from today |
| `date:` | `date:2026-02-03` | Items from specific date |
| `before:` | `before:yesterday` | Items before date |
| `after:` | `after:last-week` | Items after date |

### Advanced Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `OR` | `hello OR world` | Either term |
| `NOT` | `hello NOT world` | Exclude term |
| `-` | `hello -world` | Exclude (shorthand) |
| `*` | `hel*` | Wildcard prefix |

### Examples

```
# Find all text items from Safari
type:text from:safari

# Find images from today
type:image date:today

# Find pinned items containing "project"
project is:pinned

# Find emails not from Outlook
email type:text -from:outlook

# Find items from last week about meetings
meeting date:last-week
```

---

## Performance

### Search Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Full-text search | < 50ms | For 10K items |
| Fuzzy search | < 100ms | For 10K items |
| Semantic search | < 200ms | For 10K items |
| OCR search | < 500ms | For 1K images |
| Index update | < 10ms | Per item |

### Optimization Techniques

```swift
class SearchOptimizer {
    // Cache recent searches
    private var searchCache = LRUCache<String, [SearchResult]>(capacity: 100)

    // Debounce rapid typing
    private var searchDebouncer = Debouncer(delay: 0.15)

    func search(query: String) async -> [SearchResult] {
        // Check cache
        if let cached = searchCache.get(query) {
            return cached
        }

        // Debounce
        await searchDebouncer.debounce()

        // Early termination for empty query
        guard !query.isEmpty else {
            return await fetchRecent(limit: 50)
        }

        // Parallel search across engines
        async let fullText = fullTextEngine.search(query: query)
        async let fuzzy = fuzzyEngine.search(query: query)
        async let semantic = semanticEngine.search(query: query)

        let results = await mergeResults(fullText, fuzzy, semantic)

        // Cache results
        searchCache.set(query, results)

        return results
    }
}
```

### Index Maintenance

```swift
class IndexMaintenanceScheduler {
    func scheduleOptimization() {
        // Daily optimization at 3 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: Date())
        components.hour = 3
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // Schedule background task
        BGTaskScheduler.shared.submit(
            BGAppRefreshTaskRequest(identifier: "com.pasteshelf.indexOptimization")
        )
    }

    func performOptimization() async {
        // Compact indexes
        await spotlight.compact()
        await semanticIndex.compact()

        // Remove orphaned entries
        await cleanupOrphanedEntries()

        // Update statistics
        await updateSearchStatistics()
    }
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Clipboard Engine](CLIPBOARD_ENGINE.md) | Content capture |
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Optimization |
| [Architecture](../architecture/ARCHITECTURE.md) | System overview |

---

*Last updated: 2026-02-03*
