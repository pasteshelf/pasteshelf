//
//  AuditLogViewModel.swift
//  PasteShelf
//
//  ViewModel for the audit log viewer in the Enterprise preferences tab.
//

import AppKit
import Combine
import Foundation
import os.log
import UniformTypeIdentifiers

// MARK: - AuditLogViewModel

/// ViewModel for the audit log viewer in the Enterprise settings panel.
///
/// `AuditLogViewModel` fetches, filters, and exposes audit log entries for display
/// in `AuditLogView`. Filter changes are debounced via Combine publishers so that
/// the storage query is not re-issued on every keystroke or picker tap.
///
/// Export methods produce CSV or JSON files and present an `NSSavePanel` so the
/// user can choose a destination before saving.
@MainActor
final class AuditLogViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates the view model and wires up Combine publishers for filter auto-reload.
    init() {
        setupFilterObservation()
        Task { await loadEvents() }
    }

    // MARK: Internal

    // MARK: - Published Filter State

    /// The category used to filter displayed events. `nil` means all categories.
    @Published var selectedCategory: AuditEventCategory?

    /// The inclusive lower bound of the displayed date range.
    @Published var dateRangeStart: Date?

    /// The inclusive upper bound of the displayed date range.
    @Published var dateRangeEnd: Date?

    // MARK: - Published Display State

    /// The audit log entries currently shown in the viewer.
    @Published private(set) var events: [AuditLogDisplayItem] = []

    /// `true` while a storage fetch is in progress.
    @Published private(set) var isLoading: Bool = false

    /// A human-readable error message from the most recent failed operation, if any.
    @Published var errorMessage: String?

    /// The current retention window in days, surfaced for the Picker.
    @Published var retentionDays: Int = AuditManager.shared.retentionConfiguration.retentionDays

    /// Number of events that failed to decrypt in the last load.
    @Published private(set) var decryptionFailureCount: Int = 0

    // MARK: - Public Actions

    /// Fetches filtered audit events from storage and maps them to display items.
    ///
    /// Events are fetched up to `fetchLimit` entries, sorted most-recent-first.
    /// Detail payloads are decrypted individually; entries that cannot be decrypted
    /// are silently skipped rather than surfacing a hard error.
    func loadEvents() async {
        guard let storage = AuditManager.shared.storage else {
            events = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let entries = try await storage.fetchEvents(
                category: selectedCategory,
                from: dateRangeStart,
                to: dateRangeEnd,
                limit: fetchLimit
            )

            var displayItems: [AuditLogDisplayItem] = []
            var failures = 0
            for entry in entries {
                let detail: [String: String]
                do {
                    detail = try storage.decryptDetail(for: entry)
                } catch {
                    logger
                        .warning(
                            "Could not decrypt detail for entry \(String(describing: entry.id)): \(error.localizedDescription)"
                        )
                    detail = [:]
                    failures += 1
                }
                if let item = AuditLogDisplayItem.from(entry, decryptedDetail: detail) {
                    displayItems.append(item)
                }
            }

            events = displayItems
            decryptionFailureCount = failures
            logger.info("Audit log viewer loaded \(displayItems.count) events")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to load audit events: \(error.localizedDescription)")
        }
    }

    /// Resets all filter fields to their default (unfiltered) values.
    func clearFilters() {
        selectedCategory = nil
        dateRangeStart = nil
        dateRangeEnd = nil
    }

    /// Persists a new retention window via AuditManager.
    func updateRetentionDays(_ days: Int) {
        AuditManager.shared.updateRetentionDays(days)
        retentionDays = days
    }

    /// Exports the currently displayed events as a CSV file.
    ///
    /// Writes the CSV to a temporary file, then presents an `NSSavePanel` for the
    /// user to choose the destination. The temporary file is deleted after the copy.
    func exportAsCSV() {
        let csvString = buildCSV()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_log_\(Date().timeIntervalSince1970).csv")

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to write CSV file: \(error.localizedDescription)"
            return
        }

        presentSavePanel(sourceURL: tempURL, suggestedFilename: "audit_log.csv", fileExtension: "csv")
    }

    /// Exports the currently displayed events as a JSON file.
    ///
    /// Writes the JSON array to a temporary file, then presents an `NSSavePanel` for
    /// the user to choose the destination. The temporary file is deleted after the copy.
    func exportAsJSON() {
        let jsonObjects = events.map { item -> [String: Any] in
            buildJSONObject(for: item)
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObjects, options: [.prettyPrinted, .sortedKeys])
        } catch {
            errorMessage = "Failed to serialize events as JSON: \(error.localizedDescription)"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_log_\(Date().timeIntervalSince1970).json")

        do {
            try jsonData.write(to: tempURL, options: .atomic)
        } catch {
            errorMessage = "Failed to write JSON file: \(error.localizedDescription)"
            return
        }

        presentSavePanel(sourceURL: tempURL, suggestedFilename: "audit_log.json", fileExtension: "json")
    }

    // MARK: Private

    // MARK: - CSV Helpers

    private static let csvColumns = [
        "Timestamp", "Category", "Action", "Severity",
        "User ID", "Device ID", "Resource Type", "Resource ID", "Detail",
    ]

    // MARK: - Private Properties

    private let logger = Logger.audit
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    /// Maximum number of events returned from storage in a single fetch.
    private let fetchLimit = 500

    // MARK: - Private Helpers

    /// Wires Combine publishers on the three filter properties so that any change
    /// triggers a debounced reload after 0.3 seconds.
    private func setupFilterObservation() {
        let categoryPublisher = $selectedCategory.map { _ in () }.eraseToAnyPublisher()
        let startPublisher = $dateRangeStart.map { _ in () }.eraseToAnyPublisher()
        let endPublisher = $dateRangeEnd.map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany(categoryPublisher, startPublisher, endPublisher)
            .dropFirst()
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else {
                    return
                }
                loadTask?.cancel()
                loadTask = Task { await self.loadEvents() }
            }
            .store(in: &cancellables)
    }

    /// Presents a modal `NSSavePanel` configured for the given file type.
    ///
    /// On confirmation the source file is copied to the user-chosen destination.
    /// The temporary source file is removed after the panel is dismissed.
    ///
    /// - Parameters:
    ///   - sourceURL: The temporary file to copy from.
    ///   - suggestedFilename: The default filename shown in the panel.
    ///   - fileExtension: The required file extension for the allowed file types.
    private func presentSavePanel(sourceURL: URL, suggestedFilename: String, fileExtension: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            defer {
                try? FileManager.default.removeItem(at: sourceURL)
            }
            guard response == .OK, let destinationURL = panel.url else {
                return
            }
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                self?.logger.info("Audit log exported to \(destinationURL.path)")
            } catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Failed to save file: \(message)"
                }
                self?.logger.error("Export save failed: \(message)")
            }
        }
    }

    private func buildCSV() -> String {
        let isoFormatter = ISO8601DateFormatter()
        var lines: [String] = [Self.csvColumns.map(csvEscape).joined(separator: ",")]

        for item in events {
            let detailJSON: String = if let data = try? JSONSerialization.data(
                withJSONObject: item.detail,
                options: .sortedKeys
            ),
                let string = String(data: data, encoding: .utf8)
            {
                string
            } else {
                "{}"
            }

            let row = [
                isoFormatter.string(from: item.timestamp),
                item.categoryDisplayName,
                item.actionDisplayName,
                item.severity.rawValue,
                item.userId ?? "",
                item.deviceId ?? "",
                item.resourceType ?? "",
                item.resourceId ?? "",
                detailJSON,
            ].map(csvEscape).joined(separator: ",")

            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    /// Escapes a single CSV field value, wrapping in quotes if it contains a comma, quote, or newline.
    private func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if needsQuoting {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - JSON Helpers

    private func buildJSONObject(for item: AuditLogDisplayItem) -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        var obj: [String: Any] = [
            "timestamp": isoFormatter.string(from: item.timestamp),
            "category": item.categoryDisplayName,
            "action": item.actionDisplayName,
            "severity": item.severity.rawValue,
            "detail": item.detail,
        ]
        if let userId = item.userId {
            obj["userId"] = userId
        }
        if let deviceId = item.deviceId {
            obj["deviceId"] = deviceId
        }
        if let resourceType = item.resourceType {
            obj["resourceType"] = resourceType
        }
        if let resourceId = item.resourceId {
            obj["resourceId"] = resourceId
        }
        return obj
    }
}
