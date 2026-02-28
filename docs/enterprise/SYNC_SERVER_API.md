# Self-Hosted Sync Server API Reference

> **Last Updated**: 2026-02-28 | **Reading Time**: 20 minutes

Complete REST API specification for the PasteShelf self-hosted sync server (Vapor/Swift).

---

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Versioning Policy](#versioning-policy)
- [Rate Limiting](#rate-limiting)
- [Error Codes](#error-codes)
- [Endpoint Reference](#endpoint-reference)
  - [Health](#health)
  - [Auth](#auth)
  - [Devices](#devices)
  - [Sync](#sync)

---

## Overview

### Zero-Knowledge Architecture

The PasteShelf sync server stores **end-to-end encrypted blobs** only. The server never has access to encryption keys and never decrypts `encryptedData` fields. All encryption and decryption happens exclusively on client devices.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Zero-Knowledge Sync Architecture                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Device A                                                               │
│   ┌──────────────────┐                                                   │
│   │  Plaintext Data  │                                                   │
│   │  "Hello, World"  │                                                   │
│   └────────┬─────────┘                                                   │
│            │  Encrypt with device key (never leaves device)              │
│            ▼                                                             │
│   ┌──────────────────┐         ┌───────────────────────────────┐        │
│   │  Encrypted Blob  │──POST──▶│       Sync Server             │        │
│   │  "xK93mP2Lz..."  │         │  ┌─────────────────────────┐  │        │
│   └──────────────────┘         │  │  Stores opaque blob     │  │        │
│                                │  │  Never decrypts data    │  │        │
│   Device B                     │  │  No plaintext exposure  │  │        │
│   ┌──────────────────┐         │  └─────────────────────────┘  │        │
│   │  Encrypted Blob  │◀─GET───│                               │        │
│   │  "xK93mP2Lz..."  │         └───────────────────────────────┘        │
│   └────────┬─────────┘                                                   │
│            │  Decrypt with shared device key                             │
│            ▼                                                             │
│   ┌──────────────────┐                                                   │
│   │  Plaintext Data  │                                                   │
│   │  "Hello, World"  │                                                   │
│   └──────────────────┘                                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Design Principles

| Principle | Implementation |
|-----------|---------------|
| Zero-knowledge | Server stores only ciphertext; no plaintext ever transmitted |
| Stateless server | JWT-based auth; server holds no session state |
| Idempotent sync | Change IDs are UUIDs; duplicate pushes are safely ignored |
| Conflict resolution | Client receives conflicting server versions and resolves locally |
| Auditability | All operations emit structured audit log entries |

### Global Conventions

- **Base URL**: `https://sync.your-domain.com` (self-hosted) or configured in MDM profile
- **Protocol**: HTTPS only; HTTP connections are rejected with `426 Upgrade Required`
- **Content-Type**: `application/json` for all request and response bodies
- **Character encoding**: UTF-8
- **Timestamps**: ISO 8601 with UTC timezone (e.g. `2026-02-28T14:30:00Z`)
- **Identifiers**: UUID v4 (e.g. `550e8400-e29b-41d4-a716-446655440000`)
- **Encrypted payloads**: Base64-encoded ciphertext (standard encoding, no line breaks)
- **Content hashes**: SHA-256 hex digest of the plaintext before encryption

---

## Authentication

The server supports two authentication schemes that can be used interchangeably on all sync endpoints.

### Bearer JWT

Short-lived access tokens (1-hour expiry) issued after SSO authentication. Suitable for interactive sessions.

```
Authorization: Bearer <JWT>
```

### API Key

Long-lived tokens (30-day expiry by default, configurable) for persistent device authentication. Suitable for background sync operations. API keys are generated from an authenticated JWT session.

```
Authorization: Api-Key <key>
```

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Authentication Flows                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   FLOW 1: Interactive Login (SSO → JWT)                                  │
│   ─────────────────────────────────────                                  │
│                                                                          │
│   Client            SSO Provider         Sync Server                    │
│     │                    │                    │                          │
│     │─── SSO Login ─────▶│                   │                          │
│     │◀── SSO Token ──────│                   │                          │
│     │                    │                   │                          │
│     │─── POST /api/v1/auth/token ───────────▶│                          │
│     │    { ssoToken, ssoProvider, ... }       │                          │
│     │◀── { accessToken (1h), refreshToken } ─│                          │
│     │                                        │                          │
│   FLOW 2: Token Refresh                                                  │
│   ─────────────────────                                                  │
│                                                                          │
│     │─── POST /api/v1/auth/refresh ─────────▶│                          │
│     │    Authorization: Bearer <refreshToken> │                          │
│     │◀── { accessToken (1h), refreshToken } ─│                          │
│     │                                        │                          │
│   FLOW 3: API Key for Background Sync                                    │
│   ────────────────────────────────────                                   │
│                                                                          │
│     │─── POST /api/v1/auth/apikey ──────────▶│                          │
│     │    Authorization: Bearer <JWT>          │                          │
│     │◀── { keyId, apiKey, expiresAt } ───────│                          │
│     │                                        │                          │
│     │─── POST /api/v1/sync/push ────────────▶│                          │
│     │    Authorization: Api-Key <apiKey>      │                          │
│     │◀── 200 OK ─────────────────────────────│                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Versioning Policy

All endpoints are versioned under `/api/v1/`. When breaking changes are introduced:

1. A new version path (e.g. `/api/v2/`) is published alongside the existing version.
2. The old version is supported for a minimum of **12 months** after the new version ships.
3. Deprecation notices are delivered via a `Deprecation` response header and documented in the server release notes.
4. Non-breaking additions (new optional fields, new endpoints) are made to the existing version without incrementing the version number.

---

## Rate Limiting

Rate limits are enforced per authenticated identity (user + device combination).

| Endpoint Group | Limit | Window |
|----------------|-------|--------|
| Auth endpoints | 20 requests | 1 minute |
| Sync push/pull | 120 requests | 1 minute |
| Device management | 30 requests | 1 minute |
| Health endpoints | Unlimited | — |

When a limit is exceeded the server responds with `429 Too Many Requests` and includes the following headers:

| Header | Description |
|--------|-------------|
| `X-RateLimit-Limit` | Maximum requests allowed in the window |
| `X-RateLimit-Remaining` | Requests remaining in the current window |
| `X-RateLimit-Reset` | Unix timestamp when the window resets |
| `Retry-After` | Seconds to wait before retrying |

```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 120
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1740751200
Retry-After: 37
Content-Type: application/json

{
  "error": "rate_limit_exceeded",
  "message": "Too many requests. Retry after 37 seconds.",
  "retryAfter": 37
}
```

---

## Error Codes

All error responses share a common envelope:

```json
{
  "error": "error_code",
  "message": "Human-readable description.",
  "requestId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

The `requestId` field correlates to server log entries and should be included when contacting support.

### HTTP Status Codes

| Status | Meaning | Common Causes |
|--------|---------|---------------|
| `200 OK` | Success | — |
| `201 Created` | Resource created | Device registration |
| `400 Bad Request` | Invalid request body | Missing required fields, malformed UUID |
| `401 Unauthorized` | Authentication failed | Missing, expired, or invalid token |
| `403 Forbidden` | Authorization failed | Valid token but insufficient permissions |
| `404 Not Found` | Resource not found | Device ID or key ID does not exist |
| `409 Conflict` | Sync conflict | Server has a newer version of the entity |
| `413 Payload Too Large` | Request body too large | Push batch exceeds 200 changes |
| `422 Unprocessable Entity` | Validation error | Field value out of allowed range |
| `426 Upgrade Required` | HTTPS required | HTTP connection attempted |
| `429 Too Many Requests` | Rate limit exceeded | See Rate Limiting section |
| `500 Internal Server Error` | Server error | Contact server administrator |
| `503 Service Unavailable` | Server unavailable | Maintenance window or overload |

### Application Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `invalid_sso_token` | 401 | The SSO token is expired, malformed, or from an unrecognized provider |
| `invalid_organization` | 403 | The organization ID is unknown or the license is inactive |
| `token_expired` | 401 | The JWT or refresh token has expired |
| `token_invalid` | 401 | The JWT signature is invalid |
| `apikey_invalid` | 401 | The API key is unrecognized or has been revoked |
| `apikey_expired` | 401 | The API key has passed its expiry date |
| `device_not_registered` | 403 | The device ID in the request is not registered for this user |
| `device_limit_exceeded` | 403 | The organization has reached its maximum device count |
| `batch_too_large` | 413 | Push batch contains more than 200 change records |
| `entity_type_unknown` | 400 | The `entityType` field contains an unrecognized value |
| `change_type_unknown` | 400 | The `changeType` field contains an unrecognized value |
| `rate_limit_exceeded` | 429 | See Rate Limiting section |

---

## Endpoint Reference

### Health

#### GET /health

Liveness probe. Returns immediately without checking downstream dependencies. Used by load balancers to confirm the process is running.

**Authentication**: None required.

**Response 200**

```json
{
  "status": "ok",
  "version": "1.4.2",
  "timestamp": "2026-02-28T14:30:00Z"
}
```

---

#### GET /api/v1/health/ready

Readiness probe. Checks that the server can service requests, including verifying the database connection. Used by orchestrators (Kubernetes, Docker Compose) to gate traffic.

**Authentication**: None required.

**Response 200** — Server is ready

```json
{
  "status": "ready",
  "checks": {
    "database": "ok",
    "migrations": "up_to_date"
  },
  "version": "1.4.2",
  "timestamp": "2026-02-28T14:30:00Z"
}
```

**Response 503** — Server is not ready

```json
{
  "status": "not_ready",
  "checks": {
    "database": "error",
    "migrations": "up_to_date"
  },
  "message": "Database connection unavailable.",
  "timestamp": "2026-02-28T14:30:00Z"
}
```

---

### Auth

#### POST /api/v1/auth/token

Exchange an SSO token for a server-issued JWT access token and a long-lived refresh token. The server validates the SSO token with the configured identity provider, confirms the user belongs to a licensed organization, and returns credentials for subsequent API calls.

**Authentication**: SSO Token (provided in the request body; no `Authorization` header required).

**Request**

```json
{
  "ssoToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "ssoProvider": "oidc",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ssoToken` | string | Yes | Raw token from the identity provider |
| `ssoProvider` | `"oidc"` \| `"saml"` | Yes | Protocol used by the identity provider |
| `organizationId` | UUID | Yes | Organization the user is authenticating against |
| `deviceId` | UUID | Yes | Stable device identifier; used to bind the refresh token to a device |

**Response 200**

```json
{
  "accessToken": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "dGhpcyBpcyBhIG9wYXF1ZSByZWZyZXNoIHRva2Vu",
  "expiresAt": "2026-02-28T15:30:00Z",
  "userId": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `accessToken` | string | JWT for use in `Authorization: Bearer` header; expires in 1 hour |
| `refreshToken` | string | Opaque token for refreshing the access token; expires in 30 days |
| `expiresAt` | ISO 8601 | Absolute expiry time of the `accessToken` |
| `userId` | UUID | Server-assigned user identifier |
| `organizationId` | UUID | Confirmed organization identifier |

**Error responses**: `400 invalid_organization`, `401 invalid_sso_token`, `403 device_limit_exceeded`

---

#### POST /api/v1/auth/refresh

Obtain a new access token using a valid refresh token before or after the access token expires. Refresh tokens are single-use; this endpoint issues a new refresh token with each response (token rotation).

**Authentication**: The refresh token is passed in the `Authorization` header as a Bearer token.

```
Authorization: Bearer <refreshToken>
```

**Request body**: Empty — no body required.

**Response 200**

```json
{
  "accessToken": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "bmV3UmVmcmVzaFRva2VuSGVyZQ==",
  "expiresAt": "2026-02-28T16:45:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `accessToken` | string | New JWT; previous access token is immediately invalidated |
| `refreshToken` | string | New refresh token; previous refresh token is invalidated |
| `expiresAt` | ISO 8601 | Expiry of the new `accessToken` |

**Error responses**: `401 token_expired`, `401 token_invalid`

---

#### POST /api/v1/auth/apikey

Generate a persistent API key bound to the authenticated user and device. API keys are intended for background daemon processes that cannot perform interactive SSO on each launch.

The raw API key value is returned **only once** in this response. Store it securely in the macOS Keychain. The server stores only a hashed representation.

**Authentication**: `Authorization: Bearer <JWT>`

**Request**

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "label": "MacBook Pro — Background Sync",
  "expiresInDays": 30
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | UUID | Yes | Device the key is bound to |
| `label` | string | No | Human-readable label shown in the admin console |
| `expiresInDays` | integer | No | Key lifetime in days (1–365); defaults to 30 |

**Response 201**

```json
{
  "keyId": "c3d4e5f6-a7b8-9012-cdef-123456789012",
  "apiKey": "psk_live_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789",
  "label": "MacBook Pro — Background Sync",
  "createdAt": "2026-02-28T14:30:00Z",
  "expiresAt": "2026-03-30T14:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `keyId` | UUID | Identifier used to revoke this key |
| `apiKey` | string | Full API key value; shown only once — store immediately |
| `label` | string | Label as stored |
| `createdAt` | ISO 8601 | Key creation time |
| `expiresAt` | ISO 8601 | Key expiry time |

**Error responses**: `401 token_expired`, `401 token_invalid`

---

#### DELETE /api/v1/auth/apikey/{keyId}

Revoke an API key immediately. Any in-flight or subsequent requests using the revoked key will receive `401 apikey_invalid`. This operation cannot be undone.

**Authentication**: `Authorization: Bearer <JWT>`

**Path parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `keyId` | UUID | The key identifier returned when the key was created |

**Request body**: Empty — no body required.

**Response 204**: No content. Key has been revoked.

**Error responses**: `401 token_expired`, `401 token_invalid`, `404` (key not found or does not belong to the authenticated user)

---

### Devices

#### POST /api/v1/devices/register

Register a device to participate in sync. A device must be registered before pushing or pulling changes. Registering an already-registered device ID is idempotent — the existing record is returned with a `200` status instead of `201`.

**Authentication**: `Authorization: Bearer <JWT>`

**Request**

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "deviceName": "MacBook Pro (14-inch, M3)",
  "osVersion": "macOS 15.2",
  "appVersion": "2.4.1"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | UUID | Yes | Stable, client-generated identifier; persist across app reinstalls |
| `deviceName` | string | Yes | Human-readable device name for admin console display |
| `osVersion` | string | Yes | macOS version string |
| `appVersion` | string | Yes | PasteShelf app version string |

**Response 201** — New device registered

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "registeredAt": "2026-02-28T14:30:00Z",
  "syncToken": null
}
```

**Response 200** — Device already registered (idempotent)

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "registeredAt": "2026-01-15T09:00:00Z",
  "syncToken": "c2luY1Rva2VuT3BhcXVlVmFsdWU="
}
```

| Field | Type | Description |
|-------|------|-------------|
| `deviceId` | UUID | Confirmed device identifier |
| `registeredAt` | ISO 8601 | When the device was first registered |
| `syncToken` | string \| null | Current sync cursor; null for brand-new devices; use with `/sync/pull` |

**Error responses**: `400 Bad Request`, `403 device_limit_exceeded`

---

#### GET /api/v1/devices

List all devices registered to the authenticated user.

**Authentication**: `Authorization: Bearer <JWT>`

**Request body**: Empty — no body required.

**Response 200**

```json
{
  "devices": [
    {
      "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "deviceName": "MacBook Pro (14-inch, M3)",
      "osVersion": "macOS 15.2",
      "appVersion": "2.4.1",
      "registeredAt": "2026-01-15T09:00:00Z",
      "lastSeenAt": "2026-02-28T14:28:00Z"
    },
    {
      "deviceId": "d4e5f6a7-b8c9-0123-def0-123456789012",
      "deviceName": "Mac mini (M4, 2025)",
      "osVersion": "macOS 15.2",
      "appVersion": "2.4.1",
      "registeredAt": "2026-02-01T12:00:00Z",
      "lastSeenAt": "2026-02-27T20:00:00Z"
    }
  ],
  "total": 2
}
```

| Field | Type | Description |
|-------|------|-------------|
| `devices` | array | Registered devices for this user |
| `devices[].deviceId` | UUID | Device identifier |
| `devices[].deviceName` | string | Human-readable device name |
| `devices[].osVersion` | string | macOS version at last registration or update |
| `devices[].appVersion` | string | App version at last registration or update |
| `devices[].registeredAt` | ISO 8601 | First registration timestamp |
| `devices[].lastSeenAt` | ISO 8601 | Most recent authenticated API call from this device |
| `total` | integer | Total number of registered devices |

---

#### DELETE /api/v1/devices/{deviceId}

Unregister a device. All sync state for the device is removed from the server. The device will need to perform a full pull sync if it is re-registered.

**Authentication**: `Authorization: Bearer <JWT>`

**Path parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `deviceId` | UUID | Device to unregister |

**Request body**: Empty — no body required.

**Response 204**: No content. Device unregistered.

**Error responses**: `401 token_expired`, `401 token_invalid`, `404` (device not found or does not belong to the authenticated user)

---

### Sync

#### POST /api/v1/sync/push

Push a batch of encrypted change records from the device to the server. The server assigns a server-side timestamp and appends the changes to the log for distribution to other devices.

The server validates structural fields (UUIDs, change type values, etc.) but **never inspects `encryptedData`**. The `contentHash` is stored verbatim for client-side integrity verification after decryption.

**Authentication**: `Authorization: Bearer <JWT>` or `Authorization: Api-Key <key>`

**Limits**: Maximum 200 change records per request. Split larger batches into multiple sequential calls.

**Request**

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "changes": [
    {
      "id": "e5f6a7b8-c9d0-1234-ef01-234567890123",
      "changeType": "insert",
      "entityType": "ClipboardItem",
      "entityId": "f6a7b8c9-d0e1-2345-f012-345678901234",
      "encryptedData": "xK93mP2LzQr4TsUvWxYzAbCdEfGhIjKlMnOpQrStUvWx...",
      "contentHash": "a3f5c8d2e1b4967f0c2e5a8b3d6f9c2e1a4b7d0f3e6c9b2a5d8f1c4e7b0a3d6",
      "localTimestamp": "2026-02-28T14:29:55Z"
    },
    {
      "id": "a7b8c9d0-e1f2-3456-0123-456789012345",
      "changeType": "delete",
      "entityType": "ClipboardItem",
      "entityId": "b8c9d0e1-f2a3-4567-1234-567890123456",
      "encryptedData": null,
      "contentHash": null,
      "localTimestamp": "2026-02-28T14:29:58Z"
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | UUID | Yes | Registered device submitting the changes |
| `changes` | array | Yes | Batch of change records (1–200 items) |
| `changes[].id` | UUID | Yes | Client-generated unique ID for this change record; used for deduplication |
| `changes[].changeType` | `"insert"` \| `"update"` \| `"delete"` | Yes | Type of change |
| `changes[].entityType` | `"ClipboardItem"` \| `"Tag"` \| `"Folder"` | Yes | Entity type being changed |
| `changes[].entityId` | UUID | Yes | Stable identifier of the entity being changed |
| `changes[].encryptedData` | base64 string \| null | Yes for insert/update | E2E encrypted entity payload; null for delete |
| `changes[].contentHash` | string \| null | Yes for insert/update | SHA-256 hex digest of plaintext before encryption; null for delete |
| `changes[].localTimestamp` | ISO 8601 | Yes | Device-local time when the change occurred |

**Response 200** — All changes accepted

```json
{
  "accepted": 2,
  "rejected": 0,
  "newSyncToken": "c2luY1Rva2VuT3BhcXVlVmFsdWU=",
  "serverTimestamp": "2026-02-28T14:30:01Z"
}
```

**Response 409** — One or more changes conflict with server state

The server returns `409` when a submitted change targets an entity that has a newer server-side version. This occurs when two devices modify the same entity concurrently. The client is responsible for resolution (e.g. last-write-wins, CRDT merge, or user prompt).

```json
{
  "accepted": 1,
  "conflicts": [
    {
      "entityId": "f6a7b8c9-d0e1-2345-f012-345678901234",
      "serverVersion": {
        "encryptedData": "yL04nQ3MaRs5UtVwXyZaBcDeFgHiJkLmNoPqRsTuVwXy...",
        "serverTimestamp": "2026-02-28T14:29:30Z"
      }
    }
  ],
  "newSyncToken": "bmV3U3luY1Rva2VuVmFsdWU=",
  "serverTimestamp": "2026-02-28T14:30:01Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `accepted` | integer | Number of changes stored successfully |
| `rejected` | integer | Number of changes that could not be stored (validation errors) |
| `conflicts` | array | Present in 409 only; conflicting entities with their server versions |
| `conflicts[].entityId` | UUID | Entity that has a conflict |
| `conflicts[].serverVersion.encryptedData` | base64 | Server's current encrypted payload for the entity |
| `conflicts[].serverVersion.serverTimestamp` | ISO 8601 | When the server version was last written |
| `newSyncToken` | string | Updated sync cursor; use in the next `/sync/pull` call |
| `serverTimestamp` | ISO 8601 | Server time when the response was generated |

**Error responses**: `400 entity_type_unknown`, `400 change_type_unknown`, `403 device_not_registered`, `413 batch_too_large`

---

#### POST /api/v1/sync/pull

Pull changes from the server since a given sync token. Returns changes made by all other devices (the requesting device's own changes are excluded from the response). Responses are paginated; call repeatedly with the returned `newSyncToken` until `hasMore` is false.

Pass `sinceSyncToken: null` for a brand-new device to receive the full change history.

**Authentication**: `Authorization: Bearer <JWT>` or `Authorization: Api-Key <key>`

**Request**

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "sinceSyncToken": "c2luY1Rva2VuT3BhcXVlVmFsdWU=",
  "limit": 100
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceId` | UUID | Yes | Registered device requesting changes |
| `sinceSyncToken` | string \| null | Yes | Pagination cursor from a previous push or pull response; null for initial sync |
| `limit` | integer | No | Maximum changes to return per page (1–200); defaults to 100 |

**Response 200**

```json
{
  "changes": [
    {
      "id": "e5f6a7b8-c9d0-1234-ef01-234567890123",
      "changeType": "insert",
      "entityType": "ClipboardItem",
      "entityId": "f6a7b8c9-d0e1-2345-f012-345678901234",
      "encryptedData": "xK93mP2LzQr4TsUvWxYzAbCdEfGhIjKlMnOpQrStUvWx...",
      "contentHash": "a3f5c8d2e1b4967f0c2e5a8b3d6f9c2e1a4b7d0f3e6c9b2a5d8f1c4e7b0a3d6",
      "serverTimestamp": "2026-02-28T14:30:01Z",
      "sourceDeviceId": "d4e5f6a7-b8c9-0123-def0-123456789012"
    }
  ],
  "newSyncToken": "bmV3U3luY1Rva2VuVmFsdWU=",
  "hasMore": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `changes` | array | Change records from other devices since the sync token |
| `changes[].id` | UUID | Original client-generated change record ID |
| `changes[].changeType` | string | `"insert"`, `"update"`, or `"delete"` |
| `changes[].entityType` | string | `"ClipboardItem"`, `"Tag"`, or `"Folder"` |
| `changes[].entityId` | UUID | Entity being changed |
| `changes[].encryptedData` | base64 \| null | Encrypted payload; null for delete changes |
| `changes[].contentHash` | string \| null | SHA-256 hex digest for integrity verification after decryption; null for delete |
| `changes[].serverTimestamp` | ISO 8601 | When the server received and stored this change |
| `changes[].sourceDeviceId` | UUID | Device that originally pushed this change |
| `newSyncToken` | string | Cursor to use in the next pull request |
| `hasMore` | boolean | True if more pages are available; continue pulling until false |

**Error responses**: `400 Bad Request`, `403 device_not_registered`

---

#### GET /api/v1/sync/status

Return the current sync state for the authenticated device, including the latest sync token and the count of changes pending delivery.

**Authentication**: `Authorization: Bearer <JWT>` or `Authorization: Api-Key <key>`

**Query parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `deviceId` | UUID | Yes | Device to query (`?deviceId=<uuid>`) |

**Response 200**

```json
{
  "deviceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "currentSyncToken": "c2luY1Rva2VuT3BhcXVlVmFsdWU=",
  "pendingChanges": 14,
  "lastSyncAt": "2026-02-28T14:28:00Z",
  "serverTimestamp": "2026-02-28T14:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `deviceId` | UUID | Device the status is for |
| `currentSyncToken` | string \| null | Most recent sync cursor for this device; null if never synced |
| `pendingChanges` | integer | Number of changes from other devices not yet pulled by this device |
| `lastSyncAt` | ISO 8601 \| null | Timestamp of last successful push or pull; null if never synced |
| `serverTimestamp` | ISO 8601 | Server time when the response was generated |

**Error responses**: `400 Bad Request`, `403 device_not_registered`

---

#### POST /api/v1/sync/reset

Delete all sync state for the authenticated user. This removes all stored change records and sync tokens for every device. All devices will need to perform a full re-upload followed by a full pull. This operation is irreversible.

This endpoint requires a Bearer JWT; API keys are not accepted to prevent automated processes from triggering a reset accidentally.

**Authentication**: `Authorization: Bearer <JWT>` only.

**Request body**: Empty — no body required.

**Response 200**

```json
{
  "message": "Sync data reset. All devices must re-synchronize.",
  "resetAt": "2026-02-28T14:30:00Z",
  "affectedDevices": 2
}
```

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Confirmation message |
| `resetAt` | ISO 8601 | When the reset was performed |
| `affectedDevices` | integer | Number of devices whose sync state was cleared |

**Error responses**: `401 token_expired`, `401 token_invalid`, `401 apikey_invalid` (API keys rejected for this endpoint)

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Deployment](ENTERPRISE_DEPLOYMENT.md) | How to deploy the self-hosted sync server |
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Admin console and policy management |
| [Security](../security/SECURITY.md) | Encryption implementation details |
| [Legal & Compliance](../security/LEGAL_COMPLIANCE.md) | Data residency and compliance |

---

*Last updated: 2026-02-28*
