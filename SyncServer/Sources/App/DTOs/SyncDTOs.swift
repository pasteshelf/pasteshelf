import Vapor

// MARK: - SyncPushRequest

struct SyncPushRequest: Content {
    let changes: [SyncChangeDTO]
    let deviceID: String
}

// MARK: - SyncChangeDTO

struct SyncChangeDTO: Content {
    let entityID: UUID
    let entityType: String
    let encryptedData: String? // Base64-encoded
    let contentHash: String?
    let isDeleted: Bool
    let clientVersion: Int64?
}

// MARK: - SyncPushResponse

struct SyncPushResponse: Content {
    let accepted: Int
    let conflicts: [SyncConflictDTO]
    let serverTimestamp: Date
}

// MARK: - SyncConflictDTO

struct SyncConflictDTO: Content {
    let entityID: UUID
    let entityType: String
    let serverVersion: Int64
    let serverEncryptedData: String? // Base64-encoded
    let serverContentHash: String?
}

// MARK: - SyncPullRequest

struct SyncPullRequest: Content {
    let since: String?
    let limit: Int?
}

// MARK: - SyncPullResponse

struct SyncPullResponse: Content {
    let changes: [SyncPullChangeDTO]
    let newToken: String
    let hasMore: Bool
}

// MARK: - SyncPullChangeDTO

struct SyncPullChangeDTO: Content {
    let entityID: UUID
    let entityType: String
    let changeType: String
    let encryptedData: String? // Base64-encoded
    let contentHash: String?
    let isDeleted: Bool
    let version: Int64
    let sourceDevice: String?
    let timestamp: Date
}

// MARK: - SyncStatusResponse

struct SyncStatusResponse: Content {
    let deviceID: String
    let lastSyncToken: String?
    let totalRecords: Int
    let serverTimestamp: Date
}

// MARK: - SyncResetResponse

struct SyncResetResponse: Content {
    let deletedRecords: Int
    let message: String
}
