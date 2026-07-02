#!/usr/bin/env swift
//
// watch-forti-window.swift — live monitor for FortiClient's dialog windows.
//
// Usage:  swift scripts/watch-forti-window.swift
//
// Run this WHILE trying to connect a (real or fake) FortiClient VPN. It polls
// the window list 10x/sec and prints, for every Fortinet-owned on-screen
// window: its window level, its z-order rank (0 = frontmost of all windows),
// and its bounds. This tells us:
//   1. the exact level the token/credential dialog uses (can we out-level it?)
//   2. whether it re-fronts on a timer (z-rank keeps snapping back to 0)
//   3. whether the PasteShelf panel (also printed) is above or below it
//
import CoreGraphics
import Foundation

// Line-buffer stdout so output appears immediately when redirected to a file.
setvbuf(stdout, nil, _IOLBF, 0)

func snapshot() -> [[String: Any]] {
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
}

let maxLevel = Int(CGWindowLevelForKey(.maximumWindow))
print("Watching for Fortinet + PasteShelf windows. Ctrl-C to stop.")
print("Reference: kCGMaximumWindowLevel = \(maxLevel), INT32_MAX = \(Int32.max)\n")

var lastSignature = ""

while true {
    let windows = snapshot()
    var lines: [String] = []
    for (rank, w) in windows.enumerated() {
        let owner = (w[kCGWindowOwnerName as String] as? String) ?? "?"
        guard owner.range(of: "forti", options: .caseInsensitive) != nil
            || owner.range(of: "PasteShelf", options: .caseInsensitive) != nil
        else { continue }
        let level = w[kCGWindowLayer as String] as? Int ?? 0
        let name = (w[kCGWindowName as String] as? String) ?? ""
        var boundsStr = ""
        if let b = w[kCGWindowBounds as String] as? [String: Any],
           let r = CGRect(dictionaryRepresentation: b as CFDictionary) {
            boundsStr = "\(Int(r.width))x\(Int(r.height))@(\(Int(r.minX)),\(Int(r.minY)))"
        }
        let flag = level >= maxLevel ? " [>=maxLevel]" : ""
        lines.append("  z-rank=\(rank)  level=\(level)\(flag)  \(owner)  \(name)  \(boundsStr)")
    }
    let signature = lines.joined(separator: "\n")
    if signature != lastSignature {
        let stamp = ISO8601DateFormatter().string(from: Date())
        print("[\(stamp)]")
        print(signature.isEmpty ? "  (no Fortinet/PasteShelf windows on screen)" : signature)
        print("")
        lastSignature = signature
    }
    usleep(100_000) // 100 ms
}
