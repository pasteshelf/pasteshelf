import Vapor

struct DeviceRegisterRequest: Content {
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
}

struct DeviceResponse: Content {
    let id: UUID
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let lastSeen: Date
    let createdAt: Date?
}

struct DeviceListResponse: Content {
    let devices: [DeviceResponse]
}
