//
//  ActionExecutor.swift
//  PasteShelf
//
//  Executes automation actions on clipboard content.
//  Handles transformations, tagging, notifications, and external integrations.
//

import AppKit
import CryptoKit
import Foundation
import os.log
import UserNotifications

/// Executes automation actions on clipboard content
@MainActor
final class ActionExecutor {
    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "automation.actions"
    )

    private let storageManager = StorageManager.shared

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
        logger.debug("Executing action: \(action.displayName)")

        switch action {
        case .transform(_, let preset):
            return try await executeTransform(preset: preset, content: content)

        case .addTag(_, let tagName):
            return try await executeAddTag(tagName: tagName, content: content)

        case .removeTag(_, let tagName):
            return try await executeRemoveTag(tagName: tagName, content: content)

        case .setFavorite(_, let isFavorite):
            return try await executeSetFavorite(isFavorite: isFavorite, content: content)

        case .moveToFolder(_, let folderName):
            return try await executeMoveToFolder(folderName: folderName, content: content)

        case .copyToClipboard:
            return try executeCopyToClipboard(content: content)

        case .notify(_, let title, let message):
            return try await executeNotify(title: title, message: message, content: content, rule: rule)

        case .openURL(_, let urlTemplate):
            return try executeOpenURL(urlTemplate: urlTemplate, content: content)

        case .runScript(_, let scriptPath):
            return try await executeRunScript(scriptPath: scriptPath, content: content)

        case .webhook(_, let endpointId):
            return try await executeWebhook(endpointId: endpointId, content: content, rule: rule)

        case .markSensitive(_, let isSensitive):
            return executeMarkSensitive(isSensitive: isSensitive, content: content)

        case .delete:
            return executeDelete(content: content)
        }
    }

    // MARK: - Transform Action

    private func executeTransform(
        preset: TransformPreset,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        var modifiedContent = content

        // Only transform text content
        guard let text = content.plainText else {
            logger.warning("Transform action skipped: no text content")
            return ActionExecutionResult(content: content)
        }

        let transformed = preset.transform(text)
        modifiedContent.plainText = transformed

        logger.debug("Transformed text using \(preset.displayName)")
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
            tag = await storageManager.saveTag(name: tagName, color: "#007AFF")
        }

        guard let resolvedTag = tag else {
            logger.warning("Failed to find or create tag: \(tagName)")
            return ActionExecutionResult(content: content)
        }

        if let item = await storageManager.fetchItem(byId: content.id) {
            let success = await storageManager.addTags([resolvedTag], to: item)
            if success {
                logger.debug("Added tag '\(tagName)' to item \(content.id)")
            }
        }

        return ActionExecutionResult(content: content)
    }

    private func executeRemoveTag(
        tagName: String,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        logger.debug("Tag to remove: \(tagName) (applied after save)")
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
                logger.debug("Set favorite=\(isFavorite) for item \(content.id)")
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
            logger.warning("Folder not found: \(folderName)")
            return ActionExecutionResult(content: content)
        }

        if let item = await storageManager.fetchItem(byId: content.id) {
            let success = await storageManager.moveItem(item, to: targetFolder)
            if success {
                logger.debug("Moved item \(content.id) to folder '\(folderName)'")
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
            logger.debug("Copied text to clipboard")
        } else if let imageData = content.imageData,
                  let image = NSImage(data: imageData)
        {
            pasteboard.writeObjects([image])
            logger.debug("Copied image to clipboard")
        } else if let url = content.url {
            pasteboard.setString(url.absoluteString, forType: .string)
            logger.debug("Copied URL to clipboard")
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
        let expandedTitle = expandTemplate(title, content: content, rule: rule)
        let expandedMessage = expandTemplate(message, content: content, rule: rule)

        // Request notification permission if needed
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Failed to request notification permission: \(error.localizedDescription)")
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
            logger.debug("Notification posted: \(expandedTitle)")
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
        let expandedURL = expandTemplate(urlTemplate, content: content, rule: nil)

        guard let url = URL(string: expandedURL) else {
            throw AutomationError.actionExecutionFailed(
                actionType: "openURL",
                reason: "Invalid URL: \(expandedURL)"
            )
        }

        NSWorkspace.shared.open(url)
        logger.debug("Opened URL: \(url.absoluteString)")

        return ActionExecutionResult(content: content)
    }

    // MARK: - Run Script Action

    /// Script execution timeout in seconds
    private static let scriptTimeout: UInt64 = 30_000_000_000 // 30s in nanoseconds

    private func executeRunScript(
        scriptPath: String,
        content: ClipboardContent
    ) async throws -> ActionExecutionResult {
        let expandedPath = expandTemplate(scriptPath, content: content, rule: nil)
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

        logger.debug("Executed script: \(expandedPath)")
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
        try await sendWebhook(endpoint: endpoint, payload: payload)

        logger.debug("Webhook sent to: \(endpoint.url)")
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
              (200...299).contains(httpResponse.statusCode)
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
        logger.debug("Marked content as sensitive: \(isSensitive)")
        return ActionExecutionResult(content: modifiedContent)
    }

    // MARK: - Delete Action

    private func executeDelete(
        content: ClipboardContent
    ) -> ActionExecutionResult {
        logger.debug("Delete action: item will not be stored")
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
        if let rule = rule {
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

// MARK: - Webhook Types

/// Configuration for a webhook endpoint
struct WebhookEndpointConfig {
    let id: UUID
    let url: String
    let secretKey: String?
    let headers: [String: String]
    let isEnabled: Bool
}

/// Payload sent to webhook endpoints for automation events
struct AutomationWebhookPayload: Codable {
    let event: String
    let timestamp: Date
    let ruleId: UUID
    let ruleName: String
    let data: PayloadData

    struct PayloadData: Codable {
        let contentType: String
        let preview: String?
        let sourceApp: String?
        let characterCount: Int?
        let isSensitive: Bool
    }

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
