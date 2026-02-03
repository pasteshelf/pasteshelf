# Open-Core Business Model

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Documentation for PasteShelf's open-core business model and feature tiers.

---

## Table of Contents

- [Overview](#overview)
- [Feature Tiers](#feature-tiers)
- [Tier Comparison](#tier-comparison)
- [Pricing Strategy](#pricing-strategy)
- [Upgrade Paths](#upgrade-paths)
- [License Terms](#license-terms)

---

## Overview

PasteShelf uses an **open-core** business model:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Open-Core Model                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                  │   │
│   │                     COMMUNITY EDITION 🆓                         │   │
│   │                     ──────────────────                           │   │
│   │                                                                  │   │
│   │   • Open source (AGPL-3.0)                                       │   │
│   │   • Full-featured clipboard manager                              │   │
│   │   • Community-driven development                                 │   │
│   │   • Free forever                                                 │   │
│   │                                                                  │   │
│   │   "Everything you need for personal productivity"                │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                  │   │
│   │                       PRO EDITION ⭐                             │   │
│   │                       ──────────────                             │   │
│   │                                                                  │   │
│   │   • Commercial license                                           │   │
│   │   • Advanced productivity features                               │   │
│   │   • Cloud sync & AI-powered search                               │   │
│   │   • Priority support                                             │   │
│   │                                                                  │   │
│   │   "Power user features for professionals"                        │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                  │   │
│   │                    ENTERPRISE EDITION 🏢                         │   │
│   │                    ─────────────────────                         │   │
│   │                                                                  │   │
│   │   • Enterprise license                                           │   │
│   │   • Team collaboration features                                  │   │
│   │   • Admin controls & compliance                                  │   │
│   │   • Self-hosted & dedicated support                              │   │
│   │                                                                  │   │
│   │   "Secure, compliant, and manageable for organizations"          │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Feature Tiers

### Community Edition 🆓

**License**: AGPL-3.0 (Open Source)
**Price**: Free forever

Core clipboard management for everyone:

| Category | Features |
|----------|----------|
| **Clipboard** | Unlimited history, all content types |
| **Search** | Full-text search, fuzzy matching, filters |
| **Organization** | Folders, tags, favorites, pinning |
| **Privacy** | Local storage, sensitive data detection |
| **Security** | Biometric unlock, auto-lock, encryption |
| **UI** | Menu bar, floating panel, keyboard shortcuts |
| **Export** | JSON/CSV export, import |

### Pro Edition ⭐

**License**: Commercial
**Price**: $29/year or $49 lifetime

Everything in Community, plus:

| Category | Features |
|----------|----------|
| **Sync** | iCloud sync across devices |
| **AI Search** | Semantic search, natural language queries |
| **OCR** | Search text within images |
| **Automation** | Custom rules, JavaScript actions |
| **Plugins** | Plugin store, custom plugins |
| **Shortcuts** | Shortcuts.app integration |
| **AppleScript** | Full AppleScript support |
| **Smart Folders** | Auto-organizing folders |
| **Support** | Priority email support |

### Enterprise Edition 🏢

**License**: Enterprise Agreement
**Price**: Contact sales

Everything in Pro, plus:

| Category | Features |
|----------|----------|
| **Team** | Shared clipboard, team snippets |
| **Admin** | Central management console |
| **SSO** | SAML/OIDC integration |
| **MDM** | Jamf, Kandji, Intune support |
| **Compliance** | Audit logs, DLP policies |
| **Self-Hosted** | On-premise sync server |
| **Air-Gap** | No internet required deployment |
| **Support** | Dedicated account manager, SLA |

---

## Tier Comparison

### Complete Feature Matrix

| Feature | 🆓 CE | ⭐ Pro | 🏢 Enterprise |
|---------|:-----:|:------:|:-------------:|
| **Core Clipboard** |
| Unlimited history | ✅ | ✅ | ✅ |
| Text, images, files | ✅ | ✅ | ✅ |
| Rich text support | ✅ | ✅ | ✅ |
| Global hotkey | ✅ | ✅ | ✅ |
| Menu bar integration | ✅ | ✅ | ✅ |
| Floating panel | ✅ | ✅ | ✅ |
| **Search** |
| Full-text search | ✅ | ✅ | ✅ |
| Fuzzy matching | ✅ | ✅ | ✅ |
| Filter by type/app | ✅ | ✅ | ✅ |
| Semantic search | ❌ | ✅ | ✅ |
| OCR search | ❌ | ✅ | ✅ |
| **Organization** |
| Folders | ✅ | ✅ | ✅ |
| Tags | ✅ | ✅ | ✅ |
| Favorites | ✅ | ✅ | ✅ |
| Smart Folders | ❌ | ✅ | ✅ |
| **Privacy & Security** |
| Local storage | ✅ | ✅ | ✅ |
| Sensitive data detection | ✅ | ✅ | ✅ |
| App exclusion | ✅ | ✅ | ✅ |
| Biometric unlock | ✅ | ✅ | ✅ |
| E2E encryption | ❌ | ✅ | ✅ |
| **Sync** |
| iCloud sync | ❌ | ✅ | ✅ |
| Multi-device | ❌ | ✅ | ✅ |
| Self-hosted sync | ❌ | ❌ | ✅ |
| **Automation** |
| Basic actions | ✅ | ✅ | ✅ |
| Custom rules | ❌ | ✅ | ✅ |
| JavaScript actions | ❌ | ✅ | ✅ |
| Shortcuts.app | ❌ | ✅ | ✅ |
| AppleScript | ❌ | ✅ | ✅ |
| Webhooks | ❌ | ❌ | ✅ |
| **Plugins** |
| Use plugins | ❌ | ✅ | ✅ |
| Create plugins | ❌ | ✅ | ✅ |
| Private plugins | ❌ | ❌ | ✅ |
| **Enterprise** |
| Team sharing | ❌ | ❌ | ✅ |
| Admin console | ❌ | ❌ | ✅ |
| SSO (SAML/OIDC) | ❌ | ❌ | ✅ |
| MDM support | ❌ | ❌ | ✅ |
| Audit logging | ❌ | ❌ | ✅ |
| DLP policies | ❌ | ❌ | ✅ |
| **Support** |
| Community forum | ✅ | ✅ | ✅ |
| GitHub issues | ✅ | ✅ | ✅ |
| Priority email | ❌ | ✅ | ✅ |
| Dedicated support | ❌ | ❌ | ✅ |
| SLA | ❌ | ❌ | ✅ |

---

## Pricing Strategy

### Consumer Pricing

| Edition | Monthly | Annual | Lifetime |
|---------|---------|--------|----------|
| Community 🆓 | Free | Free | Free |
| Pro ⭐ | - | $29/year | $49 |

### Enterprise Pricing 🏢

| Team Size | Per Seat/Year | Volume Discount |
|-----------|---------------|-----------------|
| 5-25 | $99 | - |
| 26-100 | $89 | 10% |
| 101-500 | $79 | 20% |
| 500+ | Custom | Contact sales |

### Pricing Philosophy

1. **Free tier is genuinely useful** - Not crippled to force upgrades
2. **Fair value exchange** - Pro features justify the cost
3. **No dark patterns** - No artificial limitations or nagware
4. **Transparent pricing** - No hidden fees
5. **Lifetime option** - For users who prefer one-time purchase

---

## Upgrade Paths

### Community → Pro

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Upgrade to Pro                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  You're missing out on these Pro features:                               │
│                                                                          │
│  ⭐ iCloud Sync - Access your clipboard anywhere                         │
│  ⭐ AI Search - Find anything with natural language                      │
│  ⭐ OCR - Search text in images                                          │
│  ⭐ Automation - Custom rules and actions                                │
│  ⭐ Plugins - Extend with community plugins                              │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ┌─────────────────────┐     ┌─────────────────────────────────────┐   │
│  │  Annual Plan        │     │  Lifetime License                    │   │
│  │  ────────────       │     │  ─────────────────                   │   │
│  │                     │     │                                      │   │
│  │  $29/year           │     │  $49 one-time                        │   │
│  │                     │     │                                      │   │
│  │  [Subscribe]        │     │  [Purchase]                          │   │
│  └─────────────────────┘     └─────────────────────────────────────┘   │
│                                                                          │
│  30-day money-back guarantee                                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Pro → Enterprise

Contact sales for:
- Volume licensing
- Custom deployment
- Enterprise features
- Dedicated support

### Trial Period

- **Pro**: 14-day free trial
- **Enterprise**: 30-day pilot program

---

## License Terms

### Community Edition (AGPL-3.0)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AGPL-3.0 Key Points                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ✅ PERMITTED:                                                           │
│  • Use for any purpose (personal, commercial)                            │
│  • Modify and distribute                                                 │
│  • Use privately without sharing changes                                 │
│                                                                          │
│  ⚠️ REQUIRED:                                                            │
│  • Disclose source when distributing                                     │
│  • License derivatives under AGPL-3.0                                    │
│  • Provide source to network users (AGPL clause)                         │
│  • State changes made                                                    │
│                                                                          │
│  ❌ NOT PERMITTED:                                                       │
│  • Hold liable / warranty                                                │
│  • Use trademarks                                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Pro Edition (Commercial License)

```
PasteShelf Pro License Agreement

GRANT: License to use PasteShelf Pro on up to 3 devices
       owned by the licensee.

RESTRICTIONS:
• No redistribution
• No reverse engineering
• No transfer without consent

SUPPORT: Priority email support included.

UPDATES: All updates during license period.

TERMINATION: License revoked upon violation of terms.
```

### Enterprise Edition (Enterprise Agreement)

Custom license including:
- Named or floating seats
- Deployment rights
- Modification rights (for internal use)
- Support SLA
- Data processing agreement
- Security addendum

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [License System](LICENSE_SYSTEM.md) | Technical implementation |
| [Repository Structure](REPOSITORY_STRUCTURE.md) | Code organization |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Enterprise setup |

---

*Last updated: 2026-02-03*
