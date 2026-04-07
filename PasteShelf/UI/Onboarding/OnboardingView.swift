//
//  OnboardingView.swift
//  PasteShelf
//
//  Main container view for the onboarding flow with page navigation.
//

import SwiftUI

// MARK: - OnboardingView

/// Main onboarding container view
struct OnboardingView: View {
    // MARK: Internal

    @ObservedObject var viewModel: OnboardingViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator — simple dots
            HStack(spacing: 8) {
                let steps = OnboardingStep.activeSteps
                let currentIndex = steps.firstIndex(of: self.viewModel.currentStep) ?? 0
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                    Circle()
                        .fill(
                            index <= currentIndex
                                ? Color.accentColor
                                : Color.gray.opacity(0.3)
                        )
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Setup progress: step "
                    + "\(Self.currentStepNumber(for: self.viewModel.currentStep)) "
                    + "of \(OnboardingStep.activeSteps.count)"
            )

            // Step content
            Group {
                switch self.viewModel.currentStep {
                case .welcome:
                    WelcomeStepView()
                case .permissions:
                    #if APP_STORE
                        EmptyView()
                    #else
                        PermissionStepView(viewModel: self.viewModel)
                    #endif
                case .notifications:
                    NotificationPermissionStepView(viewModel: self.viewModel)
                case .tutorial:
                    TutorialStepView()
                case .hotkeySetup:
                    HotkeySetupStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(self.reduceMotion ? nil : .easeInOut(duration: 0.3), value: self.viewModel.currentStep)

            // Navigation buttons
            HStack {
                if self.viewModel.currentStep.previous != nil {
                    Button("Back") {
                        if self.reduceMotion {
                            self.viewModel.previousStep()
                        } else {
                            withAnimation { self.viewModel.previousStep() }
                        }
                    }
                    .accessibilityHint("Goes to the previous setup step")
                }

                Spacer()

                // Skip button (if allowed)
                if self.viewModel.currentStep.isSkippable {
                    Button("Skip") {
                        if self.reduceMotion {
                            self.viewModel.skipStep()
                        } else {
                            withAnimation { self.viewModel.skipStep() }
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                // Next/Finish button
                if self.viewModel.currentStep.next != nil {
                    Button("Continue") {
                        if self.reduceMotion {
                            self.viewModel.nextStep()
                        } else {
                            withAnimation { self.viewModel.nextStep() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!self.canProceed)
                    .accessibilityHint("Proceeds to the next setup step")
                } else {
                    Button("Get Started") {
                        self.viewModel.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Completes setup and opens PasteShelf")
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var canProceed: Bool {
        switch self.viewModel.currentStep {
        case .permissions:
            #if APP_STORE
                return true
            #else
                return self.viewModel.hasAccessibilityPermission
            #endif
        case .notifications:
            return true
        default:
            return true
        }
    }

    private static func currentStepNumber(for step: OnboardingStep) -> Int {
        (OnboardingStep.activeSteps.firstIndex(of: step) ?? 0) + 1
    }
}

// MARK: - Preview

#if DEBUG
    struct OnboardingView_Previews: PreviewProvider {
        static var previews: some View {
            OnboardingView(viewModel: OnboardingViewModel())
        }
    }
#endif
