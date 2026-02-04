//
//  RuleBuilderView.swift
//  PasteShelf
//
//  View for building collection rules with multiple conditions.
//

import SwiftUI

/// View for building and editing collection rules
struct RuleBuilderView: View {
    // MARK: - Properties

    /// The rules being edited
    @Binding var rules: CollectionRules

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with logical operator
            headerView

            // Conditions list
            conditionsList

            // Add condition button
            addConditionButton
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Items matching")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Picker("", selection: $rules.logicalOperator) {
                Text("all").tag(LogicalOperator.and)
                Text("any").tag(LogicalOperator.or)
            }
            .labelsHidden()
            .fixedSize()

            Text("of the following:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Conditions List

    @ViewBuilder
    private var conditionsList: some View {
        if rules.conditions.isEmpty {
            emptyState
        } else {
            VStack(spacing: 4) {
                ForEach($rules.conditions) { $condition in
                    RuleConditionRow(
                        condition: $condition,
                        onDelete: {
                            removeCondition(condition)
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("No conditions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Add a condition to filter items")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    // MARK: - Add Condition Button

    private var addConditionButton: some View {
        Button {
            addCondition()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                Text("Add Condition")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addCondition() {
        let newCondition = RuleCondition(
            field: .contentType,
            comparisonOperator: .equals,
            value: ContentTypeValue.text.rawValue
        )
        rules.conditions.append(newCondition)
    }

    private func removeCondition(_ condition: RuleCondition) {
        rules.conditions.removeAll { $0.id == condition.id }
    }
}

// MARK: - Preview

#if DEBUG
    struct RuleBuilderView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            @State private var rules = CollectionRules(
                conditions: [
                    RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                    RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "7d"),
                ],
                logicalOperator: .and
            )

            var body: some View {
                RuleBuilderView(rules: $rules)
                    .padding()
            }
        }

        static var previews: some View {
            PreviewWrapper()
                .frame(width: 500)
        }
    }
#endif
