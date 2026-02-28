# Sync Server WebSocket Protocol

> **Last Updated**: 2026-02-28 | **Reading Time**: 10 minutes

Real-time change notification protocol for the PasteShelf self-hosted sync server.

---

## Table of Contents

- [Overview](#overview)
- [Connection](#connection)
- [Message Format](#message-format)
- [Server to Client Messages](#server-to-client-messages)
- [Client to Server Messages](#client-to-server-messages)
- [Error Codes](#error-codes)
- [Connection Lifecycle](#connection-lifecycle)
- [Fallback Behavior](#fallback-behavior)
- [Server Implementation Notes](#server-implementation-notes)
- [Scaling to Multiple Instances](#scaling-to-multiple-instances)

---

## Overview

WebSocket in PasteShelf carries **notifications only** — it does not transfer clipboard data. The protocol is designed around a lightweight signal model:

1. Device A pushes changes to the server via REST (`POST /api/v1/sync/push`).
2. The server broadcasts a `changes_available` notification to all other connected devices belonging to the same user via WebSocket.
3. Those devices pull the actual data via REST (`GET /api/v1/sync/pull`).

This separation keeps the WebSocket layer simple, stateless with respect to data, and easy to scale.

```
Device A                   Sync Server                  Device B
   │                            │                            │
   │── POST /api/v1/sync/push ─▶│                            │
   │                            │── changes_available ──────▶│
   │                            │                            │
   │                            │◀── GET /api/v1/sync/pull ──│
   │                            │─── clipboard data ────────▶│
```

---

## Connection

### URL

```
wss://<server>/api/v1/ws?token=<JWT>&deviceId=<DEVICE_ID>
```

| Parameter  | Type   | Required | Description                                       |
|------------|--------|----------|---------------------------------------------------|
| `token`    | string | Yes      | JWT issued by the sync server authentication flow |
| `deviceId` | string | Yes      | Unique identifier of the connecting device        |

### Authentication

The JWT is validated on connection. If the token is missing, malformed, or expired, the server closes the connection immediately with close code `4001`.

### Keepalive

The client is responsible for sending a `ping` message every **30 seconds**. If the server does not receive a ping within 90 seconds, it may close the connection. The server responds to each ping with a `pong` message.

### Reconnection

Clients must implement exponential backoff on disconnect:

| Attempt | Delay   |
|---------|---------|
| 1       | 1 s     |
| 2       | 2 s     |
| 3       | 4 s     |
| 4       | 8 s     |
| 5       | 16 s    |
| 6+      | 60 s    |

Backoff resets after a successful reconnection. On receiving `auth_expired`, the client must refresh the JWT before attempting to reconnect — do not retry with an expired token.

---

## Message Format

All messages are JSON payloads transmitted over **WebSocket text frames**. Binary frames are not used.

Every message contains a `type` field that identifies the message kind. All other fields are specific to the message type.

---

## Server to Client Messages

### `changes_available`

Sent when another device belonging to the same user has pushed new changes. Upon receiving this message, the client should fetch the new data via `GET /api/v1/sync/pull?since=<since>`.

```json
{
    "type": "changes_available",
    "since": "opaque-server-token",
    "changeCount": 3,
    "sourceDeviceId": "DDDD-EEEE-FFFF",
    "timestamp": "2026-02-28T18:00:01Z"
}
```

| Field            | Type    | Description                                                                 |
|------------------|---------|-----------------------------------------------------------------------------|
| `since`          | string  | Opaque cursor token to pass to the pull endpoint as the `since` parameter   |
| `changeCount`    | integer | Number of new change records available; informational, not authoritative    |
| `sourceDeviceId` | string  | Device ID that pushed the changes; clients may use this to skip self-pulls  |
| `timestamp`      | string  | ISO 8601 UTC timestamp of when the changes were received by the server      |

### `force_sync`

Sent by the server when an administrator triggers a synchronization across all devices — for example, after a policy update that requires clients to re-evaluate their local data.

```json
{
    "type": "force_sync",
    "reason": "policy_update"
}
```

| Field    | Type   | Description                                                            |
|----------|--------|------------------------------------------------------------------------|
| `reason` | string | Human-readable reason code; informational. Example: `policy_update`    |

Upon receiving `force_sync`, the client should perform a full sync pull regardless of its local state.

### `device_removed`

Sent when an administrator removes the device from the organization. The client should immediately stop sync operations, clear any locally cached sync tokens, and prompt the user.

```json
{
    "type": "device_removed",
    "reason": "admin_action"
}
```

| Field    | Type   | Description                                              |
|----------|--------|----------------------------------------------------------|
| `reason` | string | Reason for removal. Example: `admin_action`              |

After receiving this message the server closes the connection with close code `4002`.

### `auth_expired`

Sent when the server detects that the client's JWT has expired during an active session (for example, if token lifetime is shorter than the connection duration). The client should refresh its JWT and reconnect.

```json
{
    "type": "auth_expired"
}
```

After sending this message the server closes the connection with close code `4001`.

### `pong`

Response to a client `ping`. The client uses this to confirm the connection is alive.

```json
{
    "type": "pong"
}
```

---

## Client to Server Messages

### `ping`

Keepalive heartbeat. Must be sent every 30 seconds to prevent the connection from being closed.

```json
{
    "type": "ping"
}
```

The server responds with a `pong` message.

---

## Error Codes

WebSocket close codes in the range `4000–4999` are application-defined. PasteShelf uses the following:

| Code | Name                  | Description                                                              |
|------|-----------------------|--------------------------------------------------------------------------|
| 4001 | Authentication expired | JWT is missing, invalid, or expired. Refresh token and reconnect.        |
| 4002 | Device removed         | Device was deregistered by an administrator. Do not reconnect.           |
| 4003 | Server shutting down   | Server is performing a graceful shutdown. Reconnect after backoff.       |
| 4004 | Rate limited           | Too many connection attempts. Back off before reconnecting.              |

Clients should inspect the close code and react accordingly:

- **4001**: Refresh JWT, then reconnect with a new token.
- **4002**: Stop sync, clear sync tokens, notify user. Do not reconnect.
- **4003**: Apply exponential backoff and reconnect normally.
- **4004**: Apply extended backoff (start at 60 s) before reconnecting.

---

## Connection Lifecycle

```
Client                              Server
  │                                    │
  │── wss://…?token=JWT&deviceId=… ───▶│  Validate JWT + deviceId
  │                                    │
  │◀──────────── 101 Switching ────────│  Connection established
  │                                    │
  │  (30 s timer fires)                │
  │── { "type": "ping" } ─────────────▶│
  │◀── { "type": "pong" } ─────────────│
  │                                    │
  │  (Another device pushes changes)   │
  │◀── { "type": "changes_available" }─│
  │                                    │
  │── GET /api/v1/sync/pull?since=… ──▶│  (REST, not WebSocket)
  │◀── clipboard data ─────────────────│
  │                                    │
  │  (Admin removes device)            │
  │◀── { "type": "device_removed" } ───│
  │◀──────────── close 4002 ───────────│
```

---

## Fallback Behavior

WebSocket is the preferred notification transport. When a WebSocket connection cannot be established or is lost, clients fall back to **REST polling**:

- Poll interval: every **5 minutes**
- Endpoint: `GET /api/v1/sync/pull?since=<last-cursor>`
- Polling stops and WebSocket reconnection resumes once connectivity is restored

The fallback ensures sync continues in environments where WebSocket connections are blocked (for example, some corporate proxies).

---

## Server Implementation Notes

### Connection Tracking

The server maintains an in-memory map of active connections keyed by `(userId, deviceId)`. Each entry holds the WebSocket connection handle.

```
connectionMap: Map<userId, Map<deviceId, WebSocketConnection>>
```

When a device reconnects with the same `deviceId`, the old connection is replaced.

### Broadcasting `changes_available`

When Device A pushes changes via `POST /api/v1/sync/push`:

1. The server processes and persists the changes.
2. The server looks up all connections for the same `userId`.
3. It sends `changes_available` to every connection **except** the one with `deviceId` matching Device A's `deviceId`.
4. The `since` token in the message is the opaque cursor for the newly committed change set.

### JWT Validation on Connect

1. Extract `token` from the query string.
2. Validate signature, issuer, and expiry.
3. Extract `userId` and confirm `deviceId` is registered to that user.
4. On any failure, close with `4001` before the handshake completes.

---

## Scaling to Multiple Instances

In a single-instance deployment, the in-memory connection map is sufficient. For multi-instance deployments (load-balanced horizontally), the connection map must be shared across instances.

The recommended approach is **Redis Pub/Sub**:

```
Device A ──▶ Instance 1 ──▶ Redis channel "user:<userId>" ──▶ Instance 2 ──▶ Device B
                                                            └──▶ Instance 3 ──▶ Device C
```

When Instance 1 receives a push from Device A:

1. It publishes a `changes_available` payload to the Redis channel `user:<userId>`.
2. All instances (including Instance 1) subscribed to that channel receive the message.
3. Each instance broadcasts to its locally connected devices for that user, skipping the source `deviceId`.

This pattern requires no shared state beyond the Redis channel and does not require sticky sessions.

> **Note**: Redis Pub/Sub is optional and only required when running more than one sync server instance. Single-instance deployments do not need Redis for WebSocket routing.

---

*For REST API documentation, see the [Sync Server API Reference](../api/API_DOCUMENTATION.md).*
*For deployment instructions, see the [Enterprise Deployment Guide](ENTERPRISE_DEPLOYMENT.md).*
