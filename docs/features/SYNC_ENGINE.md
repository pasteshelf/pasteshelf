# Sync Engine

> **Last Updated**: 2026-02-03 | **Reading Time**: 18 minutes

Documentation for PasteShelf's cross-device synchronization system.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [CloudKit Integration](#cloudkit-integration)
- [Sync Protocol](#sync-protocol)
- [Conflict Resolution](#conflict-resolution)
- [Encryption](#encryption)
- [Self-Hosted Option](#self-hosted-option)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Sync Engine enables clipboard history synchronization across devices ⭐.

| Feature | Tier | Description |
|---------|------|-------------|
| iCloud Sync | ⭐ Pro | Sync via Apple CloudKit |
| E2E Encryption | ⭐ Pro | End-to-end encryption |
| Selective Sync | ⭐ Pro | Choose what to sync |
| Self-Hosted Sync | 🏢 Enterprise | On-premise sync server |
| Team Sync | 🏢 Enterprise | Share across team members |

### Sync Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Sync Architecture                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Device A (MacBook)              Cloud              Device B (iMac)     │
│   ──────────────────              ─────              ──────────────      │
│                                                                          │
│   ┌──────────────────┐      ┌─────────────────┐    ┌──────────────────┐ │
│   │   Local Store    │      │    CloudKit     │    │   Local Store    │ │
│   │   ──────────     │      │    ─────────    │    │   ──────────     │ │
│   │                  │      │                 │    │                  │ │
│   │   ClipboardItem  │◀────▶│  Private DB     │◀──▶│   ClipboardItem  │ │
│   │   ClipboardItem  │      │  Custom Zone    │    │   ClipboardItem  │ │
│   │   ClipboardItem  │      │  E2E Encrypted  │    │   ClipboardItem  │ │
│   │                  │      │                 │    │                  │ │
│   └────────┬─────────┘      └────────┬────────┘    └────────┬─────────┘ │
│            │                         │                      │            │
│   ┌────────▼─────────┐      ┌────────▼────────┐    ┌────────▼─────────┐ │
│   │   Sync Engine    │      │  Push/Pull      │    │   Sync Engine    │ │
│   │   ───────────    │      │  Notifications  │    │   ───────────    │ │
│   │                  │      │                 │    │                  │ │
│   │  • Change track  │─────▶│  • Zone changes │───▶│  • Change track  │ │
│   │  • Encrypt       │      │  • Subscriptions│    │  • Decrypt       │ │
│   │  • Conflict res  │◀─────│  • Silent push  │◀───│  • Conflict res  │ │
│   └──────────────────┘      └─────────────────┘    └──────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Sync Engine Components                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      SyncManager                                 │   │
│   │                      ───────────                                 │   │
│   │                                                                  │   │
│   │   Main coordinator for all sync operations                       │   │
│   │                                                                  │   │
│   │   Properties:                                                    │   │
│   │   • syncStatus: SyncStatus                                       │   │
│   │   • lastSyncDate: Date?                                          │   │
│   │   • pendingChanges: Int                                          │   │
│   │                                                                  │   │
│   │   Methods:                                                       │   │
│   │   • startSync()                                                  │   │
│   │   • stopSync()                                                   │   │
│   │   • forceSync()                                                  │   │
│   │   • resetSync()                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│            ┌─────────────────────────┼─────────────────────────┐        │
│            │                         │                         │        │
│            ▼                         ▼                         ▼        │
│   ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐│
│   │ ChangeTracker   │      │CloudKitProvider │      │ConflictResolver ││
│   │ ─────────────   │      │────────────────  │      │─────────────────││
│   │                 │      │                 │      │                 ││
│   │ Track local     │      │ CloudKit API    │      │ Resolve sync    ││
│   │ changes since   │      │ wrapper with    │      │ conflicts with  ││
│   │ last sync       │      │ error handling  │      │ configurable    ││
│   │                 │      │                 │      │ strategies      ││
│   └─────────────────┘      └─────────────────┘      └─────────────────┘│
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Sync States

```swift
enum SyncStatus {
    case disabled
    case idle
    case syncing(progress: Double)
    case error(SyncError)
    case paused

    var description: String {
        switch self {
        case .disabled:
            return "Sync disabled"
        case .idle:
            return "Up to date"
        case .syncing(let progress):
            return "Syncing... \(Int(progress * 100))%"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        case .paused:
            return "Sync paused"
        }
    }
}
```

---

## CloudKit Integration

### Container Setup

```swift
class CloudKitProvider {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let customZone: CKRecordZone

    static let zoneName = "com.pasteshelf.clipboardHistory"

    init() {
        container = CKContainer(identifier: "iCloud.com.pasteshelf.PasteShelf")
        privateDatabase = container.privateCloudDatabase

        customZone = CKRecordZone(zoneName: Self.zoneName)
    }

    func setupZone() async throws {
        // Create custom zone if not exists
        do {
            _ = try await privateDatabase.save(customZone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, ignore
        }

        // Create subscription for changes
        try await createSubscription()
    }

    private func createSubscription() async throws {
        let subscription = CKRecordZoneSubscription(
            zoneID: customZone.zoneID,
            subscriptionID: "clipboard-changes"
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent push

        subscription.notificationInfo = notificationInfo

        _ = try await privateDatabase.save(subscription)
    }
}
```

### Record Mapping

```swift
extension ClipboardItem {
    /// Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: id.uuidString,
            zoneID: CKRecordZone.ID(zoneName: CloudKitProvider.zoneName)
        )

        let record = CKRecord(recordType: "ClipboardItem", recordID: recordID)

        // Encrypt content before storing
        if let encryptedContent = try? EncryptionManager.shared.encrypt(content.data) {
            record["encryptedContent"] = encryptedContent as CKRecordValue
        }

        record["contentType"] = contentType.rawValue as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["sourceApp"] = sourceApp?.bundleId as CKRecordValue?
        record["isFavorite"] = isFavorite as CKRecordValue
        record["isPinned"] = isPinned as CKRecordValue

        // Large content as asset
        if let imageData = content.imageData, imageData.count > 1_000_000 {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try? imageData.write(to: tempURL)
            record["contentAsset"] = CKAsset(fileURL: tempURL)
        }

        return record
    }

    /// Create from CloudKit record
    static func from(_ record: CKRecord) throws -> ClipboardItem {
        guard let encryptedContent = record["encryptedContent"] as? Data else {
            throw SyncError.invalidRecord
        }

        // Decrypt content
        let contentData = try EncryptionManager.shared.decrypt(encryptedContent)
        let content = try JSONDecoder().decode(ClipboardContent.self, from: contentData)

        return ClipboardItem(
            id: UUID(uuidString: record.recordID.recordName)!,
            content: content,
            contentType: ContentType(rawValue: record["contentType"] as! String)!,
            createdAt: record["createdAt"] as! Date,
            modifiedAt: record["modifiedAt"] as! Date,
            sourceApp: (record["sourceApp"] as? String).map { SourceApp(bundleId: $0) },
            isFavorite: record["isFavorite"] as? Bool ?? false,
            isPinned: record["isPinned"] as? Bool ?? false
        )
    }
}
```

---

## Sync Protocol

### Push Changes

```swift
class SyncManager {
    func pushChanges() async throws {
        let pendingChanges = changeTracker.getPendingChanges()

        guard !pendingChanges.isEmpty else { return }

        // Batch operations
        let modifyOperation = CKModifyRecordsOperation(
            recordsToSave: pendingChanges.toSave.map { $0.toCKRecord() },
            recordIDsToDelete: pendingChanges.toDelete.map { $0.recordID }
        )

        modifyOperation.savePolicy = .changedKeys
        modifyOperation.isAtomic = true

        modifyOperation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.changeTracker.markAsSynced(pendingChanges)
            case .failure(let error):
                self?.handleSyncError(error)
            }
        }

        try await cloudKit.privateDatabase.add(modifyOperation)
    }
}
```

### Pull Changes

```swift
extension SyncManager {
    func pullChanges() async throws {
        let changeToken = UserDefaults.standard.data(forKey: "cloudKitChangeToken")
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [cloudKit.customZone.zoneID],
            configurationsByRecordZoneID: [cloudKit.customZone.zoneID: options]
        )

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneFetchResultBlock = { [weak self] _, result in
            if case .success(let (newToken, _, _)) = result {
                // Save new change token
                if let tokenData = try? NSKeyedArchiver.archivedData(
                    withRootObject: newToken,
                    requiringSecureCoding: true
                ) {
                    UserDefaults.standard.set(tokenData, forKey: "cloudKitChangeToken")
                }
            }
        }

        try await cloudKit.privateDatabase.add(operation)

        // Process changes
        await processIncomingChanges(changedRecords, deletedRecordIDs)
    }

    private func processIncomingChanges(_ records: [CKRecord], _ deletions: [CKRecord.ID]) async {
        for record in records {
            do {
                let item = try ClipboardItem.from(record)
                await storageManager.merge(item)
            } catch {
                Logger.sync.error("Failed to process record: \(error)")
            }
        }

        for recordID in deletions {
            if let uuid = UUID(uuidString: recordID.recordName) {
                await storageManager.delete(id: uuid)
            }
        }
    }
}
```

---

## Conflict Resolution

### Resolution Strategies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Conflict Resolution Strategies                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   LAST WRITE WINS (Default)                                             │
│   ─────────────────────────                                             │
│                                                                          │
│   Device A: Item modified at 10:00:00                                    │
│   Device B: Item modified at 10:00:05                                    │
│   Result:   Device B's version wins                                      │
│                                                                          │
│   ───────────────────────────────────────────────────────────────────── │
│                                                                          │
│   MERGE (For compatible changes)                                         │
│   ─────                                                                  │
│                                                                          │
│   Device A: Added tag "work"                                             │
│   Device B: Added tag "important"                                        │
│   Result:   Item has both tags ["work", "important"]                     │
│                                                                          │
│   ───────────────────────────────────────────────────────────────────── │
│                                                                          │
│   ASK USER (For significant conflicts)                                   │
│   ────────                                                               │
│                                                                          │
│   Device A: Edited content to "Version A"                                │
│   Device B: Edited content to "Version B"                                │
│   Result:   Prompt user to choose or keep both                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
class ConflictResolver {
    enum Strategy {
        case lastWriteWins
        case merge
        case askUser
    }

    func resolve(local: ClipboardItem, remote: ClipboardItem) async -> ClipboardItem {
        // Check if content differs
        if local.contentHash == remote.contentHash {
            // Only metadata differs - merge
            return mergeMetadata(local: local, remote: remote)
        }

        // Content differs - use timestamp
        if remote.modifiedAt > local.modifiedAt {
            Logger.sync.info("Conflict resolved: remote wins (newer)")
            return remote
        } else {
            Logger.sync.info("Conflict resolved: local wins (newer)")
            return local
        }
    }

    private func mergeMetadata(local: ClipboardItem, remote: ClipboardItem) -> ClipboardItem {
        var merged = local

        // Take latest favorite/pinned status
        if remote.modifiedAt > local.modifiedAt {
            merged.isFavorite = remote.isFavorite
            merged.isPinned = remote.isPinned
        }

        // Merge tags (union)
        merged.tags = local.tags.union(remote.tags)

        // Take latest folder assignment
        if remote.modifiedAt > local.modifiedAt {
            merged.folder = remote.folder
        }

        merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)

        return merged
    }
}
```

---

## Encryption

### End-to-End Encryption

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      E2E Encryption Flow                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   1. KEY GENERATION (per user)                                           │
│   ────────────────────────────                                           │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  Master Key (256-bit)                                            │   │
│   │  └── Derived from iCloud Keychain identity                       │   │
│   │      └── HKDF(salt="pasteshelf", info="sync-encryption")        │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   2. ENCRYPTION (before upload)                                          │
│   ─────────────────────────────                                          │
│                                                                          │
│   ┌──────────┐    ┌──────────────┐    ┌───────────────────┐            │
│   │Plaintext │───▶│  AES-256-GCM │───▶│ Ciphertext + Tag  │            │
│   │ Content  │    │  + Random IV │    │   (CloudKit)      │            │
│   └──────────┘    └──────────────┘    └───────────────────┘            │
│                          │                                              │
│                    Master Key                                            │
│                                                                          │
│   3. DECRYPTION (after download)                                         │
│   ──────────────────────────────                                         │
│                                                                          │
│   ┌───────────────────┐    ┌──────────────┐    ┌──────────┐            │
│   │ Ciphertext + Tag  │───▶│  AES-256-GCM │───▶│Plaintext │            │
│   │   (CloudKit)      │    │  + IV        │    │ Content  │            │
│   └───────────────────┘    └──────────────┘    └──────────┘            │
│                                   │                                      │
│                             Master Key                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
import CryptoKit

class SyncEncryptionManager {
    private func deriveKey(from iCloudIdentity: Data) -> SymmetricKey {
        // Use HKDF to derive sync key from iCloud identity
        let salt = "com.pasteshelf.sync".data(using: .utf8)!
        let info = "encryption-key".data(using: .utf8)!

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: iCloudIdentity),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    func encryptForSync(_ data: Data) throws -> Data {
        let key = try getSyncKey()
        let nonce = AES.GCM.Nonce()

        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        // Combine nonce + ciphertext + tag
        var encrypted = Data()
        encrypted.append(contentsOf: nonce)
        encrypted.append(sealedBox.ciphertext)
        encrypted.append(sealedBox.tag)

        return encrypted
    }

    func decryptFromSync(_ encrypted: Data) throws -> Data {
        let key = try getSyncKey()

        // Extract components
        let nonceSize = 12
        let tagSize = 16

        let nonce = try AES.GCM.Nonce(data: encrypted.prefix(nonceSize))
        let ciphertext = encrypted.dropFirst(nonceSize).dropLast(tagSize)
        let tag = encrypted.suffix(tagSize)

        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

---

## Self-Hosted Option 🏢

For Enterprise customers requiring on-premise sync.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   Self-Hosted Sync Architecture                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Enterprise Network                            │   │
│   │                                                                  │   │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│   │   │  Device A   │  │  Device B   │  │    Sync Server          │ │   │
│   │   │  ─────────  │  │  ─────────  │  │    ───────────          │ │   │
│   │   │             │  │             │  │                         │ │   │
│   │   │  PasteShelf │  │  PasteShelf │  │  ┌───────────────────┐ │ │   │
│   │   │  Client     │  │  Client     │  │  │  Sync API (REST)  │ │ │   │
│   │   │             │  │             │  │  │  WebSocket        │ │ │   │
│   │   └──────┬──────┘  └──────┬──────┘  │  └─────────┬─────────┘ │ │   │
│   │          │                │         │            │           │ │   │
│   │          └────────┬───────┘         │  ┌─────────▼─────────┐ │ │   │
│   │                   │                 │  │  PostgreSQL       │ │ │   │
│   │                   │    HTTPS/WSS    │  │  + Encryption     │ │ │   │
│   │                   │                 │  └───────────────────┘ │ │   │
│   │                   └────────────────▶│                        │ │   │
│   │                                     └─────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   Features:                                                              │
│   • No internet required                                                 │
│   • Full data sovereignty                                                │
│   • Custom retention policies                                            │
│   • Integration with enterprise IdP                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Server Configuration

```yaml
# pasteshelf-sync-server.yaml
server:
  host: sync.company.internal
  port: 443
  tls:
    cert: /etc/pasteshelf/cert.pem
    key: /etc/pasteshelf/key.pem

database:
  type: postgresql
  host: db.company.internal
  port: 5432
  name: pasteshelf_sync
  ssl: true

authentication:
  type: saml
  idp_metadata_url: https://idp.company.com/metadata
  entity_id: https://sync.company.internal

encryption:
  enabled: true
  key_derivation: argon2id
  # Keys stored encrypted in database

retention:
  max_items_per_user: 10000
  max_age_days: 365
  cleanup_interval: daily
```

---

## Troubleshooting

### Common Issues

#### Sync Not Working

```
Checklist:
1. ✅ iCloud signed in on all devices?
2. ✅ iCloud Drive enabled?
3. ✅ Pro license active?
4. ✅ Same Apple ID on all devices?
5. ✅ Internet connection available?

Diagnostic commands:
$ defaults read com.pasteshelf.PasteShelf SyncStatus
$ log show --predicate 'subsystem == "com.pasteshelf.PasteShelf"' --last 1h | grep -i sync
```

#### Sync Conflicts

```
Problem: Same item modified on multiple devices

Solutions:
1. Check sync status before editing important items
2. Review conflict resolution settings
   Preferences → Sync → Conflict Resolution

3. Manual resolution:
   - View sync history for item
   - Choose preferred version
   - Force sync to propagate
```

#### High Data Usage

```
Problem: Sync using too much data

Solutions:
1. Enable selective sync
   Preferences → Sync → Selective Sync
   - Exclude images
   - Exclude large items
   - Set size limit

2. Reduce sync frequency
   Preferences → Sync → Sync Frequency → Manual

3. Compress before sync
   Preferences → Sync → Compress Large Items ✓
```

### Debug Mode

```bash
# Enable sync debugging
defaults write com.pasteshelf.PasteShelf SyncDebugMode -bool true

# View sync logs
log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "sync"' --level debug

# Force full sync
osascript -e 'tell application "PasteShelf" to force sync'

# Reset sync state (caution: will re-download everything)
defaults delete com.pasteshelf.PasteShelf cloudKitChangeToken
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Security](../security/SECURITY.md) | Encryption details |
| [Database Schema](../architecture/DATABASE_SCHEMA.md) | Data model |
| [Enterprise Deployment](../enterprise/ENTERPRISE_DEPLOYMENT.md) | Self-hosted setup |

---

*Last updated: 2026-02-03*
