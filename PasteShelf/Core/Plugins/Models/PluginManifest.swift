//
//  PluginManifest.swift
//  PasteShelf
//
//  Represents the parsed Info.plist metadata for a plugin bundle.
//  Contains all declarative information about a plugin's identity and capabilities.
//

import Foundation

/// Plugin manifest parsed from Info.plist
struct PluginManifest: Equatable, Sendable, Identifiable {
    // MARK: - Required Fields

    /// Bundle identifier (CFBundleIdentifier)
    let identifier: String

    /// Display name (CFBundleName)
    let name: String

    /// Version string (CFBundleVersion)
    let version: String

    /// Short version string (CFBundleShortVersionString)
    let shortVersion: String

    /// Principal class name (PSPluginClass)
    let pluginClass: String

    // MARK: - Optional Metadata

    /// Plugin description (PSPluginDescription)
    let pluginDescription: String?

    /// Author name (PSPluginAuthor)
    let author: String?

    /// Plugin website URL (PSPluginWebsite)
    let website: URL?

    /// Minimum PasteShelf version required (PSMinimumPasteShelfVersion)
    let minPasteShelfVersion: String?

    /// Support email (PSPluginSupportEmail)
    let supportEmail: String?

    // MARK: - Capabilities

    /// Required permissions (PSRequiredPermissions)
    let requiredPermissions: Set<PluginPermission>

    /// Supported content types (PSSupportedContentTypes)
    let supportedContentTypes: [String]

    /// Plugin categories (PSPluginCategories)
    let categories: [PluginCategory]

    // MARK: - Identifiable

    var id: String { identifier }

    // MARK: - Initialization

    init(
        identifier: String,
        name: String,
        version: String,
        shortVersion: String,
        pluginClass: String,
        pluginDescription: String? = nil,
        author: String? = nil,
        website: URL? = nil,
        minPasteShelfVersion: String? = nil,
        supportEmail: String? = nil,
        requiredPermissions: Set<PluginPermission> = [],
        supportedContentTypes: [String] = [],
        categories: [PluginCategory] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.shortVersion = shortVersion
        self.pluginClass = pluginClass
        self.pluginDescription = pluginDescription
        self.author = author
        self.website = website
        self.minPasteShelfVersion = minPasteShelfVersion
        self.supportEmail = supportEmail
        self.requiredPermissions = requiredPermissions
        self.supportedContentTypes = supportedContentTypes
        self.categories = categories
    }

    // MARK: - Info.plist Parsing

    /// Creates a manifest from Info.plist dictionary
    /// - Parameter plist: The Info.plist dictionary
    /// - Returns: Parsed manifest or nil if required fields are missing
    static func from(plist: [String: Any]) -> PluginManifest? {
        // Required fields
        guard let identifier = plist["CFBundleIdentifier"] as? String,
              let name = plist["CFBundleName"] as? String,
              let version = plist["CFBundleVersion"] as? String,
              let pluginClass = plist["PSPluginClass"] as? String
        else {
            return nil
        }

        // Short version (default to version if not present)
        let shortVersion = plist["CFBundleShortVersionString"] as? String ?? version

        // Optional metadata
        let pluginDescription = plist["PSPluginDescription"] as? String
        let author = plist["PSPluginAuthor"] as? String
        let websiteString = plist["PSPluginWebsite"] as? String
        let website = websiteString.flatMap { URL(string: $0) }
        let minVersion = plist["PSMinimumPasteShelfVersion"] as? String
        let supportEmail = plist["PSPluginSupportEmail"] as? String

        // Permissions
        let permissionStrings = plist["PSRequiredPermissions"] as? [String] ?? []
        let permissions = PluginPermission.from(rawValues: permissionStrings)

        // Content types
        let contentTypes = plist["PSSupportedContentTypes"] as? [String] ?? []

        // Categories
        let categoryStrings = plist["PSPluginCategories"] as? [String] ?? []
        let categories = categoryStrings.compactMap { PluginCategory(rawValue: $0) }

        return PluginManifest(
            identifier: identifier,
            name: name,
            version: version,
            shortVersion: shortVersion,
            pluginClass: pluginClass,
            pluginDescription: pluginDescription,
            author: author,
            website: website,
            minPasteShelfVersion: minVersion,
            supportEmail: supportEmail,
            requiredPermissions: permissions,
            supportedContentTypes: contentTypes,
            categories: categories.isEmpty ? [.utility] : categories
        )
    }

    /// Loads manifest from Info.plist at the given URL
    /// - Parameter url: URL to Info.plist file
    /// - Returns: Parsed manifest or nil on failure
    static func load(from url: URL) -> PluginManifest? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ) as? [String: Any]
        else {
            return nil
        }

        return from(plist: plist)
    }

    // MARK: - Version Comparison

    /// Checks if this plugin is compatible with the given PasteShelf version
    /// - Parameter hostVersion: The host app version string
    /// - Returns: True if compatible
    func isCompatible(with hostVersion: String) -> Bool {
        guard let minVersion = minPasteShelfVersion else {
            return true // No minimum version specified
        }

        return compareVersions(hostVersion, minVersion) >= 0
    }

    /// Compares two semantic version strings
    /// - Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(components1.count, components2.count)

        for i in 0..<maxCount {
            let c1 = i < components1.count ? components1[i] : 0
            let c2 = i < components2.count ? components2[i] : 0

            if c1 < c2 { return -1 }
            if c1 > c2 { return 1 }
        }

        return 0
    }
}

/// Plugin categories for organization and discovery
enum PluginCategory: String, Codable, CaseIterable, Sendable {
    case transformation = "transformation"
    case integration = "integration"
    case formatting = "formatting"
    case productivity = "productivity"
    case developer = "developer"
    case utility = "utility"

    var displayName: String {
        switch self {
        case .transformation:
            return String(localized: "Transformation")
        case .integration:
            return String(localized: "Integration")
        case .formatting:
            return String(localized: "Formatting")
        case .productivity:
            return String(localized: "Productivity")
        case .developer:
            return String(localized: "Developer Tools")
        case .utility:
            return String(localized: "Utility")
        }
    }

    var iconName: String {
        switch self {
        case .transformation:
            return "wand.and.stars"
        case .integration:
            return "arrow.triangle.2.circlepath"
        case .formatting:
            return "textformat"
        case .productivity:
            return "bolt.fill"
        case .developer:
            return "hammer.fill"
        case .utility:
            return "wrench.and.screwdriver.fill"
        }
    }
}
