# Self-Hosted Sync Server — PostgreSQL Schema

> **Last Updated**: 2026-02-28 | **Reading Time**: 18 minutes

PostgreSQL database schema documentation for the PasteShelf Enterprise self-hosted sync server.

---

## Table of Contents

- [Overview](#overview)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Table Definitions](#table-definitions)
  - [users](#table-users)
  - [devices](#table-devices)
  - [api_keys](#table-api_keys)
  - [sync_records](#table-sync_records)
  - [change_log](#table-change_log)
  - [sync_tokens](#table-sync_tokens)
- [Index Strategy](#index-strategy)
- [Key Design Decisions](#key-design-decisions)
- [Data Retention and Cleanup](#data-retention-and-cleanup)
- [Migration Strategy](#migration-strategy)
- [Related Documentation](#related-documentation)

---

## Overview

The PasteShelf Enterprise self-hosted sync server uses PostgreSQL as its primary data store. It is designed for organizations that cannot use iCloud-based sync due to compliance requirements, data residency policies, or network isolation constraints.

### Design Principles

- **Zero-knowledge architecture**: The server stores only encrypted blobs. No plaintext clipboard data is ever present on the server.
- **SSO-native identity**: Users are identified by their SSO `external_id` and `org_id`. No standalone password authentication is supported.
- **Append-only change tracking**: A dedicated `change_log` table enables efficient incremental sync. Clients pull only the changes since their last cursor.
- **Optimistic concurrency**: A `version` counter on `sync_records` prevents lost-update conflicts across devices.
- **Soft deletes**: Records are marked `is_deleted = TRUE` rather than physically removed, preserving tombstones for cross-device propagation.

### Server Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                   Self-Hosted Sync Server Architecture                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   ┌──────────────────────┐        ┌──────────────────────────────┐   │
│   │   macOS Client       │        │    Enterprise IdP (SSO)      │   │
│   │   (PasteShelf)       │        │    SAML 2.0 / OIDC           │   │
│   └──────────┬───────────┘        └────────────────┬─────────────┘   │
│              │                                      │                  │
│              │  HTTPS + API Key                     │ Token exchange   │
│              ▼                                      ▼                  │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │                    Sync API (REST/gRPC)                       │   │
│   └────────────────────────────┬─────────────────────────────────┘   │
│                                 │                                      │
│                                 ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │                   PostgreSQL Database                          │   │
│   │                                                                │   │
│   │   users ──┬── devices ── api_keys                             │   │
│   │           ├── sync_records (encrypted blobs)                  │   │
│   │           ├── change_log (append-only)                        │   │
│   │           └── sync_tokens (per-device cursors)                │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Entity Relationship Diagram                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│              ┌──────────────────────────┐                             │
│              │          users           │                             │
│              │  ────────────────────    │                             │
│              │  id            UUID PK   │                             │
│              │  external_id   VARCHAR   │                             │
│              │  org_id        VARCHAR   │                             │
│              │  email         VARCHAR   │                             │
│              │  created_at    TIMESTAMPTZ                             │
│              │  updated_at    TIMESTAMPTZ                             │
│              └──────┬───────────────────┘                            │
│                     │                                                  │
│          ┌──────────┼─────────────────────────┐                      │
│          │          │                          │                      │
│          ▼          ▼                          ▼                      │
│   ┌──────────┐  ┌────────────┐         ┌─────────────────┐          │
│   │ devices  │  │sync_records│         │   change_log    │          │
│   │ ──────── │  │ ────────── │         │   ──────────    │          │
│   │ id   PK  │  │ id     PK  │         │   id   BIGSERIAL│          │
│   │ user_id  │  │ user_id FK │         │   user_id    FK │          │
│   │ device_id│  │ entity_id  │         │   entity_id     │          │
│   │ ...      │  │ enc_data   │         │   change_type   │          │
│   └────┬─────┘  │ version    │         │   source_device │          │
│        │        │ is_deleted │         │   sync_record_id│          │
│        │        └────────────┘         └─────────────────┘          │
│        │                                                              │
│   ┌────┴──────────────────┐                                          │
│   │       api_keys        │                                          │
│   │  ──────────────────   │                                          │
│   │  id        UUID PK    │                                          │
│   │  user_id   UUID FK    │                                          │
│   │  device_id UUID FK    │                                          │
│   │  key_hash  VARCHAR    │                                          │
│   │  key_prefix VARCHAR   │                                          │
│   │  expires_at TIMESTAMPTZ                                          │
│   │  revoked_at TIMESTAMPTZ                                          │
│   └───────────────────────┘                                          │
│                                                                        │
│   ┌────────────────────────┐                                          │
│   │      sync_tokens       │                                          │
│   │  ──────────────────    │                                          │
│   │  id         UUID PK    │                                          │
│   │  device_id  UUID FK ── ┼──▶ devices.id                          │
│   │  user_id    UUID FK ── ┼──▶ users.id                            │
│   │  token_value VARCHAR   │                                          │
│   │  updated_at TIMESTAMPTZ│                                          │
│   └────────────────────────┘                                          │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Table Definitions

### Table: users

Maps SSO identities to server accounts. One row is created the first time a user authenticates via SSO. The server never stores passwords — authentication is delegated entirely to the organization's identity provider.

```
┌──────────────────────────────────────────────────────────────┐
│                           users                               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id           UUID         PK, auto-generated                │
│  external_id  VARCHAR(255) SSO subject ID (non-nullable)      │
│  org_id       VARCHAR(255) Organization identifier            │
│  email        VARCHAR(255) User email (optional, from IdP)    │
│  created_at   TIMESTAMPTZ  Row creation timestamp             │
│  updated_at   TIMESTAMPTZ  Last update timestamp              │
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • UNIQUE (external_id, org_id)                               │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • external_id is the OIDC `sub` claim or SAML NameID        │
│  • org_id allows multi-tenant deployments from one server     │
│  • email is informational only — not used for auth           │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id VARCHAR(255) NOT NULL,         -- SSO subject ID
    org_id      VARCHAR(255) NOT NULL,         -- Organization identifier
    email       VARCHAR(255),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (external_id, org_id)
);
```

---

### Table: devices

Registered client devices belonging to a user. A device record is created the first time a client exchanges an SSO token for a persistent API key.

```
┌──────────────────────────────────────────────────────────────┐
│                          devices                              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id           UUID         PK, auto-generated                │
│  user_id      UUID         FK → users(id) ON DELETE CASCADE  │
│  device_id    VARCHAR(255) Client-generated UUID (per device) │
│  device_name  VARCHAR(255) Human-readable device name         │
│  os_version   VARCHAR(50)  macOS version string               │
│  app_version  VARCHAR(50)  PasteShelf app version             │
│  last_seen    TIMESTAMPTZ  Last successful API request        │
│  created_at   TIMESTAMPTZ  Row creation timestamp             │
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • FOREIGN KEY (user_id) REFERENCES users(id)                 │
│  • UNIQUE (user_id, device_id)                                │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • device_id is generated once by the client at install time  │
│  • last_seen is updated on every successful API call          │
│  • Cascade delete removes all device data on user removal     │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE devices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id   VARCHAR(255) NOT NULL,         -- Client-generated device UUID
    device_name VARCHAR(255),
    os_version  VARCHAR(50),
    app_version VARCHAR(50),
    last_seen   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_id)
);
```

---

### Table: api_keys

Persistent API keys issued to individual devices after SSO authentication. Clients use these keys for subsequent sync requests, avoiding a full SSO flow on every operation.

```
┌──────────────────────────────────────────────────────────────┐
│                         api_keys                              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id           UUID         PK, auto-generated                │
│  user_id      UUID         FK → users(id) ON DELETE CASCADE  │
│  device_id    UUID         FK → devices(id) ON DELETE CASCADE│
│  key_hash     VARCHAR(255) SHA-256 hash of the raw API key    │
│  key_prefix   VARCHAR(8)   First 8 chars for identification   │
│  created_at   TIMESTAMPTZ  Key issuance timestamp             │
│  expires_at   TIMESTAMPTZ  Optional expiry (NULL = no expiry) │
│  revoked_at   TIMESTAMPTZ  Revocation timestamp (NULL = active│
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • FOREIGN KEY (user_id) REFERENCES users(id)                 │
│  • FOREIGN KEY (device_id) REFERENCES devices(id)             │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • Raw key is never stored — only the SHA-256 hash            │
│  • key_prefix allows admins to identify keys in audit logs    │
│  • A key is considered active when:                           │
│    revoked_at IS NULL AND                                     │
│    (expires_at IS NULL OR expires_at > NOW())                 │
│  • MDM-initiated revocation sets revoked_at to NOW()          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE api_keys (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id   UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    key_hash    VARCHAR(255) NOT NULL,         -- SHA256 of the API key
    key_prefix  VARCHAR(8) NOT NULL,           -- First 8 chars for identification
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ,
    revoked_at  TIMESTAMPTZ
);
```

---

### Table: sync_records

The central table for storing encrypted clipboard data. Each row corresponds to one client-side entity (e.g., a `ClipboardItem` or `Tag`). The server stores only the encrypted blob — it cannot read the plaintext content.

```
┌──────────────────────────────────────────────────────────────┐
│                       sync_records                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id             UUID        PK, auto-generated               │
│  user_id        UUID        FK → users(id) ON DELETE CASCADE  │
│  entity_id      UUID        Client-side entity UUID           │
│  entity_type    VARCHAR(50) "ClipboardItem", "Tag", etc.      │
│  encrypted_data BYTEA       E2E-encrypted payload blob        │
│  content_hash   VARCHAR(64) SHA-256 of plaintext (client-set) │
│  is_deleted     BOOLEAN     Soft-delete tombstone flag        │
│  source_device  VARCHAR(255)Device ID of last writer          │
│  created_at     TIMESTAMPTZ Row creation timestamp            │
│  updated_at     TIMESTAMPTZ Last update timestamp             │
│  version        BIGINT      Optimistic concurrency counter    │
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • FOREIGN KEY (user_id) REFERENCES users(id)                 │
│  • UNIQUE (user_id, entity_id)                                │
│                                                               │
│  INDEXES                                                      │
│  ───────                                                      │
│                                                               │
│  • idx_sync_records_user_updated (user_id, updated_at)        │
│  • idx_sync_records_user_hash    (user_id, content_hash)      │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • entity_id is generated by the client; the server treats    │
│    it as opaque                                               │
│  • encrypted_data may be NULL for tombstone-only records      │
│  • content_hash is used by the client to detect duplicates    │
│    before uploading; the server does not validate it          │
│  • version increments on every write; conflicts occur when    │
│    two clients write the same (user_id, entity_id) with the   │
│    same incoming version                                       │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE sync_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_id       UUID NOT NULL,             -- Client-side entity UUID
    entity_type     VARCHAR(50) NOT NULL,      -- "ClipboardItem", "Tag", etc.
    encrypted_data  BYTEA,                     -- E2E encrypted blob
    content_hash    VARCHAR(64),               -- SHA256 hash for dedup
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    source_device   VARCHAR(255),              -- Device that last updated
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version         BIGINT NOT NULL DEFAULT 1, -- Optimistic concurrency control
    UNIQUE (user_id, entity_id)
);

CREATE INDEX idx_sync_records_user_updated ON sync_records(user_id, updated_at);
CREATE INDEX idx_sync_records_user_hash ON sync_records(user_id, content_hash);
```

---

### Table: change_log

An append-only audit and sync-cursor log. Every insert, update, and soft-delete on `sync_records` appends a row here. Clients use their last-seen `change_log.id` (stored in `sync_tokens`) to pull only incremental changes.

```
┌──────────────────────────────────────────────────────────────┐
│                        change_log                             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id             BIGSERIAL   PK, monotonically increasing      │
│  user_id        UUID        FK → users(id) ON DELETE CASCADE  │
│  entity_id      UUID        Identifies the affected entity    │
│  entity_type    VARCHAR(50) Mirrors sync_records.entity_type  │
│  change_type    VARCHAR(20) "insert", "update", or "delete"   │
│  source_device  VARCHAR(255)Device that triggered the change  │
│  created_at     TIMESTAMPTZ When this change was recorded     │
│  sync_record_id UUID        FK → sync_records(id) SET NULL    │
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • FOREIGN KEY (user_id) REFERENCES users(id)                 │
│  • FOREIGN KEY (sync_record_id) REFERENCES sync_records(id)   │
│                                                               │
│  INDEXES                                                      │
│  ───────                                                      │
│                                                               │
│  • idx_change_log_user_id (user_id, id)                       │
│  • idx_change_log_created (user_id, created_at)               │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • Rows are NEVER updated or deleted during normal operation  │
│  • BIGSERIAL guarantees total ordering within a Postgres      │
│    instance; do not rely on created_at for ordering           │
│  • sync_record_id becomes NULL if the referenced sync_record  │
│    is physically deleted during a cleanup pass                │
│  • The incremental pull query pattern is:                     │
│    SELECT * FROM change_log                                   │
│    WHERE user_id = $1 AND id > $last_seen_id                  │
│    ORDER BY id ASC LIMIT $page_size;                          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE change_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_id       UUID NOT NULL,
    entity_type     VARCHAR(50) NOT NULL,
    change_type     VARCHAR(20) NOT NULL,      -- "insert", "update", "delete"
    source_device   VARCHAR(255),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_record_id  UUID REFERENCES sync_records(id) ON DELETE SET NULL
);

CREATE INDEX idx_change_log_user_id ON change_log(user_id, id);
CREATE INDEX idx_change_log_created ON change_log(user_id, created_at);
```

---

### Table: sync_tokens

Stores each device's sync cursor — the highest `change_log.id` the device has successfully processed. This allows the API to efficiently serve incremental pulls without requiring full-table scans.

```
┌──────────────────────────────────────────────────────────────┐
│                       sync_tokens                             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  COLUMNS                                                      │
│  ───────                                                      │
│                                                               │
│  id           UUID         PK, auto-generated                │
│  device_id    UUID         FK → devices(id) ON DELETE CASCADE│
│  user_id      UUID         FK → users(id) ON DELETE CASCADE  │
│  token_value  VARCHAR(255) Encodes last change_log.id seen    │
│  created_at   TIMESTAMPTZ  Row creation timestamp             │
│  updated_at   TIMESTAMPTZ  Last cursor advancement timestamp  │
│                                                               │
│  CONSTRAINTS                                                  │
│  ───────────                                                  │
│                                                               │
│  • PRIMARY KEY (id)                                           │
│  • FOREIGN KEY (device_id) REFERENCES devices(id)             │
│  • FOREIGN KEY (user_id) REFERENCES users(id)                 │
│  • UNIQUE (device_id)                                         │
│                                                               │
│  NOTES                                                        │
│  ─────                                                        │
│                                                               │
│  • One row per device — the UNIQUE constraint on device_id    │
│    enforces this                                              │
│  • token_value is an opaque string from the client's          │
│    perspective; it encodes the last change_log.id the device  │
│    has acknowledged                                           │
│  • A missing row means the device has never synced; the       │
│    server returns all records in this case                    │
│  • Advancing the cursor is idempotent — re-sending an old     │
│    token value must not regress the cursor                    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**SQL Definition**:

```sql
CREATE TABLE sync_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id   UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_value VARCHAR(255) NOT NULL,         -- Encodes last change_log.id seen
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (device_id)
);
```

---

## Index Strategy

```
┌──────────────────────────────────────────────────────────────┐
│                      Index Summary                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  sync_records                                                 │
│  ────────────                                                 │
│                                                               │
│  idx_sync_records_user_updated (user_id, updated_at)          │
│  Purpose: Fetch all records modified after a timestamp.       │
│  Used by: Full-refresh pull (initial sync or recovery).       │
│                                                               │
│  idx_sync_records_user_hash (user_id, content_hash)           │
│  Purpose: Client-side deduplication check before upload.      │
│  Used by: Upload API to detect already-known content.         │
│                                                               │
│  UNIQUE (user_id, entity_id) [implicit index]                 │
│  Purpose: Enforce one record per logical entity per user.     │
│  Used by: Upsert path (INSERT … ON CONFLICT DO UPDATE).       │
│                                                               │
│  change_log                                                   │
│  ──────────                                                   │
│                                                               │
│  idx_change_log_user_id (user_id, id)                         │
│  Purpose: Core incremental pull query. Filters by user and    │
│           seeks from the last-seen BIGSERIAL id.              │
│  Selectivity: High. This is the most-hit index on the server. │
│                                                               │
│  idx_change_log_created (user_id, created_at)                 │
│  Purpose: Time-range queries for audit log exports and        │
│           retention cleanup jobs.                             │
│  Used by: Admin APIs, cleanup scheduler.                      │
│                                                               │
│  devices                                                      │
│  ───────                                                      │
│                                                               │
│  UNIQUE (user_id, device_id) [implicit index]                 │
│  Purpose: Fast lookup during device registration.             │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Index Maintenance Notes

- All indexes use the default B-tree access method, which is appropriate for equality and range queries.
- `change_log` grows unboundedly during normal operation. Partition or truncate old rows periodically (see [Data Retention and Cleanup](#data-retention-and-cleanup)).
- After large cleanup passes, run `ANALYZE` on `change_log` and `sync_records` to refresh planner statistics.
- For deployments with high write volume, consider using `pg_partman` to partition `change_log` by `created_at` (monthly range partitions are recommended).

---

## Key Design Decisions

### 1. Append-Only `change_log`

`change_log` is never updated or deleted during normal server operation. Every state transition on a `sync_record` appends a new row.

**Why**: Clients sync incrementally using a monotonically increasing cursor (`BIGSERIAL id`). An append-only table guarantees that a client's cursor remains valid indefinitely — there is no risk of a row shifting position or disappearing between two pull requests. This is simpler and more reliable than timestamp-based cursors, which suffer from clock skew and transaction isolation edge cases.

**Trade-off**: The table grows continuously. A separate cleanup job must archive or delete old entries (see [Data Retention and Cleanup](#data-retention-and-cleanup)).

### 2. Optimistic Concurrency via `version`

`sync_records.version` is a client-managed integer that increments on every write. When a client submits an update, it includes the version it last read. The server rejects the write if the stored version is higher, indicating a concurrent write from another device.

**Conflict resolution flow**:

```
┌────────────────────────────────────────────────────────┐
│               Optimistic Concurrency Flow               │
├────────────────────────────────────────────────────────┤
│                                                         │
│  Client A reads record, version = 3                     │
│  Client B reads record, version = 3                     │
│                                                         │
│  Client A writes version = 4  ──▶ Server accepts        │
│  Client B writes version = 4  ──▶ Server rejects        │
│       (stored version is now 4, conflict detected)      │
│                                                         │
│  Client B receives 409 Conflict                         │
│  Client B re-fetches record (version = 4)               │
│  Client B applies local changes, writes version = 5     │
│       ──▶ Server accepts                                │
│                                                         │
└────────────────────────────────────────────────────────┘
```

**Why**: Last-write-wins semantics are unacceptable for clipboard history because two devices may legitimately update the same item concurrently (e.g., applying a tag on both). Optimistic locking surfaces these conflicts to the client, which applies entity-specific merge logic using its local knowledge of the decrypted content.

### 3. Soft Deletes via `is_deleted`

Deleted entities are never removed immediately. Instead, `is_deleted` is set to `TRUE` and the record is retained as a tombstone.

**Why**: Without tombstones, a device that has been offline cannot distinguish between "this entity was deleted" and "this entity was never synced to me." Tombstones propagate deletions correctly to all devices. Physical deletion occurs only after a configurable retention window has elapsed and all active devices have acknowledged the tombstone.

### 4. Zero-Knowledge Encrypted Storage

`sync_records.encrypted_data` contains an AES-256-GCM ciphertext produced by the client before transmission. The server has no access to decryption keys.

```
┌────────────────────────────────────────────────────────┐
│             Zero-Knowledge Encryption Flow              │
├────────────────────────────────────────────────────────┤
│                                                         │
│  Client (Device A)                                      │
│  ──────────────────                                     │
│  1. Generate per-user E2E key (stored in Keychain)      │
│  2. Encrypt ClipboardItem with AES-256-GCM              │
│  3. POST encrypted blob to /sync/push                   │
│                                                         │
│  Server                                                 │
│  ──────                                                 │
│  4. Store BYTEA blob — no decryption performed          │
│                                                         │
│  Client (Device B)                                      │
│  ──────────────────                                     │
│  5. GET encrypted blob from /sync/pull                  │
│  6. Decrypt using shared E2E key from Keychain          │
│                                                         │
└────────────────────────────────────────────────────────┘
```

**Key distribution**: The symmetric E2E key is shared between a user's devices via a separate key-agreement protocol (not handled by this server). Administrators operating the sync server cannot read user clipboard data.

### 5. SSO-Native Identity (No Passwords)

`users.external_id` maps to the IdP's subject claim. The server does not implement any form of local credential storage.

**Why**: Enterprise deployments require centralized identity management. Storing passwords would create an additional attack surface and complicate offboarding. When a user's SSO account is deprovisioned, their API keys expire on next rotation and their device access is terminated at the IdP level.

---

## Data Retention and Cleanup

### Tombstone Retention

Soft-deleted records (`is_deleted = TRUE`) must be retained until all registered devices for the user have acknowledged the deletion via their sync cursor. A safe minimum retention window is 90 days, after which tombstones may be physically deleted.

```sql
-- Example: physical delete of tombstones older than 90 days
-- where no active device has a sync cursor older than the tombstone
DELETE FROM sync_records
WHERE is_deleted = TRUE
  AND updated_at < NOW() - INTERVAL '90 days'
  AND NOT EXISTS (
      SELECT 1 FROM sync_tokens st
      JOIN devices d ON d.id = st.device_id
      WHERE d.user_id = sync_records.user_id
        AND d.last_seen > NOW() - INTERVAL '90 days'
        AND CAST(st.token_value AS BIGINT) < (
            SELECT MIN(cl.id) FROM change_log cl
            WHERE cl.entity_id = sync_records.entity_id
              AND cl.change_type = 'delete'
        )
  );
```

### `change_log` Archival

`change_log` rows older than the tombstone retention window can be archived to cold storage (e.g., S3-compatible object store) and deleted from the live database.

```sql
-- Example: archive and delete change_log rows older than 90 days
-- Run inside a transaction with S3 export first
DELETE FROM change_log
WHERE created_at < NOW() - INTERVAL '90 days';
```

After deletion, run `VACUUM ANALYZE change_log` to reclaim space.

### Inactive Device Cleanup

Devices that have not been seen for 180 days (or the MDM-configured device inactivity timeout) should be deregistered. Cascade deletes will remove associated `api_keys` and `sync_tokens` rows automatically.

```sql
-- Example: deregister devices inactive for 180 days
DELETE FROM devices
WHERE last_seen < NOW() - INTERVAL '180 days';
```

### Retention Policy Summary

| Data | Minimum Retention | Maximum Retention | Notes |
|------|-------------------|-------------------|-------|
| Active sync records | Indefinite | User-configurable | Bounded by client history limit |
| Tombstones (is_deleted) | 90 days | 365 days | Must outlive inactive device window |
| change_log rows | 90 days | 365 days | Archive before delete |
| api_keys (revoked) | 30 days | 90 days | Kept for audit log correlation |
| Inactive devices | 180 days | 365 days | MDM policy may override |

---

## Migration Strategy

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-28 | Initial schema |

### Tooling

All schema migrations are managed with [Flyway](https://flywaydb.org/) or [golang-migrate](https://github.com/golang-migrate/migrate). Migration scripts are stored in `server/migrations/` and follow the naming convention:

```
V{version}__{description}.sql       -- e.g., V1__initial_schema.sql
V{version}_{minor}__{description}.sql  -- e.g., V1_1__add_api_key_index.sql
```

### Migration Guidelines

1. **Backward-compatible changes only** in patch versions: adding nullable columns, adding indexes, expanding VARCHAR lengths.
2. **Never drop or rename columns** without a multi-step migration (add new column, migrate data, remove old column across separate releases).
3. **All new columns** must either be `NOT NULL DEFAULT <value>` or `NULL` to avoid locking issues on large tables.
4. **Add indexes concurrently** to avoid table locks:
   ```sql
   CREATE INDEX CONCURRENTLY idx_new_index ON sync_records(user_id, entity_type);
   ```
5. **Test migrations** against a production-sized dataset before deploying. Use `pg_dump` snapshots from staging.
6. **Wrap DDL in transactions** where possible. Index creation with `CONCURRENTLY` cannot be inside a transaction — run these separately with manual rollback steps documented.

### Rollback Procedure

```
┌────────────────────────────────────────────────────────┐
│               Schema Rollback Procedure                 │
├────────────────────────────────────────────────────────┤
│                                                         │
│  1. Take a pg_dump snapshot BEFORE applying migrations  │
│  2. Apply migration in a staging environment first      │
│  3. If production migration fails:                      │
│     a. Halt API servers (prevent further writes)        │
│     b. Restore from pre-migration snapshot              │
│     c. Re-deploy previous application version           │
│     d. Investigate root cause before re-attempting      │
│                                                         │
└────────────────────────────────────────────────────────┘
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Administrator setup and management |
| [Enterprise Deployment](ENTERPRISE_DEPLOYMENT.md) | Deployment options and infrastructure |
| [Database Schema (CoreData)](../architecture/DATABASE_SCHEMA.md) | Client-side CoreData schema |
| [Architecture Overview](../architecture/ARCHITECTURE.md) | System architecture |
| [Security](../security/SECURITY.md) | Encryption and privacy model |

---

*Last updated: 2026-02-28*
