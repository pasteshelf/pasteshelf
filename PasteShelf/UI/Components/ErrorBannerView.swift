//
//  ErrorBannerView.swift
//  PasteShelf
//
//  A dismissible error banner component for displaying error messages.
//

import SwiftUI

/// Displays an error message with optional dismiss action
struct ErrorBannerView: View {
    let message: String
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?

    init(
        message: String,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Preview

#if DEBUG
    struct ErrorBannerView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                ErrorBannerView(
                    message: "Unable to load clipboard items",
                    onDismiss: {},
                    onRetry: {}
                )

                ErrorBannerView(
                    message: "Network error occurred",
                    onDismiss: {}
                )

                ErrorBannerView(
                    message: "Something went wrong"
                )
            }
            .padding()
            .frame(width: 400)
        }
    }
#endif
