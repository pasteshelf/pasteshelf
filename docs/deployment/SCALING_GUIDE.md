# Scaling Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 10 minutes

Guidelines for scaling PasteShelf for large deployments.

---

## Table of Contents

- [Client Performance](#client-performance)
- [Server Scaling](#server-scaling)
- [Database Optimization](#database-optimization)
- [Monitoring](#monitoring)

---

## Client Performance

### History Limits

| Use Case | Recommended Limit |
|----------|-------------------|
| Light user | 1,000 items |
| Power user | 5,000 items |
| Heavy user | 10,000 items |

### Memory Usage

| Items | Estimated RAM |
|-------|---------------|
| 1,000 | ~50 MB |
| 5,000 | ~150 MB |
| 10,000 | ~250 MB |

### Optimization Settings

```swift
// Recommended settings for performance
struct PerformanceConfig {
    static let batchSize = 50
    static let preloadCount = 100
    static let thumbnailSize = 256
    static let searchDebounce = 0.15
}
```

---

## Server Scaling (Enterprise)

### Horizontal Scaling

```
┌───────────────────────────────────────────────────────────────┐
│                    Load Balanced Architecture                  │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│   Clients                                                      │
│      │                                                         │
│      ▼                                                         │
│   ┌──────────────────┐                                        │
│   │  Load Balancer   │                                        │
│   └────────┬─────────┘                                        │
│            │                                                   │
│     ┌──────┼──────┐                                           │
│     │      │      │                                           │
│     ▼      ▼      ▼                                           │
│   ┌────┐ ┌────┐ ┌────┐                                       │
│   │ S1 │ │ S2 │ │ S3 │  Sync Servers (stateless)             │
│   └────┘ └────┘ └────┘                                       │
│     │      │      │                                           │
│     └──────┼──────┘                                           │
│            ▼                                                   │
│   ┌──────────────────┐                                        │
│   │  PostgreSQL      │  (Primary + Read Replicas)             │
│   └──────────────────┘                                        │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

### Capacity Planning

| Users | Sync Servers | DB Size |
|-------|--------------|---------|
| 100 | 1 | 10 GB |
| 1,000 | 2 | 100 GB |
| 10,000 | 5 | 1 TB |

---

## Database Optimization

### Indexes

```sql
-- Essential indexes
CREATE INDEX idx_items_user_created ON clipboard_items(user_id, created_at DESC);
CREATE INDEX idx_items_content_hash ON clipboard_items(content_hash);
CREATE INDEX idx_items_sync_status ON clipboard_items(sync_status) WHERE sync_status != 'synced';
```

### Maintenance

```sql
-- Regular maintenance
VACUUM ANALYZE clipboard_items;
REINDEX INDEX idx_items_user_created;
```

---

## Monitoring

### Key Metrics

- Response latency (p50, p95, p99)
- Sync queue depth
- Database connection pool
- Memory usage per user
- Error rates

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Client optimization |
| [Enterprise Deployment](../enterprise/ENTERPRISE_DEPLOYMENT.md) | Deployment |

---

*Last updated: 2026-02-03*
