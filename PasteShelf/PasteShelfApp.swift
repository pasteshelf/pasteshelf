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
    // MARK: - App Delegate

    /// AppDelegate manages menu bar, floating panel, and clipboard monitoring
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Core Services

    let persistenceController = PersistenceController.shared

    // MARK: - Body

    var body: some Scene {
        // Empty Settings scene for menu bar only app
        // The app runs entirely from the menu bar via AppDelegate
        Settings {
            EmptyView()
        }
    }
}
