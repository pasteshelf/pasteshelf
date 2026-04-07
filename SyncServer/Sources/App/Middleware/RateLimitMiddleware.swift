import Vapor

// MARK: - RateLimitStore

actor RateLimitStore {
    // MARK: Lifecycle

    init(limit: Int = 100, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    // MARK: Internal

    func check(key: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-self.window)
        var entries = self.requests[key, default: []].filter { $0 > cutoff }
        entries.append(now)
        self.requests[key] = entries
        return entries.count <= self.limit
    }

    // MARK: Private

    private var requests: [String: [Date]] = [:]
    private let limit: Int
    private let window: TimeInterval
}

// MARK: - RateLimitMiddleware

struct RateLimitMiddleware: AsyncMiddleware {
    // MARK: Internal

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let key = request.peerAddress?.description ?? "unknown"
        guard await self.store.check(key: key) else {
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Try again later.")
        }
        return try await next.respond(to: request)
    }

    // MARK: Private

    private let store = RateLimitStore()
}
