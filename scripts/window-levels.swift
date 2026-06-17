#!/usr/bin/env swift
//
// window-levels.swift — diagnostic: dump every on-screen window's level.
//
// Usage:  swift scripts/window-levels.swift
// Run it WHILE the FortiClient credential prompt is visible to learn the
// exact window level that prompt uses, so we know whether the PasteShelf
// panel can be raised above it.
//
import CoreGraphics
import Foundation

guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
    print("Could not read window list (grant Screen Recording permission if needed).")
    exit(1)
}

let shield = Int(CGShieldingWindowLevel())
let panelLevel = shield - 1

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

print("\(pad("LAYER", 12))\(pad("OWNER", 28))WINDOW NAME")
print(String(repeating: "-", count: 70))

// Sort by layer descending so the top-most windows print first.
let rows = info.compactMap { w -> (Int, String, String)? in
    guard let layer = w[kCGWindowLayer as String] as? Int else { return nil }
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? "?"
    let name = (w[kCGWindowName as String] as? String) ?? ""
    return (layer, owner, name)
}.sorted { $0.0 > $1.0 }

for (layer, owner, name) in rows {
    // Flag any window at or above the PasteShelf panel level — those are the
    // ones that can sit on top of (or tie with) the panel.
    let marker = layer >= panelLevel ? " <== at/above PasteShelf panel" : ""
    print("\(pad(String(layer), 12))\(pad(owner, 28))\(name)\(marker)")
}

print("")
print("Reference levels:")
print("  CGShieldingWindowLevel()        = \(shield)")
print("  PasteShelf panel (shield - 1)   = \(shield - 1)")
print("  .popUpMenu                      = \(Int(CGWindowLevelForKey(.popUpMenuWindow)))")
print("  .mainMenu                       = \(Int(CGWindowLevelForKey(.mainMenuWindow)))")
print("  .statusBar (NSStatusWindowLevel)= \(Int(CGWindowLevelForKey(.statusWindow)))")
print("  .floating                       = \(Int(CGWindowLevelForKey(.floatingWindow)))")
print("  maximumWindow                   = \(Int(CGWindowLevelForKey(.maximumWindow)))")
