import Fluent
import Vapor

final class ChangeLog: Model, Content, @unchecked Sendable {
    // MARK: Lifecycle

    init() {}

    init(
        userID: UUID,
        entityID: UUID,
        entityType: String,
        changeType: String,
        sourceDevice: String? = nil,
        syncRecordID: UUID? = nil
    ) {
        self.$user.id = userID
        self.entityID = entityID
        self.entityType = entityType
        self.changeType = changeType
        self.sourceDevice = sourceDevice
        if let syncRecordID {
            self.$syncRecord.id = syncRecordID
        }
    }

    // MARK: Internal

    static let schema = "change_log"

    @ID(custom: "id", generatedBy: .database) var id: Int?
    @Parent(key: "user_id") var user: User
    @Field(key: "entity_id") var entityID: UUID
    @Field(key: "entity_type") var entityType: String
    @Field(key: "change_type") var changeType: String
    @OptionalField(key: "source_device") var sourceDevice: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @OptionalParent(key: "sync_record_id") var syncRecord: SyncRecord?
}
