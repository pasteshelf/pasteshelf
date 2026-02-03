//
//  PasteShelfApp.swift
//  PasteShelf
//
//  Created by Harun Güngörer on 3.02.2026.
//

import CoreData
import SwiftUI

@main
struct PasteShelfApp: App {
    // MARK: - Core Services

    let persistenceController = PersistenceController.shared
    let storageManager = StorageManager.shared

    /// Clipboard monitor with storage integration
    @State private var clipboardMonitor: ClipboardMonitor?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(storageManager)
                .onAppear {
                    setupClipboardMonitor()
                }
        }
    }

    // MARK: - Setup

    private func setupClipboardMonitor() {
        // Create clipboard monitor with storage integration
        clipboardMonitor = ClipboardMonitor(storage: storageManager)
        // Note: Start monitoring when UI is ready (Phase 1.4)
        // clipboardMonitor?.startMonitoring()
    }
}
