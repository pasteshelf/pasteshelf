import Fluent
import SQLKit

struct CreateSyncRecord: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sync_records")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("entity_id", .uuid, .required)
            .field("entity_type", .string, .required)
            .field("encrypted_data", .data)
            .field("content_hash", .string)
            .field("is_deleted", .bool, .required, .sql(.default(false)))
            .field("source_device", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("version", .int64, .required, .sql(.default(1)))
            .unique(on: "user_id", "entity_id")
            .create()

        // Performance indexes
        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX idx_sync_records_user_updated ON sync_records(user_id, updated_at)").run()
            try await sql.raw("CREATE INDEX idx_sync_records_user_hash ON sync_records(user_id, content_hash)").run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("sync_records").delete()
    }
}
