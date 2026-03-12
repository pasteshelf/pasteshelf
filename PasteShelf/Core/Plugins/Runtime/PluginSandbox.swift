#if !APP_STORE
//
//  PluginSandbox.swift
//  PasteShelf
//
//  Defines sandbox restrictions and resource limits for plugins.
//  Plugins run in-process but with restricted API access.
//

import Foundation
import os.log

/// Configuration for plugin sandbox restrictions
struct PluginSandboxConfig: Sendable {
    /// Maximum execution time for plugin operations (seconds)
    let maxExecutionTime: TimeInterval

    /// Maximum memory usage (bytes, 0 = unlimited)
    let maxMemoryUsage: Int

    /// Whether network access is allowed
    let allowNetwork: Bool

    /// Whether file system access is allowed (outside plugin storage)
    let allowFileSystem: Bool

    /// Whether subprocess execution is allowed
    let allowSubprocesses: Bool

    /// Allowed URL schemes for network requests
    let allowedURLSchemes: Set<String>

    /// Blocked hosts for network requests
    let blockedHosts: Set<String>

    /// Default configuration with reasonable limits
    static let `default` = PluginSandboxConfig(
        maxExecutionTime: 30.0,
        maxMemoryUsage: 100 * 1024 * 1024, // 100 MB
        allowNetwork: false,
        allowFileSystem: false,
        allowSubprocesses: false,
        allowedURLSchemes: ["https"],
        blockedHosts: []
    )

    /// Permissive configuration for trusted plugins
    static let trusted = PluginSandboxConfig(
        maxExecutionTime: 60.0,
        maxMemoryUsage: 256 * 1024 * 1024, // 256 MB
        allowNetwork: true,
        allowFileSystem: false,
        allowSubprocesses: false,
        allowedURLSchemes: ["https", "http"],
        blockedHosts: []
    )
}

/// Sandbox environment for executing plugin code
actor PluginSandbox {
    // MARK: - Properties

    private let pluginId: String
    private let config: PluginSandboxConfig
    private let logger = Logger.plugins

    /// Currently active operations for timeout tracking
    private var activeOperations: [UUID: Date] = [:]

    // MARK: - Initialization

    init(pluginId: String, config: PluginSandboxConfig = .default) {
        self.pluginId = pluginId
        self.config = config
    }

    // MARK: - Sandboxed Execution

    /// Executes a plugin operation with timeout
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - timeout: Optional custom timeout (uses config default if nil)
    /// - Returns: The operation result
    /// - Throws: PluginSandboxError on timeout or other sandbox violations
    func execute<T: Sendable>(
        _ operation: @Sendable @escaping () async throws -> T,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let operationId = UUID()
        let effectiveTimeout = timeout ?? config.maxExecutionTime

        activeOperations[operationId] = Date()

        defer {
            activeOperations.removeValue(forKey: operationId)
        }

        // Create task with timeout
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                throw PluginSandboxError.timeout(seconds: effectiveTimeout)
            }

            // Return first result (operation or timeout)
            guard let result = try await group.next() else {
                throw PluginSandboxError.executionFailed("No result")
            }

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    // MARK: - Network Validation

    /// Validates a network request against sandbox policy
    /// - Parameter request: The URL request to validate
    /// - Throws: PluginSandboxError if request violates policy
    func validateNetworkRequest(_ request: URLRequest) throws {
        guard config.allowNetwork else {
            throw PluginSandboxError.networkNotAllowed
        }

        guard let url = request.url else {
            throw PluginSandboxError.invalidRequest("No URL")
        }

        // Check URL scheme
        guard let scheme = url.scheme?.lowercased(),
              config.allowedURLSchemes.contains(scheme)
        else {
            throw PluginSandboxError.invalidURLScheme(url.scheme ?? "none")
        }

        // Check blocked hosts
        if let host = url.host?.lowercased(),
           config.blockedHosts.contains(host)
        {
            throw PluginSandboxError.blockedHost(host)
        }

        logger.debug("[\(self.pluginId)] Network request validated: \(url.host ?? "unknown")")
    }

    // MARK: - File System Validation

    /// Validates a file path against sandbox policy
    /// - Parameters:
    ///   - path: The file path to validate
    ///   - allowedPaths: Paths the plugin is allowed to access
    /// - Throws: PluginSandboxError if path violates policy
    func validateFilePath(_ path: String, allowedPaths: [String]) throws {
        guard config.allowFileSystem || !allowedPaths.isEmpty else {
            throw PluginSandboxError.fileSystemNotAllowed
        }

        let resolvedPath = (path as NSString).standardizingPath

        // Check if path is within allowed paths
        let isAllowed = allowedPaths.contains { allowedPath in
            resolvedPath.hasPrefix((allowedPath as NSString).standardizingPath)
        }

        guard isAllowed else {
            throw PluginSandboxError.pathNotAllowed(path)
        }

        logger.debug("[\(self.pluginId)] File path validated: \(path)")
    }

    // MARK: - Resource Monitoring

    /// Gets current resource usage statistics
    var resourceUsage: PluginResourceUsage {
        PluginResourceUsage(
            activeOperations: activeOperations.count,
            oldestOperation: activeOperations.values.min(),
            config: config
        )
    }

    /// Checks if the plugin is within resource limits
    func checkResourceLimits() throws {
        // Check for stuck operations
        let now = Date()
        for (operationId, startTime) in activeOperations {
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed > config.maxExecutionTime * 2 {
                logger.warning("[\(self.pluginId)] Operation \(operationId) exceeded 2x timeout limit")
                throw PluginSandboxError.resourceLimitExceeded("Operation timeout exceeded")
            }
        }
    }
}

// MARK: - Resource Usage

/// Current resource usage for a plugin
struct PluginResourceUsage: Sendable {
    let activeOperations: Int
    let oldestOperation: Date?
    let config: PluginSandboxConfig

    var oldestOperationAge: TimeInterval? {
        oldestOperation.map { Date().timeIntervalSince($0) }
    }
}

// MARK: - Sandbox Errors

/// Errors from sandbox policy violations
enum PluginSandboxError: Error, LocalizedError, Sendable {
    case timeout(seconds: TimeInterval)
    case executionFailed(String)
    case networkNotAllowed
    case invalidRequest(String)
    case invalidURLScheme(String)
    case blockedHost(String)
    case fileSystemNotAllowed
    case pathNotAllowed(String)
    case resourceLimitExceeded(String)

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .networkNotAllowed:
            return "Network access is not allowed for this plugin"
        case .invalidRequest(let reason):
            return "Invalid network request: \(reason)"
        case .invalidURLScheme(let scheme):
            return "URL scheme '\(scheme)' is not allowed"
        case .blockedHost(let host):
            return "Host '\(host)' is blocked"
        case .fileSystemNotAllowed:
            return "File system access is not allowed for this plugin"
        case .pathNotAllowed(let path):
            return "Access to path '\(path)' is not allowed"
        case .resourceLimitExceeded(let limit):
            return "Resource limit exceeded: \(limit)"
        }
    }
}

#endif
