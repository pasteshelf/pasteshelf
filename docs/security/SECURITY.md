# Security Documentation

> **Last Updated**: 2026-02-03 | **Reading Time**: 18 minutes

Comprehensive security architecture for PasteShelf.

---

## Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Encryption](#encryption)
- [Authentication](#authentication)
- [Data Protection](#data-protection)
- [Secure Development](#secure-development)
- [Vulnerability Disclosure](#vulnerability-disclosure)

---

## Security Overview

### Security Principles

1. **Privacy by Design**: Data stays local by default
2. **Defense in Depth**: Multiple security layers
3. **Least Privilege**: Minimal permissions required
4. **Transparency**: Open source core for audit

### Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Security Architecture                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Application Layer                                                      │
│   ─────────────────                                                      │
│   • Input validation                                                     │
│   • Sensitive data detection                                             │
│   • App sandboxing                                                       │
│                                                                          │
│   Data Layer                                                             │
│   ──────────                                                             │
│   • CoreData encryption                                                  │
│   • Keychain for secrets                                                 │
│   • Secure file storage                                                  │
│                                                                          │
│   Transport Layer                                                        │
│   ───────────────                                                        │
│   • TLS 1.3 for all connections                                          │
│   • Certificate pinning                                                  │
│   • E2E encryption for sync ⭐                                           │
│                                                                          │
│   System Layer                                                           │
│   ────────────                                                           │
│   • FileVault integration                                                │
│   • Biometric authentication                                             │
│   • App notarization                                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Threat Model

### Assets

| Asset | Sensitivity | Protection |
|-------|-------------|------------|
| Clipboard content | Variable | Encryption, access control |
| Passwords/keys | Critical | Auto-detection, exclusion |
| Sync data | High | E2E encryption |
| License tokens | Medium | Keychain storage |

### Threats

| Threat | Mitigation |
|--------|------------|
| Malware clipboard sniffing | App exclusion, secure detection |
| Device theft | FileVault, biometric lock |
| Network interception | TLS 1.3, E2E encryption |
| Memory dumping | Secure enclave, memory clearing |

---

## Encryption

### At Rest

```swift
// AES-256-GCM for local encryption
import CryptoKit

class LocalEncryption {
    func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!
    }

    func decrypt(_ encrypted: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: encrypted)
        return try AES.GCM.open(box, using: key)
    }
}
```

### In Transit

- TLS 1.3 for all connections
- Certificate pinning for API endpoints
- E2E encryption before CloudKit upload

### Key Management

- Master key derived from Keychain identity
- Per-device sync keys with ECDH exchange
- 90-day automatic key rotation (Enterprise)

---

## Authentication

### Biometric Authentication

```swift
import LocalAuthentication

func authenticate() async throws -> Bool {
    let context = LAContext()
    return try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Unlock PasteShelf"
    )
}
```

### License Authentication

- JWT tokens with RS256 signatures
- Offline grace period: 7-30 days
- Device binding with hardware ID

---

## Data Protection

### Sensitive Data Detection

Automatically detected:
- Passwords
- API keys
- Credit card numbers
- Social Security Numbers
- Private keys

### App Exclusion

Default excluded apps:
- 1Password
- Bitwarden
- LastPass
- Keychain Access
- Password managers

---

## Secure Development

### Code Security

- Static analysis with CodeQL
- Dependency scanning
- Code signing and notarization

### Build Security

- Reproducible builds
- Signed artifacts
- Secure CI/CD pipeline

---

## Vulnerability Disclosure

### Reporting

Email: security@pasteshelf.app

Include:
- Description
- Steps to reproduce
- Impact assessment
- Your contact info

### Response Timeline

| Severity | Response | Fix |
|----------|----------|-----|
| Critical | 24 hours | 7 days |
| High | 48 hours | 14 days |
| Medium | 1 week | 30 days |
| Low | 2 weeks | 90 days |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Privacy & Security Features](../features/PRIVACY_SECURITY_FEATURES.md) | Feature details |
| [Legal & Compliance](LEGAL_COMPLIANCE.md) | Compliance |

---

*Last updated: 2026-02-03*
