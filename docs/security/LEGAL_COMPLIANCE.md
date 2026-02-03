# Legal & Compliance

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Legal framework and compliance information for PasteShelf.

---

## Table of Contents

- [Privacy Policy](#privacy-policy)
- [Data Collection](#data-collection)
- [GDPR Compliance](#gdpr-compliance)
- [HIPAA Considerations](#hipaa-considerations)
- [Terms of Service](#terms-of-service)

---

## Privacy Policy

### Data We Collect

**Community Edition 🆓**:
- No data collected by default
- Optional: Anonymous crash reports

**Pro Edition ⭐**:
- License activation data
- Encrypted sync data (E2E)
- Optional: Usage analytics

**Enterprise Edition 🏢**:
- License and user data
- Audit logs (if enabled)
- Sync data (configurable)

### Data We Don't Collect

- Clipboard contents (stored locally)
- Browsing history
- Personal files
- Keystrokes

---

## Data Collection

### Telemetry (Opt-in)

```
Preferences → Privacy → Help Improve PasteShelf

┌─────────────────────────────────────────────────────────────┐
│  Share anonymous usage data                                  │
│                                                              │
│  ○ No data sharing (default)                                │
│  ● Basic analytics only                                      │
│  ○ Full telemetry                                           │
│                                                              │
│  Data collected:                                             │
│  • App version and OS version                               │
│  • Feature usage (counts only)                              │
│  • Crash reports                                            │
│                                                              │
│  NOT collected:                                              │
│  • Clipboard contents                                        │
│  • Personal information                                      │
│  • Search queries                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## GDPR Compliance

### User Rights

| Right | Implementation |
|-------|----------------|
| Access | Export all data (JSON) |
| Rectification | Edit clipboard metadata |
| Erasure | Delete all data |
| Portability | Export/import functionality |
| Restriction | Disable sync, local-only mode |

### Data Processing

- **Legal Basis**: Legitimate interest (functionality)
- **Data Location**: User's device, iCloud (if synced)
- **Retention**: User-configurable
- **DPA**: Available for Enterprise customers

### GDPR Features

```swift
// Data export
func exportUserData() -> Data {
    let export = GDPRExport(
        clipboardItems: getAllItems(),
        preferences: getPreferences(),
        metadata: [
            "exportDate": Date(),
            "version": appVersion
        ]
    )
    return try! JSONEncoder().encode(export)
}

// Data deletion
func deleteAllUserData() {
    // Clear clipboard history
    clearAllHistory()

    // Remove preferences
    UserDefaults.standard.removePersistentDomain(forName: bundleId)

    // Clear Keychain
    clearKeychain()

    // Remove CloudKit data
    deleteCloudKitRecords()
}
```

---

## HIPAA Considerations

### Covered Entities

For healthcare organizations using Enterprise:

| Requirement | PasteShelf Support |
|-------------|-------------------|
| Access controls | ✅ SSO, biometric |
| Audit logs | ✅ Full audit trail |
| Encryption | ✅ E2E encryption |
| BAA | ✅ Available |

### Configuration for HIPAA

```yaml
# hipaa-compliant.yaml
security:
  encryption: required
  biometric_auth: required
  auto_lock: 5_minutes
  sensitive_detection: enabled

data:
  retention: 365_days
  auto_delete_phi: enabled
  sync_phi: disabled

audit:
  enabled: true
  log_access: true
  log_modifications: true
  retention: 6_years
```

### BAA

Business Associate Agreement available for Enterprise customers. Contact: legal@pasteshelf.app

---

## Terms of Service

### License Summary

| Edition | License | Key Terms |
|---------|---------|-----------|
| Community | AGPL-3.0 | Open source, copyleft |
| Pro | Commercial | Personal use, 3 devices |
| Enterprise | Enterprise | Team use, custom terms |

### Acceptable Use

**Permitted**:
- Personal productivity
- Business use (with appropriate license)
- Integration with other tools

**Prohibited**:
- Reverse engineering Pro features
- Circumventing license validation
- Reselling or redistributing
- Use for illegal purposes

### Limitation of Liability

Software provided "as is" without warranty. See full terms at pasteshelf.app/terms.

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Security](SECURITY.md) | Security architecture |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Admin guide |

---

*Last updated: 2026-02-03*
