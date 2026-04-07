//
//  SkeletonLoadingView.swift
//  PasteShelf
//
//  Skeleton loading placeholder views for improved perceived performance.
//

import SwiftUI

// MARK: - SkeletonItemRow

/// A skeleton placeholder row for loading states
struct SkeletonItemRow: View {
    // MARK: Internal

    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(self.shimmerGradient)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(self.shimmerGradient)
                    .frame(height: 12)
                    .frame(maxWidth: 200)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(self.shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: 120)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            guard !self.reduceMotion else {
                return
            }
            withAnimation(
                .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                self.isAnimating = true
            }
        }
        .accessibilityLabel("Loading clipboard items")
    }

    // MARK: Private

    @State private var isAnimating = false
    @Environment(\.reduceMotion)
    private var reduceMotion

    private var shimmerGradient: LinearGradient {
        let baseOpacity = self.reduceMotion ? 0.2 : (self.isAnimating ? 0.3 : 0.15)
        let endOpacity = self.reduceMotion ? 0.2 : (self.isAnimating ? 0.15 : 0.3)

        return LinearGradient(
            gradient: Gradient(colors: [
                Color.gray.opacity(baseOpacity),
                Color.gray.opacity(endOpacity),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - SkeletonLoadingView

/// A view showing multiple skeleton rows
struct SkeletonLoadingView: View {
    // MARK: Lifecycle

    init(rowCount: Int = 5) {
        self.rowCount = rowCount
    }

    // MARK: Internal

    let rowCount: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< self.rowCount, id: \.self) { _ in
                SkeletonItemRow()
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct SkeletonLoadingView_Previews: PreviewProvider {
        static var previews: some View {
            SkeletonLoadingView()
                .frame(width: 400)
                .background(Color(.windowBackgroundColor))
        }
    }
#endif
