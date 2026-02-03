//
//  Logger+Extensions.swift
//  PasteShelf
//
//  Logger extensions providing subsystem-specific loggers for different
//  components of the application. Uses Apple's os.log framework for
//  efficient, privacy-aware logging.
//

import Foundation
import os.log

extension Logger {
    /// The subsystem identifier for all PasteShelf loggers
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pasteshelf.PasteShelf"

    // MARK: - Core Subsystem Loggers

    /// Logger for clipboard monitoring and content handling
    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")

    /// Logger for CoreData persistence and data storage operations
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// Logger for search engine operations (full-text, semantic, OCR)
    static let search = Logger(subsystem: subsystem, category: "Search")

    /// Logger for CloudKit sync operations (Pro feature)
    static let sync = Logger(subsystem: subsystem, category: "Sync")

    /// Logger for encryption, sensitive data handling, and security operations
    static let security = Logger(subsystem: subsystem, category: "Security")

    /// Logger for SwiftUI views and user interface components
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Logger for app lifecycle and general application events
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Logger for licensing and feature gating operations
    static let licensing = Logger(subsystem: subsystem, category: "Licensing")

    /// Logger for plugin system operations (Pro feature)
    static let plugins = Logger(subsystem: subsystem, category: "Plugins")
}

// MARK: - Debug/Release Configuration

#if DEBUG
/// Debug-only logging utilities
extension Logger {
    /// Logs verbose debug information. Only available in DEBUG builds.
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func verbose(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        self.debug("[\(filename):\(line)] \(function) - \(message)")
    }
}
#endif
