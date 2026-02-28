//
//  HealthController.swift
//  SyncServer
//
//  Health check endpoint for load balancers and monitoring.
//

import Vapor

struct HealthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("health", use: healthCheck)
    }

    @Sendable
    func healthCheck(req: Request) async throws -> HealthResponse {
        // Check database connectivity
        do {
            try await req.db.query(User.self).count()
            return HealthResponse(status: "ok", version: "1.0.0", database: "connected")
        } catch {
            return HealthResponse(status: "degraded", version: "1.0.0", database: "disconnected")
        }
    }
}

struct HealthResponse: Content {
    let status: String
    let version: String
    let database: String
}
