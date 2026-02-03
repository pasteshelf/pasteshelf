# Database Schema

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

CoreData model documentation for PasteShelf.

---

## Table of Contents

- [Overview](#overview)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Core Entities](#core-entities)
- [Supporting Entities](#supporting-entities)
- [CloudKit Mapping](#cloudkit-mapping)
- [Migration Strategy](#migration-strategy)
- [Performance Considerations](#performance-considerations)

---

## Overview

PasteShelf uses CoreData with CloudKit integration for data persistence. The schema is designed to:

- Efficiently store diverse clipboard content types
- Support fast full-text search
- Enable seamless CloudKit sync (Pro)
- Handle large binary data (images, files)
- Maintain privacy with encryption support

### Data Store Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Data Store Architecture                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │          NSPersistentCloudKitContainer                │ │
│   │                                                        │ │
│   │   ┌────────────────────┐  ┌────────────────────────┐ │ │
│   │   │    Local Store     │  │    CloudKit Store ⭐   │ │ │
│   │   │    ────────────    │  │    ─────────────────   │ │ │
│   │   │                    │  │                        │ │ │
│   │   │  ~/Library/        │  │  iCloud Private DB     │ │ │
│   │   │  Application       │  │  Custom Zone           │ │ │
│   │   │  Support/          │  │  E2E Encrypted         │ │ │
│   │   │  PasteShelf/       │  │                        │ │ │
│   │   │  PasteShelf.sqlite │  │                        │ │ │
│   │   └────────────────────┘  └────────────────────────┘ │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
│   Store Configuration:                                       │
│   • Local: Always available, primary storage                 │
│   • Cloud: Pro/Enterprise only, synced with iCloud          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Entity Relationship Diagram                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                           ┌─────────────────┐                           │
│                           │   Application   │                           │
│                           │   (excluded)    │                           │
│                           └────────┬────────┘                           │
│                                    │                                     │
│                                    │ excludedApp                         │
│                                    ▼                                     │
│   ┌──────────────┐         ┌─────────────────┐         ┌─────────────┐ │
│   │    Folder    │◀────────│  ClipboardItem  │────────▶│    Tag      │ │
│   │              │ folder  │    (Core)       │ tags    │             │ │
│   └──────────────┘         └────────┬────────┘         └─────────────┘ │
│         │                           │                         │         │
│         │                           │                         │         │
│   ┌─────┴─────┐            ┌────────┴────────┐         ┌─────┴─────┐   │
│   │ subfolders│            │                 │         │ items     │   │
│   └───────────┘            │                 │         └───────────┘   │
│                            ▼                 ▼                          │
│                   ┌─────────────────┐ ┌─────────────────┐              │
│                   │ ClipboardContent│ │  ContentPreview │              │
│                   │   (Binary)      │ │   (Thumbnail)   │              │
│                   └─────────────────┘ └─────────────────┘              │
│                                                                          │
│                                                                          │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐    │
│   │  UserPreference │  │   SearchIndex   │  │   Action ⭐         │    │
│   │  (Settings)     │  │  (Search Cache) │  │  (Automation)       │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### ClipboardItem 🆓

The primary entity storing clipboard history entries.

```
┌─────────────────────────────────────────────────────────────┐
│                      ClipboardItem                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key, unique          │
│  createdAt       Date           When item was captured       │
│  modifiedAt      Date           Last modification time       │
│  accessedAt      Date           Last paste/view time         │
│  accessCount     Int32          Number of times accessed     │
│                                                              │
│  contentType     String         UTI type identifier          │
│  contentHash     String         SHA-256 hash for dedup       │
│  textContent     String?        Searchable text (indexed)    │
│  plainText       String?        Plain text representation    │
│                                                              │
│  sourceApp       String?        Bundle ID of source app      │
│  sourceURL       String?        URL if copied from browser   │
│  title           String?        Auto-generated or user title │
│                                                              │
│  isFavorite      Bool           User marked as favorite      │
│  isPinned        Bool           Pinned to top                │
│  isSensitive     Bool           Contains sensitive data      │
│  isEncrypted     Bool           Content is encrypted         │
│                                                              │
│  RELATIONSHIPS                                               │
│  ─────────────                                               │
│                                                              │
│  content         ClipboardContent   1:1 Binary content       │
│  preview         ContentPreview     1:1 Thumbnail            │
│  folder          Folder?            N:1 Optional folder      │
│  tags            [Tag]              N:N Tag associations     │
│                                                              │
│  INDEXES                                                     │
│  ───────                                                     │
│                                                              │
│  • createdAt (descending) - Default sort                    │
│  • textContent (full-text search)                           │
│  • contentHash (deduplication)                              │
│  • contentType (filtering)                                  │
│  • isFavorite, isPinned (quick access)                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**CoreData Definition**:

```swift
// ClipboardItem+CoreDataClass.swift
@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
    @NSManaged public var accessedAt: Date
    @NSManaged public var accessCount: Int32

    @NSManaged public var contentType: String
    @NSManaged public var contentHash: String
    @NSManaged public var textContent: String?
    @NSManaged public var plainText: String?

    @NSManaged public var sourceApp: String?
    @NSManaged public var sourceURL: String?
    @NSManaged public var title: String?

    @NSManaged public var isFavorite: Bool
    @NSManaged public var isPinned: Bool
    @NSManaged public var isSensitive: Bool
    @NSManaged public var isEncrypted: Bool

    @NSManaged public var content: ClipboardContent?
    @NSManaged public var preview: ContentPreview?
    @NSManaged public var folder: Folder?
    @NSManaged public var tags: Set<Tag>
}
```

### ClipboardContent 🆓

Stores the actual binary content separately for performance.

```
┌─────────────────────────────────────────────────────────────┐
│                    ClipboardContent                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key                  │
│  data            Binary         Raw content data             │
│  mimeType        String         MIME type                    │
│  size            Int64          Size in bytes                │
│  isCompressed    Bool           Compression applied          │
│                                                              │
│  RELATIONSHIPS                                               │
│  ─────────────                                               │
│                                                              │
│  item            ClipboardItem  1:1 Parent item              │
│                                                              │
│  NOTES                                                       │
│  ─────                                                       │
│                                                              │
│  • External storage for data > 100KB                        │
│  • Compression using LZ4 for text > 10KB                    │
│  • CloudKit: Stored as CKAsset                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### ContentPreview 🆓

Stores thumbnails and previews for quick display.

```
┌─────────────────────────────────────────────────────────────┐
│                    ContentPreview                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key                  │
│  thumbnail       Binary         Image thumbnail (256px)      │
│  textPreview     String         First 500 chars of text      │
│  ocrText         String? ⭐     OCR extracted text           │
│  embedding       Binary? ⭐     ML embedding vector          │
│                                                              │
│  RELATIONSHIPS                                               │
│  ─────────────                                               │
│                                                              │
│  item            ClipboardItem  1:1 Parent item              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Supporting Entities

### Folder 🆓

Organizes clipboard items into folders (Smart Folders in Pro).

```
┌─────────────────────────────────────────────────────────────┐
│                        Folder                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key                  │
│  name            String         Folder name                  │
│  icon            String         SF Symbol name               │
│  color           String         Hex color code               │
│  sortOrder       Int16          Display order                │
│  isSmartFolder   Bool ⭐        Auto-populated folder        │
│  smartQuery      String? ⭐     Query for smart folder       │
│                                                              │
│  RELATIONSHIPS                                               │
│  ─────────────                                               │
│                                                              │
│  items           [ClipboardItem] 1:N Items in folder        │
│  parent          Folder?         N:1 Parent folder          │
│  children        [Folder]        1:N Subfolders             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Tag 🆓

Flexible tagging system for items.

```
┌─────────────────────────────────────────────────────────────┐
│                          Tag                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key                  │
│  name            String         Tag name (unique)            │
│  color           String         Hex color code               │
│  isAutoTag       Bool           System-generated tag         │
│                                                              │
│  RELATIONSHIPS                                               │
│  ─────────────                                               │
│                                                              │
│  items           [ClipboardItem] N:N Tagged items           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Application (Excluded Apps) 🆓

Apps excluded from clipboard monitoring.

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  bundleId        String         App bundle identifier        │
│  name            String         App display name             │
│  isExcluded      Bool           Don't capture from this app  │
│  excludeReason   String?        Why excluded                 │
│                                                              │
│  Default Exclusions:                                         │
│  • 1Password (com.1password.1password)                       │
│  • Bitwarden (com.bitwarden.desktop)                         │
│  • LastPass (com.lastpass.LastPass)                          │
│  • Keychain Access (com.apple.keychainaccess)               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Action ⭐

Custom automation actions.

```
┌─────────────────────────────────────────────────────────────┐
│                        Action ⭐                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  id              UUID           Primary key                  │
│  name            String         Action name                  │
│  script          String         JavaScript code              │
│  trigger         String         When to run (manual/auto)    │
│  contentTypes    [String]       Applicable content types     │
│  isEnabled       Bool           Action enabled               │
│                                                              │
│  Examples:                                                   │
│  • "Uppercase Text"                                          │
│  • "Shorten URL"                                             │
│  • "Format JSON"                                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### UserPreference 🆓

User settings stored in CoreData (synced with iCloud).

```
┌─────────────────────────────────────────────────────────────┐
│                    UserPreference                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ATTRIBUTES                                                  │
│  ──────────                                                  │
│                                                              │
│  key             String         Preference key               │
│  value           Transformable  Codable value                │
│  modifiedAt      Date           Last change                  │
│                                                              │
│  Stored Preferences:                                         │
│  • historyLimit: Int                                         │
│  • theme: String                                             │
│  • globalHotkey: String                                      │
│  • launchAtLogin: Bool                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## CloudKit Mapping ⭐

### Record Types

| CoreData Entity | CloudKit Record Type | Zone |
|-----------------|---------------------|------|
| ClipboardItem | CD_ClipboardItem | com.pasteshelf.clipboard |
| ClipboardContent | CD_ClipboardContent (CKAsset) | com.pasteshelf.clipboard |
| ContentPreview | CD_ContentPreview | com.pasteshelf.clipboard |
| Folder | CD_Folder | com.pasteshelf.clipboard |
| Tag | CD_Tag | com.pasteshelf.clipboard |
| UserPreference | CD_UserPreference | com.pasteshelf.settings |

### Sync Configuration

```swift
// CloudKit Container Setup
let container = NSPersistentCloudKitContainer(name: "PasteShelf")

let cloudStoreDescription = NSPersistentStoreDescription()
cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.pasteshelf.PasteShelf"
)

// Custom zone for clipboard data
cloudStoreDescription.setOption(
    true as NSNumber,
    forKey: NSPersistentHistoryTrackingKey
)
cloudStoreDescription.setOption(
    true as NSNumber,
    forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
)
```

### Encryption ⭐

```
┌─────────────────────────────────────────────────────────────┐
│                  CloudKit Encryption                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Encryption Flow:                                            │
│                                                              │
│  1. Generate device-specific key pair                        │
│  2. Derive symmetric key from user's iCloud identity         │
│  3. Encrypt content before CoreData save                     │
│  4. CoreData/CloudKit sync encrypted data                    │
│  5. Decrypt on other devices with same iCloud account        │
│                                                              │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐        │
│  │  Plaintext │───▶│   AES-256  │───▶│ Ciphertext │        │
│  │   Content  │    │    GCM     │    │  (synced)  │        │
│  └────────────┘    └────────────┘    └────────────┘        │
│                          │                                   │
│                    Key from Keychain                         │
│                    (iCloud Keychain)                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Migration Strategy

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-03 | Initial schema |

### Migration Types

```swift
// Lightweight migration (automatic)
let options = [
    NSMigratePersistentStoresAutomaticallyOption: true,
    NSInferMappingModelAutomaticallyOption: true
]

// Heavy migration (custom mapping model)
class MigrationManager {
    func migrateStore(from sourceURL: URL, to destinationURL: URL) throws {
        let sourceModel = // ...
        let destinationModel = // ...
        let mappingModel = NSMappingModel(
            from: nil,
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )

        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )

        try migrationManager.migrateStore(
            from: sourceURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: destinationURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )
    }
}
```

### Migration Guidelines

1. **Prefer lightweight migrations** when possible
2. **Add optional attributes** with default values
3. **Never remove attributes** in minor versions
4. **Version the data model** for each schema change
5. **Test migrations** with production-like data

---

## Performance Considerations

### Indexing Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                   Index Configuration                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ClipboardItem Indexes:                                      │
│                                                              │
│  1. createdAt (DESC)         - Default sort, recent first   │
│  2. textContent (FTS)        - Full-text search             │
│  3. contentHash (UNIQUE)     - Deduplication lookups        │
│  4. contentType              - Filter by type               │
│  5. (isFavorite, createdAt)  - Favorites query              │
│  6. (isPinned, createdAt)    - Pinned items query           │
│  7. sourceApp                - Filter by app                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Fetch Optimization

```swift
// Batch fetching for large lists
let fetchRequest = ClipboardItem.fetchRequest()
fetchRequest.fetchBatchSize = 50
fetchRequest.fetchLimit = 100
fetchRequest.propertiesToFetch = ["id", "textContent", "createdAt", "contentType"]
fetchRequest.relationshipKeyPathsForPrefetching = ["preview"]

// Background fetch
let backgroundContext = container.newBackgroundContext()
backgroundContext.perform {
    let items = try? backgroundContext.fetch(fetchRequest)
    // Process items
}
```

### Storage Optimization

| Content Type | Storage Strategy |
|--------------|------------------|
| Text < 10KB | Inline in SQLite |
| Text ≥ 10KB | Compressed (LZ4) |
| Images | External file, thumbnail inline |
| Files | Reference only, no duplication |
| Binary > 100KB | External storage |

### Cleanup Policy

```swift
class StorageManager {
    func cleanup() async {
        let context = container.newBackgroundContext()

        await context.perform {
            // Delete items older than retention period
            let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
            let deleteRequest = NSBatchDeleteRequest(
                fetchRequest: ClipboardItem.fetchRequest(
                    predicate: NSPredicate(format: "createdAt < %@ AND isFavorite == NO", cutoffDate as NSDate)
                )
            )

            try? context.execute(deleteRequest)

            // Compact database
            try? context.persistentStoreCoordinator?.performAndWait {
                // SQLite VACUUM
            }
        }
    }
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](ARCHITECTURE.md) | System architecture |
| [Tech Stack](TECH_STACK.md) | Technology choices |
| [Sync Engine](../features/SYNC_ENGINE.md) | CloudKit sync |
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Optimization |

---

*Last updated: 2026-02-03*
