//
//  PluginLoader.swift
//  PasteShelf
//
//  Discovers and loads plugin bundles from the plugins directory.
//  Handles bundle scanning, manifest parsing, and plugin instantiation.
//

import Foundation
import os.log

/// Discovers and loads plugin bundles
final class PluginLoader: Sendable {
    // MARK: - Singleton

    static let shared = PluginLoader()

    // MARK: - Properties

    private let logger = Logger.plugins

    /// Base plugin directory URLs (searched in order)
    private let pluginDirectories: [URL]

    /// Bundled plugins directory (in app bundle Resources)
    private var bundledPluginsDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Plugins")
    }

    // MARK: - Constants

    /// Application Support subdirectory for plugins
    private static let pluginsSubdirectory = "PasteShelf/Plugins"

    // MARK: - Initialization

    private init() {
        // Build list of plugin directories
        var directories: [URL] = []

        // User plugins directory (~/Library/Application Support/PasteShelf/Plugins)
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let userPlugins = appSupport.appendingPathComponent(Self.pluginsSubdirectory)
            directories.append(userPlugins)
        }

        // System plugins directory (/Library/Application Support/PasteShelf/Plugins)
        if let localAppSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .localDomainMask
        ).first {
            let systemPlugins = localAppSupport.appendingPathComponent(Self.pluginsSubdirectory)
            directories.append(systemPlugins)
        }

        self.pluginDirectories = directories

        logger.debug("Plugin directories: \(directories.map(\.path).joined(separator: ", "))")
    }

    // MARK: - Directory Management

    /// Returns the primary user plugins directory, creating it if needed
    var userPluginsDirectory: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let pluginsDir = appSupport.appendingPathComponent(Self.pluginsSubdirectory)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: pluginsDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: pluginsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("Created plugins directory at \(pluginsDir.path)")
            } catch {
                logger.error("Failed to create plugins directory: \(error.localizedDescription)")
                return nil
            }
        }

        return pluginsDir
    }

    // MARK: - Plugin Discovery

    /// Discovers all plugin bundles in the plugin directories
    /// - Returns: Array of discovered plugin bundles
    func discoverPlugins() -> [PluginBundle] {
        var discoveredBundles: [PluginBundle] = []
        var seenIdentifiers = Set<String>()

        // Discover bundled plugins first
        if let bundledDir = bundledPluginsDirectory {
            let bundled = discoverPlugins(in: bundledDir)
            for bundle in bundled {
                if !seenIdentifiers.contains(bundle.manifest.identifier) {
                    discoveredBundles.append(bundle)
                    seenIdentifiers.insert(bundle.manifest.identifier)
                }
            }
            logger.debug("Discovered \(bundled.count) bundled plugins")
        }

        // Discover user/system plugins (may override bundled)
        for directory in pluginDirectories {
            let plugins = discoverPlugins(in: directory)
            for bundle in plugins {
                // User plugins override bundled plugins with same identifier
                if let existingIndex = discoveredBundles.firstIndex(
                    where: { $0.manifest.identifier == bundle.manifest.identifier }
                ) {
                    discoveredBundles[existingIndex] = bundle
                    logger.debug("User plugin overrides bundled: \(bundle.manifest.identifier)")
                } else if !seenIdentifiers.contains(bundle.manifest.identifier) {
                    discoveredBundles.append(bundle)
                    seenIdentifiers.insert(bundle.manifest.identifier)
                }
            }
        }

        logger.info("Discovered \(discoveredBundles.count) total plugins")
        return discoveredBundles
    }

    /// Discovers plugins in a specific directory
    /// - Parameter directory: Directory to scan
    /// - Returns: Array of valid plugin bundles found
    private func discoverPlugins(in directory: URL) -> [PluginBundle] {
        let fm = FileManager.default

        // Check if directory exists
        guard fm.fileExists(atPath: directory.path) else {
            logger.debug("Plugin directory does not exist: \(directory.path)")
            return []
        }

        // Enumerate contents
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.warning("Failed to enumerate plugin directory: \(directory.path)")
            return []
        }

        // Filter for plugin bundles
        let pluginURLs = contents.filter { url in
            url.pathExtension == PluginBundle.bundleExtension
        }

        logger.debug("Found \(pluginURLs.count) plugin bundles in \(directory.lastPathComponent)")

        // Load each bundle
        return pluginURLs.compactMap { url in
            loadPluginBundle(at: url)
        }
    }

    /// Loads a single plugin bundle
    /// - Parameter url: URL to the plugin bundle
    /// - Returns: Loaded PluginBundle or nil on failure
    func loadPluginBundle(at url: URL) -> PluginBundle? {
        do {
            let bundle = try PluginBundle(url: url)
            logger.debug("Loaded plugin bundle: \(bundle.manifest.name) (\(bundle.manifest.identifier))")
            return bundle
        } catch let error as PluginLoadError {
            logger.error("Failed to load plugin at \(url.lastPathComponent): \(error.localizedDescription ?? "Unknown error")")
            return nil
        } catch {
            logger.error("Unexpected error loading plugin at \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Plugin Installation

    /// Installs a plugin bundle from a source URL
    /// - Parameter sourceURL: URL to the plugin bundle to install
    /// - Returns: The installed plugin bundle
    /// - Throws: PluginInstallError on failure
    func installPlugin(from sourceURL: URL) throws -> PluginBundle {
        // Validate source is a valid plugin
        guard sourceURL.pathExtension == PluginBundle.bundleExtension else {
            throw PluginInstallError.invalidBundle
        }

        // Load and validate the bundle
        let bundle = try PluginBundle(url: sourceURL)

        // Get destination directory
        guard let pluginsDir = userPluginsDirectory else {
            throw PluginInstallError.directoryCreationFailed
        }

        // Check for existing plugin with same identifier
        let destinationURL = pluginsDir.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // Remove existing version
            try FileManager.default.removeItem(at: destinationURL)
            logger.info("Removed existing plugin: \(bundle.manifest.identifier)")
        }

        // Copy plugin to plugins directory
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            logger.info("Installed plugin: \(bundle.manifest.name) to \(destinationURL.path)")
        } catch {
            throw PluginInstallError.copyFailed(error)
        }

        // Return the newly installed bundle
        guard let installedBundle = loadPluginBundle(at: destinationURL) else {
            throw PluginInstallError.loadFailed
        }

        return installedBundle
    }

    /// Uninstalls a plugin
    /// - Parameter pluginId: The plugin identifier to uninstall
    /// - Throws: PluginInstallError on failure
    func uninstallPlugin(pluginId: String) throws {
        // Find the plugin bundle
        guard let bundle = findPlugin(byId: pluginId) else {
            throw PluginInstallError.pluginNotFound
        }

        // Only allow uninstalling user plugins (not bundled)
        if let bundledDir = bundledPluginsDirectory,
           bundle.bundleURL.path.hasPrefix(bundledDir.path)
        {
            throw PluginInstallError.cannotUninstallBundled
        }

        // Remove the bundle
        do {
            try FileManager.default.removeItem(at: bundle.bundleURL)
            logger.info("Uninstalled plugin: \(pluginId)")
        } catch {
            throw PluginInstallError.deleteFailed(error)
        }
    }

    /// Finds a plugin by its identifier
    /// - Parameter pluginId: The plugin identifier
    /// - Returns: The plugin bundle if found
    func findPlugin(byId pluginId: String) -> PluginBundle? {
        discoverPlugins().first { $0.manifest.identifier == pluginId }
    }

    // MARK: - File System Watching

    /// Sets up file system monitoring for plugin changes
    /// - Parameter handler: Called when plugins directory changes
    /// - Returns: A dispatch source to keep alive, or nil if setup failed
    func watchForChanges(handler: @escaping () -> Void) -> DispatchSourceFileSystemObject? {
        guard let pluginsDir = userPluginsDirectory else {
            logger.warning("Cannot watch plugins directory - not available")
            return nil
        }

        let fileDescriptor = open(pluginsDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.error("Failed to open plugins directory for watching")
            return nil
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler {
            handler()
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        logger.debug("Watching plugins directory for changes")

        return source
    }
}

// MARK: - Plugin Install Errors

/// Errors that can occur during plugin installation
enum PluginInstallError: Error, LocalizedError, Sendable {
    case invalidBundle
    case directoryCreationFailed
    case copyFailed(Error)
    case loadFailed
    case pluginNotFound
    case cannotUninstallBundled
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBundle:
            return "The file is not a valid PasteShelf plugin"
        case .directoryCreationFailed:
            return "Failed to create plugins directory"
        case .copyFailed(let error):
            return "Failed to copy plugin: \(error.localizedDescription)"
        case .loadFailed:
            return "Failed to load installed plugin"
        case .pluginNotFound:
            return "Plugin not found"
        case .cannotUninstallBundled:
            return "Cannot uninstall bundled plugins"
        case .deleteFailed(let error):
            return "Failed to delete plugin: \(error.localizedDescription)"
        }
    }
}
