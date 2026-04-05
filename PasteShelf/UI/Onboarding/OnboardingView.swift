//
//  OnboardingView.swift
//  PasteShelf
//
//  Main container view for the onboarding flow with page navigation.
//

import SwiftUI

/// Main onboarding container view
struct OnboardingView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator — simple dots
            HStack(spacing: 8) {
                let steps = OnboardingStep.activeSteps
                let currentIndex = steps.firstIndex(of: viewModel.currentStep) ?? 0
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
                "Setup progress: step \(Self.currentStepNumber(for: viewModel.currentStep)) of \(OnboardingStep.activeSteps.count)"
            )

            // Step content
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView()
                case .permissions:
                    #if APP_STORE
                    EmptyView()
                    #else
                    PermissionStepView(viewModel: viewModel)
                    #endif
                case .notifications:
                    NotificationPermissionStepView(viewModel: viewModel)
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.currentStep)

            // Navigation buttons
            HStack {
                if viewModel.currentStep.previous != nil {
                    Button("Back") {
                        if reduceMotion {
                            viewModel.previousStep()
                        } else {
                            withAnimation { viewModel.previousStep() }
                        }
                    }
                    .accessibilityHint("Goes to the previous setup step")
                }

                Spacer()

                // Skip button (if allowed)
                if viewModel.currentStep.isSkippable {
                    Button("Skip") {
                        if reduceMotion {
                            viewModel.skipStep()
                        } else {
                            withAnimation { viewModel.skipStep() }
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                // Next/Finish button
                if viewModel.currentStep.next != nil {
                    Button("Continue") {
                        if reduceMotion {
                            viewModel.nextStep()
                        } else {
                            withAnimation { viewModel.nextStep() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                    .accessibilityHint("Proceeds to the next setup step")
                } else {
                    Button("Get Started") {
                        viewModel.completeOnboarding()
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

    private static func currentStepNumber(for step: OnboardingStep) -> Int {
        (OnboardingStep.activeSteps.firstIndex(of: step) ?? 0) + 1
    }

    private var canProceed: Bool {
        switch viewModel.currentStep {
        case .permissions:
            #if APP_STORE
            return true
            #else
            return viewModel.hasAccessibilityPermission
            #endif
        case .notifications:
            return true
        default:
            return true
        }
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
