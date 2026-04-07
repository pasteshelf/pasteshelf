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

    // MARK: Internal

    /// Steps active in the current build (App Store skips Accessibility permission)
    static var activeSteps: [OnboardingStep] {
        #if APP_STORE
            return allCases.filter { $0 != .permissions }
        #else
            return Array(allCases)
        #endif
    }

    var id: Int {
        rawValue
    }

    /// Display title for each step
    var title: String {
        switch self {
        case .welcome:
            "Welcome to PasteShelf"
        case .permissions:
            "Accessibility Permission"
        case .notifications:
            "Notifications"
        case .tutorial:
            "How It Works"
        case .hotkeySetup:
            "Set Your Hotkey"
        }
    }

    /// Subtitle for progress indicator
    var subtitle: String {
        switch self {
        case .welcome:
            "Get started"
        case .permissions:
            "Required for paste"
        case .notifications:
            "Stay informed"
        case .tutorial:
            "Quick overview"
        case .hotkeySetup:
            "Almost done"
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
              currentIndex + 1 < steps.count
        else {
            return nil
        }
        return steps[currentIndex + 1]
    }

    /// Previous step in the sequence (respects active steps for current build)
    var previous: OnboardingStep? {
        let steps = Self.activeSteps
        guard let currentIndex = steps.firstIndex(of: self),
              currentIndex - 1 >= 0
        else {
            return nil
        }
        return steps[currentIndex - 1]
    }
}
