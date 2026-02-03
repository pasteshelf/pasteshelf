# License System

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Technical documentation for PasteShelf's license validation system.

---

## Table of Contents

- [Overview](#overview)
- [License Types](#license-types)
- [Validation Flow](#validation-flow)
- [JWT Tokens](#jwt-tokens)
- [Offline Support](#offline-support)
- [Enterprise Licensing](#enterprise-licensing)
- [Implementation](#implementation)

---

## Overview

The License System validates and manages feature entitlements across tiers.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     License System Architecture                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    PasteShelf Client                             │   │
│   │                                                                  │   │
│   │   ┌───────────────────────────────────────────────────────────┐ │   │
│   │   │                  License Manager                           │ │   │
│   │   │                                                            │ │   │
│   │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │ │   │
│   │   │  │   License   │  │   Feature   │  │     Token       │   │ │   │
│   │   │  │  Validator  │  │    Flags    │  │   Refresh       │   │ │   │
│   │   │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘   │ │   │
│   │   │         │                │                  │            │ │   │
│   │   └─────────┼────────────────┼──────────────────┼────────────┘ │   │
│   │             │                │                  │              │   │
│   │   ┌─────────▼────────────────▼──────────────────▼────────────┐ │   │
│   │   │                  Secure Storage                           │ │   │
│   │   │                  (Keychain)                               │ │   │
│   │   │                                                           │ │   │
│   │   │  • License JWT token                                      │ │   │
│   │   │  • Device ID                                              │ │   │
│   │   │  • Offline grace timestamp                                │ │   │
│   │   └───────────────────────────────────────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      │ HTTPS                             │
│                                      ▼                                   │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    License Server                                │   │
│   │                                                                  │   │
│   │   /api/v1/licenses/activate    - Activate license                │   │
│   │   /api/v1/licenses/validate    - Validate license                │   │
│   │   /api/v1/licenses/refresh     - Refresh token                   │   │
│   │   /api/v1/licenses/deactivate  - Deactivate device               │   │
│   │                                                                  │   │
│   │   ┌───────────────────────────────────────────────────────────┐ │   │
│   │   │                    Database                                │ │   │
│   │   │  • Licenses                                                │ │   │
│   │   │  • Device activations                                      │ │   │
│   │   │  • Audit logs                                              │ │   │
│   │   └───────────────────────────────────────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## License Types

### License Key Format

```
Format: XXXX-XXXX-XXXX-XXXX-XXXX

Example: PS-PRO-A1B2-C3D4-E5F6
        │   │   │
        │   │   └── Random segment (checksum)
        │   └── Edition (PRO, ENT)
        └── Product prefix
```

### License Tiers

```swift
enum LicenseTier: String, Codable {
    case community = "community"   // 🆓 Free
    case pro = "pro"               // ⭐ Pro
    case enterprise = "enterprise"  // 🏢 Enterprise

    var displayName: String {
        switch self {
        case .community: return "Community Edition"
        case .pro: return "Pro Edition"
        case .enterprise: return "Enterprise Edition"
        }
    }
}

enum LicenseType: String, Codable {
    case trial          // Time-limited trial
    case subscription   // Annual subscription
    case lifetime       // One-time purchase
    case enterprise     // Enterprise agreement
}
```

---

## Validation Flow

### Activation Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       License Activation Flow                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   User enters license key                                                │
│           │                                                              │
│           ▼                                                              │
│   ┌───────────────────┐                                                 │
│   │  Validate format  │                                                 │
│   │  (local check)    │                                                 │
│   └─────────┬─────────┘                                                 │
│             │                                                            │
│             ▼                                                            │
│   ┌───────────────────┐     ┌───────────────────┐                       │
│   │  POST /activate   │────▶│   License Server  │                       │
│   │  • license_key    │     │   ─────────────   │                       │
│   │  • device_id      │     │                   │                       │
│   │  • device_name    │     │   Validate:       │                       │
│   │  • hardware_id    │     │   • Key exists    │                       │
│   └───────────────────┘     │   • Not revoked   │                       │
│                             │   • Seats available│                       │
│             ┌───────────────│   • Device limit  │                       │
│             │               └───────────────────┘                       │
│             ▼                                                            │
│   ┌───────────────────┐                                                 │
│   │  Receive JWT      │                                                 │
│   │  License Token    │                                                 │
│   └─────────┬─────────┘                                                 │
│             │                                                            │
│             ▼                                                            │
│   ┌───────────────────┐                                                 │
│   │  Store in         │                                                 │
│   │  Keychain         │                                                 │
│   └─────────┬─────────┘                                                 │
│             │                                                            │
│             ▼                                                            │
│   ┌───────────────────┐                                                 │
│   │  Enable Pro       │                                                 │
│   │  features         │                                                 │
│   └───────────────────┘                                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Validation Flow

```swift
class LicenseValidator {
    func validateLicense() async throws -> LicenseStatus {
        // 1. Check for stored token
        guard let token = try? keychain.get("licenseToken") else {
            return .community
        }

        // 2. Decode and verify JWT locally
        let claims = try decodeAndVerify(token)

        // 3. Check expiration
        if claims.exp < Date() {
            // Token expired, try to refresh
            return try await refreshToken()
        }

        // 4. Check if online validation needed
        if shouldValidateOnline(lastCheck: claims.iat) {
            return try await onlineValidation(token)
        }

        // 5. Return cached status
        return .valid(tier: claims.tier)
    }

    private func shouldValidateOnline(lastCheck: Date) -> Bool {
        // Validate online at least every 24 hours
        return Date().timeIntervalSince(lastCheck) > 86400
    }
}
```

---

## JWT Tokens

### Token Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       JWT License Token                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   HEADER (Algorithm & Token Type)                                        │
│   ─────────────────────────────────                                      │
│   {                                                                      │
│     "alg": "RS256",                                                      │
│     "typ": "JWT",                                                        │
│     "kid": "key-2026-01"                                                │
│   }                                                                      │
│                                                                          │
│   PAYLOAD (Claims)                                                       │
│   ────────────────                                                       │
│   {                                                                      │
│     "iss": "https://license.pasteshelf.app",                            │
│     "sub": "lic_abc123",                      // License ID             │
│     "aud": "pasteshelf-client",                                         │
│     "exp": 1735689600,                        // Expiration             │
│     "iat": 1704067200,                        // Issued at              │
│     "nbf": 1704067200,                        // Not before             │
│                                                                          │
│     // Custom claims                                                     │
│     "tier": "pro",                            // License tier           │
│     "type": "subscription",                   // License type           │
│     "email": "user@example.com",              // User email             │
│     "device_id": "dev_xyz789",                // Device identifier      │
│     "device_limit": 3,                        // Max devices            │
│     "features": ["sync", "ai_search", "ocr"], // Enabled features       │
│     "org_id": null                            // Enterprise only        │
│   }                                                                      │
│                                                                          │
│   SIGNATURE (RS256)                                                      │
│   ─────────────────                                                      │
│   RSASHA256(base64UrlEncode(header) + "." + base64UrlEncode(payload))   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Token Verification

```swift
import CryptoKit

class JWTVerifier {
    private let publicKey: SecKey

    init() throws {
        // Load embedded public key
        guard let keyData = Bundle.main.url(forResource: "license-public", withExtension: "pem"),
              let key = try? loadPublicKey(from: keyData) else {
            throw LicenseError.invalidPublicKey
        }
        self.publicKey = key
    }

    func verify(_ token: String) throws -> LicenseClaims {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw LicenseError.malformedToken
        }

        let header = parts[0]
        let payload = parts[1]
        let signature = parts[2]

        // Verify signature
        let signedData = Data("\(header).\(payload)".utf8)
        let signatureData = Data(base64URLEncoded: String(signature))!

        guard SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signedData as CFData,
            signatureData as CFData,
            nil
        ) else {
            throw LicenseError.invalidSignature
        }

        // Decode payload
        let payloadData = Data(base64URLEncoded: String(payload))!
        let claims = try JSONDecoder().decode(LicenseClaims.self, from: payloadData)

        // Verify claims
        try verifyClaims(claims)

        return claims
    }

    private func verifyClaims(_ claims: LicenseClaims) throws {
        // Check expiration
        if claims.exp < Date() {
            throw LicenseError.expired
        }

        // Check not before
        if claims.nbf > Date() {
            throw LicenseError.notYetValid
        }

        // Check issuer
        if claims.iss != "https://license.pasteshelf.app" {
            throw LicenseError.invalidIssuer
        }

        // Check audience
        if claims.aud != "pasteshelf-client" {
            throw LicenseError.invalidAudience
        }
    }
}
```

---

## Offline Support

### Grace Period

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Offline Grace Period                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Timeline:                                                              │
│   ─────────                                                              │
│                                                                          │
│   Last online       7 days         14 days        30 days               │
│   validation        grace          warning        revocation             │
│       │               │               │               │                  │
│       ▼               ▼               ▼               ▼                  │
│   ───●───────────────●───────────────●───────────────●──────────────▶   │
│       │               │               │               │                  │
│       │               │               │               │                  │
│       │               │               │               └─ Features       │
│       │               │               │                  disabled       │
│       │               │               │                                  │
│       │               │               └─ Warning: "Please connect      │
│       │               │                  to verify license"             │
│       │               │                                                  │
│       │               └─ Still valid, no warnings                       │
│       │                                                                  │
│       └─ Full Pro features, normal operation                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
class OfflineGraceManager {
    private let gracePeriod: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private let warningPeriod: TimeInterval = 14 * 24 * 60 * 60  // 14 days
    private let maxOffline: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    func checkGraceStatus() -> GraceStatus {
        guard let lastOnline = UserDefaults.standard.object(forKey: "lastOnlineValidation") as? Date else {
            return .unknown
        }

        let offlineDuration = Date().timeIntervalSince(lastOnline)

        if offlineDuration > maxOffline {
            return .revoked
        } else if offlineDuration > warningPeriod {
            return .warning(daysRemaining: Int((maxOffline - offlineDuration) / 86400))
        } else if offlineDuration > gracePeriod {
            return .graceExpiring(daysRemaining: Int((warningPeriod - offlineDuration) / 86400))
        } else {
            return .valid
        }
    }

    enum GraceStatus {
        case valid
        case graceExpiring(daysRemaining: Int)
        case warning(daysRemaining: Int)
        case revoked
        case unknown
    }
}
```

---

## Enterprise Licensing

### License Server Integration

```swift
// Enterprise license validation via company's IdP
class EnterpriseAuthManager {
    func authenticate() async throws -> LicenseToken {
        // 1. Redirect to SSO provider
        let authURL = try await getAuthorizationURL()

        // 2. Handle callback with authorization code
        let code = try await waitForCallback()

        // 3. Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code)

        // 4. Validate enterprise license from ID token
        let claims = try validateIdToken(tokens.idToken)

        // 5. Check enterprise entitlements
        guard claims.groups.contains("pasteshelf-users") else {
            throw LicenseError.notEntitled
        }

        // 6. Generate license token
        return try await generateLicenseToken(from: claims)
    }
}
```

### Floating Licenses

```swift
// Enterprise floating license checkout
class FloatingLicenseManager {
    func checkoutLicense() async throws -> FloatingLicense {
        let request = CheckoutRequest(
            deviceId: DeviceInfo.shared.deviceId,
            userId: currentUser.id,
            features: ["all"]
        )

        let license = try await licenseServer.checkout(request)

        // Start heartbeat to maintain checkout
        startHeartbeat(license)

        return license
    }

    func checkinLicense() async throws {
        stopHeartbeat()
        try await licenseServer.checkin(currentLicense)
    }

    private func startHeartbeat(_ license: FloatingLicense) {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                try? await self.licenseServer.heartbeat(license.id)
            }
        }
    }
}
```

---

## Implementation

### Feature Flags

```swift
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    @Published private(set) var currentTier: LicenseTier = .community

    // Feature checks
    var isCloudSyncEnabled: Bool { currentTier >= .pro }
    var isAISearchEnabled: Bool { currentTier >= .pro }
    var isOCREnabled: Bool { currentTier >= .pro }
    var isAutomationEnabled: Bool { currentTier >= .pro }
    var isPluginsEnabled: Bool { currentTier >= .pro }
    var isTeamSharingEnabled: Bool { currentTier >= .enterprise }
    var isAdminConsoleEnabled: Bool { currentTier >= .enterprise }
    var isSSOEnabled: Bool { currentTier >= .enterprise }
    var isAuditLogEnabled: Bool { currentTier >= .enterprise }

    func updateFromLicense(_ claims: LicenseClaims) {
        currentTier = claims.tier

        // Explicit feature overrides
        if let features = claims.features {
            // Apply feature-specific flags
        }
    }
}

// Tier comparison
extension LicenseTier: Comparable {
    static func < (lhs: LicenseTier, rhs: LicenseTier) -> Bool {
        let order: [LicenseTier] = [.community, .pro, .enterprise]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
```

### Upgrade Prompts

```swift
struct FeatureGate<Content: View>: View {
    let requiredTier: LicenseTier
    let feature: String
    let content: () -> Content

    @EnvironmentObject var featureFlags: FeatureFlags

    var body: some View {
        if featureFlags.currentTier >= requiredTier {
            content()
        } else {
            UpgradePromptView(
                feature: feature,
                requiredTier: requiredTier
            )
        }
    }
}

// Usage
FeatureGate(requiredTier: .pro, feature: "Cloud Sync") {
    SyncSettingsView()
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Open-Core Model](OPEN_CORE_MODEL.md) | Business model |
| [Security](../security/SECURITY.md) | Security details |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Enterprise setup |

---

*Last updated: 2026-02-03*
