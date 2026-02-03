# Enterprise Deployment Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 20 minutes

Guide for deploying PasteShelf in enterprise environments.

---

## Table of Contents

- [Deployment Options](#deployment-options)
- [MDM Deployment](#mdm-deployment)
- [Self-Hosted Deployment](#self-hosted-deployment)
- [Air-Gapped Deployment](#air-gapped-deployment)
- [Configuration Management](#configuration-management)
- [Network Requirements](#network-requirements)
- [Troubleshooting](#troubleshooting)

---

## Deployment Options

### Comparison

| Option | Internet | Management | Best For |
|--------|----------|------------|----------|
| Cloud Managed | Required | PasteShelf Cloud | Standard enterprises |
| MDM Deployed | Required | Your MDM | Managed Mac fleets |
| Self-Hosted | Optional | Your servers | Data sovereignty |
| Air-Gapped | Not needed | Isolated | High-security environments |

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Enterprise Deployment Options                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   OPTION 1: Cloud Managed                                                │
│   ───────────────────────                                                │
│                                                                          │
│   ┌─────────┐        ┌─────────────────────┐                           │
│   │ Mac     │◀──────▶│  PasteShelf Cloud   │                           │
│   │ Devices │        │  • License server   │                           │
│   └─────────┘        │  • Sync server      │                           │
│                      │  • Admin console    │                           │
│                      └─────────────────────┘                           │
│                                                                          │
│   OPTION 2: MDM Deployed (Hybrid)                                       │
│   ───────────────────────────────                                       │
│                                                                          │
│   ┌─────────┐   ┌────────┐        ┌─────────────────────┐              │
│   │ Mac     │◀──│  MDM   │        │  PasteShelf Cloud   │              │
│   │ Devices │   │ Server │        │  (License + Sync)   │              │
│   └─────────┘   └────────┘        └─────────────────────┘              │
│       │              │                      ▲                           │
│       └──────────────┴──────────────────────┘                           │
│                                                                          │
│   OPTION 3: Self-Hosted                                                 │
│   ─────────────────────                                                 │
│                                                                          │
│   ┌─────────┐        ┌─────────────────────────────────────┐           │
│   │ Mac     │◀──────▶│  Your Infrastructure                │           │
│   │ Devices │        │  ┌──────────┐  ┌──────────────────┐ │           │
│   └─────────┘        │  │ License  │  │   Sync Server    │ │           │
│                      │  │  Server  │  │   (PostgreSQL)   │ │           │
│                      │  └──────────┘  └──────────────────┘ │           │
│                      └─────────────────────────────────────┘           │
│                                                                          │
│   OPTION 4: Air-Gapped                                                  │
│   ────────────────────                                                  │
│                                                                          │
│   ┌─────────┐        ┌─────────────────────────────────────┐           │
│   │ Mac     │◀──────▶│  Isolated Network                   │           │
│   │ Devices │        │  ┌──────────┐  ┌──────────────────┐ │           │
│   └─────────┘        │  │ License  │  │   Local Sync     │ │           │
│   (No Internet)      │  │  Server  │  │   (No Cloud)     │ │           │
│                      │  └──────────┘  └──────────────────┘ │           │
│                      └─────────────────────────────────────┘           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## MDM Deployment

### Supported MDM Solutions

| MDM | Support Level | Notes |
|-----|---------------|-------|
| Jamf Pro | ✅ Full | Recommended |
| Kandji | ✅ Full | |
| Mosyle | ✅ Full | |
| Microsoft Intune | ✅ Full | |
| VMware Workspace ONE | ✅ Full | |
| SimpleMDM | ✅ Basic | |

### Jamf Pro Deployment

#### 1. Package Preparation

```bash
# Download enterprise package
curl -O https://download.pasteshelf.app/enterprise/PasteShelf-Enterprise-1.0.0.pkg

# Verify checksum
shasum -a 256 PasteShelf-Enterprise-1.0.0.pkg
# Expected: abc123...
```

#### 2. Configuration Profile

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.pasteshelf.PasteShelf</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.company.pasteshelf.config</string>
            <key>PayloadUUID</key>
            <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
            <key>PayloadDisplayName</key>
            <string>PasteShelf Configuration</string>

            <!-- License Configuration -->
            <key>LicenseServer</key>
            <string>https://license.company.com</string>
            <key>OrganizationID</key>
            <string>org_abc123</string>

            <!-- SSO Configuration -->
            <key>SSOEnabled</key>
            <true/>
            <key>SSOProvider</key>
            <string>okta</string>
            <key>SSODomain</key>
            <string>company.okta.com</string>

            <!-- Feature Configuration -->
            <key>CloudSyncEnabled</key>
            <true/>
            <key>LocalStorageOnly</key>
            <false/>

            <!-- Security Settings -->
            <key>RequireBiometricAuth</key>
            <true/>
            <key>AutoLockTimeout</key>
            <integer>300</integer>
            <key>ClearOnQuit</key>
            <false/>

            <!-- DLP Settings -->
            <key>DLPEnabled</key>
            <true/>
            <key>BlockCreditCards</key>
            <true/>
            <key>BlockAPIKeys</key>
            <true/>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>PasteShelf Enterprise</string>
    <key>PayloadIdentifier</key>
    <string>com.company.pasteshelf</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>12345678-1234-1234-1234-123456789012</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

#### 3. Smart Group

```xml
<!-- Target Macs with PasteShelf license -->
<smart_computer_group>
    <name>PasteShelf Users</name>
    <criteria>
        <criterion>
            <name>Department</name>
            <type>String</type>
            <operator>is</operator>
            <value>Engineering</value>
        </criterion>
        <criterion>
            <name>Operating System Version</name>
            <type>String</type>
            <operator>greater than or equal</operator>
            <value>14.0</value>
        </criterion>
    </criteria>
</smart_computer_group>
```

### Kandji Deployment

```yaml
# kandji-blueprint.yaml
name: "PasteShelf Enterprise"
description: "Deploy PasteShelf to managed Macs"

items:
  - type: custom_app
    name: "PasteShelf"
    installer_url: "https://download.pasteshelf.app/enterprise/latest.pkg"
    version: "1.0.0"
    auto_update: true

  - type: custom_profile
    name: "PasteShelf Configuration"
    payload: |
      <configuration_profile>
        <!-- Profile content -->
      </configuration_profile>

  - type: custom_script
    name: "PasteShelf License Activation"
    script: |
      #!/bin/bash
      # Activate enterprise license
      /Applications/PasteShelf.app/Contents/MacOS/pasteshelf-cli \
        activate --enterprise \
        --server https://license.company.com \
        --org org_abc123

assignment:
  blueprints:
    - "Engineering Macs"
    - "Product Macs"
```

---

## Self-Hosted Deployment

### Infrastructure Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **License Server** | 1 vCPU, 2GB RAM | 2 vCPU, 4GB RAM |
| **Sync Server** | 2 vCPU, 4GB RAM | 4 vCPU, 8GB RAM |
| **Database** | PostgreSQL 14+ | PostgreSQL 15+ with replication |
| **Storage** | 100GB SSD | 500GB SSD |

### Docker Deployment

```yaml
# docker-compose.yml
version: '3.8'

services:
  license-server:
    image: pasteshelf/license-server:latest
    environment:
      - DATABASE_URL=postgres://USERNAME:PASSWORD@db:5432/licenses
      - JWT_SECRET=${JWT_SECRET}
      - ADMIN_EMAIL=admin@company.com
    ports:
      - "8080:8080"
    depends_on:
      - db
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  sync-server:
    image: pasteshelf/sync-server:latest
    environment:
      - DATABASE_URL=postgres://USERNAME:PASSWORD@db:5432/sync
      - ENCRYPTION_KEY=${ENCRYPTION_KEY}
      - LICENSE_SERVER_URL=http://license-server:8080
    ports:
      - "8081:8081"
    depends_on:
      - db
      - license-server
    volumes:
      - sync-data:/data

  admin-console:
    image: pasteshelf/admin-console:latest
    environment:
      - API_URL=http://license-server:8080
      - SYNC_URL=http://sync-server:8081
    ports:
      - "443:443"
    depends_on:
      - license-server
      - sync-server

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

volumes:
  db-data:
  sync-data:
```

### Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pasteshelf-license-server
  namespace: pasteshelf
spec:
  replicas: 2
  selector:
    matchLabels:
      app: license-server
  template:
    metadata:
      labels:
        app: license-server
    spec:
      containers:
      - name: license-server
        image: pasteshelf/license-server:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: pasteshelf-secrets
              key: database-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: pasteshelf-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: license-server
  namespace: pasteshelf
spec:
  selector:
    app: license-server
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

---

## Air-Gapped Deployment

### Overview

For high-security environments without internet access.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Air-Gapped Architecture                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌───────────────────────────────────────────────────────────────────┐ │
│   │                      Secure Network                                │ │
│   │                                                                    │ │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │ │
│   │   │   Mac #1    │  │   Mac #2    │  │      Internal           │  │ │
│   │   │             │  │             │  │      Servers            │  │ │
│   │   │  PasteShelf │  │  PasteShelf │  │  ┌─────────────────┐   │  │ │
│   │   │             │  │             │  │  │ License Server  │   │  │ │
│   │   └──────┬──────┘  └──────┬──────┘  │  └─────────────────┘   │  │ │
│   │          │                │         │  ┌─────────────────┐   │  │ │
│   │          │                │         │  │  Sync Server    │   │  │ │
│   │          └────────┬───────┘         │  │  (Local only)   │   │  │ │
│   │                   │                 │  └─────────────────┘   │  │ │
│   │                   └─────────────────│                        │  │ │
│   │                                     └─────────────────────────┘  │ │
│   └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│   No Internet Required                                                   │
│   ────────────────────                                                   │
│   • Offline license validation                                           │
│   • Local-only sync                                                      │
│   • No telemetry                                                         │
│   • Manual updates                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Offline License Activation

```bash
# 1. Generate activation request on air-gapped machine
/Applications/PasteShelf.app/Contents/MacOS/pasteshelf-cli \
  license generate-request \
  --output /tmp/activation-request.json

# 2. Transfer request to internet-connected machine
# (via USB, secure file transfer, etc.)

# 3. On internet-connected machine, get license
curl -X POST https://license.pasteshelf.app/api/v1/activate/offline \
  -H "Authorization: Bearer <admin_token>" \
  -d @activation-request.json \
  -o activation-response.json

# 4. Transfer response back to air-gapped machine

# 5. Apply license
/Applications/PasteShelf.app/Contents/MacOS/pasteshelf-cli \
  license apply \
  --file /tmp/activation-response.json
```

### Local Sync Server

```yaml
# air-gapped-sync.yaml
sync:
  mode: local
  server: https://sync.internal.company.com
  database:
    type: postgresql
    host: db.internal.company.com
    port: 5432
    name: pasteshelf_sync
    ssl: true

  # No cloud features
  cloud_backup: disabled
  external_sync: disabled

  # Local network only
  allowed_networks:
    - 10.0.0.0/8
    - 192.168.0.0/16

  # Encryption
  encryption:
    enabled: true
    algorithm: AES-256-GCM
    key_rotation: 90_days
```

---

## Configuration Management

### Managed Preferences

```xml
<!-- com.pasteshelf.PasteShelf.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Managed by IT - users cannot change -->
    <key>ManagedPreferences</key>
    <dict>
        <!-- Security -->
        <key>RequireBiometricAuth</key>
        <true/>
        <key>AutoLockTimeout</key>
        <integer>300</integer>

        <!-- Data Retention -->
        <key>MaxHistoryDays</key>
        <integer>90</integer>
        <key>MaxHistoryItems</key>
        <integer>5000</integer>

        <!-- Features -->
        <key>CloudSyncEnabled</key>
        <true/>
        <key>PluginsEnabled</key>
        <false/>

        <!-- DLP -->
        <key>DLPEnabled</key>
        <true/>
    </dict>

    <!-- Defaults - users can change -->
    <key>DefaultPreferences</key>
    <dict>
        <key>Theme</key>
        <string>system</string>
        <key>GlobalHotkey</key>
        <string>cmd+shift+v</string>
    </dict>
</dict>
</plist>
```

---

## Network Requirements

### Firewall Rules

| Service | Destination | Port | Protocol |
|---------|-------------|------|----------|
| License Validation | license.pasteshelf.app | 443 | HTTPS |
| CloudKit Sync | *.icloud-content.com | 443 | HTTPS |
| Admin Console | admin.pasteshelf.app | 443 | HTTPS |
| Updates | download.pasteshelf.app | 443 | HTTPS |

### Self-Hosted Firewall

| Service | Internal Port | Notes |
|---------|---------------|-------|
| License Server | 8080 | Behind load balancer |
| Sync Server | 8081 | WebSocket support required |
| Admin Console | 443 | HTTPS required |
| Database | 5432 | Internal only |

---

## Troubleshooting

### Common Issues

#### License Activation Failure

```bash
# Check network connectivity
curl -v https://license.pasteshelf.app/health

# View detailed logs
log show --predicate 'subsystem == "com.pasteshelf.PasteShelf"' \
  --last 1h --level debug | grep -i license

# Reset license state
defaults delete com.pasteshelf.PasteShelf LicenseToken
```

#### Sync Issues

```bash
# Check sync server connectivity
curl -v https://sync.company.com/health

# View sync logs
log show --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "sync"' \
  --last 1h

# Force sync reset
/Applications/PasteShelf.app/Contents/MacOS/pasteshelf-cli sync reset
```

#### MDM Profile Not Applying

```bash
# Check profile installation
profiles show -type configuration | grep -i pasteshelf

# Reinstall profile
sudo profiles remove -identifier com.company.pasteshelf
sudo profiles install -path /path/to/profile.mobileconfig
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Admin console |
| [Security](../security/SECURITY.md) | Security details |
| [Troubleshooting](../operations/TROUBLESHOOTING.md) | Common issues |

---

*Last updated: 2026-02-03*
