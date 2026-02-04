//
//  PermissionStepView.swift
//  PasteShelf
//
//  Accessibility permission request step in the onboarding flow.
//

import SwiftUI

/// Permission request step view
struct PermissionStepView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: OnboardingViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            permissionIconView

            // Title and description
            textContentView

            Spacer()

            // Permission status
            permissionStatusView

            // Action button
            actionButtonView

            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            viewModel.startPermissionChecking()
        }
        .onDisappear {
            viewModel.stopPermissionChecking()
        }
    }

    // MARK: - Icon

    private var permissionIconView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    viewModel.hasAccessibilityPermission
                        ? Color.green.opacity(0.15)
                        : Color.orange.opacity(0.15)
                )
                .frame(width: 120, height: 120)

            // Icon
            Image(
                systemName: viewModel.hasAccessibilityPermission
                    ? "checkmark.shield.fill"
                    : "hand.raised.fill"
            )
            .font(.system(size: 48, weight: .light))
            .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .orange)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasAccessibilityPermission)
        .accessibilityHidden(true)
    }

    // MARK: - Text Content

    private var textContentView: some View {
        VStack(spacing: 16) {
            Text("Accessibility Permission")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(
                "PasteShelf needs accessibility permission to paste items into other apps. Your data stays private and is never shared."
            )
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(4)
        }
    }

    // MARK: - Permission Status

    private var permissionStatusView: some View {
        HStack(spacing: 12) {
            Image(
                systemName: viewModel.hasAccessibilityPermission
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle.fill"
            )
            .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .orange)
            .font(.system(size: 18))

            Text(
                viewModel.hasAccessibilityPermission
                    ? "Permission granted"
                    : "Permission required"
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(viewModel.hasAccessibilityPermission ? .green : .orange)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    viewModel.hasAccessibilityPermission
                        ? Color.green.opacity(0.1)
                        : Color.orange.opacity(0.1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasAccessibilityPermission)
    }

    // MARK: - Action Button

    private var actionButtonView: some View {
        VStack(spacing: 12) {
            if !viewModel.hasAccessibilityPermission {
                Button {
                    viewModel.requestAccessibilityPermission()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Click \"Open System Settings\", then enable PasteShelf in the list")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You're all set!")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct PermissionStepView_Previews: PreviewProvider {
        static var previews: some View {
            PermissionStepView(viewModel: OnboardingViewModel())
                .frame(width: 500, height: 500)
        }
    }
#endif
