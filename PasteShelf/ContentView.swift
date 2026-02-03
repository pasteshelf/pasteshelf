//
//  ContentView.swift
//  PasteShelf
//
//  Created by Harun Güngörer on 3.02.2026.
//
//  Note: PasteShelf is a menu bar application. This view is not used
//  in normal operation but kept for potential future use (e.g., preferences window).
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("PasteShelf")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Clipboard manager running in menu bar")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Press \u{2318}\u{21E7}V to open clipboard history")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

#if DEBUG
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
#endif
