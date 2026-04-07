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
                Text(rule == nil ? "New DLP Rule" : "Edit DLP Rule")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Form content
            Form {
                ruleDetailsSection
                severitySection
                actionsSection
            }
            .formStyle(.grouped)

            Divider()

            // Bottom buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || pattern
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
                TextField("e.g. Credit Card Numbers", text: $name)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Picker("Category", selection: $patternCategory) {
                ForEach(DLPPatternCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }

            LabeledContent("Pattern") {
                TextField("Regular expression pattern", text: $pattern)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: pattern) { _, _ in regexError = nil }
            }

            if let regexError {
                Text(regexError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Enabled", isOn: $isEnabled)
        }
    }

    // MARK: - Severity Section

    private var severitySection: some View {
        Section("Severity") {
            Picker("Severity", selection: $severity) {
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
                Toggle(actionDisplayName(action), isOn: Binding(
                    get: { selectedActions.contains(action) },
                    set: { isOn in
                        if isOn {
                            selectedActions.insert(action)
                        } else {
                            selectedActions.remove(action)
                        }
                    }
                ))
            }
        }
    }

    // MARK: - Save

    private func saveRule() {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespaces)
        do {
            _ = try NSRegularExpression(pattern: trimmedPattern)
        } catch {
            regexError = "Invalid regex: \(error.localizedDescription)"
            return
        }
        regexError = nil

        let now = Date()
        let orderedActions = DLPAction.allCases.filter { selectedActions.contains($0) }

        let saved = if let existing = rule {
            DLPRule(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                isEnabled: isEnabled,
                patternCategory: patternCategory,
                pattern: pattern.trimmingCharacters(in: .whitespaces),
                severity: severity,
                actions: orderedActions,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            DLPRule(
                name: name.trimmingCharacters(in: .whitespaces),
                isEnabled: isEnabled,
                patternCategory: patternCategory,
                pattern: pattern.trimmingCharacters(in: .whitespaces),
                severity: severity,
                actions: orderedActions,
                createdAt: now,
                updatedAt: now
            )
        }

        onSave(saved)
        isPresented = false
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
