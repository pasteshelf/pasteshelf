# Microsoft Intune Deployment Guide for PasteShelf Enterprise

> **Last Updated**: 2026-02-28 | **Reading Time**: 35 minutes | **Audience**: Microsoft Intune / Endpoint Manager Administrators

Complete guide for deploying and managing PasteShelf Enterprise on managed Mac fleets using Microsoft Intune (part of Microsoft Endpoint Manager).

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Package Preparation](#package-preparation)
- [App Deployment](#app-deployment)
- [Custom Configuration Profile](#custom-configuration-profile)
- [Configuration Key Reference](#configuration-key-reference)
- [Example Configuration Profile XML](#example-configuration-profile-xml)
- [Device Filters and Dynamic Groups](#device-filters-and-dynamic-groups)
- [Deployment Verification](#deployment-verification)
- [Troubleshooting](#troubleshooting)
- [Updating and Removal](#updating-and-removal)
- [Security Considerations](#security-considerations)
- [Related Documentation](#related-documentation)

---

## Quick Start

For experienced Intune administrators, here is the complete deployment sequence at a glance:

```
1. Build the .intunemac package:
   IntuneAppUtil -c PasteShelf-Enterprise-1.0.0.pkg \
                 -o /tmp/intunemac/ \
                 -v

2. In the Intune admin center (https://intune.microsoft.com):
   a. Apps > macOS > Add > Line-of-business app
      - Upload the .intunemac file
      - Set bundle ID: com.pasteshelf.PasteShelf
      - Assign to the target device or user group

   b. Devices > macOS > Configuration profiles > Create > New policy
      - Platform: macOS
      - Profile type: Templates > Custom
      - Upload your PasteShelf-Enterprise.mobileconfig
      - Assign to the same group as the app

3. Verify on a target device:
   defaults read com.pasteshelf.PasteShelf
   profiles list | grep -i pasteshelf
```

The sections below cover each step in full detail with examples.

---

## Prerequisites

Before beginning the deployment, confirm the following are in place.

### Microsoft Intune Licensing

| License | Minimum Required | Notes |
|---------|-----------------|-------|
| Microsoft Intune Plan 1 | Required | Included in Microsoft 365 Business Premium, E3, E5, and EMS E3/E5 |
| Microsoft Intune Plan 2 | Recommended | Adds advanced endpoint analytics and privilege management |
| Microsoft Entra ID P1 | Required for dynamic groups | Needed to create dynamic Azure AD device or user groups |
| Microsoft Entra ID P2 | Required for Conditional Access policies | Needed for device compliance-based Conditional Access |

Confirm your tenant has the Intune service enabled by navigating to [https://intune.microsoft.com](https://intune.microsoft.com) and verifying access.

### macOS Device Enrollment

All target Macs must be enrolled in Intune before policies and apps can be deployed. Supported enrollment methods for macOS:

| Method | Description | Recommended For |
|--------|-------------|-----------------|
| Automated Device Enrollment (ADE) | Zero-touch enrollment via Apple Business Manager or Apple School Manager | New corporate-owned Macs |
| Device Enrollment | User-initiated enrollment via Company Portal | Existing devices or BYOD |
| Direct Enrollment | Enrollment without user affinity via Apple Configurator | Shared or kiosk devices |

To confirm enrollment status for a device, navigate to **Intune admin center** → **Devices** → **macOS** → select the device → confirm **Enrollment state** is `Enrolled`.

The **Intune Management Extension (IME)** must be installed on each device for shell-script-based deployments. It is installed automatically on enrolled macOS devices the first time a shell script or LOB app is assigned.

### PasteShelf Enterprise Setup

- Your **Organization ID** (`OrganizationID`), configured by your IT administrator.

### PasteShelf Installer Package

Download the signed `.pkg` from the PasteShelf releases page:

```bash
# Download the Enterprise package
curl -O https://download.pasteshelf.app/enterprise/PasteShelf-Enterprise-1.0.0.pkg

# Verify the SHA-256 checksum against the value in your customer portal
shasum -a 256 PasteShelf-Enterprise-1.0.0.pkg
```

Confirm the package is signed by **PasteShelf, Inc.** before wrapping it for Intune:

```bash
pkgutil --check-signature PasteShelf-Enterprise-1.0.0.pkg
```

Expected output includes:
```
Status: signed by a developer certificate issued by Apple
```

### Required Tools

| Tool | Purpose | Install |
|------|---------|---------|
| `IntuneAppUtil` | Wraps `.pkg` into `.intunemac` format | Download from the [Microsoft Intune GitHub releases page](https://github.com/msintuneappsdk/intune-app-wrapping-tool-mac) |
| `uuidgen` | Generates UUIDs for configuration profiles | Built in to macOS |
| `pkgbuild` / `productbuild` | Builds `.pkg` installers if creating a custom package | Built in to macOS with Xcode Command Line Tools |

---

## Package Preparation

Intune deploys macOS line-of-business (LOB) apps using the `.intunemac` container format. You must wrap the PasteShelf `.pkg` installer into this format before uploading to the Intune admin center.

### Step 1: Download IntuneAppUtil

`IntuneAppUtil` is a command-line tool provided by Microsoft. Download it from the Microsoft Intune App Wrapping Tool for Mac repository:

```bash
# Download IntuneAppUtil
curl -L -o /usr/local/bin/IntuneAppUtil \
  https://github.com/msintuneappsdk/intune-app-wrapping-tool-mac/releases/latest/download/IntuneAppUtil

# Make it executable
chmod +x /usr/local/bin/IntuneAppUtil

# Verify the tool is functional
IntuneAppUtil -h
```

> **Note**: `IntuneAppUtil` requires macOS and Xcode Command Line Tools. Install them with `xcode-select --install` if not already present.

### Step 2: Wrap the Package

Run `IntuneAppUtil` to produce the `.intunemac` file. The tool validates the package signature and wraps it into the format Intune expects.

```bash
# Create the output directory
mkdir -p /tmp/intunemac-output

# Wrap the PasteShelf installer
IntuneAppUtil \
  -c PasteShelf-Enterprise-1.0.0.pkg \
  -o /tmp/intunemac-output/ \
  -v

# The output file will be named after the input package:
# /tmp/intunemac-output/PasteShelf-Enterprise-1.0.0.pkg.intunemac
```

`IntuneAppUtil` flags:

| Flag | Description |
|------|-------------|
| `-c` | Path to the source `.pkg` file |
| `-o` | Output directory for the `.intunemac` file |
| `-v` | Verbose output |

Expected output:
```
Wrapping PasteShelf-Enterprise-1.0.0.pkg...
Verifying package...
Package signed by: PasteShelf, Inc.
Wrapping complete.
Output: /tmp/intunemac-output/PasteShelf-Enterprise-1.0.0.pkg.intunemac
```

### Step 3: Verify the Wrapped Package

Confirm the `.intunemac` file was created:

```bash
ls -lh /tmp/intunemac-output/
# PasteShelf-Enterprise-1.0.0.pkg.intunemac   ~XX MB
```

The `.intunemac` file is a zip archive containing the original `.pkg` and Intune metadata. You can inspect its contents with:

```bash
unzip -l /tmp/intunemac-output/PasteShelf-Enterprise-1.0.0.pkg.intunemac
```

### Building a Custom Installer Package (Optional)

If your organization requires a custom pre-configuration script or post-install steps, you can build a custom `.pkg` using `pkgbuild` before wrapping with `IntuneAppUtil`:

```bash
# Build a flat package from an application bundle
pkgbuild \
  --root /Applications/PasteShelf.app \
  --install-location /Applications/PasteShelf.app \
  --identifier com.pasteshelf.PasteShelf \
  --version 1.0.0 \
  --sign "Developer ID Installer: Your Company (TEAMID)" \
  PasteShelf-Enterprise-1.0.0-custom.pkg
```

For packages that include pre/post-install scripts:

```bash
# Build with scripts
pkgbuild \
  --root /Applications/PasteShelf.app \
  --install-location /Applications/PasteShelf.app \
  --identifier com.pasteshelf.PasteShelf \
  --version 1.0.0 \
  --scripts /path/to/scripts/ \
  --sign "Developer ID Installer: Your Company (TEAMID)" \
  PasteShelf-Enterprise-1.0.0-custom.pkg
```

After building your custom `.pkg`, wrap it with `IntuneAppUtil` as described in Step 2 above.

---

## App Deployment

### Adding PasteShelf as a Line-of-Business App

1. Sign in to the **Intune admin center** at [https://intune.microsoft.com](https://intune.microsoft.com).
2. Navigate to **Apps** → **macOS** → **Add**.
3. In the **Select app type** pane, select **Line-of-business app** and click **Select**.
4. Under the **App package file** tab:
   - Click **Select file** and upload `PasteShelf-Enterprise-1.0.0.pkg.intunemac`.
   - Intune parses the file and auto-populates fields from the package metadata.
5. Under the **App information** tab, confirm or fill in the following:

   | Field | Value |
   |-------|-------|
   | Name | `PasteShelf Enterprise` |
   | Description | `Privacy-first clipboard manager for managed macOS devices` |
   | Publisher | `PasteShelf, Inc.` |
   | Minimum operating system | `macOS 14.0` |
   | Bundle ID | `com.pasteshelf.PasteShelf` |
   | Build number | `1.0.0` |
   | Version | `1.0.0` |
   | Category | `Productivity` |
   | Featured app | Optional |
   | Information URL | `https://pasteshelf.app/enterprise` |
   | Privacy URL | `https://pasteshelf.app/privacy` |

6. Click **Next**.

### Configuring Scope Tags

Scope tags control which Intune admin roles can see and manage this app. Under the **Scope tags** tab:

1. Click **Select scope tags** and choose the appropriate tags for your environment (for example, `MacOS-Apps` or `Enterprise`).
2. Click **Next**.

### Assigning the App to Groups

Under the **Assignments** tab:

1. Click **Add group** under **Required**.
2. Select the Azure AD device group or user group that should receive PasteShelf (see [Device Filters and Dynamic Groups](#device-filters-and-dynamic-groups)).
3. The **Required** assignment type installs the app silently without user interaction.
4. Optionally, add a group under **Available for enrolled devices** if you want to also allow on-demand installation via Company Portal for devices not in the required group.
5. Click **Next** → **Create**.

> **Device vs. User groups**: For macOS app deployments, Microsoft recommends assigning LOB apps to **device groups** when using Automated Device Enrollment, as device-based assignment does not require a user to be signed in. Assign to **user groups** when targeting BYOD or user-enrolled devices.

### Monitoring Deployment Status

After the app is created and assigned:

1. Navigate to **Apps** → **macOS** → select `PasteShelf Enterprise`.
2. Under the **Monitor** section, click **Device install status** or **User install status**.
3. The status column shows `Installed`, `Pending`, `Failed`, or `Not applicable` for each device or user.

Allow up to 15 minutes for newly enrolled devices to receive and install the app. The **Intune Management Extension** handles the actual package installation on the device.

---

## Custom Configuration Profile

The configuration profile delivers managed preferences to PasteShelf on each device. Settings pushed via Intune take precedence over user-configured settings and are displayed as locked (read-only) within the PasteShelf preferences pane.

Intune supports two approaches for delivering custom preferences to macOS apps:

| Approach | When to Use |
|----------|-------------|
| **Custom profile (.mobileconfig upload)** | Recommended. Works for all Intune tenants. Full control over payload structure. |
| **Settings Catalog** | Use when Microsoft has added PasteShelf keys to the Intune Settings Catalog. Check the catalog for `com.pasteshelf.PasteShelf` entries before proceeding. |

This guide covers the **Custom profile** approach, which is universally supported.

### Step 1: Create the .mobileconfig File

Create a file named `PasteShelf-Enterprise.mobileconfig` on your administrator workstation. The full XML for a complete enterprise deployment is provided in the [Example Configuration Profile XML](#example-configuration-profile-xml) section.

Generate unique UUIDs for the profile before deploying:

```bash
# Generate two UUIDs: one for the outer profile, one for the inner payload
uuidgen   # Use for outer PayloadUUID
uuidgen   # Use for inner PayloadUUID
```

Replace the placeholder UUID values in the XML with your generated UUIDs.

### Step 2: Create a Configuration Profile in Intune

1. In the **Intune admin center**, navigate to **Devices** → **macOS** → **Configuration profiles**.
2. Click **Create** → **New policy**.
3. Under **Platform**, select `macOS`.
4. Under **Profile type**, select `Templates`.
5. Select `Custom` from the template list and click **Create**.
6. Under the **Basics** tab:

   | Field | Value |
   |-------|-------|
   | Name | `PasteShelf Enterprise Configuration` |
   | Description | `Managed preferences for PasteShelf Enterprise. Deployed by IT via Intune.` |

7. Click **Next**.
8. Under the **Configuration settings** tab:

   | Field | Value |
   |-------|-------|
   | Custom configuration profile name | `PasteShelf Enterprise Settings` |
   | Deployment channel | `Device channel` |

   > Use **Device channel** for device-level preferences that apply regardless of which user is signed in. Use **User channel** only if you need per-user preferences on shared Macs.

9. Click **Upload file** and select your `PasteShelf-Enterprise.mobileconfig` file.
10. Intune validates the XML structure. If validation fails, check the [Troubleshooting](#troubleshooting) section.
11. Click **Next**.

### Step 3: Assign the Configuration Profile

Under the **Assignments** tab:

1. Click **Add groups** under **Included groups**.
2. Select the same Azure AD device group or user group you used for the app assignment. Profile and app must be assigned to matching groups to ensure they are delivered together.
3. Optionally, use **Add filter** to scope the assignment further with a device filter (see [Device Filters and Dynamic Groups](#device-filters-and-dynamic-groups)).
4. Click **Next** → **Create**.

### Step 4: Monitor Profile Delivery

After assignment:

1. Navigate to **Devices** → **macOS** → **Configuration profiles** → select `PasteShelf Enterprise Configuration`.
2. Under the **Monitor** section, click **Device status**.
3. Confirm devices show `Succeeded` in the **State** column.

Allow up to 15 minutes for profiles to be delivered to devices that have recently checked in.

---

## Configuration Key Reference

All keys are read from the managed preferences domain `com.pasteshelf.PasteShelf`. Keys delivered via an Intune configuration profile are locked and cannot be overridden by end users.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `OrganizationID` | String | — | Your organization identifier, provided by PasteShelf at license issuance. Example: `org_abc123` |
| `SSOEnabled` | Boolean | `false` | Enable SSO authentication. When `true`, users are required to authenticate via the configured identity provider before accessing the app. |
| `SSOProvider` | String | — | Name of the identity provider. Accepted values: `okta`, `azure`, `google`, `onelogin`, `ping`, `custom` |
| `SSODomain` | String | — | The IdP domain used for SSO. For Azure AD, use your tenant's `.onmicrosoft.com` domain or verified custom domain. Example: `company.okta.com` or `company.onmicrosoft.com` |
| `CloudSyncEnabled` | Boolean | `true` | Enable iCloud sync for clipboard history across the user's Apple devices. Set to `false` to disable sync organization-wide. |
| `LocalStorageOnly` | Boolean | `false` | When `true`, restricts all clipboard data to the local device and disables all sync. Overrides `CloudSyncEnabled`. |
| `PluginsEnabled` | Boolean | `true` | Enable the PasteShelf plugin system. Set to `false` to prevent users from installing or running plugins. |
| `RequireBiometricAuth` | Boolean | `false` | Require Touch ID (or password fallback) before the app window opens or before pasting sensitive items. |
| `AutoLockTimeout` | Integer | `0` | Number of seconds of inactivity before PasteShelf locks and requires re-authentication. `0` disables auto-lock. Example: `300` (5 minutes). Requires `RequireBiometricAuth` to be `true`. |
| `ClearOnQuit` | Boolean | `false` | When `true`, clears the local clipboard history every time PasteShelf quits. |
| `MaxHistoryDays` | Integer | `0` | Maximum number of days to retain clipboard history. Older items are automatically purged. `0` means unlimited retention. |
| `MaxHistoryItems` | Integer | `500` | Maximum number of clipboard items to store. When the limit is reached, the oldest items are removed. |
| `ExcludePrivateBrowsing` | Boolean | `true` | When `true`, clipboard content copied from private browsing windows (Safari Private, Firefox Private, Chrome Incognito) is not saved to history. |
| `DLPEnabled` | Boolean | `false` | Enable the Data Loss Prevention engine. When `true`, clipboard content is inspected against the active DLP rules before being stored. |
| `BlockCreditCards` | Boolean | `false` | When `true` and `DLPEnabled` is `true`, blocks clipboard entries that match credit card number patterns (Luhn-validated). |
| `BlockAPIKeys` | Boolean | `false` | When `true` and `DLPEnabled` is `true`, blocks clipboard entries that match known API key patterns (AWS, GitHub, Stripe, and others). |
| `Theme` | String | `system` | Sets the UI theme. Accepted values: `system`, `light`, `dark`. When managed, users cannot change the theme in preferences. |

### Notes on Key Behavior

- Keys not present in the managed plist remain user-configurable.
- `LocalStorageOnly` takes precedence over `CloudSyncEnabled`. If both are set, local storage only is enforced.
- DLP sub-keys (`BlockCreditCards`, `BlockAPIKeys`) are only active when `DLPEnabled` is `true`.
- `AutoLockTimeout` requires `RequireBiometricAuth` to be `true` to have any effect.
- `MaxHistoryDays` and `MaxHistoryItems` enforce upper bounds; if both are set, whichever limit is reached first applies.
- For Azure AD SSO (`SSOProvider: azure`), set `SSODomain` to your Azure AD tenant domain (e.g., `contoso.onmicrosoft.com` or your verified custom domain `contoso.com`).

---

## Example Configuration Profile XML

The following is a complete `.mobileconfig` XML example ready for upload to Intune. Replace placeholder values with your organization's actual values before uploading.

### Full Enterprise Profile

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <!-- ═══════════════════════════════════════════════
         Top-Level Profile Metadata
         ═══════════════════════════════════════════════ -->
    <key>PayloadDisplayName</key>
    <string>PasteShelf Enterprise Configuration</string>

    <key>PayloadDescription</key>
    <string>Managed settings for PasteShelf Enterprise. Deployed by IT via Microsoft Intune.</string>

    <key>PayloadIdentifier</key>
    <string>com.company.intune.pasteshelf</string>

    <key>PayloadOrganization</key>
    <string>Contoso IT</string>

    <key>PayloadType</key>
    <string>Configuration</string>

    <!-- Generate a unique UUID for each profile you create.
         Run: uuidgen -->
    <key>PayloadUUID</key>
    <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>

    <key>PayloadVersion</key>
    <integer>1</integer>

    <!-- Prevent users from removing this profile manually.
         Set to <true/> for enforced policies. -->
    <key>PayloadRemovalDisallowed</key>
    <true/>

    <!-- ═══════════════════════════════════════════════
         Payload Content Array
         ═══════════════════════════════════════════════ -->
    <key>PayloadContent</key>
    <array>
        <dict>
            <!-- The inner PayloadType must exactly match the app's bundle ID.
                 This is what tells macOS to deliver these keys as managed
                 preferences for com.pasteshelf.PasteShelf. -->
            <key>PayloadType</key>
            <string>com.pasteshelf.PasteShelf</string>

            <key>PayloadVersion</key>
            <integer>1</integer>

            <!-- Unique identifier for this payload within the profile -->
            <key>PayloadIdentifier</key>
            <string>com.company.intune.pasteshelf.settings</string>

            <!-- Generate a separate UUID for this inner payload -->
            <key>PayloadUUID</key>
            <string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>

            <key>PayloadDisplayName</key>
            <string>PasteShelf Application Preferences</string>

            <!-- Organization ID configured by your IT administrator -->
            <key>OrganizationID</key>
            <string>org_abc123</string>

            <!-- ─────────────────────────────────────
                 SSO Configuration
                 For Azure AD / Microsoft Entra ID:
                   SSOProvider: azure
                   SSODomain: contoso.onmicrosoft.com
                 ───────────────────────────────────── -->

            <!-- Enable SSO. Set to <false/> to disable. -->
            <key>SSOEnabled</key>
            <true/>

            <!-- Identity provider: okta | azure | google | onelogin | ping | custom -->
            <key>SSOProvider</key>
            <string>azure</string>

            <!-- Your Azure AD tenant domain or verified custom domain -->
            <key>SSODomain</key>
            <string>contoso.onmicrosoft.com</string>

            <!-- ─────────────────────────────────────
                 Sync and Storage
                 ───────────────────────────────────── -->

            <!-- Allow iCloud sync (disable for strict data residency) -->
            <key>CloudSyncEnabled</key>
            <false/>

            <!-- Restrict all data to the local device only -->
            <key>LocalStorageOnly</key>
            <true/>

            <!-- ─────────────────────────────────────
                 Plugin System
                 ───────────────────────────────────── -->

            <!-- Disable to prevent users from installing plugins -->
            <key>PluginsEnabled</key>
            <false/>

            <!-- ─────────────────────────────────────
                 Security and Authentication
                 ───────────────────────────────────── -->

            <!-- Require Touch ID (or password) to open the app -->
            <key>RequireBiometricAuth</key>
            <true/>

            <!-- Auto-lock after 900 seconds (15 minutes) of inactivity.
                 Set to 0 to disable auto-lock. -->
            <key>AutoLockTimeout</key>
            <integer>900</integer>

            <!-- Clear clipboard history when the app quits -->
            <key>ClearOnQuit</key>
            <false/>

            <!-- ─────────────────────────────────────
                 Data Retention
                 ───────────────────────────────────── -->

            <!-- Keep history for a maximum of 90 days (0 = unlimited) -->
            <key>MaxHistoryDays</key>
            <integer>90</integer>

            <!-- Keep a maximum of 1000 items (default: 500) -->
            <key>MaxHistoryItems</key>
            <integer>1000</integer>

            <!-- ─────────────────────────────────────
                 Privacy
                 ───────────────────────────────────── -->

            <!-- Exclude clipboard content from private browsing windows -->
            <key>ExcludePrivateBrowsing</key>
            <true/>

            <!-- ─────────────────────────────────────
                 Data Loss Prevention
                 ───────────────────────────────────── -->

            <!-- Enable DLP engine -->
            <key>DLPEnabled</key>
            <true/>

            <!-- Block credit card numbers (requires DLPEnabled = true) -->
            <key>BlockCreditCards</key>
            <true/>

            <!-- Block API keys and secrets (requires DLPEnabled = true) -->
            <key>BlockAPIKeys</key>
            <true/>

            <!-- ─────────────────────────────────────
                 User Interface
                 ───────────────────────────────────── -->

            <!-- Enforce a UI theme: system | light | dark -->
            <key>Theme</key>
            <string>system</string>

        </dict>
    </array>

</dict>
</plist>
```

### Generating UUIDs

Each profile and inner payload requires a unique UUID. Generate them on macOS with:

```bash
uuidgen
# Example output: 3F6A1C2B-9E4D-4F78-B1A3-5D2E7C890A12
```

Replace both UUID placeholders in the XML above with freshly generated values before uploading to Intune. Reusing UUIDs across profiles can cause Intune to incorrectly deduplicate them.

### Minimal Profile (License + DLP Only)

For organizations that only need to enforce licensing and DLP without restricting other settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>PasteShelf Minimal Configuration</string>
    <key>PayloadDescription</key>
    <string>License and DLP enforcement for PasteShelf. Deployed via Microsoft Intune.</string>
    <key>PayloadIdentifier</key>
    <string>com.company.intune.pasteshelf.minimal</string>
    <key>PayloadOrganization</key>
    <string>Contoso IT</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string><!-- Run: uuidgen --></string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadRemovalDisallowed</key>
    <true/>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.pasteshelf.PasteShelf</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.company.intune.pasteshelf.minimal.settings</string>
            <key>PayloadUUID</key>
            <string><!-- Run: uuidgen --></string>
            <key>PayloadDisplayName</key>
            <string>PasteShelf Minimal Settings</string>

            <key>OrganizationID</key>
            <string>org_abc123</string>

            <key>DLPEnabled</key>
            <true/>
            <key>BlockCreditCards</key>
            <true/>
            <key>BlockAPIKeys</key>
            <true/>
        </dict>
    </array>
</dict>
</plist>
```

---

## Device Filters and Dynamic Groups

Intune provides two mechanisms for targeting deployments to specific devices: **device filters** and **dynamic Azure AD groups**. Both can be used independently or together.

### Dynamic Azure AD Device Groups

Dynamic groups use rules to automatically include devices based on their attributes. This is the recommended approach for ongoing fleet management.

**Prerequisites**: Microsoft Entra ID P1 license (included in Microsoft 365 E3/E5 and Microsoft 365 Business Premium).

#### Creating a Dynamic Device Group for macOS 14+

1. Sign in to the **Azure portal** at [https://portal.azure.com](https://portal.azure.com).
2. Navigate to **Microsoft Entra ID** (formerly Azure Active Directory) → **Groups** → **New group**.
3. Fill in:

   | Field | Value |
   |-------|-------|
   | Group type | `Security` |
   | Group name | `Intune-PasteShelf-Enterprise-Macs` |
   | Group description | `macOS 14+ devices eligible for PasteShelf Enterprise deployment` |
   | Membership type | `Dynamic Device` |

4. Click **Add dynamic query** and enter the following rule:

   ```
   (device.deviceOSType -eq "MacMDM") and (device.deviceOSVersion -ge "14.0")
   ```

5. Click **Save** → **Create**.

The group will automatically include all Intune-enrolled Macs running macOS 14.0 or later. New devices meeting the criteria are added within minutes of enrollment.

#### Department-Scoped Group

To target a specific department, add an attribute for the department (requires device attributes to be populated from your HR system or set manually):

```
(device.deviceOSType -eq "MacMDM") and
(device.deviceOSVersion -ge "14.0") and
(device.department -eq "Engineering")
```

#### Pilot Group Using Serial Numbers

For a phased rollout, create a static group and add specific device objects. Then widen the scope by switching to a dynamic group rule after validating the pilot:

```
(device.deviceOSType -eq "MacMDM") and
(device.devicePhysicalIds -any (_ -startsWith "[SerialNumber]:"))
```

To target specific serial numbers, use:
```
(device.deviceOSType -eq "MacMDM") and
(device.devicePhysicalIds -any (_ -eq "[SerialNumber]:C02ABC123DEF"))
```

### Device Filters

Intune **device filters** are evaluated at assignment time and allow you to narrow the scope of an existing group assignment without creating additional groups.

#### Creating a macOS 14+ Device Filter

1. In the **Intune admin center**, navigate to **Tenant administration** → **Filters** → **Create**.
2. Fill in:

   | Field | Value |
   |-------|-------|
   | Filter name | `macOS 14 and later` |
   | Description | `Targets macOS Sonoma (14.0) and later for PasteShelf deployment` |
   | Platform | `macOS` |

3. Under **Rules**, add:

   ```
   (device.osVersion -ge "14.0")
   ```

4. Click **Next** → **Create**.

#### Applying a Filter to an Assignment

When assigning the PasteShelf app or configuration profile, click **Edit filter** next to the group assignment and select `macOS 14 and later` with mode `Include filtered devices in assignment`.

### Combining Groups and Filters

A common pattern is to assign the app and profile to a broad group (all enrolled Macs) and then apply a filter to restrict delivery to macOS 14+:

| Assignment Group | Filter | Result |
|-----------------|--------|--------|
| `All Devices` | `macOS 14 and later` (Include) | Delivers to all Intune-enrolled Macs running macOS 14+ |
| `Intune-PasteShelf-Enterprise-Macs` | None | Delivers to members of the dynamic group |
| `All Devices` | `Engineering Macs` (Include) | Delivers only to Engineering Macs |

---

## Deployment Verification

After deploying the app and configuration profile, use these steps to confirm successful installation and configuration on a target device.

### 1. Verify the MDM Profile Is Installed

On the target Mac, open Terminal and run:

```bash
profiles list -type configuration
```

Look for an entry matching your profile's display name:

```
PasteShelf Enterprise Configuration
  com.company.intune.pasteshelf
  Installed: <date>
```

To see the full profile contents:

```bash
profiles show -type configuration | grep -A 40 "PasteShelf"
```

### 2. Verify Managed Preferences Are Applied

Read the effective preferences for PasteShelf:

```bash
defaults read com.pasteshelf.PasteShelf
```

Managed keys delivered by the Intune profile appear in the output. You should see the values you set in the configuration profile, for example:

```
{
    BlockAPIKeys = 1;
    BlockCreditCards = 1;
    DLPEnabled = 1;
    LocalStorageOnly = 1;
    MaxHistoryDays = 90;
    OrganizationID = "org_abc123";
    RequireBiometricAuth = 1;
    SSODomain = "contoso.onmicrosoft.com";
    SSOEnabled = 1;
    SSOProvider = azure;
    Theme = system;
}
```

To read a specific key:

```bash
defaults read com.pasteshelf.PasteShelf DLPEnabled
# Expected: 1
```

### 3. Verify the App Is Installed

Confirm the PasteShelf application bundle is present:

```bash
ls -la /Applications/PasteShelf.app

# Check the installed version
defaults read /Applications/PasteShelf.app/Contents/Info CFBundleShortVersionString
# Expected: 1.0.0
```

### 4. Verify Managed Keys Are Locked in the App

1. Open PasteShelf.
2. Navigate to **PasteShelf** → **Preferences** (or press `Cmd+,`).
3. Settings managed by Intune should be grayed out with a lock icon and the label "Managed by your organization."

### 5. Verify via the Intune Admin Center

1. Navigate to **Devices** → **macOS** → select the target device.
2. Under the **Monitor** section:
   - Click **Device configuration** and confirm `PasteShelf Enterprise Configuration` shows `Succeeded`.
3. Under the **Apps** section:
   - Click **Managed apps** and confirm `PasteShelf Enterprise` shows `Installed`.

### 6. Check the Intune Management Extension Log

The Intune Management Extension (IME) handles package installation and logs details on the device:

```bash
# View IME logs
log show \
  --predicate 'subsystem == "com.microsoft.intune"' \
  --last 1h \
  --level info | grep -i pasteshelf
```

The IME log file is also available at:

```bash
cat /Library/Logs/Microsoft/Intune/IntuneMDMAgent.log | grep -i pasteshelf
```

### 7. Check PasteShelf Application Logs

```bash
# View PasteShelf MDM and configuration logs from the last hour
log show \
  --predicate 'subsystem == "com.pasteshelf.PasteShelf"' \
  --last 1h \
  --level debug | grep -i -E "mdm|config|license|policy"
```

### 8. Verify Company Portal Status

If end users have the **Company Portal** app installed:

1. Open Company Portal on the managed Mac.
2. Navigate to **Devices** → select the device.
3. Confirm the device is marked **Compliant** and **Managed**.
4. Under **Apps**, PasteShelf should appear as **Installed**.

---

## Troubleshooting

### Profile Not Applying to Devices

**Symptom**: The configuration profile does not appear on managed devices, or `profiles list` does not show the PasteShelf profile.

**Checklist**:
- Confirm the device is enrolled in Intune and the enrollment state is `Enrolled`:
  ```
  Intune admin center → Devices → macOS → [Device] → Overview
  ```
- Confirm the device is a member of the assigned group. In the Azure portal, navigate to the group and check **Members**.
- Confirm the profile is assigned with status `Assigned` (not `Not assigned`):
  ```
  Intune admin center → Devices → Configuration profiles → [Profile] → Properties → Assignments
  ```
- Trigger an immediate Intune sync from the device:
  ```bash
  sudo /usr/bin/profiles renew -type enrollment
  ```
  Or from the Company Portal app: **Devices** → [Device] → **Check Status**.
- Wait up to 15 minutes and recheck.

---

### Settings Not Locked / User Can Still Change Managed Preferences

**Symptom**: Managed keys appear in `defaults read` but users can still modify them in PasteShelf preferences.

**Cause**: The `PayloadType` in the inner payload does not exactly match the app's bundle identifier.

**Resolution**:
- Confirm the inner `PayloadType` is exactly `com.pasteshelf.PasteShelf` (case-sensitive).
- Do not confuse this with the outer `PayloadType`, which must remain `Configuration`.
- Re-check the profile XML:

```xml
<!-- Inner payload — PayloadType must be the app's bundle ID -->
<key>PayloadType</key>
<string>com.pasteshelf.PasteShelf</string>
```

After correcting the XML, upload a new version of the profile to Intune and re-assign it. Intune will push the corrected profile at the next device check-in.

---

### App Installation Fails or Shows "Failed" in Intune

**Symptom**: The PasteShelf app shows a `Failed` status in the Intune device app list.

**Checklist**:
- Verify the `.intunemac` file was generated correctly from a signed `.pkg`:
  ```bash
  pkgutil --check-signature PasteShelf-Enterprise-1.0.0.pkg
  ```
- Check the Intune Management Extension log on the device for the specific error:
  ```bash
  cat /Library/Logs/Microsoft/Intune/IntuneMDMAgent.log | tail -100
  ```
- Confirm the Intune Management Extension is installed and running:
  ```bash
  ls /Library/Intune/Microsoft\ Intune\ Agent.app
  launchctl list | grep -i intune
  ```
- If the IME is not installed, it should install automatically on next MDM check-in. Trigger a sync:
  ```bash
  sudo /usr/bin/profiles renew -type enrollment
  ```
- Verify macOS version is 14.0 or later:
  ```bash
  sw_vers -productVersion
  ```
- Attempt a manual installation to isolate the error:
  ```bash
  sudo installer -pkg /path/to/PasteShelf-Enterprise-1.0.0.pkg -target / -verbose
  ```

---

### MDM Agent Not Running

**Symptom**: The Intune MDM agent appears inactive and the device is not receiving policies.

**Resolution**:

1. Verify the MDM enrollment profile is present:
   ```bash
   profiles list -type enrollment
   # Should show a Microsoft Intune profile
   ```

2. If the enrollment profile is missing, the device has been unenrolled. Re-enroll via Company Portal or ADE.

3. Restart the `mdmclient` daemon:
   ```bash
   sudo launchctl kickstart -k system/com.apple.mdmclient
   ```

4. Check for MDM framework errors:
   ```bash
   log show \
     --predicate 'subsystem == "com.apple.managedclient"' \
     --last 30m \
     --level info | grep -i error
   ```

---

### Forced Preferences Not Being Enforced After Profile Update

**Symptom**: You updated the configuration profile in Intune, but PasteShelf on already-enrolled devices still shows old values.

**Resolution**:
PasteShelf observes `NSUserDefaultsDidChangeNotification` and re-reads managed preferences when notified. If changes are not reflected immediately:

1. Trigger a device sync from the Intune admin center:
   ```
   Intune admin center → Devices → macOS → [Device] → Sync
   ```

2. Trigger a sync from the device:
   ```bash
   sudo /usr/bin/profiles renew -type enrollment
   ```

3. Re-read preferences to confirm updated values are delivered:
   ```bash
   defaults read com.pasteshelf.PasteShelf
   ```

4. Quit and relaunch PasteShelf. The app re-reads managed preferences at launch.

5. If new keys were added (not just modified), macOS may require a full profile re-installation. In Intune, delete the existing profile assignment, wait for removal to propagate (up to 15 minutes), then re-assign.

---

### SSO Authentication Loop or Failure (Azure AD)

**Symptom**: Users are stuck in an SSO redirect loop or cannot complete authentication with Azure AD.

**Checklist**:
- Confirm `SSOProvider` is set to `azure`.
- Confirm `SSODomain` is your Azure AD tenant domain (e.g., `contoso.onmicrosoft.com`).
- Verify the redirect URI `pasteshelf://auth/callback` is registered in your Azure App Registration:
  1. Sign in to the Azure portal.
  2. Navigate to **Microsoft Entra ID** → **App registrations** → select your PasteShelf app.
  3. Under **Authentication** → **Redirect URIs**, confirm `pasteshelf://auth/callback` is listed under **Public client/native (mobile & desktop)**.
- Check that the device's system clock is accurate (token validation is time-sensitive):
  ```bash
  date
  sntp -sS time.apple.com
  ```
- Inspect SSO-related logs:
  ```bash
  log show \
    --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "sso"' \
    --last 30m \
    --level debug
  ```

---

### DLP Settings Not Blocking Content

**Symptom**: `DLPEnabled` is `true` in managed preferences, but credit card numbers or API keys are not being blocked.

**Checklist**:
- Confirm `DLPEnabled` reads as `1`:
  ```bash
  defaults read com.pasteshelf.PasteShelf DLPEnabled
  # Expected: 1
  ```
- Confirm the sub-keys are present and set correctly:
  ```bash
  defaults read com.pasteshelf.PasteShelf BlockCreditCards
  defaults read com.pasteshelf.PasteShelf BlockAPIKeys
  ```
- Verify PasteShelf has Accessibility and Input Monitoring permissions, which are required for clipboard monitoring:
  - Open **System Settings** → **Privacy & Security** → **Accessibility** → confirm PasteShelf is listed and enabled.
  - Open **System Settings** → **Privacy & Security** → **Input Monitoring** → confirm PasteShelf is listed and enabled.

---

### Log Collection for Intune Support

When filing a support case with Microsoft or PasteShelf, collect the following logs:

```bash
# Intune Management Extension logs
cat /Library/Logs/Microsoft/Intune/IntuneMDMAgent.log > /tmp/intune-ime.log

# MDM client logs (last 2 hours)
log show \
  --predicate 'subsystem == "com.apple.managedclient"' \
  --last 2h \
  --level debug \
  > /tmp/mdmclient.log

# PasteShelf application logs (last 2 hours)
log show \
  --predicate 'subsystem == "com.pasteshelf.PasteShelf"' \
  --last 2h \
  --level debug \
  > /tmp/pasteshelf.log

# Installed profiles
profiles show -type configuration > /tmp/profiles.txt

# Current managed preferences
defaults read com.pasteshelf.PasteShelf > /tmp/pasteshelf-defaults.txt
```

---

### Common Error Reference

| Error / Symptom | Likely Cause | Resolution |
|-----------------|--------------|------------|
| `profiles list` shows no PasteShelf profile | Device not in assigned group or not synced | Check group membership; trigger sync |
| Profile deployment shows `Failed` in Intune | Invalid XML in `.mobileconfig` | Validate XML, re-upload; check Intune portal error details |
| Managed keys absent from `defaults read` | Inner `PayloadType` mismatch | Verify inner `PayloadType` is `com.pasteshelf.PasteShelf` |
| App shows `Failed` in Intune managed apps | Invalid `.intunemac` or IME not running | Re-wrap package; check IME installation |
| Settings grayed out but wrong value shown | Stale profile not updated | Delete and re-assign profile in Intune |
| SSO redirect loop with Azure AD | Redirect URI not registered in Azure App Registration | Add `pasteshelf://auth/callback` to app registration |
| DLP not blocking content | Missing Accessibility/Input Monitoring permission | Grant permissions in System Settings → Privacy & Security |
| Profile installed but app ignores it | App not restarted after profile delivery | Quit and relaunch PasteShelf |
| Device shows `Not compliant` in Intune | Compliance policy not met | Review compliance policy; check device health |

---

## Updating and Removal

### Updating PasteShelf

When a new version of PasteShelf Enterprise is available:

1. Download the new `.pkg` from the PasteShelf customer portal.
2. Wrap it with `IntuneAppUtil`:
   ```bash
   IntuneAppUtil \
     -c PasteShelf-Enterprise-2.0.0.pkg \
     -o /tmp/intunemac-output/ \
     -v
   ```
3. In the **Intune admin center**, navigate to **Apps** → **macOS** → select `PasteShelf Enterprise`.
4. Click **Properties** → **App package file** → **Edit** and upload the new `.intunemac` file.
5. Update the **Version** and **Build number** fields to match the new release.
6. Click **Review + save** → **Save**.

Intune will automatically push the update to devices where PasteShelf is already installed. Users do not need to take any action.

> **Version detection**: Intune compares the installed bundle version on the device against the version specified in the app properties. If the on-device version is lower, Intune triggers a reinstallation with the new package.

### Removing PasteShelf

To uninstall PasteShelf from managed devices:

**Via Intune (Recommended)**:

1. Navigate to **Apps** → **macOS** → select `PasteShelf Enterprise`.
2. Click **Properties** → **Assignments** → **Edit**.
3. Change the group assignment from `Required` to `Uninstall`.
4. Click **Review + save** → **Save**.

Intune will instruct the IME to remove the application from devices in the assigned group. The process runs silently in the background at next check-in.

**Via Shell Script (Manual removal)**:

If you need to force-remove the application immediately, deploy a shell script via Intune:

```bash
#!/bin/bash
# PasteShelf Removal Script
# Deploy via Intune: Devices > macOS > Shell scripts

# Quit the app if running
pkill -x "PasteShelf" 2>/dev/null || true

# Remove the application bundle
rm -rf /Applications/PasteShelf.app

# Remove user preferences and app data
# Note: Run this step only if you want to clear all user data
# rm -rf ~/Library/Application\ Support/PasteShelf
# rm -rf ~/Library/Containers/com.pasteshelf.PasteShelf

# Remove the package receipt
pkgutil --forget com.pasteshelf.PasteShelf 2>/dev/null || true

echo "PasteShelf removed successfully."
exit 0
```

Deploy this script via **Devices** → **macOS** → **Shell scripts** → **Add**.

### Revoking the Configuration Profile

To stop enforcing managed preferences without uninstalling the app:

1. Navigate to **Devices** → **macOS** → **Configuration profiles** → select `PasteShelf Enterprise Configuration`.
2. Click **Properties** → **Assignments** → **Edit**.
3. Remove all group assignments and click **Review + save** → **Save**.

After the profile is removed from devices, PasteShelf preferences revert to being user-configurable.

---

## Security Considerations

### Profile Signing and Integrity

Configuration profiles deployed via Intune are delivered over an encrypted MDM channel (APNS + TLS). The profiles are not additionally signed by default, but Intune's MDM channel provides transport-layer integrity.

For additional assurance, you can sign the `.mobileconfig` file with your organization's MDM certificate or an S/MIME certificate before uploading to Intune:

```bash
# Sign a .mobileconfig with a certificate from your keychain
# (The signing certificate must be trusted by macOS on target devices)
security cms -S \
  -N "MDM Signing Certificate" \
  -i PasteShelf-Enterprise.mobileconfig \
  -o PasteShelf-Enterprise-signed.mobileconfig
```

### Conditional Access Integration

Intune integrates with Microsoft Entra ID Conditional Access to require device compliance before granting access to corporate resources. To require PasteShelf-managed devices to be compliant:

1. **Create a compliance policy** for macOS devices in Intune that enforces your baseline (e.g., minimum OS version, encryption required, no jailbreak):
   ```
   Intune admin center → Devices → Compliance → Create policy → macOS
   ```

2. **Create a Conditional Access policy** in Microsoft Entra ID:
   - Sign in to the Azure portal → **Microsoft Entra ID** → **Security** → **Conditional Access** → **New policy**.
   - Set **Users**: target the group of PasteShelf users.
   - Set **Cloud apps**: select the apps requiring compliant device access.
   - Under **Grant**: select **Require device to be marked as compliant**.

3. Devices that have the PasteShelf profile installed and meet the compliance policy will be marked compliant and granted access. Non-compliant devices are blocked.

### Data Residency and LocalStorageOnly

For organizations with strict data residency requirements, set `LocalStorageOnly` to `true` in the managed profile. This prevents all cloud sync and ensures clipboard data never leaves the device:

```xml
<key>LocalStorageOnly</key>
<true/>

<key>CloudSyncEnabled</key>
<false/>
```

When `LocalStorageOnly` is `true`, it overrides `CloudSyncEnabled` regardless of its value.

### FileVault Encryption

Ensure all managed Macs have FileVault enabled. PasteShelf stores its local clipboard database in the user's Application Support directory, which is protected by FileVault when enabled. Enforce FileVault via an Intune compliance policy:

```
Intune admin center → Devices → Compliance → Create policy → macOS
→ System security → FileVault → Require
```

### Network Security

Devices must be able to reach the following endpoints over HTTPS (port 443):

| Endpoint | Purpose |
|----------|---------|
| `https://sync.company.com` (or your self-hosted URL) | Self-hosted sync server |
| `https://manage.microsoft.com` | Intune MDM channel |
| `https://portal.manage.microsoft.com` | Company Portal communication |
| `https://login.microsoftonline.com` | Azure AD / Entra ID authentication |

If your organization uses a web proxy, configure the proxy settings via an Intune network configuration profile so the Intune Management Extension can communicate through the proxy.

### Audit Logging

PasteShelf Enterprise writes audit log entries for DLP events, SSO authentication events, and preference changes driven by MDM. To collect audit logs centrally, configure a syslog forwarding rule on managed Macs:

```bash
# View PasteShelf audit events
log show \
  --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "audit"' \
  --last 24h \
  --level info
```

For SIEM integration, forward these events to your logging infrastructure using a log collection agent (e.g., Microsoft Sentinel agent, Splunk Universal Forwarder).

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Deployment Guide](ENTERPRISE_DEPLOYMENT.md) | Deployment options including self-hosted and air-gapped |
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Admin console, user management, and policy management |
| [Jamf Pro Deployment Guide](MDM_JAMF_GUIDE.md) | Deploying PasteShelf via Jamf Pro |
| [Kandji Deployment Guide](MDM_KANDJI_GUIDE.md) | Deploying PasteShelf via Kandji |
| [Security Guide](../security/SECURITY.md) | Encryption, privacy, and security architecture |
| [Troubleshooting Guide](../operations/TROUBLESHOOTING.md) | General troubleshooting for all editions |

---

*Last updated: 2026-02-28*
