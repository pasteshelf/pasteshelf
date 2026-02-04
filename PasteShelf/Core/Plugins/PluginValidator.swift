//
//  PluginValidator.swift
//  PasteShelf
//
//  Validates plugin bundles for security and compatibility.
//  Verifies code signatures and checks version requirements.
//

import Foundation
import os.log
import Security

/// Validates plugin bundles before loading
final class PluginValidator: Sendable {
    // MARK: - Singleton

    static let shared = PluginValidator()

    // MARK: - Properties

    private let logger = Logger.plugins

    /// Current PasteShelf version for compatibility checking
    private var hostVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Blocked plugin identifiers (security blacklist)
    private let blockedPlugins: Set<String> = []

    /// Whether to require signed plugins (can be disabled for development)
    private let requireSignature: Bool

    // MARK: - Initialization

    private init() {
        #if DEBUG
        // Allow unsigned plugins in debug builds
        self.requireSignature = false
        #else
        self.requireSignature = true
        #endif
    }

    // MARK: - Validation

    /// Validates a plugin bundle
    /// - Parameter bundle: The plugin bundle to validate
    /// - Returns: Validation result with success or failure reason
    func validate(_ bundle: PluginBundle) -> PluginValidationResult {
        let manifest = bundle.manifest

        // Check if plugin is blocked
        if blockedPlugins.contains(manifest.identifier) {
            logger.warning("Plugin \(manifest.identifier) is blocked")
            return .failure(.pluginBlocked(manifest.identifier))
        }

        // Check version compatibility
        if !manifest.isCompatible(with: hostVersion) {
            let required = manifest.minPasteShelfVersion ?? "unknown"
            logger.warning("""
                Plugin \(manifest.name) requires PasteShelf \(required), \
                but host version is \(self.hostVersion)
                """)
            return .failure(.incompatibleVersion(
                pluginVersion: manifest.version,
                requiredHostVersion: required,
                currentHostVersion: hostVersion
            ))
        }

        // Validate code signature
        if requireSignature {
            let signatureResult = validateSignature(bundle)
            if case .failure(let error) = signatureResult {
                return .failure(error)
            }
        }

        logger.debug("Plugin \(manifest.identifier) passed validation")
        return .success
    }

    // MARK: - Code Signature Validation

    /// Validates the code signature of a plugin bundle
    /// - Parameter bundle: The plugin bundle to check
    /// - Returns: Validation result
    func validateSignature(_ bundle: PluginBundle) -> PluginValidationResult {
        let bundleURL = bundle.bundleURL

        // Create static code reference
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundleURL as CFURL,
            [],
            &staticCode
        )

        guard createStatus == errSecSuccess, let code = staticCode else {
            logger.error("Failed to create static code for \(bundle.manifest.identifier): \(createStatus)")
            return .failure(.signatureValidationFailed("Unable to analyze code signature"))
        }

        // Check validity of signature
        let validityStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            nil
        )

        switch validityStatus {
        case errSecSuccess:
            // Signature is valid, get signing info
            var info: CFDictionary?
            let infoStatus = SecCodeCopySigningInformation(
                code,
                SecCSFlags(rawValue: kSecCSSigningInformation),
                &info
            )

            if infoStatus == errSecSuccess, let signingInfo = info as? [String: Any] {
                // Log signing info
                if let teamId = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String {
                    logger.debug("Plugin \(bundle.manifest.identifier) signed by team: \(teamId)")
                }
                return .success
            }
            return .success

        case errSecCSUnsigned:
            logger.warning("Plugin \(bundle.manifest.identifier) is not signed")
            return .failure(.notSigned)

        case errSecCSSignatureFailed:
            logger.error("Plugin \(bundle.manifest.identifier) signature is invalid")
            return .failure(.signatureInvalid)

        case errSecCSSignatureNotVerifiable:
            logger.error("Plugin \(bundle.manifest.identifier) signature cannot be verified")
            return .failure(.signatureNotVerifiable)

        case errSecCSStaticCodeChanged:
            logger.error("Plugin \(bundle.manifest.identifier) code was modified after signing")
            return .failure(.codeModified)

        default:
            logger.error("Plugin \(bundle.manifest.identifier) signature check failed: \(validityStatus)")
            return .failure(.signatureValidationFailed("Security check failed with code \(validityStatus)"))
        }
    }

    /// Gets the team identifier from a signed plugin
    /// - Parameter bundle: The plugin bundle
    /// - Returns: Team identifier or nil if not signed or unavailable
    func getTeamIdentifier(_ bundle: PluginBundle) -> String? {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundle.bundleURL as CFURL,
            [],
            &staticCode
        )

        guard createStatus == errSecSuccess, let code = staticCode else {
            return nil
        }

        var info: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        )

        guard infoStatus == errSecSuccess,
              let signingInfo = info as? [String: Any]
        else {
            return nil
        }

        return signingInfo[kSecCodeInfoTeamIdentifier as String] as? String
    }

    // MARK: - Permission Validation

    /// Validates that a plugin has declared all required permissions
    /// - Parameters:
    ///   - bundle: The plugin bundle
    ///   - requiredPermissions: Permissions the plugin wants to use
    /// - Returns: Validation result
    func validatePermissions(
        _ bundle: PluginBundle,
        requesting permissions: Set<PluginPermission>
    ) -> PluginValidationResult {
        let declared = bundle.manifest.requiredPermissions

        // Check all requested permissions are declared in manifest
        let undeclared = permissions.subtracting(declared)
        if !undeclared.isEmpty {
            let undeclaredNames = undeclared.map(\.displayName).joined(separator: ", ")
            logger.warning("""
                Plugin \(bundle.manifest.identifier) requesting undeclared permissions: \(undeclaredNames)
                """)
            return .failure(.undeclaredPermissions(undeclared))
        }

        return .success
    }

    // MARK: - Batch Validation

    /// Validates multiple plugins and returns results
    /// - Parameter bundles: Plugins to validate
    /// - Returns: Dictionary mapping plugin identifier to validation result
    func validateAll(_ bundles: [PluginBundle]) -> [String: PluginValidationResult] {
        var results: [String: PluginValidationResult] = [:]

        for bundle in bundles {
            results[bundle.manifest.identifier] = validate(bundle)
        }

        let validCount = results.values.filter { $0.isSuccess }.count
        logger.info("Validated \(bundles.count) plugins: \(validCount) passed, \(bundles.count - validCount) failed")

        return results
    }
}

// MARK: - Validation Result

/// Result of plugin validation
enum PluginValidationResult: Sendable {
    case success
    case failure(PluginValidationError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var error: PluginValidationError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Errors that can occur during plugin validation
enum PluginValidationError: Error, LocalizedError, Sendable {
    case pluginBlocked(String)
    case incompatibleVersion(pluginVersion: String, requiredHostVersion: String, currentHostVersion: String)
    case notSigned
    case signatureInvalid
    case signatureNotVerifiable
    case codeModified
    case signatureValidationFailed(String)
    case undeclaredPermissions(Set<PluginPermission>)

    var errorDescription: String? {
        switch self {
        case .pluginBlocked(let identifier):
            return "Plugin '\(identifier)' has been blocked for security reasons"
        case .incompatibleVersion(_, let required, let current):
            return "Plugin requires PasteShelf \(required) or later (current: \(current))"
        case .notSigned:
            return "Plugin is not code signed"
        case .signatureInvalid:
            return "Plugin code signature is invalid"
        case .signatureNotVerifiable:
            return "Plugin code signature cannot be verified"
        case .codeModified:
            return "Plugin code was modified after signing"
        case .signatureValidationFailed(let reason):
            return "Code signature validation failed: \(reason)"
        case .undeclaredPermissions(let permissions):
            let names = permissions.map(\.displayName).joined(separator: ", ")
            return "Plugin uses undeclared permissions: \(names)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pluginBlocked:
            return "This plugin may contain malware or has known security issues. Do not use it."
        case .incompatibleVersion:
            return "Update PasteShelf to the latest version or contact the plugin developer."
        case .notSigned:
            return "Only use plugins from trusted developers with valid code signatures."
        case .signatureInvalid, .signatureNotVerifiable, .codeModified:
            return "The plugin may have been tampered with. Re-download from the original source."
        case .signatureValidationFailed:
            return "Contact the plugin developer or try re-downloading the plugin."
        case .undeclaredPermissions:
            return "Contact the plugin developer to update the plugin's Info.plist."
        }
    }
}
