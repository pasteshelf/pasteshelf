# Privacy & Security Features

> **Last Updated**: 2026-02-03 | **Reading Time**: 20 minutes

Comprehensive guide to PasteShelf's privacy and security capabilities.

---

## Table of Contents

- [Privacy Philosophy](#privacy-philosophy)
- [Data Protection](#data-protection)
- [Sensitive Data Handling](#sensitive-data-handling)
- [Authentication](#authentication)
- [Encryption](#encryption)
- [Privacy Controls](#privacy-controls)
- [Enterprise Security](#enterprise-security)
- [Security Audit](#security-audit)

---

## Privacy Philosophy

PasteShelf is built on the principle of **privacy by design**:

```
┌─────────────────────────────────────────────────────────────┐
│                   Privacy Principles                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. LOCAL FIRST                                              │
│     All data stored locally by default                       │
│     No server-side processing                                │
│     No telemetry without explicit consent                    │
│                                                              │
│  2. MINIMAL DATA COLLECTION                                  │
│     Only collect what's necessary                            │
│     No unnecessary metadata                                  │
│     Clear data retention policies                            │
│                                                              │
│  3. USER CONTROL                                             │
│     Full control over what's captured                        │
│     Easy data export and deletion                            │
│     Transparent about data handling                          │
│                                                              │
│  4. SECURITY BY DEFAULT                                      │
│     Encryption enabled by default                            │
│     Sensitive data detection                                 │
│     Secure app exclusion                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Protection

### Data at Rest 🆓

All clipboard data is protected at rest:

```
┌─────────────────────────────────────────────────────────────┐
│                  Data at Rest Protection                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Clipboard Item Storage                  │   │
│   │                                                      │   │
│   │   ┌───────────────┐    ┌────────────────────────┐  │   │
│   │   │  CoreData DB  │    │    External Files      │  │   │
│   │   │  ────────────  │    │    ──────────────      │  │   │
│   │   │               │    │                        │  │   │
│   │   │  SQLite with  │    │  Images & binaries     │  │   │
│   │   │  encryption   │    │  in App Support dir    │  │   │
│   │   └───────┬───────┘    └───────────┬────────────┘  │   │
│   │           │                        │               │   │
│   │           └────────┬───────────────┘               │   │
│   │                    │                               │   │
│   │           ┌────────▼────────┐                      │   │
│   │           │   FileVault     │                      │   │
│   │           │   (System)      │                      │   │
│   │           │                 │                      │   │
│   │           │   Full disk     │                      │   │
│   │           │   encryption    │                      │   │
│   │           └─────────────────┘                      │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Protection Layers**:

| Layer | Technology | Protection |
|-------|------------|------------|
| Application | CoreData encryption | App-level protection |
| File System | FileVault | Disk encryption |
| Keychain | Secure Enclave | Secrets protection |

### Data in Transit ⭐

For Pro/Enterprise sync:

```
┌─────────────────────────────────────────────────────────────┐
│                Data in Transit Protection                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Device A                  CloudKit                Device B │
│   ────────                  ────────                ──────── │
│                                                              │
│   ┌──────────┐         ┌────────────┐         ┌──────────┐ │
│   │Plaintext │         │ Encrypted  │         │Plaintext │ │
│   │  Data    │         │   Data     │         │  Data    │ │
│   └────┬─────┘         └────────────┘         └────▲─────┘ │
│        │                     ▲                     │        │
│        ▼                     │                     │        │
│   ┌──────────┐               │                ┌──────────┐ │
│   │  AES-256 │───────────────┘                │  AES-256 │ │
│   │   GCM    │                                │   GCM    │ │
│   │ Encrypt  │                                │ Decrypt  │ │
│   └──────────┘                                └──────────┘ │
│        │                                           ▲        │
│        │                                           │        │
│        └──────────────── TLS 1.3 ──────────────────┘        │
│                                                              │
│   Encryption:                                                │
│   • E2E: AES-256-GCM (before leaving device)                │
│   • Transport: TLS 1.3 (Apple infrastructure)               │
│   • Key exchange: ECDH on Curve25519                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Data Deletion 🆓

Complete data removal:

```swift
// Delete single item
func deleteItem(_ item: ClipboardItem) async throws {
    // Remove from CoreData
    viewContext.delete(item)
    try viewContext.save()

    // Remove external files
    if let contentPath = item.content?.externalPath {
        try FileManager.default.removeItem(at: contentPath)
    }

    // Remove from search index
    await searchIndex.remove(itemId: item.id)

    // If synced, mark for deletion in CloudKit
    if syncEnabled {
        await syncEngine.markForDeletion(item.id)
    }
}

// Clear all history
func clearAllHistory() async throws {
    // Batch delete all items
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardItem.fetchRequest()
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    try viewContext.execute(deleteRequest)

    // Clear external storage
    let supportDir = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("PasteShelf/Content")
    try FileManager.default.removeItem(at: supportDir)

    // Rebuild search index
    await searchIndex.rebuild()
}
```

---

## Sensitive Data Handling

### Automatic Detection 🆓

PasteShelf automatically detects sensitive content:

```
┌─────────────────────────────────────────────────────────────┐
│               Sensitive Data Detection                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Detection Categories:                                      │
│   ─────────────────────                                      │
│                                                              │
│   🔑 CREDENTIALS                                             │
│      • Passwords (password managers, forms)                  │
│      • API keys (AWS, GCP, Stripe, etc.)                     │
│      • SSH private keys                                      │
│      • OAuth tokens                                          │
│                                                              │
│   💳 FINANCIAL                                               │
│      • Credit card numbers (Luhn validation)                 │
│      • Bank account numbers                                  │
│      • Social Security Numbers                               │
│                                                              │
│   🏥 HEALTH                                                  │
│      • Medical record numbers                                │
│      • Health insurance IDs                                  │
│                                                              │
│   📧 PERSONAL                                                │
│      • Email addresses                                       │
│      • Phone numbers                                         │
│      • Physical addresses                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Detection Patterns

```swift
class SensitiveDataDetector {
    private let patterns: [(name: String, regex: NSRegularExpression, severity: Severity)] = [
        // API Keys
        ("AWS Access Key", try! NSRegularExpression(pattern: "AKIA[0-9A-Z]{16}"), .high),
        ("GitHub Token", try! NSRegularExpression(pattern: "ghp_[a-zA-Z0-9]{36}"), .high),
        ("Stripe Key", try! NSRegularExpression(pattern: "sk_live_[a-zA-Z0-9]{24}"), .high),

        // Passwords
        ("Password Field", try! NSRegularExpression(pattern: "password[\"']?\\s*[:=]\\s*[\"'][^\"']+[\"']", options: .caseInsensitive), .high),

        // Financial
        ("Credit Card", try! NSRegularExpression(pattern: "\\b(?:\\d[ -]*?){13,16}\\b"), .high),
        ("SSN", try! NSRegularExpression(pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b"), .high),

        // Personal
        ("Email", try! NSRegularExpression(pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"), .low),
        ("Phone", try! NSRegularExpression(pattern: "\\+?\\d{1,3}[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}"), .low)
    ]

    func analyze(_ content: String) -> SensitiveDataResult {
        var detections: [Detection] = []

        for pattern in patterns {
            let matches = pattern.regex.matches(
                in: content,
                range: NSRange(content.startIndex..., in: content)
            )
            for match in matches {
                detections.append(Detection(
                    type: pattern.name,
                    severity: pattern.severity,
                    range: match.range
                ))
            }
        }

        // Additional validation (e.g., Luhn for credit cards)
        detections = detections.filter { validateDetection($0, in: content) }

        return SensitiveDataResult(
            isSensitive: !detections.isEmpty,
            detections: detections,
            highestSeverity: detections.map(\.severity).max() ?? .none
        )
    }
}
```

### Handling Options

```
┌─────────────────────────────────────────────────────────────┐
│            Sensitive Data Handling Options                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Preferences → Privacy → Sensitive Data:                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  When sensitive data is detected:                    │    │
│  │                                                      │    │
│  │  ○ Store normally                                    │    │
│  │  ● Require authentication to view [Recommended]     │    │
│  │  ○ Redact in history (show as ••••••)               │    │
│  │  ○ Don't store at all                               │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  Auto-delete sensitive items:                        │    │
│  │  ☑ Delete after 1 hour                              │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  ☑ Exclude from sync                                │    │
│  │  ☑ Exclude from search                              │    │
│  │  ☑ Exclude from export                              │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Authentication

### Biometric Authentication 🆓

```
┌─────────────────────────────────────────────────────────────┐
│               Biometric Authentication                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Supported Methods:                                         │
│   ─────────────────                                          │
│                                                              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│   │  Touch ID   │  │  Apple Watch│  │     Password        │ │
│   │  ─────────  │  │  ───────────│  │     ────────        │ │
│   │             │  │             │  │                     │ │
│   │  Fingerprint│  │  Proximity  │  │  Fallback when      │ │
│   │  sensor on  │  │  unlock via │  │  biometrics         │ │
│   │  MacBook/   │  │  paired     │  │  unavailable        │ │
│   │  keyboard   │  │  watch      │  │                     │ │
│   └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
│   Authentication Required For:                               │
│   ────────────────────────────                               │
│                                                              │
│   ☑ Viewing sensitive items                                 │
│   ☑ Exporting clipboard history                             │
│   ☑ Changing security settings                              │
│   ☐ Opening PasteShelf (optional)                           │
│   ☐ Every paste action (optional)                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
import LocalAuthentication

class BiometricAuth {
    private let context = LAContext()

    var biometryType: LABiometryType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"

        // Check if biometrics available
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to device password
            return try await authenticateWithPassword(reason: reason)
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    private func authenticateWithPassword(reason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
    }
}
```

### Auto-Lock 🆓

```swift
class AutoLockManager {
    @AppStorage("autoLockTimeout") var timeout: TimeInterval = 300 // 5 minutes
    @Published var isLocked = false

    private var lastActivity: Date = Date()
    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkLock()
        }
    }

    func recordActivity() {
        lastActivity = Date()
        isLocked = false
    }

    private func checkLock() {
        if Date().timeIntervalSince(lastActivity) > timeout {
            isLocked = true
        }
    }
}
```

---

## Encryption

### Encryption Architecture 🆓

```
┌─────────────────────────────────────────────────────────────┐
│                 Encryption Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Key Hierarchy:                                             │
│   ─────────────                                              │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                 Master Key                           │   │
│   │           (Derived from user's Keychain)            │   │
│   └─────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│           ┌─────────────┼─────────────┐                     │
│           │             │             │                     │
│           ▼             ▼             ▼                     │
│   ┌───────────┐  ┌───────────┐  ┌───────────────┐          │
│   │ Database  │  │  Content  │  │    Sync       │          │
│   │    Key    │  │    Key    │  │    Key ⭐     │          │
│   └─────┬─────┘  └─────┬─────┘  └───────┬───────┘          │
│         │              │                │                   │
│         ▼              ▼                ▼                   │
│   ┌───────────┐  ┌───────────┐  ┌───────────────┐          │
│   │  CoreData │  │  Binary   │  │   CloudKit    │          │
│   │   Store   │  │  Files    │  │   Records     │          │
│   └───────────┘  └───────────┘  └───────────────┘          │
│                                                              │
│   Algorithms:                                                │
│   • Key derivation: PBKDF2 with 100,000 iterations          │
│   • Symmetric encryption: AES-256-GCM                        │
│   • Key storage: Secure Enclave (when available)            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### CryptoKit Implementation

```swift
import CryptoKit

class EncryptionManager {
    private let keychain = KeychainManager()

    // Generate or retrieve master key
    private func getMasterKey() throws -> SymmetricKey {
        if let keyData = try? keychain.get("masterKey") {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        try keychain.save("masterKey", data: key.dataRepresentation)
        return key
    }

    // Encrypt data
    func encrypt(_ data: Data) throws -> Data {
        let key = try getMasterKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    // Decrypt data
    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getMasterKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // Encrypt for sync (with per-device key exchange)
    func encryptForSync(_ data: Data, recipientPublicKey: P256.KeyAgreement.PublicKey) throws -> Data {
        let privateKey = try getSyncPrivateKey()
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)

        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("PasteShelf-Sync".utf8),
            outputByteCount: 32
        )

        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined!
    }
}
```

---

## Privacy Controls

### App Exclusion 🆓

```
┌─────────────────────────────────────────────────────────────┐
│                    App Exclusion                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Preferences → Privacy → Excluded Apps:                      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Never capture from these apps:                      │    │
│  │                                                      │    │
│  │  ┌────────────────────────────────────────────────┐ │    │
│  │  │ 🔐 1Password                           [Built-in] │ │
│  │  │ 🔐 Bitwarden                           [Built-in] │ │
│  │  │ 🔐 LastPass                            [Built-in] │ │
│  │  │ 🔐 Dashlane                            [Built-in] │ │
│  │  │ 🔐 Keychain Access                     [Built-in] │ │
│  │  │ 💬 Messages (private conversations)   [Custom]   │ │
│  │  │ 💼 Slack (when in #private channel)   [Custom]   │ │
│  │  └────────────────────────────────────────────────┘ │    │
│  │                                                      │    │
│  │  [+ Add App]                                         │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  ☑ Auto-detect password manager fields              │    │
│  │  ☑ Exclude private browsing windows                 │    │
│  │  ☑ Exclude secure text fields                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Capture Rules 🆓

```swift
struct CaptureRule {
    let id: UUID
    let name: String
    let condition: CaptureCondition
    let action: CaptureAction

    enum CaptureCondition {
        case app(bundleId: String)
        case contentType(uti: String)
        case contentMatches(regex: String)
        case windowTitle(contains: String)
        case isSecureTextField
        case isPrivateBrowsing
    }

    enum CaptureAction {
        case capture
        case skip
        case captureButMarkSensitive
        case captureButEncrypt
    }
}

// Default rules
let defaultRules: [CaptureRule] = [
    CaptureRule(
        name: "Skip password managers",
        condition: .app(bundleId: "com.1password.*"),
        action: .skip
    ),
    CaptureRule(
        name: "Skip secure text fields",
        condition: .isSecureTextField,
        action: .skip
    ),
    CaptureRule(
        name: "Mark API keys as sensitive",
        condition: .contentMatches(regex: "(api[_-]?key|secret)[\"']?\\s*[:=]"),
        action: .captureButMarkSensitive
    )
]
```

### Data Retention 🆓

```
┌─────────────────────────────────────────────────────────────┐
│                   Data Retention Settings                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Preferences → Privacy → Data Retention:                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Keep clipboard items for:                           │    │
│  │                                                      │    │
│  │  ○ Forever                                           │    │
│  │  ○ 1 year                                            │    │
│  │  ● 90 days [Recommended]                             │    │
│  │  ○ 30 days                                           │    │
│  │  ○ 7 days                                            │    │
│  │  ○ 1 day                                             │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  Maximum items: [1000            ]                   │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  ☑ Automatically delete duplicates                  │    │
│  │  ☑ Clear history on quit                            │    │
│  │  ☑ Delete sensitive items after 1 hour             │    │
│  │                                                      │    │
│  │  [Clear All History Now]                             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Enterprise Security 🏢

### SSO Integration

Supported providers:
- Okta
- Azure AD
- Google Workspace
- OneLogin
- Custom SAML 2.0 / OIDC

```swift
// SSO Configuration
struct SSOConfiguration {
    let provider: SSOProvider
    let clientId: String
    let issuer: URL
    let redirectURI: URL
    let scopes: [String]

    // SAML specific
    var samlMetadataURL: URL?
    var samlEntityId: String?

    // OIDC specific
    var oidcDiscoveryURL: URL?
}
```

### Audit Logging 🏢

```
┌─────────────────────────────────────────────────────────────┐
│                     Audit Logging                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Events logged:                                              │
│  ─────────────                                               │
│                                                              │
│  • User authentication (success/failure)                     │
│  • Clipboard item capture                                    │
│  • Clipboard item access (view/paste)                        │
│  • Item deletion                                             │
│  • Export operations                                         │
│  • Settings changes                                          │
│  • Sync events                                               │
│  • Policy violations                                         │
│                                                              │
│  Log format (JSON):                                          │
│  ─────────────────                                           │
│                                                              │
│  {                                                           │
│    "timestamp": "2026-02-03T12:00:00Z",                     │
│    "eventType": "item.accessed",                            │
│    "userId": "user@company.com",                            │
│    "deviceId": "device_abc123",                             │
│    "itemId": "550e8400-e29b-...",                          │
│    "action": "paste",                                        │
│    "metadata": {                                             │
│      "targetApp": "com.apple.mail",                         │
│      "contentType": "public.plain-text"                     │
│    }                                                         │
│  }                                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Data Loss Prevention 🏢

```swift
// DLP Policy
struct DLPPolicy {
    let id: UUID
    let name: String
    let rules: [DLPRule]
    let action: DLPAction
    let notification: DLPNotification

    struct DLPRule {
        let type: RuleType
        let pattern: String

        enum RuleType {
            case regex
            case keyword
            case contentType
            case fileExtension
        }
    }

    enum DLPAction {
        case allow
        case block
        case encrypt
        case notify
        case quarantine
    }
}

// Example: Block credit card numbers from leaving secure apps
let creditCardPolicy = DLPPolicy(
    name: "Credit Card Protection",
    rules: [
        DLPRule(type: .regex, pattern: "\\b(?:\\d[ -]*?){13,16}\\b")
    ],
    action: .block,
    notification: .alertAdmin
)
```

---

## Security Audit

### Self-Assessment Checklist

```
┌─────────────────────────────────────────────────────────────┐
│                Security Self-Assessment                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Access Control                                              │
│  ☑ Biometric authentication enabled                         │
│  ☑ Auto-lock configured                                     │
│  ☑ No unauthorized users                                    │
│                                                              │
│  Data Protection                                             │
│  ☑ FileVault enabled on this Mac                           │
│  ☑ Encryption keys in Keychain                             │
│  ☑ Sensitive data detection on                             │
│                                                              │
│  Privacy Settings                                            │
│  ☑ Password managers excluded                               │
│  ☑ Private browsing excluded                                │
│  ☑ Data retention configured                                │
│                                                              │
│  Sync Security (Pro)                                         │
│  ☑ E2E encryption enabled                                   │
│  ☑ Only trusted devices synced                              │
│  ☐ Sync disabled (highest security)                         │
│                                                              │
│  Overall Score: 9/10 ✓ Excellent                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Security](../security/SECURITY.md) | Security architecture |
| [Legal & Compliance](../security/LEGAL_COMPLIANCE.md) | GDPR, HIPAA |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Admin setup |

---

*Last updated: 2026-02-03*
