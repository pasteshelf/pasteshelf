//
//  NotificationPermissionStepView.swift
//  PasteShelf
//
//  Notification permission request step in the onboarding flow.
//

import SwiftUI

/// Notification permission request step view
struct NotificationPermissionStepView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: OnboardingViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            if viewModel.hasNotificationPermission {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.green)
            } else {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
            }

            // Title
            Text("Notifications")
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(
                "PasteShelf can notify you when sensitive content is copied or when automation rules trigger. Allow notifications to stay informed."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)

            // Permission status and action
            if viewModel.hasNotificationPermission {
                Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .font(.callout)
            } else {
                Button("Enable Notifications") {
                    viewModel.requestNotificationPermission()
                }
                .buttonStyle(.bordered)

                Text(
                    "If System Settings opens, enable \"Allow Notifications\" for PasteShelf."
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasNotificationPermission)
        .onAppear {
            viewModel.startNotificationChecking()
        }
        .onDisappear {
            viewModel.stopNotificationChecking()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct NotificationPermissionStepView_Previews: PreviewProvider {
        static var previews: some View {
            NotificationPermissionStepView(viewModel: OnboardingViewModel())
                .frame(width: 520, height: 380)
        }
    }
#endif
