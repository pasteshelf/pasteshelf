import Fluent
import Vapor

final class SyncToken: Model, Content, @unchecked Sendable {
    static let schema = "sync_tokens"

    @ID(key: .id) var id: UUID?
    @Parent(key: "device_id") var device: Device
    @Parent(key: "user_id") var user: User
    @Field(key: "token_value") var tokenValue: String
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, deviceID: UUID, userID: UUID, tokenValue: String) {
        self.id = id
        self.$device.id = deviceID
        self.$user.id = userID
        self.tokenValue = tokenValue
    }
}
