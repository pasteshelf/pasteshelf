//
//  OnboardingViewModelTests.swift
//  PasteShelfTests
//
//  Unit tests for OnboardingViewModel.
//

import ApplicationServices
import Foundation
import Testing
@testable import PasteShelf

struct OnboardingViewModelTests {
    // MARK: - OnboardingStep Tests

    @Test("OnboardingStep has correct order")
    func onboardingStepHasCorrectOrder() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.permissions.rawValue == 1)
        #expect(OnboardingStep.tutorial.rawValue == 2)
        #expect(OnboardingStep.hotkeySetup.rawValue == 3)
    }

    @Test("OnboardingStep.next returns correct step")
    func onboardingStepNextReturnsCorrectStep() {
        #expect(OnboardingStep.welcome.next == .permissions)
        #expect(OnboardingStep.permissions.next == .tutorial)
        #expect(OnboardingStep.tutorial.next == .hotkeySetup)
        #expect(OnboardingStep.hotkeySetup.next == nil)
    }

    @Test("OnboardingStep.previous returns correct step")
    func onboardingStepPreviousReturnsCorrectStep() {
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.permissions.previous == .welcome)
        #expect(OnboardingStep.tutorial.previous == .permissions)
        #expect(OnboardingStep.hotkeySetup.previous == .tutorial)
    }

    @Test("OnboardingStep skippable status is correct")
    func onboardingStepSkippableStatusIsCorrect() {
        // Welcome and permissions are required
        #expect(OnboardingStep.welcome.isSkippable == false)
        #expect(OnboardingStep.permissions.isSkippable == false)

        // Tutorial and hotkey setup are optional
        #expect(OnboardingStep.tutorial.isSkippable == true)
        #expect(OnboardingStep.hotkeySetup.isSkippable == true)
    }

    @Test("All steps have titles")
    func allStepsHaveTitles() {
        for step in OnboardingStep.allCases {
            #expect(!step.title.isEmpty)
        }
    }

    @Test("All steps have subtitles")
    func allStepsHaveSubtitles() {
        for step in OnboardingStep.allCases {
            #expect(!step.subtitle.isEmpty)
        }
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

    @Test("Total steps count is 4")
    func totalStepsCountIs4() {
        #expect(OnboardingStep.allCases.count == 4)
    }

    @Test("Steps are iterable in order")
    func stepsAreIterableInOrder() {
        let steps = OnboardingStep.allCases
        #expect(steps[0] == .welcome)
        #expect(steps[1] == .permissions)
        #expect(steps[2] == .tutorial)
        #expect(steps[3] == .hotkeySetup)
    }
}

// MARK: - Accessibility Permission Tests

struct AccessibilityPermissionTests {
    @Test("AXIsProcessTrusted returns a boolean")
    func axIsProcessTrustedReturnsBool() {
        // This just verifies the API is accessible
        let result = AXIsProcessTrusted()
        #expect(result == true || result == false)
    }
}
