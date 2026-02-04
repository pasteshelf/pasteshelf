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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicatorView
                .padding(.top, 24)

            // Step content
            stepContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            navigationButtonsView
                .padding(.bottom, 24)
        }
        .frame(width: 560, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Progress Indicator

    private var progressIndicatorView: some View {
        HStack(spacing: 16) {
            ForEach(OnboardingStep.allCases) { step in
                progressStepView(step)
            }
        }
        .padding(.horizontal, 40)
    }

    private func progressStepView(_ step: OnboardingStep) -> some View {
        let isCompleted = step.rawValue < viewModel.currentStep.rawValue
        let isCurrent = step == viewModel.currentStep

        return HStack(spacing: 8) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(
                        isCompleted
                            ? Color.accentColor
                            : (isCurrent ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
                    )
                    .frame(width: 28, height: 28)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isCurrent ? .accentColor : .secondary)
                }
            }

            // Step label (only show on larger widths)
            if step.rawValue < OnboardingStep.allCases.count - 1 {
                Rectangle()
                    .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(step.title), step \(step.rawValue + 1) of \(OnboardingStep.allCases.count), \(isCompleted ? "completed" : (isCurrent ? "current" : "upcoming"))"
        )
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContentView: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView()
            case .permissions:
                PermissionStepView(viewModel: viewModel)
            case .tutorial:
                TutorialStepView()
            case .hotkeySetup:
                HotkeySetupStepView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    // MARK: - Navigation Buttons

    private var navigationButtonsView: some View {
        HStack {
            // Back button
            if viewModel.currentStep.previous != nil {
                Button {
                    viewModel.previousStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.leftArrow, modifiers: [])
            }

            Spacer()

            // Skip button (if allowed)
            if viewModel.currentStep.isSkippable {
                Button("Skip") {
                    viewModel.skipStep()
                }
                .buttonStyle(.bordered)
            }

            // Next/Finish button
            Button {
                if viewModel.currentStep.next != nil {
                    viewModel.nextStep()
                } else {
                    viewModel.completeOnboarding()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(nextButtonTitle)
                    if viewModel.currentStep.next != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!canProceed)
        }
        .padding(.horizontal, 40)
    }

    private var nextButtonTitle: String {
        if viewModel.currentStep.next == nil {
            return "Get Started"
        }
        return "Continue"
    }

    private var canProceed: Bool {
        switch viewModel.currentStep {
        case .permissions:
            return viewModel.hasAccessibilityPermission
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
