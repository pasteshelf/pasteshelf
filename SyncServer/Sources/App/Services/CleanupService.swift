//
//  CleanupService.swift
//  SyncServer
//
//  Periodic cleanup of expired data: old change_log entries, revoked API keys.
//

import Fluent
import SQLKit
import Vapor

struct CleanupService {
    let app: Application

    /// Remove change_log entries older than the retention period (default 90 days).
    func cleanupOldChangeLogs(retentionDays: Int = 90) async throws {
        guard let sql = app.db as? SQLDatabase else { return }
        try await sql.raw("""
            DELETE FROM change_log
            WHERE created_at < NOW() - INTERVAL '\(raw: String(retentionDays)) days'
            """).run()
        app.logger.info("Cleaned up change_log entries older than \(retentionDays) days")
    }

    /// Remove revoked API keys older than 30 days.
    func cleanupRevokedAPIKeys() async throws {
        guard let sql = app.db as? SQLDatabase else { return }
        try await sql.raw("""
            DELETE FROM api_keys
            WHERE revoked_at IS NOT NULL
            AND revoked_at < NOW() - INTERVAL '30 days'
            """).run()
        app.logger.info("Cleaned up old revoked API keys")
    }

    /// Remove soft-deleted sync records older than the retention period.
    func cleanupDeletedRecords(retentionDays: Int = 30) async throws {
        guard let sql = app.db as? SQLDatabase else { return }
        try await sql.raw("""
            DELETE FROM sync_records
            WHERE is_deleted = TRUE
            AND updated_at < NOW() - INTERVAL '\(raw: String(retentionDays)) days'
            """).run()
        app.logger.info("Cleaned up soft-deleted sync records older than \(retentionDays) days")
    }
}
