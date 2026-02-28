//
//  DeviceController.swift
//  SyncServer
//
//  Device registration and management endpoints.
//

import Fluent
import Vapor

struct DeviceController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let devices = routes.grouped("api", "v1", "devices")
        devices.post("register", use: register)
        devices.get(use: list)
        devices.delete(":deviceId", use: remove)
    }

    // MARK: - Register Device

    @Sendable
    func register(req: Request) async throws -> DeviceResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        let body = try req.content.decode(DeviceRegisterRequest.self)

        // Upsert: update if exists, create if not
        if let existing = try await Device.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .filter(\.$deviceID == body.deviceID)
            .first()
        {
            existing.lastSeen = Date()
            existing.deviceName = body.deviceName ?? existing.deviceName
            existing.osVersion = body.osVersion ?? existing.osVersion
            existing.appVersion = body.appVersion ?? existing.appVersion
            try await existing.save(on: req.db)
            return existing.toResponse()
        }

        let device = Device(
            userID: authUser.id,
            deviceID: body.deviceID,
            deviceName: body.deviceName,
            osVersion: body.osVersion,
            appVersion: body.appVersion
        )
        try await device.save(on: req.db)
        return device.toResponse()
    }

    // MARK: - List Devices

    @Sendable
    func list(req: Request) async throws -> DeviceListResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        let devices = try await Device.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .sort(\.$lastSeen, .descending)
            .all()
        return DeviceListResponse(devices: devices.map { $0.toResponse() })
    }

    // MARK: - Remove Device

    @Sendable
    func remove(req: Request) async throws -> HTTPStatus {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        guard let deviceIDParam = req.parameters.get("deviceId") else {
            throw Abort(.badRequest, reason: "Missing device ID")
        }

        guard let device = try await Device.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .filter(\.$deviceID == deviceIDParam)
            .first()
        else {
            throw Abort(.notFound, reason: "Device not found")
        }

        // Notify the device it has been removed via WebSocket
        if let ws = req.application.webSocketService {
            await ws.notifyDeviceRemoved(userID: authUser.id, deviceID: deviceIDParam)
        }

        try await device.delete(on: req.db)
        return .noContent
    }
}

// MARK: - Response Mapping

extension Device {
    func toResponse() -> DeviceResponse {
        DeviceResponse(
            id: id ?? UUID(),
            deviceID: deviceID,
            deviceName: deviceName,
            osVersion: osVersion,
            appVersion: appVersion,
            lastSeen: lastSeen,
            createdAt: createdAt
        )
    }
}
