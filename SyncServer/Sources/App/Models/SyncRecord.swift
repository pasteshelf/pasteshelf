import Fluent
import Vapor

final class SyncRecord: Model, Content, @unchecked Sendable {
    // MARK: Lifecycle

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        entityID: UUID,
        entityType: String,
        encryptedData: Data? = nil,
        contentHash: String? = nil,
        sourceDevice: String? = nil
    ) {
        self.id = id
        $user.id = userID
        self.entityID = entityID
        self.entityType = entityType
        self.encryptedData = encryptedData
        self.contentHash = contentHash
        isDeleted = false
        self.sourceDevice = sourceDevice
        version = 1
    }

    // MARK: Internal

    static let schema = "sync_records"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "entity_id") var entityID: UUID
    @Field(key: "entity_type") var entityType: String
    @OptionalField(key: "encrypted_data") var encryptedData: Data?
    @OptionalField(key: "content_hash") var contentHash: String?
    @Field(key: "is_deleted") var isDeleted: Bool
    @OptionalField(key: "source_device") var sourceDevice: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @Field(key: "version") var version: Int64
}
