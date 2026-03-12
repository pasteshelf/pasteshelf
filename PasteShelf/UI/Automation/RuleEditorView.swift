//
//  RuleEditorView.swift
//  PasteShelf
//
//  Modal view for creating and editing automation rules.
//  Includes trigger picker, condition builder, and action list.
//

import SwiftUI

/// View for editing an automation rule
struct RuleEditorView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: AutomationViewModel
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var trigger: AutomationTrigger = .onCapture
    @State private var isEnabled: Bool = true
    @State private var actions: [AutomationAction] = []
    @State private var showingAddAction = false
    @State private var scheduleExpression = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic info section
                    basicInfoSection

                    Divider()

                    // Trigger section
                    triggerSection

                    Divider()

                    // Actions section
                    actionsSection
                }
                .padding()
            }

            Divider()

            // Footer
            footerView
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadRule()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(viewModel.isCreating ? "Create Rule" : "Edit Rule")
                .font(.headline)

            Spacer()

            Button {
                isPresented = false
                viewModel.cancelEditing()
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

                TextField("Rule name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Enabled")
                    .frame(width: 80, alignment: .leading)

                Toggle("", isOn: $isEnabled)
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

                Picker("", selection: $trigger) {
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
                selectedTrigger: $trigger,
                scheduleExpression: $scheduleExpression
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
                    showingAddAction = true
                } label: {
                    Label("Add Action", systemImage: "plus")
                        .font(.caption)
                }
            }

            if actions.isEmpty {
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
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        ActionRowView(
                            action: action,
                            onEdit: {
                                // Edit action (could open another sheet)
                            },
                            onDelete: {
                                actions.remove(at: index)
                            }
                        )
                    }
                    .onMove { source, destination in
                        actions.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAction) {
            ActionPickerView(onSelect: { action in
                actions.append(action)
                showingAddAction = false
            })
        }
    }

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
                viewModel.cancelEditing()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button(viewModel.isCreating ? "Create" : "Save") {
                saveRule()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Methods

    private func loadRule() {
        guard let rule = viewModel.selectedRule else { return }
        name = rule.name
        trigger = rule.trigger
        isEnabled = rule.isEnabled
        actions = rule.actions

        // Extract schedule expression if applicable
        if case let .schedule(expression) = rule.trigger {
            scheduleExpression = expression.expression
        }
    }

    private func saveRule() {
        let finalTrigger: AutomationTrigger
        if case .schedule = trigger {
            finalTrigger = .schedule(CronExpression(expression: scheduleExpression))
        } else {
            finalTrigger = trigger
        }

        let rule = AutomationRule(
            id: viewModel.selectedRule?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            trigger: finalTrigger,
            conditions: viewModel.selectedRule?.conditions ?? CollectionRules(),
            actions: actions,
            priority: viewModel.selectedRule?.priority ?? 100,
            createdAt: viewModel.selectedRule?.createdAt ?? Date(),
            modifiedAt: Date(),
            lastExecutedAt: viewModel.selectedRule?.lastExecutedAt,
            executionCount: viewModel.selectedRule?.executionCount ?? 0
        )

        viewModel.selectedRule = rule

        Task {
            await viewModel.saveCurrentRule()
            isPresented = false
        }
    }
}

// MARK: - Trigger Picker View

struct TriggerPickerView: View {
    @Binding var selectedTrigger: AutomationTrigger
    @Binding var scheduleExpression: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trigger description
            Text(selectedTrigger.description)
                .font(.caption)
                .foregroundColor(.secondary)

            // Schedule options (if schedule trigger)
            if case .schedule = selectedTrigger {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule")
                        .font(.caption)
                        .fontWeight(.medium)

                    HStack {
                        Picker("Preset", selection: Binding(
                            get: { schedulePreset(for: scheduleExpression) },
                            set: { scheduleExpression = $0.expression }
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

    private func schedulePreset(for expression: String) -> CronExpression {
        switch expression {
        case CronExpression.hourly.expression: return .hourly
        case CronExpression.weekly.expression: return .weekly
        case CronExpression.monthly.expression: return .monthly
        default: return .daily
        }
    }
}

// MARK: - Action Row View

struct ActionRowView: View {
    let action: AutomationAction
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: action.actionType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.actionType.displayName)
                    .font(.body)

                Text(actionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onDelete()
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

    private var actionDescription: String {
        switch action {
        case .transform(_, let preset):
            return "Transform: \(preset.displayName)"
        case .addTag(_, let tagName):
            return "Add tag: \(tagName)"
        case .notify(_, let title, _):
            return "Notify: \(title)"
        case .webhook(_, let endpointId):
            return "Webhook: \(endpointId.uuidString.prefix(8))..."
        default:
            return action.description
        }
    }
}

// MARK: - Action Picker View

struct ActionPickerView: View {
    let onSelect: (AutomationAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Action")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
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
                            onSelect(createDefaultAction(for: actionType))
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }

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

struct ActionTypeButton: View {
    let actionType: ActionType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: actionType.iconName)
                    .frame(width: 24)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionType.displayName)
                        .font(.body)

                    Text(actionType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
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

// MARK: - Preview

#if DEBUG
    struct RuleEditorView_Previews: PreviewProvider {
        static var previews: some View {
            RuleEditorView(
                viewModel: AutomationViewModel(),
                isPresented: .constant(true)
            )
        }
    }
#endif
