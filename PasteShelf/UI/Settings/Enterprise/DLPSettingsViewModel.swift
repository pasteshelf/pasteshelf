//
//  DLPSettingsViewModel.swift
//  PasteShelf
//
//  ViewModel for the DLP settings viewer in the Enterprise preferences tab.
//

import AppKit
import Combine
import Foundation
import os.log
import UniformTypeIdentifiers

// MARK: - DLPSettingsViewModel

/// ViewModel for the DLP settings panel in the Enterprise settings tab.
///
/// `DLPSettingsViewModel` loads and exposes DLP rules and recent violations for display
/// in `DLPSettingsView`. It provides actions to toggle, delete, and install rules, as
/// well as export methods that write CSV or JSON files via an `NSSavePanel`.
@MainActor
final class DLPSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates the view model and triggers the initial data load.
    init() {
        Task { await self.loadData() }

        // Refresh data when a DLP violation is detected
        NotificationCenter.default.publisher(for: .dlpViolationDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadData() }
            }
            .store(in: &self.cancellables)
    }

    // MARK: Internal

    // MARK: - Published Display State

    /// The DLP rules currently loaded from storage.
    @Published private(set) var rules: [DLPRule] = []

    /// The most recent DLP violations loaded from the manager.
    @Published private(set) var recentViolations: [DLPViolation] = []

    /// `true` while a data fetch is in progress.
    @Published private(set) var isLoading: Bool = false

    /// A human-readable error message from the most recent failed operation, if any.
    @Published var errorMessage: String?

    /// Controls presentation of the rule editor sheet.
    @Published var showingRuleEditor: Bool = false

    /// Controls presentation of the pattern test sheet.
    @Published var showingPatternTest: Bool = false

    /// The rule being edited. `nil` when creating a new rule.
    @Published var editingRule: DLPRule?

    // MARK: - Public Actions

    /// Loads rules and recent violations from `DLPManager`.
    func loadData() async {
        self.isLoading = true
        self.errorMessage = nil
        defer { isLoading = false }

        await DLPManager.shared.loadRules()
        await DLPManager.shared.loadRecentViolations()

        self.rules = DLPManager.shared.rules
        self.recentViolations = DLPManager.shared.recentViolations

        self.logger.info("DLP settings loaded \(self.rules.count) rules and \(self.recentViolations.count) violations")
    }

    /// Toggles the `isEnabled` state of the given rule and persists the change.
    ///
    /// - Parameter rule: The `DLPRule` whose enabled state should be toggled.
    func toggleRule(_ rule: DLPRule) async {
        var updated = rule
        updated.isEnabled = !rule.isEnabled
        updated.updatedAt = Date()

        do {
            try await DLPManager.shared.updateRule(updated)
            self.rules = DLPManager.shared.rules
            self.logger.info("Toggled DLP rule '\(rule.name)' to enabled=\(updated.isEnabled)")
        } catch {
            self.errorMessage = error.localizedDescription
            self.logger.error("Failed to toggle DLP rule '\(rule.name)': \(error.localizedDescription)")
        }
    }

    /// Deletes the given rule from storage.
    ///
    /// - Parameter rule: The `DLPRule` to delete.
    func deleteRule(_ rule: DLPRule) async {
        do {
            try await DLPManager.shared.deleteRule(id: rule.id)
            self.rules = DLPManager.shared.rules
            self.logger.info("Deleted DLP rule '\(rule.name)'")
        } catch {
            self.errorMessage = error.localizedDescription
            self.logger.error("Failed to delete DLP rule '\(rule.name)': \(error.localizedDescription)")
        }
    }

    /// Installs the default DLP rules if no rules are currently configured.
    func installDefaults() async {
        await DLPManager.shared.installDefaultRulesIfNeeded()
        self.rules = DLPManager.shared.rules
        self.logger.info("Installed default DLP rules, total: \(self.rules.count)")
    }

    /// Saves (add or update) the given rule via `DLPManager`.
    ///
    /// - Parameter rule: The `DLPRule` to save. If its `id` matches an existing rule,
    ///   it is updated; otherwise it is added as a new rule.
    func saveRule(_ rule: DLPRule) async {
        do {
            if self.rules.contains(where: { $0.id == rule.id }) {
                try await DLPManager.shared.updateRule(rule)
                self.logger.info("Updated DLP rule '\(rule.name)'")
            } else {
                try await DLPManager.shared.addRule(rule)
                self.logger.info("Added DLP rule '\(rule.name)'")
            }
            self.rules = DLPManager.shared.rules
        } catch {
            self.errorMessage = error.localizedDescription
            self.logger.error("Failed to save DLP rule '\(rule.name)': \(error.localizedDescription)")
        }
    }

    // MARK: - Export

    /// Exports the current violations list as a CSV file, presenting an `NSSavePanel`.
    func exportViolationsAsCSV() {
        let csvString = self.buildViolationsCSV()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dlp_violations_\(Date().timeIntervalSince1970).csv")

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            self.errorMessage = "Failed to write CSV file: \(error.localizedDescription)"
            return
        }

        self.presentSavePanel(sourceURL: tempURL, suggestedFilename: "dlp_violations.csv", fileExtension: "csv")
    }

    /// Exports the current violations list as a JSON file, presenting an `NSSavePanel`.
    func exportViolationsAsJSON() {
        let jsonObjects = self.recentViolations.map { self.buildViolationJSONObject(for: $0) }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObjects, options: [.prettyPrinted, .sortedKeys])
        } catch {
            self.errorMessage = "Failed to serialize violations as JSON: \(error.localizedDescription)"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dlp_violations_\(Date().timeIntervalSince1970).json")

        do {
            try jsonData.write(to: tempURL, options: .atomic)
        } catch {
            self.errorMessage = "Failed to write JSON file: \(error.localizedDescription)"
            return
        }

        self.presentSavePanel(sourceURL: tempURL, suggestedFilename: "dlp_violations.json", fileExtension: "json")
    }

    // MARK: Private

    // MARK: - CSV Helpers

    private static let csvColumns = [
        "Timestamp", "Rule Name", "Action Taken", "Was Blocked",
        "Content Preview", "Matched Pattern", "Source App",
    ]

    // MARK: - Private Properties

    private let logger = Logger.security
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private Helpers

    /// Presents a modal `NSSavePanel` configured for the given file type.
    ///
    /// On confirmation the source file is copied to the user-chosen destination.
    /// The temporary source file is removed after the panel is dismissed.
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
                self?.logger.info("DLP violations exported to \(destinationURL.path)")
            } catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Failed to save file: \(message)"
                }
                self?.logger.error("Export save failed: \(message)")
            }
        }
    }

    private func buildViolationsCSV() -> String {
        let isoFormatter = ISO8601DateFormatter()
        var lines: [String] = [Self.csvColumns.map(self.csvEscape).joined(separator: ",")]

        for violation in self.recentViolations {
            let row = [
                isoFormatter.string(from: violation.timestamp),
                violation.ruleName,
                violation.actionTaken.rawValue,
                violation.wasBlocked ? "true" : "false",
                violation.contentPreview,
                violation.matchedPattern,
                violation.sourceAppName ?? "",
            ].map(self.csvEscape).joined(separator: ",")

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

    private func buildViolationJSONObject(for violation: DLPViolation) -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        var obj: [String: Any] = [
            "id": violation.id.uuidString,
            "ruleId": violation.ruleId.uuidString,
            "ruleName": violation.ruleName,
            "timestamp": isoFormatter.string(from: violation.timestamp),
            "actionTaken": violation.actionTaken.rawValue,
            "wasBlocked": violation.wasBlocked,
            "contentPreview": violation.contentPreview,
            "matchedPattern": violation.matchedPattern,
        ]
        if let appName = violation.sourceAppName {
            obj["sourceAppName"] = appName
        }
        if let bundleId = violation.sourceAppBundleId {
            obj["sourceAppBundleId"] = bundleId
        }
        return obj
    }
}
