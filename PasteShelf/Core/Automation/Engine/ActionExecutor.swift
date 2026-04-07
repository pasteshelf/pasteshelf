// swiftlint:disable file_length
//
//  ActionExecutor.swift
//  PasteShelf
//
//  Executes automation actions on clipboard content.
//  Handles transformations, tagging, notifications, and external integrations.
//

// swiftformat:disable organizeDeclarations

import AppKit
import CryptoKit
import Foundation
import os.log
import UserNotifications

// MARK: - ActionExecutor

/// Executes automation actions on clipboard content
@MainActor
final class ActionExecutor { // swiftlint:disable:this type_body_length
    // MARK: Internal

    // MARK: - Action Execution

    /// Executes an automation action on the given content
    /// - Parameters:
    ///   - action: The action to execute
    ///   - content: The content to act upon
    ///   - rule: The rule that triggered this action (for context)
    /// - Returns: ActionExecutionResult with modified content and flags
    func execute(
        action: AutomationAction,
        content: ClipboardContent,
        rule: AutomationRule
    ) async throws -> ActionExecutionResult {
        self.logger.debug("Executing action: \(action.displayName)")

        switch action {
        case let .transform(_, preset):
            return try await self.executeTransform(preset: preset, content: content)

        case let .addTag(_, tagName):
            return try await self.executeAddTag(tagName: tagName, content: content)

        case let .removeTag(_, tagName):
            return try await self.executeRemoveTag(tagName: tagName, content: content)

        case let .setFavorite(_, isFavorite):
            return try await self.executeSetFavorite(isFavorite: isFavorite, content: content)

        case let .moveToFolder(_, folderName):
            return try await self.executeMoveToFolder(folderName: folderName, content: content)

        case .copyToClipboard:
            return try self.executeCopyToClipboard(content: content)

        case let .notify(_, title, message):
            return try await self.executeNotify(title: title, message: message, content: content, rule: rule)

        case let .openURL(_, urlTemplate):
            return try self.executeOpenURL(urlTemplate: urlTemplate, content: content)

        #if !APP_STORE
            case let .runScript(_, scriptPath):
                return try await self.executeRunScript(scriptPath: scriptPath, content: content)
        #endif

        case let .webhook(_, endpointId):
            return try await self.executeWebhook(endpointId: endpointId, content: content, rule: rule)

        case let .markSensitive(_, isSensitive):
            return self.executeMarkSensitive(isSensitive: isSensitive, content: content)

        case .delete:
            return self.executeDelete(content: content)
        }
    }

    // MARK: Private

    #if !APP_STORE

        // MARK: - Run Script Action

        /// Script execution timeout in seconds
        private static let scriptTimeout: UInt64 = 30_000_000_000 // 30s in nanoseconds

        private func executeRunScript(
            scriptPath: String,
            content: ClipboardContent
        ) async throws -> ActionExecutionResult {
            let expandedPath = self.expandTemplate(scriptPath, content: content, rule: nil)
            let scriptURL = URL(fileURLWithPath: expandedPath)

            guard FileManager.default.fileExists(atPath: expandedPath) else {
                throw AutomationError.scriptExecutionFailed(
                    path: expandedPath,
                    reason: "Script file not found"
                )
            }

            // Execute AppleScript on a background thread with timeout to avoid
            // blocking the main thread (NSAppleScript.executeAndReturnError is synchronous)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @Sendable in
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        DispatchQueue.global(qos: .userInitiated).async {
                            var errorInfo: NSDictionary?
                            guard let script = NSAppleScript(contentsOf: scriptURL, error: &errorInfo) else {
                                let errorMessage = errorInfo?.description ?? "Unknown error"
                                continuation.resume(throwing: AutomationError.scriptExecutionFailed(
                                    path: expandedPath, reason: errorMessage
                                ))
                                return
                            }

                            var executeError: NSDictionary?
                            script.executeAndReturnError(&executeError)

                            if let error = executeError {
                                continuation.resume(throwing: AutomationError.scriptExecutionFailed(
                                    path: expandedPath, reason: error.description
                                ))
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }

                group.addTask { @Sendable in
                    try await Task.sleep(nanoseconds: Self.scriptTimeout)
                    throw AutomationError.scriptExecutionFailed(
                        path: expandedPath,
                        reason: "Script execution timed out after 30 seconds"
                    )
                }

                // Wait for the first task to complete (either script finishes or timeout fires)
                _ = try await group.next()
                group.cancelAll()
            }

            self.logger.debug("Executed script: \(expandedPath)")
            return ActionExecutionResult(content: content)
        }
    #endif

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "automation.actions"
    )

    private let storageManager = StorageManager.shared

    // MARK: - Transform Action

    private func executeTransform(
        preset: TransformPreset,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        var modifiedContent = content

        // Only transform text content
        guard let text = content.plainText else {
            self.logger.warning("Transform action skipped: no text content")
            return ActionExecutionResult(content: content)
        }

        let transformed = preset.transform(text)
        modifiedContent.plainText = transformed

        self.logger.debug("Transformed text using \(preset.displayName)")
        return ActionExecutionResult(content: modifiedContent)
    }

    // MARK: - Tag Actions

    private func executeAddTag(
        tagName: String,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        // Find or create the tag, then add it to the item
        var tag = await storageManager.fetchTag(byName: tagName)
        if tag == nil {
            tag = await self.storageManager.saveTag(name: tagName, color: "#007AFF")
        }

        guard let resolvedTag = tag else {
            self.logger.warning("Failed to find or create tag: \(tagName)")
            return ActionExecutionResult(content: content)
        }

        if let item = await storageManager.fetchItem(byId: content.id) {
            let success = await storageManager.addTags([resolvedTag], to: item)
            if success {
                self.logger.debug("Added tag '\(tagName)' to item \(content.id)")
            }
        }

        return ActionExecutionResult(content: content)
    }

    private func executeRemoveTag(
        tagName: String,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        self.logger.debug("Tag to remove: \(tagName) (applied after save)")
        return ActionExecutionResult(content: content)
    }

    // MARK: - Favorite Action

    private func executeSetFavorite(
        isFavorite: Bool,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        if let item = await storageManager.fetchItem(byId: content.id) {
            let success = await storageManager.setFavorite(item: item, isFavorite: isFavorite)
            if success {
                self.logger.debug("Set favorite=\(isFavorite) for item \(content.id)")
            }
        }
        return ActionExecutionResult(content: content)
    }

    // MARK: - Move to Folder Action

    private func executeMoveToFolder(
        folderName: String,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        // Find the folder by iterating through existing folders
        let folders = await storageManager.fetchFolders()
        let folder = folders.first { $0.name == folderName }

        guard let targetFolder = folder else {
            self.logger.warning("Folder not found: \(folderName)")
            return ActionExecutionResult(content: content)
        }

        if let item = await storageManager.fetchItem(byId: content.id) {
            let success = await storageManager.moveItem(item, to: targetFolder)
            if success {
                self.logger.debug("Moved item \(content.id) to folder '\(folderName)'")
            }
        }

        return ActionExecutionResult(content: content)
    }

    // MARK: - Copy to Clipboard Action

    private func executeCopyToClipboard(
        content: ClipboardContent
    ) throws -> ActionExecutionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Copy based on content type
        if let text = content.plainText {
            pasteboard.setString(text, forType: .string)
            self.logger.debug("Copied text to clipboard")
        } else if let imageData = content.imageData,
                  let image = NSImage(data: imageData)
        {
            pasteboard.writeObjects([image])
            self.logger.debug("Copied image to clipboard")
        } else if let url = content.url {
            pasteboard.setString(url.absoluteString, forType: .string)
            self.logger.debug("Copied URL to clipboard")
        }

        return ActionExecutionResult(content: content)
    }

    // MARK: - Notify Action

    private func executeNotify(
        title: String,
        message: String,
        content: ClipboardContent,
        rule: AutomationRule
    ) async throws -> ActionExecutionResult {
        // Expand template variables
        let expandedTitle = self.expandTemplate(title, content: content, rule: rule)
        let expandedMessage = self.expandTemplate(message, content: content, rule: rule)

        // Request notification permission if needed
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                self.logger.error("Failed to request notification permission: \(error.localizedDescription)")
            }
        }

        // Create and post notification
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = expandedTitle
        notificationContent.body = expandedMessage
        notificationContent.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            self.logger.debug("Notification posted: \(expandedTitle)")
        } catch {
            throw AutomationError.actionExecutionFailed(
                actionType: "notify",
                reason: error.localizedDescription
            )
        }

        return ActionExecutionResult(content: content)
    }

    // MARK: - Open URL Action

    private func executeOpenURL(
        urlTemplate: String,
        content: ClipboardContent
    ) throws -> ActionExecutionResult {
        // Expand template variables in URL
        let expandedURL = self.expandTemplate(urlTemplate, content: content, rule: nil)

        guard let url = URL(string: expandedURL) else {
            throw AutomationError.actionExecutionFailed(
                actionType: "openURL",
                reason: "Invalid URL: \(expandedURL)"
            )
        }

        NSWorkspace.shared.open(url)
        self.logger.debug("Opened URL: \(url.absoluteString)")

        return ActionExecutionResult(content: content)
    }

    // MARK: - Webhook Action

    private func executeWebhook(
        endpointId: UUID,
        content: ClipboardContent,
        rule: AutomationRule
    ) async throws -> ActionExecutionResult {
        // Fetch webhook endpoint configuration
        guard let endpoint = await fetchWebhookEndpoint(id: endpointId) else {
            throw AutomationError.invalidConfiguration(
                reason: "Webhook endpoint not found: \(endpointId)"
            )
        }

        // Build payload
        let payload = AutomationWebhookPayload(
            event: "clipboard.automation",
            ruleId: rule.id,
            ruleName: rule.name,
            content: content
        )

        // Send webhook
        try await self.sendWebhook(endpoint: endpoint, payload: payload)

        self.logger.debug("Webhook sent to: \(endpoint.url)")
        return ActionExecutionResult(content: content)
    }

    private func fetchWebhookEndpoint(id: UUID) async -> WebhookEndpointConfig? {
        let context = PersistenceController.shared.container.viewContext
        return await context.perform {
            let request = WebhookEndpoint.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@ AND isEnabled == YES", id as CVarArg)
            request.fetchLimit = 1

            guard let endpoint = try? context.fetch(request).first,
                  let url = endpoint.url
            else {
                return nil
            }

            return WebhookEndpointConfig(
                id: endpoint.id ?? id,
                url: url,
                secretKey: endpoint.secretKey,
                headers: endpoint.customHeaders,
                isEnabled: endpoint.isEnabled
            )
        }
    }

    private func sendWebhook(
        endpoint: WebhookEndpointConfig,
        payload: AutomationWebhookPayload
    ) async throws {
        guard let url = URL(string: endpoint.url) else {
            throw AutomationError.webhookFailed(url: endpoint.url, statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Sign with secret if provided
        if let secret = endpoint.secretKey {
            let signature = payload.sign(with: secret)
            request.setValue("sha256=\(signature)", forHTTPHeaderField: "X-Signature-256")
        }

        // Encode payload
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        // Send request
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            throw AutomationError.webhookFailed(url: endpoint.url, statusCode: statusCode)
        }
    }

    // MARK: - Mark Sensitive Action

    private func executeMarkSensitive(
        isSensitive: Bool,
        content: ClipboardContent
    ) -> ActionExecutionResult {
        var modifiedContent = content
        modifiedContent.isSensitive = isSensitive
        self.logger.debug("Marked content as sensitive: \(isSensitive)")
        return ActionExecutionResult(content: modifiedContent)
    }

    // MARK: - Delete Action

    private func executeDelete(
        content: ClipboardContent
    ) -> ActionExecutionResult {
        self.logger.debug("Delete action: item will not be stored")
        return ActionExecutionResult(content: content, shouldDelete: true)
    }

    // MARK: - Template Expansion

    /// Expands template variables in a string
    /// Supported variables: {{preview}}, {{contentType}}, {{sourceApp}}, {{timestamp}}, {{ruleName}}
    private func expandTemplate(
        _ template: String,
        content: ClipboardContent,
        rule: AutomationRule?
    ) -> String {
        var result = template

        // Content variables
        result = result.replacingOccurrences(
            of: "{{preview}}",
            with: content.previewText ?? ""
        )
        result = result.replacingOccurrences(
            of: "{{contentType}}",
            with: content.primaryType.rawValue
        )
        result = result.replacingOccurrences(
            of: "{{sourceApp}}",
            with: content.sourceApp?.name ?? "Unknown"
        )
        result = result.replacingOccurrences(
            of: "{{timestamp}}",
            with: ISO8601DateFormatter().string(from: content.timestamp)
        )

        // Rule variables
        if let rule {
            result = result.replacingOccurrences(
                of: "{{ruleName}}",
                with: rule.name
            )
        }

        // URL encode if needed
        result = result.replacingOccurrences(
            of: "{{preview.urlencoded}}",
            with: content.previewText?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        )

        return result
    }
}

// MARK: - WebhookEndpointConfig

/// Configuration for a webhook endpoint
struct WebhookEndpointConfig {
    let id: UUID
    let url: String
    let secretKey: String?
    let headers: [String: String]
    let isEnabled: Bool
}

// MARK: - AutomationWebhookPayload

/// Payload sent to webhook endpoints for automation events
struct AutomationWebhookPayload: Codable {
    // MARK: Lifecycle

    init(event: String, ruleId: UUID, ruleName: String, content: ClipboardContent) {
        self.event = event
        self.timestamp = Date()
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.data = PayloadData(
            contentType: content.primaryType.rawValue,
            preview: content.previewText,
            sourceApp: content.sourceApp?.name,
            characterCount: content.characterCount,
            isSensitive: content.isSensitive
        )
    }

    // MARK: Internal

    struct PayloadData: Codable {
        let contentType: String
        let preview: String?
        let sourceApp: String?
        let characterCount: Int?
        let isSensitive: Bool
    }

    let event: String
    let timestamp: Date
    let ruleId: UUID
    let ruleName: String
    let data: PayloadData

    /// Signs the payload with a secret key using HMAC-SHA256
    func sign(with secret: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(self),
              let secretData = secret.data(using: .utf8)
        else {
            return ""
        }

        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }
}
