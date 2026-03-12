#if !APP_STORE
//
//  PluginStorageImpl.swift
//  PasteShelf
//
//  Per-plugin persistent storage implementation.
//  Uses UserDefaults with plugin-specific prefixes for isolation.
//

import Foundation
import os.log

/// Per-plugin persistent storage using UserDefaults
@objc public final class PluginStorageImpl: NSObject, PluginStorage, @unchecked Sendable {
    // MARK: - Properties

    private let pluginId: String
    private let defaults: UserDefaults
    private let keyPrefix: String

    /// Storage directory for file-based storage
    private let storageDirectory: URL?

    // MARK: - Initialization

    init(pluginId: String) {
        self.pluginId = pluginId
        self.keyPrefix = "Plugin.\(pluginId)."

        // Use standard user defaults with prefixed keys
        self.defaults = UserDefaults.standard

        // Create plugin storage directory
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let pluginDir = appSupport
                .appendingPathComponent("PasteShelf")
                .appendingPathComponent("PluginData")
                .appendingPathComponent(pluginId)

            // Create directory if needed
            try? FileManager.default.createDirectory(
                at: pluginDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            self.storageDirectory = pluginDir
        } else {
            self.storageDirectory = nil
        }

        super.init()

        Logger.plugins.debug("[\(self.pluginId)] Storage initialized at \(self.storageDirectory?.path ?? "memory-only")")
    }

    // MARK: - Key Management

    private func prefixedKey(_ key: String) -> String {
        keyPrefix + key
    }

    // MARK: - String Storage

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: prefixedKey(key))
    }

    public func setString(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: prefixedKey(key))
        } else {
            defaults.removeObject(forKey: prefixedKey(key))
        }
    }

    // MARK: - Data Storage

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: prefixedKey(key))
    }

    public func setData(_ value: Data?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: prefixedKey(key))
        } else {
            defaults.removeObject(forKey: prefixedKey(key))
        }
    }

    // MARK: - Boolean Storage

    public func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: prefixedKey(key))
    }

    public func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: prefixedKey(key))
    }

    // MARK: - Integer Storage

    public func integer(forKey key: String) -> Int {
        defaults.integer(forKey: prefixedKey(key))
    }

    public func setInteger(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: prefixedKey(key))
    }

    // MARK: - Double Storage

    public func double(forKey key: String) -> Double {
        defaults.double(forKey: prefixedKey(key))
    }

    public func setDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: prefixedKey(key))
    }

    // MARK: - Object Removal

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: prefixedKey(key))
    }

    // MARK: - Clear All

    public func clear() {
        // Find and remove all keys with this plugin's prefix
        let allKeys = defaults.dictionaryRepresentation().keys
        let pluginKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        for key in pluginKeys {
            defaults.removeObject(forKey: key)
        }

        Logger.plugins.info("[\(self.pluginId)] Cleared \(pluginKeys.count) storage keys")

        // Clear file storage if exists
        if let storageDir = storageDirectory {
            try? FileManager.default.removeItem(at: storageDir)
            try? FileManager.default.createDirectory(
                at: storageDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - File Storage (Extended)

    /// Writes data to a file in the plugin's storage directory
    /// - Parameters:
    ///   - data: Data to write
    ///   - filename: File name (will be sanitized)
    /// - Returns: URL to the written file, or nil on failure
    func writeFile(_ data: Data, filename: String) -> URL? {
        guard let storageDir = storageDirectory else {
            Logger.plugins.warning("[\(self.pluginId)] No storage directory available")
            return nil
        }

        // Sanitize filename
        let sanitized = filename.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")

        let fileURL = storageDir.appendingPathComponent(sanitized)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            Logger.plugins.error("[\(self.pluginId)] Failed to write file \(sanitized): \(error.localizedDescription)")
            return nil
        }
    }

    /// Reads data from a file in the plugin's storage directory
    /// - Parameter filename: File name to read
    /// - Returns: File data, or nil if not found
    func readFile(_ filename: String) -> Data? {
        guard let storageDir = storageDirectory else {
            return nil
        }

        // Sanitize filename
        let sanitized = filename.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")

        let fileURL = storageDir.appendingPathComponent(sanitized)

        return try? Data(contentsOf: fileURL)
    }

    /// Deletes a file from the plugin's storage directory
    /// - Parameter filename: File name to delete
    /// - Returns: True if deleted or didn't exist
    func deleteFile(_ filename: String) -> Bool {
        guard let storageDir = storageDirectory else {
            return false
        }

        let sanitized = filename.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")

        let fileURL = storageDir.appendingPathComponent(sanitized)

        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return !FileManager.default.fileExists(atPath: fileURL.path)
        }
    }

    /// Lists all files in the plugin's storage directory
    /// - Returns: Array of file names
    func listFiles() -> [String] {
        guard let storageDir = storageDirectory else {
            return []
        }

        return (try? FileManager.default.contentsOfDirectory(atPath: storageDir.path)) ?? []
    }

    /// Gets the URL to the plugin's storage directory
    var directory: URL? {
        storageDirectory
    }
}

#endif
