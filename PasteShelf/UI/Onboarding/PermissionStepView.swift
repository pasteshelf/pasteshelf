//
//  PermissionStepView.swift
//  PasteShelf
//
//  Accessibility permission request step in the onboarding flow.
//

import SwiftUI

// MARK: - PermissionStepView

/// Permission request step view
struct PermissionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            if viewModel.hasAccessibilityPermission {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.green)
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
            }

            // Title
            Text("Accessibility Permission")
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(
                "PasteShelf needs accessibility permission to paste items into other apps. Your data stays private and is never shared."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)

            // Permission status and action
            if viewModel.hasAccessibilityPermission {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .font(.callout)
            } else {
                Button("Open Accessibility Settings") {
                    viewModel.requestAccessibilityPermission()
                }
                .buttonStyle(.bordered)

                Text(
                    "Click \"Open Accessibility Settings\", then enable PasteShelf in the list."
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasAccessibilityPermission)
        .onAppear {
            viewModel.startPermissionChecking()
        }
        .onDisappear {
            viewModel.stopPermissionChecking()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct PermissionStepView_Previews: PreviewProvider {
        static var previews: some View {
            PermissionStepView(viewModel: OnboardingViewModel())
                .frame(width: 520, height: 380)
        }
    }
#endif
