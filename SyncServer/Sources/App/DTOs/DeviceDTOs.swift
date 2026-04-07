import Vapor

// MARK: - DeviceRegisterRequest

struct DeviceRegisterRequest: Content {
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
}

// MARK: - DeviceResponse

struct DeviceResponse: Content {
    let id: UUID
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let lastSeen: Date
    let createdAt: Date?
}

// MARK: - DeviceListResponse

struct DeviceListResponse: Content {
    let devices: [DeviceResponse]
}
