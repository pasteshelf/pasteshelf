//
//  configure.swift
//  SyncServer
//
//  Application configuration: database, middleware, migrations.
//

import Fluent
import FluentPostgresDriver
import JWT
import Vapor

func configure(_ app: Application) async throws {
    // MARK: - Database

    app.databases.use(
        .postgres(configuration: .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DATABASE_USERNAME") ?? "pasteshelf",
            password: Environment.get("DATABASE_PASSWORD") ?? "pasteshelf",
            database: Environment.get("DATABASE_NAME") ?? "pasteshelf_sync",
            tls: .disable
        )),
        as: .psql
    )

    // MARK: - JWT

    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        fatalError("JWT_SECRET environment variable must be set")
    }
    await app.jwt.keys.add(hmac: jwtSecret, digestAlgorithm: .sha256)

    // MARK: - Migrations

    app.migrations.add(CreateUser())
    app.migrations.add(CreateDevice())
    app.migrations.add(CreateAPIKey())
    app.migrations.add(CreateSyncRecord())
    app.migrations.add(CreateChangeLog())
    app.migrations.add(CreateSyncToken())

    // Auto-migrate in development
    if app.environment == .development {
        try await app.autoMigrate()
    }

    // MARK: - Middleware

    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin]
    )))
    app.middleware.use(RateLimitMiddleware())

    // MARK: - Services

    app.webSocketService = WebSocketService()

    // MARK: - Routes

    try routes(app)
}
