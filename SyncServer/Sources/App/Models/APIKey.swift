import Fluent
import Vapor

final class APIKey: Model, Content, @unchecked Sendable {
    // MARK: Lifecycle

    init() {}

    init(id: UUID? = nil, userID: UUID, deviceID: UUID, keyHash: String, keyPrefix: String, expiresAt: Date? = nil) {
        self.id = id
        self.$user.id = userID
        self.$device.id = deviceID
        self.keyHash = keyHash
        self.keyPrefix = keyPrefix
        self.expiresAt = expiresAt
    }

    // MARK: Internal

    static let schema = "api_keys"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Parent(key: "device_id") var device: Device
    @Field(key: "key_hash") var keyHash: String
    @Field(key: "key_prefix") var keyPrefix: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @OptionalField(key: "expires_at") var expiresAt: Date?
    @OptionalField(key: "revoked_at") var revokedAt: Date?

    /// Whether this API key is currently valid.
    var isActive: Bool {
        if self.revokedAt != nil {
            return false
        }
        if let expires = expiresAt, expires < Date() {
            return false
        }
        return true
    }
}
