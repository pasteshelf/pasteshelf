# Product Roadmap

> **Last Updated**: 2026-02-03 | **Reading Time**: 10 minutes

PasteShelf development roadmap and planned features.

---

## Table of Contents

- [Vision](#vision)
- [Current Status](#current-status)
- [Release Schedule](#release-schedule)
- [Phase 1: Foundation](#phase-1-foundation)
- [Phase 2: Advanced Features](#phase-2-advanced-features)
- [Phase 3: Enterprise](#phase-3-enterprise)
- [Phase 4: Ecosystem](#phase-4-ecosystem)
- [Future Considerations](#future-considerations)

---

## Vision

**PasteShelf** aims to be the most privacy-respecting, powerful clipboard manager for macOS, serving individual users and enterprises alike.

### Core Principles

1. **Privacy First**: Local-first, E2E encryption, no tracking
2. **Open Source**: Free and open source under AGPL-3.0
3. **Native Experience**: Built with Swift/SwiftUI, feels like Apple made it
4. **Extensible**: Plugin system for customization

---

## Current Status

**Version**: 0.1.0 (Alpha)
**Stage**: Early Development

### Completed ✅
- Basic SwiftUI application structure
- CoreData persistence layer
- CloudKit container setup
- Project documentation

### In Progress 🚧
- Clipboard monitoring engine
- Basic UI implementation
- Local storage optimization

---

## Release Schedule

| Version | Target | Status | Focus |
|---------|--------|--------|-------|
| 0.1.0 | Q1 2026 | 🚧 In Progress | Core clipboard functionality |
| 0.2.0 | Q2 2026 | 📋 Planned | Search and organization |
| 0.3.0 | Q2 2026 | 📋 Planned | UI polish, settings |
| 1.0.0 | Q3 2026 | 📋 Planned | Stable release |
| 1.1.0 | Q4 2026 | 📋 Planned | Sync, semantic search, OCR |
| 2.0.0 | Q1 2027 | 📋 Planned | Enterprise features |

---

## Phase 1: Foundation

**Timeline**: Q1-Q3 2026
**Goal**: Stable initial release

### v0.1.0 - Core Engine 🚧

```
┌─────────────────────────────────────────────────────────────┐
│  Clipboard Monitoring                                        │
├─────────────────────────────────────────────────────────────┤
│  • NSPasteboard polling (500ms interval)                    │
│  • Content type detection (text, RTF, images)               │
│  • Duplicate detection                                       │
│  • App source tracking                                       │
│  • Basic storage with CoreData                              │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] Clipboard monitoring service
- [ ] Content type handlers
- [ ] CoreData persistence
- [ ] Basic menu bar UI
- [ ] Copy/paste functionality

### v0.2.0 - Search & Organization 📋

```
┌─────────────────────────────────────────────────────────────┐
│  Search & Organization                                       │
├─────────────────────────────────────────────────────────────┤
│  • Full-text search with NSPredicate                        │
│  • Favorites/pinning                                         │
│  • Tags                                                      │
│  • Filter by type                                           │
│  • Date-based navigation                                    │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] Search implementation
- [ ] Favorites system
- [ ] Tagging system
- [ ] Type filters
- [ ] Date grouping

### v0.3.0 - Polish & Settings 📋

```
┌─────────────────────────────────────────────────────────────┐
│  UI & Settings                                               │
├─────────────────────────────────────────────────────────────┤
│  • Floating panel interface                                  │
│  • Preferences window                                        │
│  • Keyboard shortcuts (customizable)                        │
│  • App exclusions                                           │
│  • History limits                                           │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] Floating panel UI
- [ ] Preferences system
- [ ] Hotkey management
- [ ] App exclusion rules
- [ ] Auto-cleanup settings

### v1.0.0 - Stable Release 📋

**Major Milestone**: Public release

**Features**:
- ✅ All Phase 1 features
- [ ] App Store submission
- [ ] GitHub open-source release
- [ ] Documentation complete
- [ ] Localization (10 languages)

---

## Phase 2: Advanced Features

**Timeline**: Q4 2026
**Goal**: Sync, search, and automation features

### v1.1.0 - Sync & Search

```
┌─────────────────────────────────────────────────────────────┐
│  Sync & Search Features                                      │
├─────────────────────────────────────────────────────────────┤
│  • iCloud sync with E2E encryption                          │
│  • Semantic search (NaturalLanguage)                        │
│  • OCR text extraction (Vision)                             │
│  • Smart collections                                         │
│  • Advanced automation rules                                │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] CloudKit sync engine
- [ ] E2E encryption layer
- [ ] Semantic search
- [ ] OCR integration

### v1.2.0 - Automation

```
┌─────────────────────────────────────────────────────────────┐
│  Automation                                                  │
├─────────────────────────────────────────────────────────────┤
│  • Rule-based actions                                        │
│  • Shortcuts app integration                                │
│  • AppleScript support                                       │
│  • URL schemes                                               │
│  • Webhooks                                                  │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] Rule engine
- [ ] Shortcuts actions
- [ ] AppleScript dictionary
- [ ] URL scheme handler
- [ ] Webhook system

### v1.3.0 - Plugin System

```
┌─────────────────────────────────────────────────────────────┐
│  Plugins                                                     │
├─────────────────────────────────────────────────────────────┤
│  • Plugin architecture                                       │
│  • Official plugins (GitHub, Notion, etc.)                  │
│  • Plugin marketplace                                        │
│  • Developer SDK                                             │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] Plugin loader
- [ ] Sandboxed plugin runtime
- [ ] Plugin API
- [ ] 5+ official plugins
- [ ] Developer documentation

---

## Phase 3: Enterprise

**Timeline**: Q1 2027
**Goal**: Enterprise-ready deployment

### v2.0.0 - Enterprise Features

```
┌─────────────────────────────────────────────────────────────┐
│  Enterprise Features                                         │
├─────────────────────────────────────────────────────────────┤
│  • SSO (SAML 2.0, OIDC)                                     │
│  • MDM deployment                                            │
│  • Centralized management                                    │
│  • Audit logging                                             │
│  • DLP policies                                              │
│  • Self-hosted sync option                                   │
└─────────────────────────────────────────────────────────────┘
```

**Deliverables**:
- [ ] SSO integration
- [ ] MDM configuration profiles
- [ ] Admin console (web)
- [ ] Audit log system
- [ ] DLP rule engine
- [ ] Self-hosted sync server

### v2.1.0 - Compliance

```
┌─────────────────────────────────────────────────────────────┐
│  Compliance                                                  │
├─────────────────────────────────────────────────────────────┤
│  • HIPAA compliance mode                                     │
│  • SOC 2 certification                                       │
│  • GDPR tools                                                │
│  • Data residency options                                    │
│  • BAA availability                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 4: Ecosystem

**Timeline**: 2027+
**Goal**: Platform expansion

### Potential Future Features

```
┌─────────────────────────────────────────────────────────────┐
│  Ecosystem Expansion                                         │
├─────────────────────────────────────────────────────────────┤
│  • iOS companion app                                         │
│  • iPadOS app                                                │
│  • visionOS app                                              │
│  • Safari extension                                          │
│  • Chrome extension                                          │
│  • AI-powered features                                       │
│  • Team collaboration                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Future Considerations

### Under Evaluation

| Feature | Consideration | Decision |
|---------|---------------|----------|
| iOS app | User demand, development cost | Evaluating |
| Windows version | Market size vs. development effort | Not planned |
| Linux version | Community interest | Considering |
| AI summarization | Privacy implications | Researching |
| Real-time collaboration | Technical complexity | Future |

### Community Requests

We track feature requests via GitHub Issues. Top requested features are prioritized in the roadmap.

**Request a feature**: [GitHub Discussions](https://github.com/pasteshelf/pasteshelf/discussions/categories/feature-requests)

---

## Contributing to the Roadmap

### How to Influence Development

1. **Vote on issues**: 👍 reactions on GitHub
2. **Submit proposals**: Detailed feature requests
3. **Contribute code**: PRs for planned features
4. **Sponsor development**: GitHub Sponsors

### Development Priorities

1. **Security fixes**: Immediate
2. **Bug fixes**: High priority
3. **Community requests**: Based on votes
4. **New features**: Per roadmap

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Contributing](../contributing/CONTRIBUTING.md) | How to contribute |
| [Architecture](../architecture/ARCHITECTURE.md) | Technical design |

---

*Last updated: 2026-02-03*
