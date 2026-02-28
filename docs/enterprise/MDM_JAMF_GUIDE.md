# Jamf Pro Deployment Guide for PasteShelf Enterprise

> **Last Updated**: 2026-02-28 | **Reading Time**: 30 minutes | **Audience**: Jamf Administrators

Complete guide for deploying and managing PasteShelf Enterprise using Jamf Pro.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Package Deployment](#package-deployment)
- [Configuration Profile](#configuration-profile)
- [Configuration Key Reference](#configuration-key-reference)
- [Example Configuration Profile XML](#example-configuration-profile-xml)
- [Smart Groups](#smart-groups)
- [Deployment Verification](#deployment-verification)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Quick Start

For experienced Jamf administrators, here is the complete deployment sequence at a glance:

```
1. Upload PasteShelf-Enterprise-<version>.pkg to Jamf Pro → Computers → Management Settings → Packages
2. Create a Smart Group targeting macOS 14.0+ devices in your target department(s)
3. Create a Policy to deploy the .pkg scoped to the Smart Group (Recurring Check-in trigger)
4. Create a Configuration Profile (Computers → Configuration Profiles → New)
   - Add "Application & Custom Settings" payload
   - Set Preference Domain: com.pasteshelf.PasteShelf
   - Upload or paste your plist with desired keys from the reference table below
   - Scope to the same Smart Group
5. Verify on a test device:
   defaults read com.pasteshelf.PasteShelf
   profiles list | grep -i pasteshelf
```

The sections below cover each step in full detail with examples.

---

## Prerequisites

Before beginning the deployment, confirm the following are in place.

### Jamf Pro Server

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Jamf Pro | 10.44.0 | Required for full Custom Settings payload support |
| Jamf Pro | 11.x | Recommended; includes improved profile reporting |

All configuration profile features in this guide are tested against Jamf Pro 10.44+ and 11.x.

### PasteShelf Enterprise Package

- PasteShelf is free and open source. No license key is required.
- Download the signed enterprise `.pkg` from the PasteShelf downloads page.

### Target Devices

- macOS 14.0 (Sonoma) or later on all managed Macs.
- Devices must be enrolled in Jamf Pro with a valid MDM enrollment profile.
- If using sync, devices must be able to reach the sync server (cloud or self-hosted) on port 443.

### PasteShelf Installer Package

- Download the signed `.pkg` from the PasteShelf customer portal or via the direct link provided with your license:

```bash
# Download the Enterprise package
curl -O https://download.pasteshelf.app/enterprise/PasteShelf-Enterprise-1.0.0.pkg

# Verify the SHA-256 checksum against the value in your customer portal
shasum -a 256 PasteShelf-Enterprise-1.0.0.pkg
```

- Confirm the package is signed by **PasteShelf, Inc.** before uploading to Jamf Pro:

```bash
pkgutil --check-signature PasteShelf-Enterprise-1.0.0.pkg
```

Expected output includes:
```
Status: signed by a developer certificate issued by Apple
```

---

## Package Deployment

### 1. Upload the Package to Jamf Pro

1. In the Jamf Pro web interface, navigate to **Computers** → **Management Settings** → **Packages**.
2. Click **New**.
3. Under the **General** tab:
   - **Display Name**: `PasteShelf Enterprise 1.0.0`
   - **Category**: Select or create `Productivity` (or your standard app category)
   - **Filename**: Upload `PasteShelf-Enterprise-1.0.0.pkg`
4. Under the **Options** tab:
   - Set **Priority**: `10` (or match your standard)
   - Enable **Require reboot**: leave unchecked (PasteShelf does not require a reboot)
5. Click **Save**.

### 2. Configure the Distribution Point

Jamf Pro distributes packages through your configured distribution points. No additional configuration is needed if your distribution point is already set up. Confirm the package appears under **Computers** → **Management Settings** → **Packages** with a valid checksum.

For cloud distribution (Jamf Cloud Distribution Service), the package is automatically available to all devices after upload.

### 3. Create a Deployment Policy

1. Navigate to **Computers** → **Policies** → **New**.
2. Under the **General** tab:
   - **Display Name**: `Deploy PasteShelf Enterprise`
   - **Enabled**: checked
   - **Trigger**: `Recurring Check-in`
   - **Execution Frequency**: `Once per computer`
3. Under the **Packages** payload:
   - Click **Configure** and add the `PasteShelf Enterprise 1.0.0` package.
   - **Action**: `Install`
4. Under the **Scope** tab:
   - Add the Smart Group you will create in the [Smart Groups](#smart-groups) section.
5. Click **Save**.

### 4. Set Up Auto-Update Policy (Optional)

To automate updates when a new PasteShelf package is uploaded:

1. Create a separate policy named `Update PasteShelf Enterprise`.
2. Set **Trigger**: `Recurring Check-in`.
3. Set **Execution Frequency**: `Once per computer per version` (requires Jamf Pro 10.48+).
4. Add the new package version under the **Packages** payload with **Action**: `Upgrade`.
5. Scope to the same Smart Group.

Alternatively, use a Jamf Pro patch management policy if your organization manages software updates through the Patch Management module.

---

## Configuration Profile

The configuration profile delivers managed preferences to PasteShelf on each device. Settings pushed via MDM take precedence over user-configured settings and are enforced as locked (read-only) within the app preferences pane.

### Creating the Profile in Jamf Pro

1. Navigate to **Computers** → **Configuration Profiles** → **New**.
2. Under the **General** tab:
   - **Name**: `PasteShelf Enterprise Configuration`
   - **Description**: `Managed settings for PasteShelf Enterprise`
   - **Category**: `Productivity` (or your standard)
   - **Distribution Method**: `Install Automatically`
   - **Level**: `Computer Level`
3. In the left sidebar, scroll to find **Application & Custom Settings** and click it.
4. Click **Configure** (or **Add**) under the **Application & Custom Settings** payload.
5. Set **Source** to **Custom Schema** or **Plist**, depending on your Jamf Pro version:
   - Jamf Pro 10.44–10.x: Select **Upload** and provide the plist XML (see [Example Configuration Profile XML](#example-configuration-profile-xml)).
   - Jamf Pro 11.x: You may paste the plist directly or use the schema editor.
6. Set **Preference Domain**: `com.pasteshelf.PasteShelf`
7. Enter or upload the plist keys corresponding to the policies you want to enforce.
8. Under the **Scope** tab, add the target Smart Group.
9. Click **Save**.

---

## Configuration Key Reference

All keys are read from the managed preferences domain `com.pasteshelf.PasteShelf`. Keys delivered via a Jamf Pro configuration profile are locked and cannot be overridden by the user.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `SSOEnabled` | Boolean | `false` | Enable SSO authentication. When `true`, users are required to authenticate via the configured identity provider before accessing the app. |
| `SSOProvider` | String | — | Name of the identity provider. Accepted values: `okta`, `azure`, `google`, `onelogin`, `ping`, `custom` |
| `SSODomain` | String | — | The IdP domain used for SSO. Example: `company.okta.com` |
| `CloudSyncEnabled` | Boolean | `true` | Enable iCloud sync for clipboard history across the user's Apple devices. Set to `false` to disable sync organization-wide. |
| `LocalStorageOnly` | Boolean | `false` | When `true`, restricts all clipboard data to the local device and disables all sync. Overrides `CloudSyncEnabled`. |
| `PluginsEnabled` | Boolean | `true` | Enable the PasteShelf plugin system. Set to `false` to prevent users from installing or running plugins. |
| `RequireBiometricAuth` | Boolean | `false` | Require Touch ID (or password fallback) before the app window opens or before pasting sensitive items. |
| `AutoLockTimeout` | Integer | `0` | Number of seconds of inactivity before PasteShelf locks and requires re-authentication. `0` disables auto-lock. Example: `300` (5 minutes) |
| `ClearOnQuit` | Boolean | `false` | When `true`, clears the local clipboard history every time PasteShelf quits. |
| `MaxHistoryDays` | Integer | `0` | Maximum number of days to retain clipboard history. Older items are automatically purged. `0` means unlimited retention. |
| `MaxHistoryItems` | Integer | `500` | Maximum number of clipboard items to store. When the limit is reached, the oldest items are removed. |
| `ExcludePrivateBrowsing` | Boolean | `true` | When `true`, clipboard content copied from private browsing windows (Safari Private, Firefox Private) is not saved to history. |
| `DLPEnabled` | Boolean | `false` | Enable the Data Loss Prevention engine. When `true`, clipboard content is inspected against the active DLP rules. |
| `BlockCreditCards` | Boolean | `false` | When `true` and `DLPEnabled` is `true`, blocks clipboard entries that match credit card number patterns (Luhn-validated). |
| `BlockAPIKeys` | Boolean | `false` | When `true` and `DLPEnabled` is `true`, blocks clipboard entries that match known API key patterns (AWS, GitHub, Stripe, and others). |
| `Theme` | String | `system` | Sets the UI theme. Accepted values: `system`, `light`, `dark`. When managed, users cannot change the theme in preferences. |

### Notes on Key Behavior

- Keys not present in the managed plist remain user-configurable.
- `LocalStorageOnly` takes precedence over `CloudSyncEnabled`. If both are set, local storage only is enforced.
- DLP sub-keys (`BlockCreditCards`, `BlockAPIKeys`) are only active when `DLPEnabled` is `true`.
- `AutoLockTimeout` requires `RequireBiometricAuth` to be `true` to have any effect.
- `MaxHistoryDays` and `MaxHistoryItems` enforce upper bounds; if both are set, whichever limit is hit first applies.

---

## Example Configuration Profile XML

The following is a complete `.mobileconfig` XML example ready for upload to Jamf Pro or distribution via the `profiles` command-line tool. Replace placeholder values with your organization's actual values.

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
    <string>Managed settings for PasteShelf Enterprise. Deployed by IT via Jamf Pro.</string>

    <key>PayloadIdentifier</key>
    <string>com.company.mdm.pasteshelf</string>

    <key>PayloadOrganization</key>
    <string>Acme Corp IT</string>

    <key>PayloadType</key>
    <string>Configuration</string>

    <!-- Generate a unique UUID for each profile you create.
         You can generate one with: uuidgen -->
    <key>PayloadUUID</key>
    <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>

    <key>PayloadVersion</key>
    <integer>1</integer>

    <!-- Prevent users from removing this profile manually -->
    <key>PayloadRemovalDisallowed</key>
    <true/>

    <!-- ═══════════════════════════════════════════════
         Payload Content Array
         ═══════════════════════════════════════════════ -->
    <key>PayloadContent</key>
    <array>
        <dict>
            <!-- This PayloadType must match the app's bundle identifier
                 for managed preferences to be delivered correctly. -->
            <key>PayloadType</key>
            <string>com.pasteshelf.PasteShelf</string>

            <key>PayloadVersion</key>
            <integer>1</integer>

            <!-- Unique identifier for this payload within the profile -->
            <key>PayloadIdentifier</key>
            <string>com.company.mdm.pasteshelf.settings</string>

            <!-- Generate a separate UUID for this inner payload -->
            <key>PayloadUUID</key>
            <string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>

            <key>PayloadDisplayName</key>
            <string>PasteShelf Settings</string>

            <!-- ─────────────────────────────────────
                 SSO Configuration
                 ───────────────────────────────────── -->

            <!-- Enable SSO. Set to <false/> to disable. -->
            <key>SSOEnabled</key>
            <true/>

            <!-- Identity provider: okta | azure | google | onelogin | ping | custom -->
            <key>SSOProvider</key>
            <string>okta</string>

            <!-- Your IdP domain -->
            <key>SSODomain</key>
            <string>company.okta.com</string>

            <!-- ─────────────────────────────────────
                 Sync and Storage
                 ───────────────────────────────────── -->

            <!-- Allow iCloud sync (disable for strict data residency) -->
            <key>CloudSyncEnabled</key>
            <true/>

            <!-- Set to <true/> to restrict all data to the local device -->
            <key>LocalStorageOnly</key>
            <false/>

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

            <!-- Auto-lock after 300 seconds (5 minutes) of inactivity.
                 Set to 0 to disable auto-lock. -->
            <key>AutoLockTimeout</key>
            <integer>300</integer>

            <!-- Clear clipboard history when the app quits -->
            <key>ClearOnQuit</key>
            <false/>

            <!-- ─────────────────────────────────────
                 Data Retention
                 ───────────────────────────────────── -->

            <!-- Keep history for a maximum of 90 days (0 = unlimited) -->
            <key>MaxHistoryDays</key>
            <integer>90</integer>

            <!-- Keep a maximum of 5000 items (default: 500) -->
            <key>MaxHistoryItems</key>
            <integer>5000</integer>

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

Replace both UUID placeholders in the XML above with freshly generated values before deploying. Reusing UUIDs across profiles can cause Jamf Pro to treat them as duplicates.

### Minimal Profile (License + DLP Only)

For organizations that only need to enforce licensing and DLP without restricting other settings, use this minimal payload:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>PasteShelf Minimal Configuration</string>
    <key>PayloadIdentifier</key>
    <string>com.company.mdm.pasteshelf.minimal</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string><!-- uuidgen --></string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.pasteshelf.PasteShelf</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.company.mdm.pasteshelf.minimal.settings</string>
            <key>PayloadUUID</key>
            <string><!-- uuidgen --></string>
            <key>PayloadDisplayName</key>
            <string>PasteShelf Minimal Settings</string>

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

## Smart Groups

Smart groups allow you to scope the deployment policy and configuration profile to the correct set of devices without manually maintaining membership.

### Creating a Smart Group by Department and OS Version

1. Navigate to **Computers** → **Smart Computer Groups** → **New**.
2. Under the **General** tab:
   - **Display Name**: `PasteShelf Enterprise - Engineering`
   - **Description**: `Macs running macOS 14+ in the Engineering department`
3. Under the **Criteria** tab, add the following criteria:

| Criteria | Operator | Value | And/Or |
|----------|----------|-------|--------|
| Department | is | Engineering | and |
| Operating System Version | greater than or equal | 14.0 | |

4. Click **Save**.

The resulting Smart Group criteria XML (for reference or API use) looks like:

```xml
<smart_computer_group>
    <name>PasteShelf Enterprise - Engineering</name>
    <criteria>
        <criterion>
            <name>Department</name>
            <priority>0</priority>
            <and_or>and</and_or>
            <search_type>is</search_type>
            <value>Engineering</value>
        </criterion>
        <criterion>
            <name>Operating System Version</name>
            <priority>1</priority>
            <and_or>and</and_or>
            <search_type>greater than or equal</search_type>
            <value>14.0</value>
        </criterion>
    </criteria>
</smart_computer_group>
```

### Organization-Wide Smart Group

To target all eligible Macs regardless of department:

| Criteria | Operator | Value |
|----------|----------|-------|
| Operating System Version | greater than or equal | 14.0 |

### Scoping the Policy and Profile

After creating the Smart Group:

1. Open your **Deploy PasteShelf Enterprise** policy → **Scope** tab → add the Smart Group → **Save**.
2. Open your **PasteShelf Enterprise Configuration** profile → **Scope** tab → add the same Smart Group → **Save**.

Jamf Pro will deploy the package and profile to all current and future members of the group automatically.

---

## Deployment Verification

After deploying the package and configuration profile, use these steps to confirm successful installation and configuration on a target device.

### 1. Verify the MDM Profile Is Installed

On the target Mac, open Terminal and run:

```bash
profiles list -type configuration
```

Look for an entry matching your profile's display name:

```
PasteShelf Enterprise Configuration
  com.company.mdm.pasteshelf
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

Managed keys delivered by the MDM profile appear in the output. You should see the values you set in the configuration profile, for example:

```
{
    DLPEnabled = 1;
    MaxHistoryDays = 90;
    RequireBiometricAuth = 1;
    SSOEnabled = 1;
    SSOProvider = okta;
}
```

To read a specific key:

```bash
defaults read com.pasteshelf.PasteShelf DLPEnabled
# Expected: 1
```

### 3. Verify Managed Keys Are Locked in the App

1. Open PasteShelf.
2. Navigate to **PasteShelf** → **Preferences** (or press `Cmd+,`).
3. Settings managed by MDM should be grayed out with a lock icon and the label "Managed by your organization."

### 4. Check Console.app for MDM-Related Logs

To inspect MDM profile delivery and PasteShelf startup logs:

1. Open **Console.app** on the target device.
2. In the search bar, enter: `subsystem:com.pasteshelf.PasteShelf`
3. Filter by **Category**: `mdm` or `config`

From Terminal, use the `log` command:

```bash
# View PasteShelf MDM and configuration logs from the last hour
log show \
  --predicate 'subsystem == "com.pasteshelf.PasteShelf"' \
  --last 1h \
  --level debug | grep -i -E "mdm|config|license|policy"
```

To view the raw MDM framework logs for profile installation:

```bash
log show \
  --predicate 'subsystem == "com.apple.managedclient"' \
  --last 30m \
  --level info | grep -i "pasteshelf"
```

### 5. Verify via Jamf Pro Inventory

In the Jamf Pro web interface:

1. Navigate to **Computers** → select a target device.
2. Under the **Management** tab, confirm:
   - **Configuration Profiles**: `PasteShelf Enterprise Configuration` is listed as **Installed**.
   - **Policy History**: `Deploy PasteShelf Enterprise` shows **Completed**.

---

## Troubleshooting

### Profile Not Applying to Devices

**Symptom**: The configuration profile does not appear on managed devices, or `profiles list` does not show the PasteShelf profile.

**Checklist**:
- Confirm the device is enrolled in Jamf Pro (`sudo jamf checkJSSConnection`).
- Confirm the device is a member of the scoped Smart Group (check **Computers** → device → **Management** tab → **Smart Groups**).
- Ensure the profile **Distribution Method** is set to `Install Automatically`, not `Make Available in Self Service`.
- Trigger an immediate MDM check-in from the device: `sudo jamf manage`
- In Jamf Pro, navigate to **Computers** → device → **Management** → **Send MDM Command** → **Update Inventory**, then wait and refresh.

---

### Settings Not Locked / User Can Still Change Managed Preferences

**Symptom**: Managed keys appear in `defaults read` but users can still modify them in PasteShelf preferences.

**Cause**: The `PayloadType` in the inner payload does not match the app's bundle identifier exactly.

**Resolution**:
- Confirm the inner `PayloadType` is exactly `com.pasteshelf.PasteShelf` (case-sensitive).
- Do not confuse this with the outer `PayloadType`, which must remain `Configuration`.
- Re-check the profile XML:

```xml
<!-- Inner payload - PayloadType must be the app's bundle ID -->
<key>PayloadType</key>
<string>com.pasteshelf.PasteShelf</string>
```

- Remove and re-push the profile after correction:

```bash
# On the target device, force profile removal and re-delivery
sudo profiles remove -identifier com.company.mdm.pasteshelf
sudo jamf manage
```

---

### App Not Picking Up Configuration Changes After Profile Update

**Symptom**: You updated the configuration profile in Jamf Pro, but PasteShelf on already-enrolled devices still shows old values.

**Resolution**:
PasteShelf observes `NSUserDefaultsDidChangeNotification` and re-reads managed preferences when notified. If changes are not reflected immediately:

1. Trigger a Jamf Pro check-in to push the updated profile:
   ```bash
   sudo jamf manage
   ```
2. Re-read the preferences to confirm the new values are delivered:
   ```bash
   defaults read com.pasteshelf.PasteShelf
   ```
3. Quit and relaunch PasteShelf. The app re-reads managed preferences at launch.
4. If the profile update changed a key that was previously absent (not just modified), macOS may require a full profile re-installation. Remove and re-deliver the profile from Jamf Pro:
   - **Computers** → device → **Management** → **Send MDM Command** → **Remove Profile**, then re-deliver.

---

### SSO Authentication Loop or Failure

**Symptom**: Users are stuck in an SSO redirect loop or cannot complete authentication.

**Checklist**:
- Verify `SSOProvider` matches one of the accepted values: `okta`, `azure`, `google`, `onelogin`, `ping`, `custom`.
- Verify `SSODomain` is the correct domain for your IdP (e.g., `company.okta.com`, not `company.com`).
- Confirm the redirect URI `pasteshelf://auth/callback` is registered in your IdP application settings.
- Check that the device's system clock is accurate (SSO token validation is time-sensitive):
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
- Confirm `DLPEnabled` reads as `1` (not `0` or absent):
  ```bash
  defaults read com.pasteshelf.PasteShelf DLPEnabled
  ```
- Confirm the sub-keys are also present and set correctly:
  ```bash
  defaults read com.pasteshelf.PasteShelf BlockCreditCards
  defaults read com.pasteshelf.PasteShelf BlockAPIKeys
  ```
- Verify PasteShelf has Accessibility and Input Monitoring permissions (required for clipboard monitoring):
  - Open **System Settings** → **Privacy & Security** → **Accessibility** → confirm PasteShelf is listed and enabled.
  - Open **System Settings** → **Privacy & Security** → **Input Monitoring** → confirm PasteShelf is listed and enabled.

---

### Common Error Reference

| Error / Symptom | Likely Cause | Resolution |
|-----------------|--------------|------------|
| `profiles list` shows no PasteShelf profile | Device out of scope or not enrolled | Check Smart Group membership; run `sudo jamf manage` |
| Managed keys absent from `defaults read` | PayloadType mismatch in profile XML | Verify inner `PayloadType` is `com.pasteshelf.PasteShelf` |
| Settings grayed out but wrong value shown | Stale profile not updated | Remove profile and re-deliver via Jamf Pro |
| SSO redirect loop | Redirect URI not registered in IdP | Add `pasteshelf://auth/callback` to IdP app config |
| DLP not blocking | Missing Accessibility/Input Monitoring permission | Grant permissions in System Settings → Privacy & Security |
| Profile installed but app ignores it | App not restarted after profile change | Quit and relaunch PasteShelf |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Deployment Guide](ENTERPRISE_DEPLOYMENT.md) | Deployment options including self-hosted and air-gapped |
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Admin console, user management, policies |
| [Security Guide](../security/SECURITY.md) | Encryption, privacy, and security architecture |
| [Troubleshooting Guide](../operations/TROUBLESHOOTING.md) | General troubleshooting for all editions |

---

*Last updated: 2026-02-28*
