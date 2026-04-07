//
//  SelfHostedWebSocketClient.swift
//  PasteShelf
//
//  WebSocket client for real-time sync notifications from self-hosted server.
//  Notification-only — no data payloads over WebSocket.
//

import Foundation
import os.log

// MARK: - SelfHostedWebSocketClient

/// WebSocket client for receiving real-time sync notifications.
///
/// Connects to the self-hosted server's WebSocket endpoint and
/// receives lightweight notification signals. Does NOT transfer
/// clipboard data — only signals like `changes_available`.
final class SelfHostedWebSocketClient: @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(configuration: SelfHostedSyncConfiguration) {
        self.configuration = configuration
    }

    // MARK: Internal

    /// Handler called when a sync notification is received.
    var onNotification: ((WebSocketNotification) -> Void)?

    /// Handler called when the connection state changes.
    var onConnectionStateChanged: ((Bool) -> Void)?

    // MARK: - Connection

    /// Connect to the WebSocket endpoint.
    func connect(token: String, deviceID: String) {
        guard let serverURL = configuration.serverURL else {
            self.logger.error("No server URL configured for WebSocket")
            return
        }

        var components = URLComponents(
            url: serverURL.appendingPathComponent("/api/v1/ws"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "deviceId", value: deviceID),
        ]

        // Convert http(s) to ws(s)
        if components?.scheme == "https" {
            components?.scheme = "wss"
        } else if components?.scheme == "http" {
            components?.scheme = "ws"
        }

        guard let wsURL = components?.url else {
            self.logger.error("Failed to construct WebSocket URL")
            return
        }

        let session = URLSession(configuration: .default)
        self.webSocketTask = session.webSocketTask(with: wsURL)
        self.webSocketTask?.resume()

        self.isConnected = true
        self.reconnectAttempt = 0
        self.onConnectionStateChanged?(true)
        self.logger.info("WebSocket connecting to \(wsURL.host ?? "unknown")")

        self.startReceiving()
        self.startPingTimer()
    }

    /// Disconnect from the WebSocket.
    func disconnect() {
        self.stopPingTimer()
        self.webSocketTask?.cancel(with: .normalClosure, reason: nil)
        self.webSocketTask = nil
        self.isConnected = false
        self.onConnectionStateChanged?(false)
        self.logger.info("WebSocket disconnected")
    }

    // MARK: Private

    private let configuration: SelfHostedSyncConfiguration
    private let logger = Logger(subsystem: "com.pasteshelf", category: "self-hosted-ws")

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectAttempt = 0
    private var isConnected = false

    // MARK: - Receiving

    private func startReceiving() {
        self.webSocketTask?.receive { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(message):
                self.handleMessage(message)
                self.startReceiving() // Continue listening

            case let .failure(error):
                self.logger.error("WebSocket receive error: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case let .string(text):
            guard let data = text.data(using: .utf8),
                  let notification = try? JSONDecoder().decode(WebSocketNotification.self, from: data)
            else {
                self.logger.warning("Failed to decode WebSocket message: \(text)")
                return
            }
            self.logger.debug("WebSocket notification: \(notification.type)")
            self.onNotification?(notification)

        case let .data(data):
            guard let notification = try? JSONDecoder().decode(WebSocketNotification.self, from: data) else {
                return
            }
            self.onNotification?(notification)

        @unknown default:
            break
        }
    }

    // MARK: - Ping/Pong

    private func startPingTimer() {
        self.stopPingTimer()
        self.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopPingTimer() {
        self.pingTimer?.invalidate()
        self.pingTimer = nil
    }

    private func sendPing() {
        let ping = WebSocketNotification(type: "ping")
        guard let data = try? JSONEncoder().encode(ping),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return
        }

        self.webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.logger.error("WebSocket ping failed: \(error.localizedDescription)")
                self?.handleDisconnect()
            }
        }
    }

    // MARK: - Reconnection

    private func handleDisconnect() {
        self.isConnected = false
        self.onConnectionStateChanged?(false)
        self.stopPingTimer()

        // Exponential backoff
        let delays: [TimeInterval] = [1, 2, 4, 8, 16, 60]
        let delay = delays[min(reconnectAttempt, delays.count - 1)]
        self.reconnectAttempt += 1

        self.logger.info("WebSocket reconnecting in \(delay)s (attempt \(self.reconnectAttempt))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            // Reconnection requires a new token — the caller must handle this
            self?.onConnectionStateChanged?(false)
        }
    }
}

// MARK: - WebSocketNotification

struct WebSocketNotification: Codable {
    let type: String
    var changeCount: Int?
    var deviceID: String?
}
