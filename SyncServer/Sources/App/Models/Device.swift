import Fluent
import Vapor

final class Device: Model, Content, @unchecked Sendable {
    static let schema = "devices"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "device_id") var deviceID: String
    @OptionalField(key: "device_name") var deviceName: String?
    @OptionalField(key: "os_version") var osVersion: String?
    @OptionalField(key: "app_version") var appVersion: String?
    @Field(key: "last_seen") var lastSeen: Date
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    @Children(for: \.$device) var apiKeys: [APIKey]

    init() {}

    init(id: UUID? = nil, userID: UUID, deviceID: String, deviceName: String? = nil, osVersion: String? = nil, appVersion: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.lastSeen = Date()
    }
}
