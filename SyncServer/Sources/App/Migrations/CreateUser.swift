import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("external_id", .string, .required)
            .field("org_id", .string, .required)
            .field("email", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "external_id", "org_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
