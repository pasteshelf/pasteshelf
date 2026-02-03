//
//  SkeletonLoadingView.swift
//  PasteShelf
//
//  Skeleton loading placeholder views for improved perceived performance.
//

import SwiftUI

/// A skeleton placeholder row for loading states
struct SkeletonItemRow: View {
    @State private var isAnimating = false
    @Environment(\.reduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(shimmerGradient)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 12)
                    .frame(maxWidth: 200)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: 120)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
        .accessibilityLabel("Loading clipboard items")
    }

    private var shimmerGradient: LinearGradient {
        let baseOpacity = reduceMotion ? 0.2 : (isAnimating ? 0.3 : 0.15)
        let endOpacity = reduceMotion ? 0.2 : (isAnimating ? 0.15 : 0.3)

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

/// A view showing multiple skeleton rows
struct SkeletonLoadingView: View {
    let rowCount: Int

    init(rowCount: Int = 5) {
        self.rowCount = rowCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< rowCount, id: \.self) { _ in
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
