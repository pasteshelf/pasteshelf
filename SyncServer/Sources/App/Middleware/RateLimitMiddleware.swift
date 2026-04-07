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
        let cutoff = now.addingTimeInterval(-window)
        var entries = requests[key, default: []].filter { $0 > cutoff }
        entries.append(now)
        requests[key] = entries
        return entries.count <= limit
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
        guard await store.check(key: key) else {
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Try again later.")
        }
        return try await next.respond(to: request)
    }

    // MARK: Private

    private let store = RateLimitStore()
}
