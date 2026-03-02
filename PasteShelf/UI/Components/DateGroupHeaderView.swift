//
//  DateGroupHeaderView.swift
//  PasteShelf
//
//  Section header view for date-grouped clipboard items.
//  Displays the group name with optional item count.
//

import SwiftUI

/// Section header for date-grouped items
struct DateGroupHeaderView: View {
    // MARK: - Properties

    /// The date group for this section
    let group: DateGroup

    /// Number of items in this group
    var itemCount: Int?

    /// Whether this header should be sticky
    var isSticky: Bool = true

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: group.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            // Group name
            Text(group.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            // Item count
            if let count = itemCount {
                Text("(\(count))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSticky ?
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                .opacity(0.95) :
                nil
        )
    }
}

// MARK: - Preview

#if DEBUG
    struct DateGroupHeaderView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Standard Headers")
                    .font(.caption).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(DateGroup.allCases) { group in
                        DateGroupHeaderView(group: group, itemCount: 5)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .padding()
            .frame(width: 300)
        }
    }
#endif
