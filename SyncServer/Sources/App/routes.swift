//
//  routes.swift
//  SyncServer
//
//  Route registration for the PasteShelf self-hosted sync server.
//

import Vapor

func routes(_ app: Application) throws {
    // Public routes
    try app.register(collection: HealthController())
    try app.register(collection: AuthController())

    // Authenticated routes
    let protected = app.grouped(JWTAuthMiddleware())
    try protected.register(collection: DeviceController())
    try protected.register(collection: SyncController())

    // WebSocket
    app.webSocket("api", "v1", "ws") { req, ws in
        await req.application.webSocketService.handleConnection(req: req, ws: ws)
    }
}
