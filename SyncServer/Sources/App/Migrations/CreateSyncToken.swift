import Fluent

struct CreateSyncToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sync_tokens")
            .id()
            .field("device_id", .uuid, .required, .references("devices", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token_value", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "device_id", "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sync_tokens").delete()
    }
}
