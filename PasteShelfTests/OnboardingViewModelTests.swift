//
//  OnboardingViewModelTests.swift
//  PasteShelfTests
//
//  Unit tests for OnboardingViewModel.
//

#if !APP_STORE
import ApplicationServices
#endif
import Foundation
import Testing
@testable import PasteShelf

struct OnboardingViewModelTests {
    // MARK: - OnboardingStep Tests

    @Test("OnboardingStep has correct raw values")
    func onboardingStepHasCorrectOrder() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.permissions.rawValue == 1)
        #expect(OnboardingStep.notifications.rawValue == 2)
        #expect(OnboardingStep.tutorial.rawValue == 3)
        #expect(OnboardingStep.hotkeySetup.rawValue == 4)
    }

    @Test("OnboardingStep.next returns correct step for active steps")
    func onboardingStepNextReturnsCorrectStep() {
        let steps = OnboardingStep.activeSteps
        for (index, step) in steps.enumerated() {
            if index + 1 < steps.count {
                #expect(step.next == steps[index + 1])
            } else {
                #expect(step.next == nil)
            }
        }
    }

    @Test("OnboardingStep.previous returns correct step for active steps")
    func onboardingStepPreviousReturnsCorrectStep() {
        let steps = OnboardingStep.activeSteps
        for (index, step) in steps.enumerated() {
            if index > 0 {
                #expect(step.previous == steps[index - 1])
            } else {
                #expect(step.previous == nil)
            }
        }
    }

    @Test("OnboardingStep skippable status is correct")
    func onboardingStepSkippableStatusIsCorrect() {
        #expect(OnboardingStep.welcome.isSkippable == false)
        #expect(OnboardingStep.permissions.isSkippable == false)
        #expect(OnboardingStep.notifications.isSkippable == false)
    }

    // MARK: - Onboarding Completion Tests

    @Test("shouldShowOnboarding returns true when not completed")
    @MainActor
    func shouldShowOnboardingWhenNotCompleted() {
        // Reset onboarding state
        OnboardingViewModel.resetOnboarding()

        #expect(OnboardingViewModel.shouldShowOnboarding() == true)
    }

    @Test("Onboarding completion key is correct")
    func onboardingCompletionKeyIsCorrect() {
        #expect(OnboardingViewModel.onboardingCompletedKey == "hasCompletedOnboarding")
    }

    @Test("Onboarding version key is correct")
    func onboardingVersionKeyIsCorrect() {
        #expect(OnboardingViewModel.onboardingVersionKey == "onboardingVersion")
    }

    @Test("Current onboarding version is at least 1")
    func currentOnboardingVersionIsAtLeast1() {
        #expect(OnboardingViewModel.currentOnboardingVersion >= 1)
    }

    // MARK: - Step Count Tests

    @Test("Total steps count is 5")
    func totalStepsCountIs5() {
        #expect(OnboardingStep.allCases.count == 5)
    }

    @Test("Active steps count matches build configuration")
    func activeStepsCountMatchesBuild() {
        #if APP_STORE
        #expect(OnboardingStep.activeSteps.count == 4)
        #else
        #expect(OnboardingStep.activeSteps.count == 5)
        #endif
    }

    @Test("All cases are iterable in order")
    func stepsAreIterableInOrder() {
        let steps = OnboardingStep.allCases
        #expect(steps[0] == .welcome)
        #expect(steps[1] == .permissions)
        #expect(steps[2] == .notifications)
        #expect(steps[3] == .tutorial)
        #expect(steps[4] == .hotkeySetup)
    }
}

// MARK: - Accessibility Permission Tests

#if !APP_STORE
struct AccessibilityPermissionTests {
    @Test("AXIsProcessTrusted returns a boolean")
    func axIsProcessTrustedReturnsBool() {
        // This just verifies the API is accessible
        let result = AXIsProcessTrusted()
        #expect(result == true || result == false)
    }
}
#endif
