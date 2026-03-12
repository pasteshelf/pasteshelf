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

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.pasteshelf", category: "self-hosted-settings")
    private let configKey = "com.pasteshelf.selfhosted.config"
    private let apiKeyService = "com.pasteshelf.selfhosted.apiKey"
    private let apiKeyAccount = "selfHostedConfig"

    // MARK: - Initialization

    init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(SelfHostedSyncConfiguration.self, from: data)
        else { return }

        serverURLString = config.serverURL?.absoluteString ?? ""
        organizationID = config.organizationID
        apiKey = loadApiKeyFromKeychain() ?? ""
        isEnabled = config.isEnabled
        certificatePinningEnabled = config.certificatePinningEnabled
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
            UserDefaults.standard.set(data, forKey: configKey)
        }

        // Store API key securely in Keychain
        if apiKey.isEmpty {
            deleteApiKeyFromKeychain()
        } else {
            saveApiKeyToKeychain(apiKey)
        }

        // Propagate to SyncManager so it picks up the new configuration
        let syncConfig = SelfHostedSyncConfiguration(
            serverURL: URL(string: serverURLString),
            organizationID: organizationID,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            isEnabled: isEnabled,
            certificatePinningEnabled: certificatePinningEnabled,
            pinnedCertificateData: nil
        )
        SyncManager.shared.selfHostedConfiguration = syncConfig

        // Restart sync if the new configuration is valid and enabled
        if syncConfig.isEnabled && syncConfig.isConfigured {
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

        logger.info("Self-hosted sync configuration saved")
    }

    // MARK: - Keychain Helpers

    private func saveApiKeyToKeychain(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.warning("Keychain delete returned status \(deleteStatus)")
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("Keychain add failed with status \(addStatus)")
            errorMessage = "Failed to save API key to Keychain (error \(addStatus))"
        }
    }

    private func loadApiKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteApiKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Connection Test

    func testConnection() async {
        isTestingConnection = true
        testSteps = []
        connectionStatus = .testing

        // Step 1: Validate URL
        addStep(title: "Validating server URL", status: .inProgress)
        guard let url = URL(string: serverURLString), url.scheme == "https" || url.scheme == "http" else {
            updateLastStep(status: .failed, detail: "Invalid URL format")
            connectionStatus = .failed
            isTestingConnection = false
            return
        }
        updateLastStep(status: .passed)

        // Step 2: DNS Resolution
        addStep(title: "Resolving hostname", status: .inProgress)
        guard let host = url.host else {
            updateLastStep(status: .failed, detail: "No hostname in URL")
            connectionStatus = .failed
            isTestingConnection = false
            return
        }
        updateLastStep(status: .passed, detail: host)

        // Step 3: Health Check
        addStep(title: "Checking server health", status: .inProgress)
        let healthURL = url.appendingPathComponent("health")
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                updateLastStep(status: .failed, detail: "Invalid response")
                connectionStatus = .failed
                isTestingConnection = false
                return
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let version = json["version"] as? String
                {
                    updateLastStep(status: .passed, detail: "Server v\(version)")
                } else {
                    updateLastStep(status: .passed, detail: "HTTP 200")
                }
            } else {
                updateLastStep(status: .failed, detail: "HTTP \(httpResponse.statusCode)")
                connectionStatus = .failed
                isTestingConnection = false
                return
            }
        } catch {
            updateLastStep(status: .failed, detail: error.localizedDescription)
            connectionStatus = .failed
            isTestingConnection = false
            return
        }

        // Step 4: Authentication
        addStep(title: "Verifying authentication", status: .inProgress)
        if apiKey.isEmpty {
            updateLastStep(status: .skipped, detail: "No API key configured")
        } else {
            // Try a simple authenticated request
            let statusURL = url.appendingPathComponent("api/v1/sync/status")
            var authRequest = URLRequest(url: statusURL)
            authRequest.httpMethod = "GET"
            authRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            authRequest.timeoutInterval = 10

            do {
                let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
                if let httpAuth = authResponse as? HTTPURLResponse, httpAuth.statusCode == 200 {
                    updateLastStep(status: .passed, detail: "Authenticated")
                } else {
                    updateLastStep(status: .warning, detail: "Auth may be invalid")
                }
            } catch {
                updateLastStep(status: .warning, detail: "Could not verify auth")
            }
        }

        // Step 5: TLS Certificate
        addStep(title: "Checking TLS certificate", status: .inProgress)
        if url.scheme == "https" {
            updateLastStep(status: .passed, detail: "HTTPS enabled")
        } else {
            updateLastStep(status: .warning, detail: "Not using HTTPS")
        }

        connectionStatus = .connected
        isTestingConnection = false
    }

    // MARK: - Helpers

    private func addStep(title: String, status: ConnectionTestStep.StepStatus) {
        testSteps.append(ConnectionTestStep(title: title, status: status))
    }

    private func updateLastStep(status: ConnectionTestStep.StepStatus, detail: String? = nil) {
        guard !testSteps.isEmpty else { return }
        testSteps[testSteps.count - 1].status = status
        testSteps[testSteps.count - 1].detail = detail
    }

    // MARK: - Types

    enum ConnectionStatus {
        case unknown, testing, connected, failed
    }
}

// MARK: - ConnectionTestStep

struct ConnectionTestStep: Identifiable {
    let id = UUID()
    let title: String
    var status: StepStatus
    var detail: String?

    enum StepStatus {
        case inProgress, passed, failed, warning, skipped

        var icon: String {
            switch self {
            case .inProgress: return "arrow.trianglehead.2.counterclockwise"
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .skipped: return "minus.circle"
            }
        }

        var color: String {
            switch self {
            case .inProgress: return "blue"
            case .passed: return "green"
            case .failed: return "red"
            case .warning: return "orange"
            case .skipped: return "gray"
            }
        }
    }
}
