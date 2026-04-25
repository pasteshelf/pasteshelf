//
//  CopiedConfirmationWindow.swift
//  PasteShelf
//
//  Floating toast window shown after copying to clipboard in App Store builds
//  where auto-paste via CGEvent is not available.
//

#if APP_STORE

import AppKit
import SwiftUI

/// Displays a brief "Copied to clipboard" toast that auto-dismisses
final class CopiedConfirmationWindow {
    private static var window: NSWindow?

    @MainActor
    static func show() {
        dismiss()

        let toastView = CopiedConfirmationView()
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 44)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.contentView = hostingView
        window.center()
        window.alphaValue = 0
        window.orderFrontRegardless()
        self.window = window

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    @MainActor
    private static func dismiss() {
        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
            self.window = nil
        }
    }
}

// MARK: - Toast View

private struct CopiedConfirmationView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(String(localized: "Copied to clipboard"))
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#endif
