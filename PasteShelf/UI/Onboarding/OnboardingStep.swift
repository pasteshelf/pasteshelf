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
    case tutorial
    case hotkeySetup

    var id: Int { rawValue }

    /// Display title for each step
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to PasteShelf"
        case .permissions:
            return "Accessibility Permission"
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
        case .tutorial:
            return "Quick overview"
        case .hotkeySetup:
            return "Almost done"
        }
    }

    /// Whether this step can be skipped
    var isSkippable: Bool {
        switch self {
        case .welcome, .permissions:
            return false
        case .tutorial, .hotkeySetup:
            return true
        }
    }

    /// Next step in the sequence
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Previous step in the sequence
    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}
