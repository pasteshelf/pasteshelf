//
//  VisualEffectView.swift
//  PasteShelf
//
//  NSViewRepresentable wrapper for NSVisualEffectView to provide
//  vibrancy and blur effects in SwiftUI.
//

import AppKit
import SwiftUI

// MARK: - VisualEffectView

/// SwiftUI wrapper for NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false,
        state: NSVisualEffectView.State = .followsWindowActiveState
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
        self.state = state
    }

    // MARK: Internal

    /// The material type for the visual effect
    let material: NSVisualEffectView.Material

    /// The blending mode for the visual effect
    let blendingMode: NSVisualEffectView.BlendingMode

    /// Whether the view is emphasized (more vibrant)
    var isEmphasized: Bool = false

    /// The visual effect state
    var state: NSVisualEffectView.State = .followsWindowActiveState

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = self.material
        view.blendingMode = self.blendingMode
        view.isEmphasized = self.isEmphasized
        view.state = self.state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = self.material
        nsView.blendingMode = self.blendingMode
        nsView.isEmphasized = self.isEmphasized
        nsView.state = self.state
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Applies a visual effect background with the specified material
    func visualEffectBackground(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) -> some View {
        background(VisualEffectView(material: material, blendingMode: blendingMode))
    }

    /// Applies a sidebar-style visual effect background
    func sidebarBackground() -> some View {
        self.visualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
    }

    /// Applies a popover-style visual effect background
    func popoverBackground() -> some View {
        self.visualEffectBackground(material: .popover, blendingMode: .behindWindow)
    }

    /// Applies a menu-style visual effect background
    func menuBackground() -> some View {
        self.visualEffectBackground(material: .menu, blendingMode: .behindWindow)
    }
}

// MARK: - Preview

#if DEBUG
    struct VisualEffectView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                Text("Popover Material")
                    .padding()
                    .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
                    .cornerRadius(8)

                Text("Sidebar Material")
                    .padding()
                    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                    .cornerRadius(8)

                Text("Menu Material")
                    .padding()
                    .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
                    .cornerRadius(8)

                Text("HUD Material")
                    .padding()
                    .foregroundColor(.white)
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
                    .cornerRadius(8)
            }
            .padding(40)
            .frame(width: 300, height: 400)
        }
    }
#endif
