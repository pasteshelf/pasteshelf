# Maintenance Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 10 minutes

Regular maintenance procedures for PasteShelf.

---

## Table of Contents

- [Routine Maintenance](#routine-maintenance)
- [Database Maintenance](#database-maintenance)
- [Storage Cleanup](#storage-cleanup)
- [Update Procedures](#update-procedures)

---

## Routine Maintenance

### Daily (Automatic)

- Sync status check
- Expired item cleanup
- Search index optimization

### Weekly

- Database vacuum
- Log rotation
- Cache cleanup

### Monthly

- Full backup verification
- Storage usage review
- Performance analysis

---

## Database Maintenance

### CoreData Maintenance

```swift
class DatabaseMaintenance {
    func performMaintenance() async {
        // 1. Clean up deleted items
        await cleanupDeletedItems()

        // 2. Optimize search index
        await optimizeSearchIndex()

        // 3. Compact database
        await compactDatabase()
    }

    func cleanupDeletedItems() async {
        let context = persistenceController.container.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isDeleted == YES AND deletedAt < %@",
                Date().addingTimeInterval(-7 * 24 * 60 * 60) as NSDate)

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try? context.execute(deleteRequest)
        }
    }
}
```

### SQLite Maintenance

```bash
# Manual SQLite optimization (if needed)
sqlite3 ~/Library/Application\ Support/PasteShelf/PasteShelf.sqlite "VACUUM;"
sqlite3 ~/Library/Application\ Support/PasteShelf/PasteShelf.sqlite "ANALYZE;"
```

---

## Storage Cleanup

### Cleanup Script

```swift
func cleanupStorage() async {
    // Remove orphaned files
    let contentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("PasteShelf/Content")

    let storedFiles = try? FileManager.default.contentsOfDirectory(at: contentDir, includingPropertiesForKeys: nil)
    let referencedFiles = await getReferencedFileIds()

    for file in storedFiles ?? [] {
        let fileId = file.deletingPathExtension().lastPathComponent
        if !referencedFiles.contains(fileId) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
```

### Manual Cleanup

```bash
# Check storage usage
du -sh ~/Library/Application\ Support/PasteShelf/

# Clear cache
rm -rf ~/Library/Caches/com.pasteshelf.PasteShelf/
```

---

## Update Procedures

### Pre-Update

1. Backup clipboard history
2. Check system requirements
3. Close PasteShelf

### Post-Update

1. Verify license activation
2. Check sync status
3. Test core functionality

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Monitoring & Logging](MONITORING_LOGGING.md) | System monitoring |
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues |

---

*Last updated: 2026-02-03*
