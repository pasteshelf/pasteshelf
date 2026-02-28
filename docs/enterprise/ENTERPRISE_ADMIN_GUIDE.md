# Enterprise Administration Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 25 minutes

Complete guide for administering PasteShelf Enterprise.

---

## Table of Contents

- [Overview](#overview)
- [Admin Console](#admin-console)
- [User Management](#user-management)
- [SSO Configuration](#sso-configuration)
- [Policy Management](#policy-management)
- [Audit & Compliance](#audit--compliance)
- [Team Features](#team-features)
- [Monitoring](#monitoring)

---

## Overview

PasteShelf provides centralized management for organizations.

### Enterprise Features

| Feature | Description |
|---------|-------------|
| Admin Console | Web-based management interface |
| SSO Integration | SAML 2.0 and OIDC support |
| User Management | Centralized user provisioning |
| Policy Management | Organization-wide policies |
| Audit Logging | Complete activity visibility |
| Team Features | Shared clipboards and snippets |
| DLP | Data loss prevention rules |
| MDM Support | Managed deployment |

---

## Admin Console

### Accessing the Console

```
URL: https://admin.pasteshelf.app
     or
     https://your-domain.com/admin (self-hosted)
```

### Dashboard Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PasteShelf Admin Console                    [Organization ▼] [Logout]  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐                                                        │
│  │  Dashboard  │  Users  │  Teams  │  Policies  │  Audit  │  Settings  │
│  └─────────────┘                                                        │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  Overview                                                                │
│  ────────                                                                │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │  Active Users   │  │  Seats Used     │  │  Storage Used   │         │
│  │                 │  │                 │  │                 │         │
│  │      247        │  │    247/500      │  │   1.2 TB        │         │
│  │                 │  │                 │  │                 │         │
│  │  ↑ 12 this week │  │  49% utilized   │  │  of 5 TB quota  │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
│  Recent Activity                              Quick Actions              │
│  ───────────────                              ─────────────              │
│                                                                          │
│  ┌─────────────────────────────────────┐    ┌─────────────────────────┐ │
│  │ • john@company.com logged in        │    │ [+ Add User]            │ │
│  │   2 minutes ago                     │    │ [+ Create Team]         │ │
│  │ • Policy "DLP-Finance" updated      │    │ [⚙ Configure SSO]       │ │
│  │   15 minutes ago                    │    │ [📊 View Reports]       │ │
│  │ • New device activated              │    │                         │ │
│  │   sarah@company.com - MacBook Pro   │    │                         │ │
│  │   1 hour ago                        │    │                         │ │
│  └─────────────────────────────────────┘    └─────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## User Management

### User Provisioning

#### Manual User Creation

```
Admin Console → Users → Add User

┌─────────────────────────────────────────────────────────────┐
│  Add New User                                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Email:        [john.doe@company.com              ]         │
│  Full Name:    [John Doe                          ]         │
│  Department:   [Engineering                    ▼]           │
│  Role:         [User                           ▼]           │
│                                                              │
│  Permissions:                                                │
│  ☑ Can use all features                                     │
│  ☑ Can sync to cloud                                        │
│  ☐ Can share with team                                      │
│  ☐ Can export data                                          │
│                                                              │
│  Teams:                                                      │
│  ☑ Engineering                                              │
│  ☐ Product                                                  │
│  ☐ Marketing                                                │
│                                                              │
│  [Cancel]                              [Send Invitation]     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### SCIM Provisioning

```yaml
# SCIM Configuration
scim:
  enabled: true
  base_url: https://admin.pasteshelf.app/scim/v2
  authentication: bearer_token
  token: <generated_token>

  # Supported operations
  operations:
    - Users: create, read, update, delete
    - Groups: create, read, update, delete

  # Attribute mapping
  mapping:
    userName: email
    displayName: name
    emails[primary].value: email
    groups: teams
```

#### SCIM API Examples

```bash
# Create user
curl -X POST https://admin.pasteshelf.app/scim/v2/Users \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/scim+json" \
  -d '{
    "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
    "userName": "john.doe@company.com",
    "name": {
      "givenName": "John",
      "familyName": "Doe"
    },
    "emails": [{"primary": true, "value": "john.doe@company.com"}],
    "active": true
  }'

# List users
curl https://admin.pasteshelf.app/scim/v2/Users \
  -H "Authorization: Bearer <token>"

# Deactivate user
curl -X PATCH https://admin.pasteshelf.app/scim/v2/Users/<id> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/scim+json" \
  -d '{
    "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
    "Operations": [{"op": "replace", "path": "active", "value": false}]
  }'
```

### Roles and Permissions

| Role | Permissions |
|------|-------------|
| **User** | Use app, sync, basic features |
| **Team Lead** | User + manage team members |
| **Admin** | Team Lead + configure policies |
| **Super Admin** | Full administrative access |

---

## SSO Configuration

### Supported Providers

| Provider | Protocol | Status |
|----------|----------|--------|
| Okta | SAML 2.0, OIDC | ✅ Supported |
| Azure AD | SAML 2.0, OIDC | ✅ Supported |
| Google Workspace | OIDC | ✅ Supported |
| OneLogin | SAML 2.0 | ✅ Supported |
| Ping Identity | SAML 2.0 | ✅ Supported |
| Custom | SAML 2.0, OIDC | ✅ Supported |

### SAML 2.0 Configuration

```
Admin Console → Settings → Authentication → SAML 2.0

┌─────────────────────────────────────────────────────────────┐
│  SAML 2.0 Configuration                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Service Provider (PasteShelf)                               │
│  ─────────────────────────────                               │
│  Entity ID:     https://admin.pasteshelf.app/saml/metadata   │
│  ACS URL:       https://admin.pasteshelf.app/saml/acs        │
│  SLO URL:       https://admin.pasteshelf.app/saml/slo        │
│                                                              │
│  [Download SP Metadata]                                      │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  Identity Provider                                           │
│  ─────────────────                                           │
│                                                              │
│  ○ Upload IdP Metadata XML                                   │
│    [Choose File] idp-metadata.xml                            │
│                                                              │
│  ● Manual Configuration                                      │
│                                                              │
│  IdP Entity ID:   [https://idp.company.com/saml        ]    │
│  SSO URL:         [https://idp.company.com/sso         ]    │
│  SLO URL:         [https://idp.company.com/slo         ]    │
│  Certificate:     [-----BEGIN CERTIFICATE-----...      ]    │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  Attribute Mapping                                           │
│  ─────────────────                                           │
│                                                              │
│  Email:         [email                    ]                  │
│  First Name:    [firstName                ]                  │
│  Last Name:     [lastName                 ]                  │
│  Groups:        [memberOf                 ]                  │
│                                                              │
│  [Test Configuration]                      [Save]            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### OIDC Configuration

```json
{
  "issuer": "https://login.company.com",
  "authorization_endpoint": "https://login.company.com/oauth2/authorize",
  "token_endpoint": "https://login.company.com/oauth2/token",
  "userinfo_endpoint": "https://login.company.com/oauth2/userinfo",
  "jwks_uri": "https://login.company.com/.well-known/jwks.json",
  "client_id": "pasteshelf-enterprise",
  "client_secret": "<secret>",
  "scopes": ["openid", "email", "profile", "groups"],
  "claim_mapping": {
    "email": "email",
    "name": "name",
    "groups": "groups"
  }
}
```

---

## Policy Management

### Policy Types

| Policy | Description |
|--------|-------------|
| **Data Retention** | How long to keep clipboard data |
| **Sync Policy** | What can be synced |
| **DLP Rules** | Data loss prevention |
| **App Restrictions** | Allowed/blocked apps |
| **Security Settings** | Authentication requirements |

### Creating Policies

```
Admin Console → Policies → Create Policy

┌─────────────────────────────────────────────────────────────┐
│  Create Policy                                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Policy Name:    [Finance Department Policy       ]         │
│  Description:    [Security policy for finance team]         │
│                                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  Data Retention                                              │
│  ──────────────                                              │
│  Maximum history: [90 days        ▼]                        │
│  Auto-delete sensitive: ☑ After [1 hour ▼]                  │
│                                                              │
│  DLP Rules                                                   │
│  ─────────                                                   │
│  ☑ Block credit card numbers                                │
│  ☑ Block SSN/Tax IDs                                        │
│  ☑ Block API keys/secrets                                   │
│  ☐ Custom patterns: [                          ]            │
│                                                              │
│  Sync Restrictions                                           │
│  ─────────────────                                           │
│  ☑ Disable sync for sensitive content                       │
│  ☑ Require encryption                                       │
│  ☐ Disable external sync entirely                           │
│                                                              │
│  App Restrictions                                            │
│  ────────────────                                            │
│  Blocked apps: [Add app...]                                  │
│  • com.competitor.app                                        │
│                                                              │
│  Assign To                                                   │
│  ─────────                                                   │
│  ☑ Finance team                                             │
│  ☑ Accounting team                                          │
│  ☐ All users                                                │
│                                                              │
│  [Cancel]                                    [Create Policy] │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### DLP Rule Examples

```yaml
# dlp-rules.yaml
rules:
  - name: "Credit Card Detection"
    pattern: '\b(?:\d[ -]*?){13,16}\b'
    validation: luhn_check
    action: block
    notification: admin_alert
    severity: high

  - name: "AWS Access Key"
    pattern: 'AKIA[0-9A-Z]{16}'
    action: block
    notification: [admin_alert, user_warning]
    severity: critical

  - name: "Private Key"
    pattern: '-----BEGIN (RSA |EC )?PRIVATE KEY-----'
    action: block
    notification: security_team
    severity: critical

  - name: "Internal Domain"
    pattern: '@internal\.company\.com'
    action: encrypt
    severity: medium

  - name: "Source Code"
    pattern: '(?:function|class|def|import)\s+\w+'
    source_apps: ["com.apple.Safari", "slack"]
    action: audit_only
    severity: low
```

---

## Audit & Compliance

### Audit Log

```
Admin Console → Audit → Event Log

┌─────────────────────────────────────────────────────────────────────────┐
│  Audit Log                                    [Export CSV] [Filter ▼]    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Timestamp            User                Event              Details     │
│  ─────────            ────                ─────              ───────     │
│                                                                          │
│  2026-02-03 12:45:23  john@company.com   item.created      Text, Safari │
│  2026-02-03 12:44:15  sarah@company.com  item.pasted       To: Slack    │
│  2026-02-03 12:43:02  admin@company.com  policy.updated    DLP-Finance  │
│  2026-02-03 12:42:30  john@company.com   dlp.blocked       Credit card  │
│  2026-02-03 12:41:18  mike@company.com   user.login        MacBook Pro  │
│  2026-02-03 12:40:05  sarah@company.com  sync.completed    15 items     │
│                                                                          │
│  [< Previous]  Page 1 of 1,234  [Next >]                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Compliance Reports

| Report | Description | Schedule |
|--------|-------------|----------|
| User Activity | Login/logout, device usage | Daily |
| Data Access | Who accessed what data | Daily |
| DLP Violations | Blocked content events | Real-time |
| Sync Activity | Cross-device sync events | Weekly |
| Policy Changes | Admin configuration changes | Real-time |

### Export Formats

- **CSV**: For spreadsheet analysis
- **JSON**: For programmatic processing
- **SIEM Integration**: Splunk, Datadog, etc.

```bash
# SIEM webhook configuration
{
  "endpoint": "https://siem.company.com/api/events",
  "format": "json",
  "events": ["dlp.blocked", "user.login_failed", "policy.changed"],
  "headers": {
    "Authorization": "Bearer <siem_token>"
  }
}
```

---

## Team Features

### Team Shared Clipboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Team: Engineering                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Shared Snippets                                   [+ New Snippet]       │
│  ───────────────                                                         │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ 📋 API Endpoint Template                          [Edit] [Delete]  │ │
│  │    https://api.company.com/v1/{endpoint}                           │ │
│  │    Created by: john@company.com                                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ 📋 PR Template                                    [Edit] [Delete]  │ │
│  │    ## Summary\n## Changes\n## Testing                              │ │
│  │    Created by: sarah@company.com                                   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  Team Members (12)                                                       │
│  ────────────────                                                        │
│                                                                          │
│  👤 John Doe (Lead)              👤 Sarah Smith                         │
│  👤 Mike Johnson                 👤 Emily Davis                         │
│  ...                                                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Team Configuration

```yaml
# team-config.yaml
team:
  name: "Engineering"
  description: "Software engineering team"

  settings:
    shared_snippets_enabled: true
    max_snippets: 100
    snippet_approval_required: false

    sync_settings:
      enabled: true
      sync_frequency: "realtime"
      conflict_resolution: "last_write_wins"

    permissions:
      can_invite_members: "lead_only"
      can_create_snippets: "all_members"
      can_delete_snippets: "creator_or_lead"

  members:
    - email: "john@company.com"
      role: "lead"
    - email: "sarah@company.com"
      role: "member"
```

---

## Monitoring

### Health Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│  System Health                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Services                                                                │
│  ────────                                                                │
│                                                                          │
│  ● Sync Server          Healthy     Response: 120ms                     │
│  ● Admin Console        Healthy     Response: 80ms                      │
│  ● SCIM Endpoint        Healthy     Response: 65ms                      │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  Metrics (Last 24 Hours)                                                 │
│  ───────────────────────                                                 │
│                                                                          │
│  API Requests:       45,230        Error Rate:    0.02%                 │
│  Sync Operations:    12,456        Avg Latency:   85ms                  │
│  Active Sessions:    198           Peak Users:    247                   │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  Alerts                                                                  │
│  ──────                                                                  │
│                                                                          │
│  ⚠️ High sync latency detected (Engineering team) - 2 hours ago        │
│  ✓ Resolved: License validation timeout - 6 hours ago                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Alerting Configuration

```yaml
# alerts.yaml
alerts:
  - name: "High Error Rate"
    condition: "error_rate > 1%"
    duration: "5 minutes"
    severity: "critical"
    notify: ["ops@company.com", "pagerduty"]

  - name: "DLP Critical Violation"
    condition: "dlp_severity == 'critical'"
    severity: "critical"
    notify: ["security@company.com", "slack:#security-alerts"]

  - name: "Sync Failures"
    condition: "sync_failures > 10"
    duration: "15 minutes"
    severity: "warning"
    notify: ["ops@company.com"]
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Deployment](ENTERPRISE_DEPLOYMENT.md) | Deployment guide |
| [Security](../security/SECURITY.md) | Security details |
| [Legal & Compliance](../security/LEGAL_COMPLIANCE.md) | Compliance info |

---

*Last updated: 2026-02-03*
