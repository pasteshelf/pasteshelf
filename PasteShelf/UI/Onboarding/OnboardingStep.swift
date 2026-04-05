//
//  OnboardingStep.swift
//  PasteShelf
//
//  Defines the steps in the onboarding flow.
//

import Foundation

/// Represents each step in the onboarding process
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case permissions
    case notifications
    case tutorial
    case hotkeySetup

    var id: Int { rawValue }

    /// Steps active in the current build (App Store skips Accessibility permission)
    static var activeSteps: [OnboardingStep] {
        #if APP_STORE
        return allCases.filter { $0 != .permissions }
        #else
        return Array(allCases)
        #endif
    }

    /// Display title for each step
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to PasteShelf"
        case .permissions:
            return "Accessibility Permission"
        case .notifications:
            return "Notifications"
        case .tutorial:
            return "How It Works"
        case .hotkeySetup:
            return "Set Your Hotkey"
        }
    }

    /// Subtitle for progress indicator
    var subtitle: String {
        switch self {
        case .welcome:
            return "Get started"
        case .permissions:
            return "Required for paste"
        case .notifications:
            return "Stay informed"
        case .tutorial:
            return "Quick overview"
        case .hotkeySetup:
            return "Almost done"
        }
    }

    /// Whether this step can be skipped
    var isSkippable: Bool {
        false
    }

    /// Next step in the sequence (respects active steps for current build)
    var next: OnboardingStep? {
        let steps = Self.activeSteps
        guard let currentIndex = steps.firstIndex(of: self),
              currentIndex + 1 < steps.count else { return nil }
        return steps[currentIndex + 1]
    }

    /// Previous step in the sequence (respects active steps for current build)
    var previous: OnboardingStep? {
        let steps = Self.activeSteps
        guard let currentIndex = steps.firstIndex(of: self),
              currentIndex - 1 >= 0 else { return nil }
        return steps[currentIndex - 1]
    }
}
