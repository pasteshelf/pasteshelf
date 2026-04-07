import Fluent
import Vapor

final class SyncToken: Model, Content, @unchecked Sendable {
    // MARK: Lifecycle

    init() {}

    init(id: UUID? = nil, deviceID: UUID, userID: UUID, tokenValue: String) {
        self.id = id
        $device.id = deviceID
        $user.id = userID
        self.tokenValue = tokenValue
    }

    // MARK: Internal

    static let schema = "sync_tokens"

    @ID(key: .id) var id: UUID?
    @Parent(key: "device_id") var device: Device
    @Parent(key: "user_id") var user: User
    @Field(key: "token_value") var tokenValue: String
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
}
