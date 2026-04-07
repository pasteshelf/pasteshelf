//
//  RuleConditionRow.swift
//  PasteShelf
//
//  A single rule condition row with field, operator, and value pickers.
//

import SwiftUI

// MARK: - RuleConditionRow

/// Displays and edits a single rule condition
struct RuleConditionRow: View {
    // MARK: Internal

    /// The condition being edited
    @Binding var condition: RuleCondition

    /// Called when delete is requested
    var onDelete: (() -> Void)?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Field picker
            Picker("Field", selection: $condition.field) {
                ForEach(RuleField.allCases, id: \.self) { field in
                    Label(field.displayName, systemImage: field.icon)
                        .tag(field)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            .onChange(of: condition.field) { _, newField in
                // Reset operator when field changes
                if !newField.availableOperators.contains(condition.comparisonOperator) {
                    condition.comparisonOperator = newField.defaultOperator
                }
                // Reset value when field changes
                condition.value = defaultValue(for: newField)
            }

            // Operator picker
            Picker("Operator", selection: $condition.comparisonOperator) {
                ForEach(condition.field.availableOperators, id: \.self) { op in
                    Text(op.displayName)
                        .tag(op)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            // Value input
            valueInput

            // Delete button
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(isHovered ? 1.0 : 0.7))
                }
                .buttonStyle(.plain)
                .help("Remove condition")
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Value Input

    @ViewBuilder private var valueInput: some View {
        switch condition.field {
        case .contentType:
            contentTypePicker

        case .sourceApp:
            TextField("App name or bundle ID", text: $condition.value)
                .textFieldStyle(.roundedBorder)

        case .textContent:
            TextField("Text to match", text: $condition.value)
                .textFieldStyle(.roundedBorder)

        case .dateCreated:
            dateRangePicker

        case .isFavorite,
             .isSensitive:
            booleanPicker
        }
    }

    // MARK: - Content Type Picker

    private var contentTypePicker: some View {
        Picker("Value", selection: $condition.value) {
            ForEach(ContentTypeValue.allCases, id: \.rawValue) { contentType in
                Text(contentType.displayName)
                    .tag(contentType.rawValue)
            }
        }
        .labelsHidden()
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        Group {
            if condition.comparisonOperator == .withinLast {
                Picker("Value", selection: $condition.value) {
                    ForEach(DateRangeValue.allCases, id: \.rawValue) { range in
                        Text(range.displayName)
                            .tag(range.rawValue)
                    }
                }
                .labelsHidden()
            } else {
                // For before/after, use date picker
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { parseDate(condition.value) ?? Date() },
                        set: { condition.value = formatDate($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
    }

    // MARK: - Boolean Picker

    private var booleanPicker: some View {
        Picker("Value", selection: $condition.value) {
            Text("Yes").tag("true")
            Text("No").tag("false")
        }
        .labelsHidden()
        .frame(width: 80)
    }

    // MARK: - Helpers

    private func defaultValue(for field: RuleField) -> String {
        switch field {
        case .contentType:
            ContentTypeValue.text.rawValue
        case .sourceApp,
             .textContent:
            ""
        case .dateCreated:
            DateRangeValue.last7Days.rawValue
        case .isFavorite,
             .isSensitive:
            "true"
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
    struct RuleConditionRow_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            // MARK: Internal

            var body: some View {
                VStack(spacing: 12) {
                    RuleConditionRow(
                        condition: $condition
                    ) {}

                    Divider()

                    // Preview different fields
                    Text("Field: \(condition.field.displayName)")
                    Text("Operator: \(condition.comparisonOperator.displayName)")
                    Text("Value: \(condition.value)")
                }
                .padding()
            }

            // MARK: Private

            @State private var condition = RuleCondition(
                field: .contentType,
                comparisonOperator: .equals,
                value: "images"
            )
        }

        static var previews: some View {
            PreviewWrapper()
                .frame(width: 500)
        }
    }
#endif
