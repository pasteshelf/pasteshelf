#if !APP_STORE
//
    //  PluginBundle.swift
    //  PasteShelf
//
    //  Represents a loaded plugin bundle with its resources and metadata.
    //  Handles bundle structure validation and resource extraction.
//

    import AppKit
    import Foundation
    import os.log

    /// Represents a loaded plugin bundle
    final class PluginBundle: Sendable {
        // MARK: Lifecycle

        // MARK: - Initialization

        /// Creates a PluginBundle for built-in plugins compiled into the main app
        /// - Parameter manifest: Pre-built manifest for the built-in plugin
        init(builtIn manifest: PluginManifest) {
            bundleURL = Bundle.main.bundleURL
            self.manifest = manifest
            bundle = Bundle.main
        }

        /// Creates a PluginBundle from a bundle URL
        /// - Parameter url: URL to the .pasteshelfplugin bundle
        /// - Throws: PluginLoadError if the bundle is invalid
        init(url: URL) throws {
            bundleURL = url

            // Validate bundle extension
            guard url.pathExtension == Self.bundleExtension else {
                throw PluginLoadError.invalidBundleExtension(url.pathExtension)
            }

            // Validate bundle exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                throw PluginLoadError.bundleNotFound(url.path)
            }

            // Load Info.plist
            let infoPlistURL = url.appendingPathComponent(Self.infoPlistPath)
            guard let manifest = PluginManifest.load(from: infoPlistURL) else {
                throw PluginLoadError.invalidInfoPlist(infoPlistURL.path)
            }
            self.manifest = manifest

            // Create NSBundle
            guard let bundle = Bundle(url: url) else {
                throw PluginLoadError.bundleLoadFailed(url.path)
            }
            self.bundle = bundle

            // Validate structure
            try validateBundleStructure()
        }

        // MARK: Internal

        // MARK: - Constants

        /// Plugin bundle extension
        static let bundleExtension = "pasteshelfplugin"

        /// URL to the plugin bundle
        let bundleURL: URL

        /// Parsed manifest from Info.plist
        let manifest: PluginManifest

        /// The underlying NSBundle
        let bundle: Bundle

        // MARK: - Resources

        /// Returns the plugin icon, loading from Resources/icon.png
        var icon: NSImage {
            if let cached = _icon {
                return cached
            }

            let iconURL = bundleURL.appendingPathComponent(Self.iconPath)
            if let image = NSImage(contentsOf: iconURL) {
                _icon = image
                return image
            }

            // Return default plugin icon
            let defaultIcon = NSImage(
                systemSymbolName: "puzzlepiece.extension.fill",
                accessibilityDescription: "Plugin"
            ) ?? NSImage()
            _icon = defaultIcon
            return defaultIcon
        }

        /// Returns URL to Resources directory
        var resourcesURL: URL {
            bundleURL.appendingPathComponent(Self.resourcesPath)
        }

        // MARK: - Equatable

        static func == (lhs: PluginBundle, rhs: PluginBundle) -> Bool {
            lhs.manifest.identifier == rhs.manifest.identifier
        }

        /// Gets a resource URL by name
        /// - Parameters:
        ///   - name: Resource file name
        ///   - ext: File extension
        /// - Returns: URL to the resource if it exists
        func resourceURL(forResource name: String, withExtension ext: String?) -> URL? {
            bundle.url(forResource: name, withExtension: ext)
        }

        /// Loads localizable strings for the plugin
        /// - Parameter key: The localization key
        /// - Returns: Localized string or the key if not found
        func localizedString(forKey key: String) -> String {
            bundle.localizedString(forKey: key, value: key, table: nil)
        }

        // MARK: - Plugin Loading

        /// Loads and instantiates the principal class
        /// - Returns: An instance of the plugin's principal class
        /// - Throws: PluginLoadError if class loading fails
        func loadPrincipalClass() throws -> AnyObject {
            // Try to load the principal class from the bundle
            guard bundle.load() else {
                throw PluginLoadError.bundleLoadFailed(bundleURL.path)
            }

            // Get the principal class
            let className = manifest.pluginClass
            guard let principalClass = bundle.classNamed(className) else {
                // Try with module prefix
                let bundleName = manifest.identifier.split(separator: ".").last ?? "Plugin"
                let fullyQualifiedName = "\(bundleName).\(className.split(separator: ".").last ?? Substring(className))"
                guard let altClass = bundle.classNamed(String(fullyQualifiedName)) else {
                    throw PluginLoadError.principalClassNotFound(className)
                }
                return try instantiateClass(altClass)
            }

            return try instantiateClass(principalClass)
        }

        // MARK: Private

        /// Expected bundle structure paths
        private static let infoPlistPath = "Contents/Info.plist"
        private static let macOSPath = "Contents/MacOS"
        private static let resourcesPath = "Contents/Resources"
        private static let iconPath = "Contents/Resources/icon.png"

        /// Plugin icon (128x128)
        private nonisolated(unsafe) var _icon: NSImage?

        // MARK: - Bundle Validation

        /// Validates the plugin bundle has the required structure
        private func validateBundleStructure() throws {
            let fm = FileManager.default

            // Check MacOS directory exists
            let macOSURL = bundleURL.appendingPathComponent(Self.macOSPath)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: macOSURL.path, isDirectory: &isDir), isDir.boolValue else {
                throw PluginLoadError.missingMacOSDirectory(bundleURL.path)
            }

            // Check for executable
            let executableName = manifest.identifier.split(separator: ".").last.map(String.init)
                ?? manifest.name.replacingOccurrences(of: " ", with: "")
            let executableURL = macOSURL.appendingPathComponent(executableName)

            // Note: Executable validation is optional for Swift-based plugins
            // that may use NSBundle principal class loading
            if !fm.fileExists(atPath: executableURL.path) {
                // Try with plugin name
                let altExecutableURL = macOSURL.appendingPathComponent(
                    manifest.name.replacingOccurrences(of: " ", with: "")
                )
                if !fm.fileExists(atPath: altExecutableURL.path) {
                    // Log warning but don't fail - principal class may be in main bundle
                    Logger(
                        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
                        category: "plugins"
                    )
                    .warning("No executable found in plugin bundle, will attempt principal class loading")
                }
            }
        }

        /// Instantiates a class as NSObject
        private func instantiateClass(_ cls: AnyClass) throws -> AnyObject {
            guard let nsClass = cls as? NSObject.Type else {
                throw PluginLoadError.invalidPrincipalClass(String(describing: cls))
            }
            return nsClass.init()
        }
    }

    // MARK: - Hashable

    extension PluginBundle: Hashable {
        func hash(into hasher: inout Hasher) {
            hasher.combine(manifest.identifier)
        }
    }

    // MARK: - Plugin Load Errors

    /// Errors that can occur when loading a plugin bundle
    enum PluginLoadError: Error, LocalizedError, Sendable {
        case invalidBundleExtension(String)
        case bundleNotFound(String)
        case invalidInfoPlist(String)
        case bundleLoadFailed(String)
        case missingMacOSDirectory(String)
        case principalClassNotFound(String)
        case invalidPrincipalClass(String)
        case signatureValidationFailed(String)
        case incompatibleVersion(pluginVersion: String, requiredVersion: String)
        case permissionDenied(PluginPermission)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .invalidBundleExtension(ext):
                "Invalid bundle extension: '\(ext)'. Expected '\(PluginBundle.bundleExtension)'"
            case let .bundleNotFound(path):
                "Plugin bundle not found at: \(path)"
            case let .invalidInfoPlist(path):
                "Invalid or missing Info.plist at: \(path)"
            case let .bundleLoadFailed(path):
                "Failed to load plugin bundle at: \(path)"
            case let .missingMacOSDirectory(path):
                "Missing Contents/MacOS directory in: \(path)"
            case let .principalClassNotFound(className):
                "Principal class '\(className)' not found in plugin bundle"
            case let .invalidPrincipalClass(className):
                "Principal class '\(className)' does not inherit from NSObject"
            case let .signatureValidationFailed(reason):
                "Code signature validation failed: \(reason)"
            case let .incompatibleVersion(pluginVersion, requiredVersion):
                "Plugin version \(pluginVersion) requires PasteShelf \(requiredVersion) or later"
            case let .permissionDenied(permission):
                "Permission '\(permission.displayName)' was denied"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .invalidBundleExtension:
                "Ensure the plugin has the .pasteshelfplugin extension"
            case .bundleNotFound:
                "Verify the plugin file exists and is accessible"
            case .invalidInfoPlist:
                "The plugin's Info.plist may be corrupted or missing required fields"
            case .bundleLoadFailed:
                "The plugin binary may be corrupted or built for an incompatible architecture"
            case .missingMacOSDirectory:
                "The plugin bundle structure is invalid"
            case .principalClassNotFound:
                "The plugin may be built incorrectly or the class name is misspelled"
            case .invalidPrincipalClass:
                "Contact the plugin developer - the principal class must be an NSObject subclass"
            case .signatureValidationFailed:
                "The plugin may have been modified or is not properly signed"
            case .incompatibleVersion:
                "Update PasteShelf to the latest version"
            case .permissionDenied:
                "Grant the required permission in plugin settings"
            }
        }
    }

#endif
