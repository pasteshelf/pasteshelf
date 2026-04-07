//
//  WebSocketService.swift
//  SyncServer
//
//  WebSocket service for real-time sync notifications.
//  Notification-only — no data payloads over WebSocket.
//

import Vapor

// MARK: - WebSocketService

/// Manages WebSocket connections for real-time sync notifications.
///
/// Each connected device is tracked by user ID and device ID.
/// When a device pushes changes, all other devices for the same user
/// receive a lightweight `changes_available` notification.
final class WebSocketService: Sendable {
    // MARK: Internal

    // MARK: - Connection Handling

    func handleConnection(req: Request, ws: WebSocket) async {
        // Authenticate via query parameter
        guard let tokenString = req.query[String.self, at: "token"],
              let deviceID = req.query[String.self, at: "deviceId"]
        else {
            try? await ws.close(code: .init(codeNumber: 4001))
            return
        }

        // Verify JWT
        let userID: UUID
        do {
            let payload = try await req.jwt.verify(tokenString, as: JWTPayload.self)
            guard let uid = payload.userID else {
                try? await ws.close(code: .init(codeNumber: 4001))
                return
            }
            userID = uid
        } catch {
            try? await ws.close(code: .init(codeNumber: 4001))
            return
        }

        // Register connection
        let connectionID = UUID()
        let connection = WebSocketConnection(
            id: connectionID,
            userID: userID,
            deviceID: deviceID,
            ws: ws
        )
        await connections.add(connection)

        req.logger.info("WebSocket connected: user=\(userID) device=\(deviceID)")

        // Handle incoming messages (ping/pong)
        ws.onText { [connections] ws, text in
            guard let data = text.data(using: .utf8),
                  let message = try? JSONDecoder().decode(WebSocketMessage.self, from: data)
            else {
                return
            }

            switch message.type {
            case "ping":
                let pong = WebSocketMessage(type: "pong")
                if let encoded = try? JSONEncoder().encode(pong),
                   let jsonString = String(data: encoded, encoding: .utf8)
                {
                    try? await ws.send(jsonString)
                }
            default:
                break
            }
        }

        // Handle disconnect
        ws.onClose.whenComplete { [connections] _ in
            Task {
                await connections.remove(connectionID)
                req.logger.info("WebSocket disconnected: user=\(userID) device=\(deviceID)")
            }
        }
    }

    // MARK: - Notifications

    /// Notify all connected devices of a user (except the sender) that new changes are available.
    func notifyChangesAvailable(userID: UUID, excludeDevice: String, changeCount: Int) async {
        let message = WebSocketMessage(
            type: "changes_available",
            changeCount: changeCount
        )
        await broadcast(to: userID, excluding: excludeDevice, message: message)
    }

    /// Notify all connected devices of a user to force a full sync.
    func notifyForceSync(userID: UUID) async {
        let message = WebSocketMessage(type: "force_sync")
        await broadcast(to: userID, excluding: nil, message: message)
    }

    /// Notify all connected devices that a specific device has been removed.
    func notifyDeviceRemoved(userID: UUID, deviceID: String) async {
        let message = WebSocketMessage(type: "device_removed", deviceID: deviceID)
        await broadcast(to: userID, excluding: nil, message: message)
    }

    // MARK: Private

    private let connections = WebSocketConnectionStore()

    private func broadcast(to userID: UUID, excluding deviceID: String?, message: WebSocketMessage) async {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return
        }

        let userConnections = await connections.connections(for: userID)
        for connection in userConnections {
            if let excludeID = deviceID, connection.deviceID == excludeID {
                continue
            }
            try? await connection.ws.send(jsonString)
        }
    }
}

// MARK: - WebSocketConnectionStore

/// Thread-safe storage for active WebSocket connections.
actor WebSocketConnectionStore {
    // MARK: Internal

    func add(_ connection: WebSocketConnection) {
        self.store[connection.id] = connection
    }

    func remove(_ id: UUID) {
        self.store.removeValue(forKey: id)
    }

    func connections(for userID: UUID) -> [WebSocketConnection] {
        self.store.values.filter { $0.userID == userID }
    }

    // MARK: Private

    private var store: [UUID: WebSocketConnection] = [:]
}

// MARK: - WebSocketConnection

struct WebSocketConnection {
    let id: UUID
    let userID: UUID
    let deviceID: String
    let ws: WebSocket
}

// MARK: - WebSocketMessage

struct WebSocketMessage: Codable {
    let type: String
    var changeCount: Int?
    var deviceID: String?
}

// MARK: - Application Extension

extension Application {
    private struct WebSocketServiceKey: StorageKey {
        typealias Value = WebSocketService
    }

    var webSocketService: WebSocketService? {
        get { storage[WebSocketServiceKey.self] }
        set { storage[WebSocketServiceKey.self] = newValue }
    }
}
