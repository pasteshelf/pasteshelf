//
//  DLPRuleEditorView.swift
//  PasteShelf
//
//  Sheet for creating and editing DLP rules in the Enterprise preferences tab.
//

import SwiftUI

// MARK: - DLPRuleEditorView

/// A modal sheet for creating or editing a DLP rule.
///
/// When `rule` is `nil` the editor initialises with default values and creates a new
/// rule on save. When `rule` is non-nil the editor is pre-populated and the saved rule
/// preserves the original `id` and `createdAt`.
///
/// The caller receives the constructed `DLPRule` via the `onSave` closure.
struct DLPRuleEditorView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates the editor, pre-populating fields from `rule` if provided.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls the sheet's presentation.
    ///   - rule: An existing rule to edit, or `nil` to create a new rule.
    ///   - onSave: Closure called with the constructed rule when the user taps Save.
    init(isPresented: Binding<Bool>, rule: DLPRule?, onSave: @escaping (DLPRule) -> Void) {
        _isPresented = isPresented
        self.rule = rule
        self.onSave = onSave

        if let existing = rule {
            _name = State(initialValue: existing.name)
            _pattern = State(initialValue: existing.pattern)
            _patternCategory = State(initialValue: existing.patternCategory)
            _severity = State(initialValue: existing.severity)
            _selectedActions = State(initialValue: Set(existing.actions))
            _isEnabled = State(initialValue: existing.isEnabled)
        } else {
            _name = State(initialValue: "")
            _pattern = State(initialValue: "")
            _patternCategory = State(initialValue: .custom)
            _severity = State(initialValue: .medium)
            _selectedActions = State(initialValue: [.alert, .logOnly])
            _isEnabled = State(initialValue: true)
        }
    }

    // MARK: Internal

    @Binding var isPresented: Bool

    let rule: DLPRule?
    let onSave: (DLPRule) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(self.rule == nil ? "New DLP Rule" : "Edit DLP Rule")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Form content
            Form {
                self.ruleDetailsSection
                self.severitySection
                self.actionsSection
            }
            .formStyle(.grouped)

            Divider()

            // Bottom buttons
            HStack {
                Button("Cancel") {
                    self.isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    self.saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(self.name.trimmingCharacters(in: .whitespaces).isEmpty || self.pattern
                    .trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480)
        .frame(minHeight: 480)
    }

    // MARK: Private

    // MARK: - State

    @State private var name: String
    @State private var pattern: String
    @State private var patternCategory: DLPPatternCategory
    @State private var severity: SensitiveSeverity
    @State private var selectedActions: Set<DLPAction>
    @State private var isEnabled: Bool
    @State private var regexError: String?

    // MARK: - Rule Details Section

    private var ruleDetailsSection: some View {
        Section("Rule Details") {
            LabeledContent("Name") {
                TextField("e.g. Credit Card Numbers", text: self.$name)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Picker("Category", selection: self.$patternCategory) {
                ForEach(DLPPatternCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }

            LabeledContent("Pattern") {
                TextField("Regular expression pattern", text: self.$pattern)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: self.pattern) { _, _ in regexError = nil }
            }

            if let regexError {
                Text(regexError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Enabled", isOn: self.$isEnabled)
        }
    }

    // MARK: - Severity Section

    private var severitySection: some View {
        Section("Severity") {
            Picker("Severity", selection: self.$severity) {
                Text("None").tag(SensitiveSeverity.none)
                Text("Low").tag(SensitiveSeverity.low)
                Text("Medium").tag(SensitiveSeverity.medium)
                Text("High").tag(SensitiveSeverity.high)
                Text("Critical").tag(SensitiveSeverity.critical)
            }
            .pickerStyle(.radioGroup)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section("Actions") {
            ForEach(DLPAction.allCases, id: \.self) { action in
                Toggle(self.actionDisplayName(action), isOn: Binding(
                    get: { self.selectedActions.contains(action) },
                    set: { isOn in
                        if isOn {
                            self.selectedActions.insert(action)
                        } else {
                            self.selectedActions.remove(action)
                        }
                    }
                ))
            }
        }
    }

    // MARK: - Save

    private func saveRule() {
        let trimmedPattern = self.pattern.trimmingCharacters(in: .whitespaces)
        do {
            _ = try NSRegularExpression(pattern: trimmedPattern)
        } catch {
            self.regexError = "Invalid regex: \(error.localizedDescription)"
            return
        }
        self.regexError = nil

        let now = Date()
        let orderedActions = DLPAction.allCases.filter { self.selectedActions.contains($0) }

        let saved = if let existing = rule {
            DLPRule(
                id: existing.id,
                name: self.name.trimmingCharacters(in: .whitespaces),
                isEnabled: self.isEnabled,
                patternCategory: self.patternCategory,
                pattern: self.pattern.trimmingCharacters(in: .whitespaces),
                severity: self.severity,
                actions: orderedActions,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            DLPRule(
                name: self.name.trimmingCharacters(in: .whitespaces),
                isEnabled: self.isEnabled,
                patternCategory: self.patternCategory,
                pattern: self.pattern.trimmingCharacters(in: .whitespaces),
                severity: self.severity,
                actions: orderedActions,
                createdAt: now,
                updatedAt: now
            )
        }

        self.onSave(saved)
        self.isPresented = false
    }

    // MARK: - Helpers

    private func actionDisplayName(_ action: DLPAction) -> String {
        switch action {
        case .block:
            "Block — prevent clipboard item from being stored"
        case .alert:
            "Alert — notify the user and log to audit trail"
        case .redact:
            "Redact — replace matched content with [REDACTED]"
        case .logOnly:
            "Log Only — record in audit log without alerting"
        }
    }
}

// MARK: - Previews

#if DEBUG
    struct DLPRuleEditorView_Previews: PreviewProvider {
        @State static var isPresented = true

        static var previews: some View {
            DLPRuleEditorView(isPresented: $isPresented, rule: nil) { _ in }
        }
    }
#endif
