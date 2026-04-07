//
//  SelfHostedSyncSettingsViewModel.swift
//  PasteShelf
//
//  ViewModel for self-hosted sync server configuration.
//

import Combine
import Foundation
import os.log
import Security

// MARK: - SelfHostedSyncSettingsViewModel

@MainActor
final class SelfHostedSyncSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        self.loadConfiguration()
    }

    // MARK: Internal

    // MARK: - Types

    enum ConnectionStatus {
        case unknown
        case testing
        case connected
        case failed
    }

    // MARK: - Published Properties

    @Published var serverURLString: String = ""
    @Published var organizationID: String = ""
    @Published var apiKey: String = ""
    @Published var isEnabled: Bool = false
    @Published var certificatePinningEnabled: Bool = false

    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var isTestingConnection: Bool = false
    @Published var testSteps: [ConnectionTestStep] = []
    @Published var errorMessage: String?

    // MARK: - Configuration

    func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(SelfHostedSyncConfiguration.self, from: data)
        else {
            return
        }

        self.serverURLString = config.serverURL?.absoluteString ?? ""
        self.organizationID = config.organizationID
        self.apiKey = self.loadApiKeyFromKeychain() ?? ""
        self.isEnabled = config.isEnabled
        self.certificatePinningEnabled = config.certificatePinningEnabled
    }

    func saveConfiguration() {
        // Store config without API key in UserDefaults
        let config = SelfHostedSyncConfiguration(
            serverURL: URL(string: serverURLString),
            organizationID: organizationID,
            apiKey: nil,
            isEnabled: isEnabled,
            certificatePinningEnabled: certificatePinningEnabled,
            pinnedCertificateData: nil
        )

        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: self.configKey)
        }

        // Store API key securely in Keychain
        if self.apiKey.isEmpty {
            self.deleteApiKeyFromKeychain()
        } else {
            self.saveApiKeyToKeychain(self.apiKey)
        }

        // Propagate to SyncManager so it picks up the new configuration
        let syncConfig = SelfHostedSyncConfiguration(
            serverURL: URL(string: serverURLString),
            organizationID: organizationID,
            apiKey: apiKey.isEmpty ? nil : self.apiKey,
            isEnabled: self.isEnabled,
            certificatePinningEnabled: self.certificatePinningEnabled,
            pinnedCertificateData: nil
        )
        SyncManager.shared.selfHostedConfiguration = syncConfig

        // Restart sync if the new configuration is valid and enabled
        if syncConfig.isEnabled, syncConfig.isConfigured {
            Task { [weak self] in
                do {
                    try await SyncManager.shared.stop()
                    try await SyncManager.shared.start()
                } catch {
                    self?.errorMessage = "Sync failed to restart: \(error.localizedDescription)"
                    self?.logger.error("Sync restart failed: \(error.localizedDescription)")
                }
            }
        }

        self.logger.info("Self-hosted sync configuration saved")
    }

    // MARK: - Connection Test

    func testConnection() async {
        self.isTestingConnection = true
        self.testSteps = []
        self.connectionStatus = .testing

        guard let url = testValidateURL() else {
            return
        }
        guard self.testResolveHostname(url) else {
            return
        }
        guard await self.testHealthCheck(url) else {
            return
        }
        await self.testAuthentication(url)
        self.testTLSCertificate(url)

        self.connectionStatus = .connected
        self.isTestingConnection = false
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "self-hosted-settings")
    private let configKey = "com.pasteshelf.selfhosted.config"
    private let apiKeyService = "com.pasteshelf.selfhosted.apiKey"
    private let apiKeyAccount = "selfHostedConfig"

    /// Step 1: Validate the server URL format.
    private func testValidateURL() -> URL? {
        self.addStep(title: "Validating server URL", status: .inProgress)
        guard let url = URL(string: serverURLString),
              url.scheme == "https" || url.scheme == "http"
        else {
            self.updateLastStep(status: .failed, detail: "Invalid URL format")
            self.connectionStatus = .failed
            self.isTestingConnection = false
            return nil
        }
        self.updateLastStep(status: .passed)
        return url
    }

    /// Step 2: Verify the URL contains a resolvable hostname.
    private func testResolveHostname(_ url: URL) -> Bool {
        self.addStep(title: "Resolving hostname", status: .inProgress)
        guard let host = url.host else {
            self.updateLastStep(status: .failed, detail: "No hostname in URL")
            self.connectionStatus = .failed
            self.isTestingConnection = false
            return false
        }
        self.updateLastStep(status: .passed, detail: host)
        return true
    }

    /// Step 3: Hit the server's health endpoint.
    private func testHealthCheck(_ url: URL) async -> Bool {
        self.addStep(title: "Checking server health", status: .inProgress)
        let healthURL = url.appendingPathComponent("health")
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                self.updateLastStep(status: .failed, detail: "Invalid response")
                self.connectionStatus = .failed
                self.isTestingConnection = false
                return false
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let version = json["version"] as? String
                {
                    self.updateLastStep(status: .passed, detail: "Server v\(version)")
                } else {
                    self.updateLastStep(status: .passed, detail: "HTTP 200")
                }
            } else {
                self.updateLastStep(status: .failed, detail: "HTTP \(httpResponse.statusCode)")
                self.connectionStatus = .failed
                self.isTestingConnection = false
                return false
            }
        } catch {
            self.updateLastStep(status: .failed, detail: error.localizedDescription)
            self.connectionStatus = .failed
            self.isTestingConnection = false
            return false
        }
        return true
    }

    /// Step 4: Verify API key authentication if configured.
    private func testAuthentication(_ url: URL) async {
        self.addStep(title: "Verifying authentication", status: .inProgress)
        if self.apiKey.isEmpty {
            self.updateLastStep(status: .skipped, detail: "No API key configured")
        } else {
            let statusURL = url.appendingPathComponent("api/v1/sync/status")
            var authRequest = URLRequest(url: statusURL)
            authRequest.httpMethod = "GET"
            authRequest.setValue(self.apiKey, forHTTPHeaderField: "X-API-Key")
            authRequest.timeoutInterval = 10

            do {
                let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
                if let httpAuth = authResponse as? HTTPURLResponse, httpAuth.statusCode == 200 {
                    self.updateLastStep(status: .passed, detail: "Authenticated")
                } else {
                    self.updateLastStep(status: .warning, detail: "Auth may be invalid")
                }
            } catch {
                self.updateLastStep(status: .warning, detail: "Could not verify auth")
            }
        }
    }

    /// Step 5: Check whether the connection uses TLS.
    private func testTLSCertificate(_ url: URL) {
        self.addStep(title: "Checking TLS certificate", status: .inProgress)
        if url.scheme == "https" {
            self.updateLastStep(status: .passed, detail: "HTTPS enabled")
        } else {
            self.updateLastStep(status: .warning, detail: "Not using HTTPS")
        }
    }

    // MARK: - Keychain Helpers

    private func saveApiKeyToKeychain(_ key: String) {
        guard let data = key.data(using: .utf8) else {
            return
        }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.apiKeyService,
            kSecAttrAccount as String: self.apiKeyAccount,
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            self.logger.warning("Keychain delete returned status \(deleteStatus)")
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.apiKeyService,
            kSecAttrAccount as String: self.apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            self.logger.error("Keychain add failed with status \(addStatus)")
            self.errorMessage = "Failed to save API key to Keychain (error \(addStatus))"
        }
    }

    private func loadApiKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.apiKeyService,
            kSecAttrAccount as String: self.apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteApiKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.apiKeyService,
            kSecAttrAccount as String: self.apiKeyAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Helpers

    private func addStep(title: String, status: ConnectionTestStep.StepStatus) {
        self.testSteps.append(ConnectionTestStep(title: title, status: status))
    }

    private func updateLastStep(status: ConnectionTestStep.StepStatus, detail: String? = nil) {
        guard !self.testSteps.isEmpty else {
            return
        }
        self.testSteps[self.testSteps.count - 1].status = status
        self.testSteps[self.testSteps.count - 1].detail = detail
    }
}

// MARK: - ConnectionTestStep

struct ConnectionTestStep: Identifiable {
    enum StepStatus {
        case inProgress
        case passed
        case failed
        case warning
        case skipped

        // MARK: Internal

        var icon: String {
            switch self {
            case .inProgress: "arrow.trianglehead.2.counterclockwise"
            case .passed: "checkmark.circle.fill"
            case .failed: "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .skipped: "minus.circle"
            }
        }

        var color: String {
            switch self {
            case .inProgress: "blue"
            case .passed: "green"
            case .failed: "red"
            case .warning: "orange"
            case .skipped: "gray"
            }
        }
    }

    let id = UUID()
    let title: String
    var status: StepStatus
    var detail: String?
}
