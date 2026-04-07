//
//  VectorSimilarityCalculator.swift
//  PasteShelf
//
//  Calculates cosine similarity between embedding vectors.
//  Used for semantic search to find similar content.
//

import Accelerate
import Foundation

/// Calculates similarity between embedding vectors using cosine similarity
enum VectorSimilarityCalculator {
    // MARK: - Cosine Similarity

    /// Calculates cosine similarity between two vectors
    /// - Parameters:
    ///   - vectorA: First embedding vector
    ///   - vectorB: Second embedding vector
    /// - Returns: Similarity score between 0.0 and 1.0 (1.0 = identical)
    static func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else {
            return 0.0
        }

        // Use Accelerate framework for efficient SIMD operations
        var dotProduct = 0.0
        var magnitudeA = 0.0
        var magnitudeB = 0.0

        vDSP_dotprD(vectorA, 1, vectorB, 1, &dotProduct, vDSP_Length(vectorA.count))
        vDSP_dotprD(vectorA, 1, vectorA, 1, &magnitudeA, vDSP_Length(vectorA.count))
        vDSP_dotprD(vectorB, 1, vectorB, 1, &magnitudeB, vDSP_Length(vectorB.count))

        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)

        guard magnitude > 0 else {
            return 0.0
        }

        // Normalize to 0-1 range (cosine similarity is -1 to 1)
        let similarity = dotProduct / magnitude
        return (similarity + 1.0) / 2.0
    }

    /// Calculates similarity between a query vector and multiple candidate vectors
    /// - Parameters:
    ///   - queryVector: The query embedding vector
    ///   - candidates: Array of candidate vectors with their IDs
    /// - Returns: Array of (id, similarity) tuples, sorted by similarity descending
    static func findSimilar<ID: Hashable>(
        to queryVector: [Double],
        in candidates: [(id: ID, vector: [Double])],
        threshold: Double = 0.0
    ) -> [(id: ID, similarity: Double)] {
        var results: [(id: ID, similarity: Double)] = []

        for candidate in candidates {
            let similarity = self.cosineSimilarity(queryVector, candidate.vector)
            if similarity >= threshold {
                results.append((candidate.id, similarity))
            }
        }

        // Sort by similarity descending
        return results.sorted { $0.similarity > $1.similarity }
    }

    /// Finds the k most similar vectors (k-nearest neighbors)
    /// - Parameters:
    ///   - queryVector: The query embedding vector
    ///   - candidates: Array of candidate vectors with their IDs
    ///   - k: Maximum number of results to return
    ///   - threshold: Minimum similarity threshold
    /// - Returns: Array of (id, similarity) tuples, limited to k results
    static func findTopK<ID: Hashable>(
        to queryVector: [Double],
        in candidates: [(id: ID, vector: [Double])],
        k: Int,
        threshold: Double = 0.0
    ) -> [(id: ID, similarity: Double)] {
        let similar = self.findSimilar(to: queryVector, in: candidates, threshold: threshold)
        return Array(similar.prefix(k))
    }

    // MARK: - Batch Operations

    /// Calculates pairwise similarities between all vectors
    /// - Parameter vectors: Array of vectors with their IDs
    /// - Returns: Dictionary mapping (id1, id2) pairs to their similarity
    static func pairwiseSimilarity<ID: Hashable>(
        _ vectors: [(id: ID, vector: [Double])]
    ) -> [Set<ID>: Double] {
        var results: [Set<ID>: Double] = [:]

        for i in 0 ..< vectors.count {
            for j in (i + 1) ..< vectors.count {
                let similarity = self.cosineSimilarity(vectors[i].vector, vectors[j].vector)
                let key = Set([vectors[i].id, vectors[j].id])
                results[key] = similarity
            }
        }

        return results
    }

    // MARK: - Distance Metrics

    /// Calculates Euclidean distance between two vectors (lower = more similar)
    /// - Parameters:
    ///   - vectorA: First embedding vector
    ///   - vectorB: Second embedding vector
    /// - Returns: Euclidean distance
    static func euclideanDistance(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else {
            return Double.infinity
        }

        var difference = [Double](repeating: 0, count: vectorA.count)
        vDSP_vsubD(vectorB, 1, vectorA, 1, &difference, 1, vDSP_Length(vectorA.count))

        var sumOfSquares = 0.0
        vDSP_dotprD(difference, 1, difference, 1, &sumOfSquares, vDSP_Length(difference.count))

        return sqrt(sumOfSquares)
    }

    /// Converts Euclidean distance to a similarity score (0-1 range)
    /// - Parameter distance: The Euclidean distance
    /// - Returns: Similarity score (1.0 = identical, approaches 0 for distant vectors)
    static func distanceToSimilarity(_ distance: Double) -> Double {
        1.0 / (1.0 + distance)
    }
}
