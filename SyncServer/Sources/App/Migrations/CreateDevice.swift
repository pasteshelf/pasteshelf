import Fluent

struct CreateDevice: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("devices")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_id", .string, .required)
            .field("device_name", .string)
            .field("os_version", .string)
            .field("app_version", .string)
            .field("last_seen", .datetime, .required)
            .field("created_at", .datetime)
            .unique(on: "user_id", "device_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("devices").delete()
    }
}
