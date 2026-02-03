//
//  PasteShelfApp.swift
//  PasteShelf
//
//  Created by Harun Güngörer on 3.02.2026.
//

import SwiftUI
import CoreData

@main
struct PasteShelfApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
