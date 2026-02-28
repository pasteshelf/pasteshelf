import Fluent

struct CreateAPIKey: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("api_keys")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_id", .uuid, .required, .references("devices", "id", onDelete: .cascade))
            .field("key_hash", .string, .required)
            .field("key_prefix", .string, .required)
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .field("revoked_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("api_keys").delete()
    }
}
