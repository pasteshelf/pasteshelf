//
//  RuleEditorView.swift
//  PasteShelf
//
//  Modal view for creating and editing automation rules.
//  Includes trigger picker, condition builder, and action list.
//

import SwiftUI

// MARK: - RuleEditorView

/// View for editing an automation rule
struct RuleEditorView: View {
    // MARK: Internal

    @ObservedObject var viewModel: AutomationViewModel
    @Binding var isPresented: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.headerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic info section
                    self.basicInfoSection

                    Divider()

                    // Trigger section
                    self.triggerSection

                    Divider()

                    // Actions section
                    self.actionsSection
                }
                .padding()
            }

            Divider()

            // Footer
            self.footerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            self.loadRule()
        }
    }

    // MARK: Private

    @State private var name: String = ""
    @State private var trigger: AutomationTrigger = .onCapture
    @State private var isEnabled: Bool = true
    @State private var actions: [AutomationAction] = []
    @State private var showingAddAction = false
    @State private var scheduleExpression = ""

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(self.viewModel.isCreating ? "Create Rule" : "Edit Rule")
                .font(.headline)

            Spacer()

            Button {
                self.isPresented = false
                self.viewModel.cancelEditing()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Info")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                Text("Name")
                    .frame(width: 80, alignment: .leading)

                TextField("Rule name", text: self.$name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Enabled")
                    .frame(width: 80, alignment: .leading)

                Toggle("", isOn: self.$isEnabled)
                    .labelsHidden()

                Spacer()
            }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trigger")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: self.$trigger) {
                    Text("Captured").tag(AutomationTrigger.onCapture)
                    Text("Pasted").tag(AutomationTrigger.onPaste)
                    Text("Manual").tag(AutomationTrigger.manual)
                    Text("Schedule").tag(AutomationTrigger.schedule(CronExpression.daily))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
            }

            TriggerPickerView(
                selectedTrigger: self.$trigger,
                scheduleExpression: self.$scheduleExpression
            )
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    self.showingAddAction = true
                } label: {
                    Label("Add Action", systemImage: "plus")
                        .font(.caption)
                }
            }

            if self.actions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.slash")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No actions configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(self.actions.enumerated()), id: \.element.id) { index, action in
                        ActionRowView(
                            action: action,
                            onEdit: {
                                // Edit action (could open another sheet)
                            },
                            onDelete: {
                                self.actions.remove(at: index)
                            }
                        )
                    }
                    .onMove { source, destination in
                        self.actions.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
        }
        .sheet(isPresented: self.$showingAddAction) {
            ActionPickerView { action in
                self.actions.append(action)
                self.showingAddAction = false
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                self.isPresented = false
                self.viewModel.cancelEditing()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(self.viewModel.isCreating ? "Create" : "Save") {
                self.saveRule()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Methods

    private func loadRule() {
        guard let rule = viewModel.selectedRule else {
            return
        }
        self.name = rule.name
        self.trigger = rule.trigger
        self.isEnabled = rule.isEnabled
        self.actions = rule.actions

        // Extract schedule expression if applicable
        if case let .schedule(expression) = rule.trigger {
            self.scheduleExpression = expression.expression
        }
    }

    private func saveRule() {
        let finalTrigger: AutomationTrigger = if case .schedule = self.trigger {
            .schedule(CronExpression(expression: self.scheduleExpression))
        } else {
            self.trigger
        }

        let rule = AutomationRule(
            id: viewModel.selectedRule?.id ?? UUID(),
            name: self.name.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: self.isEnabled,
            trigger: finalTrigger,
            conditions: self.viewModel.selectedRule?.conditions ?? CollectionRules(),
            actions: self.actions,
            priority: self.viewModel.selectedRule?.priority ?? 100,
            createdAt: self.viewModel.selectedRule?.createdAt ?? Date(),
            modifiedAt: Date(),
            lastExecutedAt: self.viewModel.selectedRule?.lastExecutedAt,
            executionCount: self.viewModel.selectedRule?.executionCount ?? 0
        )

        self.viewModel.selectedRule = rule

        Task {
            await self.viewModel.saveCurrentRule()
            self.isPresented = false
        }
    }
}

// MARK: - TriggerPickerView

struct TriggerPickerView: View {
    // MARK: Internal

    @Binding var selectedTrigger: AutomationTrigger
    @Binding var scheduleExpression: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trigger description
            Text(self.selectedTrigger.description)
                .font(.caption)
                .foregroundColor(.secondary)

            // Schedule options (if schedule trigger)
            if case .schedule = self.selectedTrigger {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule")
                        .font(.caption)
                        .fontWeight(.medium)

                    HStack {
                        Picker("Preset", selection: Binding(
                            get: { self.schedulePreset(for: self.scheduleExpression) },
                            set: { self.scheduleExpression = $0.expression }
                        )) {
                            Text("Hourly").tag(CronExpression.hourly)
                            Text("Daily").tag(CronExpression.daily)
                            Text("Weekly").tag(CronExpression.weekly)
                            Text("Monthly").tag(CronExpression.monthly)
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: Private

    private func schedulePreset(for expression: String) -> CronExpression {
        switch expression {
        case CronExpression.hourly.expression: .hourly
        case CronExpression.weekly.expression: .weekly
        case CronExpression.monthly.expression: .monthly
        default: .daily
        }
    }
}

// MARK: - ActionRowView

struct ActionRowView: View {
    // MARK: Internal

    let action: AutomationAction
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: self.action.actionType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.action.actionType.displayName)
                    .font(.body)

                Text(self.actionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                self.onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    // MARK: Private

    private var actionDescription: String {
        switch self.action {
        case let .transform(_, preset):
            "Transform: \(preset.displayName)"
        case let .addTag(_, tagName):
            "Add tag: \(tagName)"
        case let .notify(_, title, _):
            "Notify: \(title)"
        case let .webhook(_, endpointId):
            "Webhook: \(endpointId.uuidString.prefix(8))..."
        default:
            self.action.description
        }
    }
}

// MARK: - ActionPickerView

struct ActionPickerView: View {
    // MARK: Internal

    let onSelect: (AutomationAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Action")
                    .font(.headline)
                Spacer()
                Button {
                    self.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Action list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ActionType.allCases, id: \.self) { actionType in
                        ActionTypeButton(actionType: actionType) {
                            self.onSelect(self.createDefaultAction(for: actionType))
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss

    private func createDefaultAction(for type: ActionType) -> AutomationAction {
        switch type {
        case .transform:
            return .transform(preset: .uppercase)
        case .addTag:
            return .addTag(tagName: "processed")
        case .removeTag:
            return .removeTag(tagName: "")
        case .setFavorite:
            return .setFavorite(isFavorite: true)
        case .moveToFolder:
            return .moveToFolder(folderName: "")
        case .copyToClipboard:
            return .copyToClipboard()
        case .notify:
            return .notify(title: "PasteShelf", message: "Rule executed")
        case .openURL:
            return .openURL(urlTemplate: "")
        #if !APP_STORE
            case .runScript:
                return .runScript(scriptPath: "")
        #endif
        case .webhook:
            return .webhook(endpointId: UUID())
        case .markSensitive:
            return .markSensitive(isSensitive: true)
        case .delete:
            return .delete()
        }
    }
}

// MARK: - ActionTypeButton

struct ActionTypeButton: View {
    let actionType: ActionType
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                Image(systemName: self.actionType.iconName)
                    .frame(width: 24)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.actionType.displayName).font(.body)
                    Text(self.actionType.description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
