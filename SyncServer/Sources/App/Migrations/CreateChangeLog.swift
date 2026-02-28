import Fluent
import SQLKit
import Vapor

struct CreateChangeLog: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            throw Abort(.internalServerError, reason: "Change log requires SQL database")
        }

        // Use raw SQL for BIGSERIAL primary key (Fluent doesn't support auto-incrementing non-UUID PKs well)
        try await sql.raw("""
            CREATE TABLE change_log (
                id BIGSERIAL PRIMARY KEY,
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                entity_id UUID NOT NULL,
                entity_type VARCHAR(50) NOT NULL,
                change_type VARCHAR(20) NOT NULL,
                source_device VARCHAR(255),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                sync_record_id UUID REFERENCES sync_records(id) ON DELETE SET NULL
            )
            """).run()

        try await sql.raw("CREATE INDEX idx_change_log_user_id ON change_log(user_id, id)").run()
        try await sql.raw("CREATE INDEX idx_change_log_created ON change_log(user_id, created_at)").run()
    }

    func revert(on database: Database) async throws {
        try await database.schema("change_log").delete()
    }
}
