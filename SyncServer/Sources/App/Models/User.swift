import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "external_id") var externalID: String
    @Field(key: "org_id") var orgID: String
    @OptionalField(key: "email") var email: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    @Children(for: \.$user) var devices: [Device]
    @Children(for: \.$user) var syncRecords: [SyncRecord]

    init() {}

    init(id: UUID? = nil, externalID: String, orgID: String, email: String? = nil) {
        self.id = id
        self.externalID = externalID
        self.orgID = orgID
        self.email = email
    }
}
