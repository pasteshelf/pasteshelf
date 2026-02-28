# Kandji Deployment Guide for PasteShelf Enterprise

> **Last Updated**: 2026-02-28 | **Reading Time**: 15 minutes

Step-by-step guide for deploying PasteShelf Enterprise to managed Mac fleets using Kandji.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Custom App Setup](#custom-app-setup)
- [Custom Profile Configuration](#custom-profile-configuration)
- [Blueprint Assignment](#blueprint-assignment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before beginning the deployment, confirm the following requirements are met.

### Kandji Account

- Kandji account with **Library** and **Blueprint** management permissions
- Access to the **Kandji Admin Portal** (`https://subdomain.kandji.io`)
- The `Manager` or `Admin` role assigned to your Kandji user

### PasteShelf Enterprise License

- An active PasteShelf Enterprise license
- Your **Organization ID** (available from the PasteShelf admin console at `https://admin.pasteshelf.app`)
- Your **License Server URL** (cloud-hosted: `https://license.pasteshelf.app`, or your self-hosted endpoint)
- The signed enterprise `.pkg` installer downloaded from the PasteShelf customer portal

### Target Devices

- macOS 14.0 (Sonoma) or later on all target devices
- Devices enrolled in Kandji and assigned to a Blueprint
- Apple Silicon or Intel Mac — both are supported

---

## Custom App Setup

Add PasteShelf as a **Custom App** Library Item in Kandji so the installer is pushed to enrolled devices automatically.

### Step 1: Upload the Installer Package

1. In the Kandji Admin Portal, navigate to **Library**.
2. Click **Add Library Item** and select **Custom App**.
3. Fill in the Library Item details:

   | Field | Value |
   |-------|-------|
   | Name | `PasteShelf Enterprise` |
   | Show in Self Service | Optional — enable if users should be able to install on demand |

4. Under **Installer**, choose **Upload Package** and upload your signed `.pkg` file:

   ```
   PasteShelf-Enterprise-<version>.pkg
   ```

5. Confirm the **Bundle Identifier** detected by Kandji matches:

   ```
   com.pasteshelf.PasteShelf
   ```

6. Confirm the **Bundle Version** matches the intended release version.

> **Note**: PasteShelf Enterprise installers are signed and notarized by Apple. Kandji will validate the signature automatically. If validation fails, confirm you downloaded the package from `https://download.pasteshelf.app/enterprise/`.

### Step 2: Configure Installation Behavior

In the **Installation** section of the Custom App Library Item:

| Setting | Recommended Value |
|---------|-------------------|
| Installation Type | Install Automatically |
| Restart Required | No |
| Uninstall on Removal | Yes |

### Step 3: Configure Auto-Update Behavior

In the **Updates** section:

| Setting | Recommended Value |
|---------|-------------------|
| Enforce Latest Version | Enabled |
| Allowed Deferral Period | 3 days (adjust to match your change management policy) |

When **Enforce Latest Version** is enabled, Kandji will automatically push the newer package to devices as soon as you upload an updated `.pkg` to the Library Item.

### Step 4: Save the Library Item

Click **Save** to finalize the Custom App Library Item. Do not assign it to a Blueprint yet — that is covered in the [Blueprint Assignment](#blueprint-assignment) section.

---

## Custom Profile Configuration

Create a **Custom Profile** Library Item to push managed preferences to devices via the `com.pasteshelf.PasteShelf` preference domain. These settings are enforced by the system and cannot be overridden by end users.

### Step 1: Create the Configuration Profile Payload

Create a file named `PasteShelf-Enterprise.mobileconfig` with the content below. Replace the placeholder values with your organization's actual values before uploading.

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
            <string>PasteShelf Enterprise Settings</string>
            <key>PayloadDescription</key>
            <string>Managed configuration for PasteShelf Enterprise</string>

            <!-- ═══════════════════════════════════
                 LICENSE CONFIGURATION
                 ═══════════════════════════════════ -->

            <!-- Enterprise license server URL -->
            <key>LicenseServer</key>
            <string>https://license.pasteshelf.app</string>

            <!-- Organization identifier from the PasteShelf admin console -->
            <key>OrganizationID</key>
            <string>org_REPLACE_WITH_YOUR_ORG_ID</string>

            <!-- ═══════════════════════════════════
                 SSO CONFIGURATION
                 ═══════════════════════════════════ -->

            <!-- Enable SSO authentication for all users -->
            <key>SSOEnabled</key>
            <true/>

            <!-- Identity provider name (okta, azure, google, onelogin, etc.) -->
            <key>SSOProvider</key>
            <string>okta</string>

            <!-- Identity provider domain -->
            <key>SSODomain</key>
            <string>company.okta.com</string>

            <!-- ═══════════════════════════════════
                 SYNC AND STORAGE CONFIGURATION
                 ═══════════════════════════════════ -->

            <!-- Enable iCloud sync (Pro/Enterprise feature) -->
            <key>CloudSyncEnabled</key>
            <true/>

            <!-- When true, disables all cloud sync and stores data locally only -->
            <key>LocalStorageOnly</key>
            <false/>

            <!-- ═══════════════════════════════════
                 FEATURES
                 ═══════════════════════════════════ -->

            <!-- Allow users to install and use plugins -->
            <key>PluginsEnabled</key>
            <true/>

            <!-- ═══════════════════════════════════
                 SECURITY SETTINGS
                 ═══════════════════════════════════ -->

            <!-- Require Touch ID or password before accessing clipboard history -->
            <key>RequireBiometricAuth</key>
            <false/>

            <!-- Auto-lock timeout in seconds (0 = disabled) -->
            <key>AutoLockTimeout</key>
            <integer>0</integer>

            <!-- Clear clipboard history when the app quits -->
            <key>ClearOnQuit</key>
            <false/>

            <!-- ═══════════════════════════════════
                 DATA RETENTION
                 ═══════════════════════════════════ -->

            <!-- Maximum number of days to retain history (0 = unlimited) -->
            <key>MaxHistoryDays</key>
            <integer>0</integer>

            <!-- Maximum number of clipboard items to retain -->
            <key>MaxHistoryItems</key>
            <integer>500</integer>

            <!-- Exclude content copied from private browsing windows -->
            <key>ExcludePrivateBrowsing</key>
            <true/>

            <!-- ═══════════════════════════════════
                 DATA LOSS PREVENTION (DLP)
                 ═══════════════════════════════════ -->

            <!-- Enable DLP engine -->
            <key>DLPEnabled</key>
            <false/>

            <!-- Block credit card numbers from being stored in history -->
            <key>BlockCreditCards</key>
            <false/>

            <!-- Block API keys and secrets from being stored in history -->
            <key>BlockAPIKeys</key>
            <false/>

            <!-- ═══════════════════════════════════
                 APPEARANCE
                 ═══════════════════════════════════ -->

            <!-- UI theme: system, light, or dark -->
            <key>Theme</key>
            <string>system</string>
        </dict>
    </array>

    <key>PayloadDisplayName</key>
    <string>PasteShelf Enterprise</string>
    <key>PayloadDescription</key>
    <string>Managed settings for PasteShelf Enterprise. Deployed via Kandji.</string>
    <key>PayloadIdentifier</key>
    <string>com.company.pasteshelf</string>
    <key>PayloadOrganization</key>
    <string>Your Organization Name</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>12345678-1234-1234-1234-123456789012</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadScope</key>
    <string>System</string>
</dict>
</plist>
```

> **Important**: Replace the two placeholder `UUID` values with unique UUIDs before deploying. Generate them with `uuidgen` in Terminal:
>
> ```bash
> uuidgen   # Run twice — once for PayloadUUID in the inner dict, once for the outer dict
> ```

### Step 2: Preference Key Reference

The table below lists all supported managed preference keys for the `com.pasteshelf.PasteShelf` domain.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `LicenseServer` | String | — | Enterprise license server URL |
| `OrganizationID` | String | — | Organization identifier from admin console |
| `SSOEnabled` | Boolean | `false` | Enable SSO authentication |
| `SSOProvider` | String | — | Provider name (`okta`, `azure`, `google`, `onelogin`, `pingidentity`) |
| `SSODomain` | String | — | Identity provider domain |
| `CloudSyncEnabled` | Boolean | `true` | Enable iCloud sync (requires Pro or Enterprise) |
| `LocalStorageOnly` | Boolean | `false` | Restrict to local storage only; disables all cloud sync |
| `PluginsEnabled` | Boolean | `true` | Allow users to install and use plugins |
| `RequireBiometricAuth` | Boolean | `false` | Require Touch ID or password to access clipboard history |
| `AutoLockTimeout` | Integer | `0` | Seconds before auto-lock activates; `0` disables auto-lock |
| `ClearOnQuit` | Boolean | `false` | Delete clipboard history when PasteShelf quits |
| `MaxHistoryDays` | Integer | `0` | Maximum retention period in days; `0` means unlimited |
| `MaxHistoryItems` | Integer | `500` | Maximum number of items to keep in history |
| `ExcludePrivateBrowsing` | Boolean | `true` | Exclude content copied from private browsing windows |
| `DLPEnabled` | Boolean | `false` | Enable the Data Loss Prevention engine |
| `BlockCreditCards` | Boolean | `false` | Prevent credit card numbers from being saved to history |
| `BlockAPIKeys` | Boolean | `false` | Prevent API keys and secrets from being saved to history |
| `Theme` | String | `system` | UI theme: `system`, `light`, or `dark` |

### Step 3: Upload the Profile to Kandji

1. In the Kandji Admin Portal, navigate to **Library**.
2. Click **Add Library Item** and select **Custom Profile**.
3. Enter a descriptive name, for example: `PasteShelf Enterprise Configuration`.
4. Under **Profile**, click **Upload Profile** and select the `PasteShelf-Enterprise.mobileconfig` file you created.
5. Kandji will parse the profile and display the payload identifier (`com.company.pasteshelf`). Confirm this is correct.
6. Click **Save**.

---

## Blueprint Assignment

A Kandji **Blueprint** defines which Library Items are applied to which devices. Assign both the Custom App and the Custom Profile to the same Blueprint so they are delivered together.

### Step 1: Open or Create a Blueprint

1. In the Kandji Admin Portal, navigate to **Blueprints**.
2. Select an existing Blueprint (for example, `Engineering Macs`) or click **Create Blueprint** to create a new one.

### Step 2: Add Library Items to the Blueprint

Within the Blueprint editor:

1. Click **Add Library Item**.
2. Search for `PasteShelf Enterprise` and add the Custom App.
3. Click **Add Library Item** again.
4. Search for `PasteShelf Enterprise Configuration` and add the Custom Profile.

Both items should now appear in the Blueprint's Library Item list with status **Assigned**.

### Step 3: Configure Assignment Rules

Use Kandji's **Assignment Rules** to target specific device groups or departments within the Blueprint:

| Rule Type | Example |
|-----------|---------|
| Device Group | `Engineering`, `Product`, `Finance` |
| Department | Match values from your directory integration (e.g., Okta or Azure AD) |
| Operating System | macOS 14.0 and later |
| Serial Number | For pilot rollout to specific devices |

To add assignment rules:

1. In the Blueprint editor, click the **Rules** tab.
2. Click **Add Rule** and define the condition.
3. Click **Save**.

> **Tip**: Start with a small pilot group (for example, 5–10 devices) by scoping the Blueprint to a test device group. Expand the scope after verifying deployment.

---

## Verification

After assignment, Kandji will push the Library Items to enrolled devices at the next MDM check-in (typically within 15 minutes). Use the following steps to confirm successful deployment.

### Verify in the Kandji Admin Portal

1. Navigate to **Devices** and select a target device.
2. Click the **Library Items** tab.
3. Confirm both items appear with a **Pass** status:
   - `PasteShelf Enterprise` (Custom App)
   - `PasteShelf Enterprise Configuration` (Custom Profile)

If an item shows **Pending**, the device has not checked in yet. If it shows **Failed**, see the [Troubleshooting](#troubleshooting) section.

### Verify on the Device

Open Terminal on a managed device and run the following commands.

**Check that the configuration profile is installed:**

```bash
profiles show -type configuration | grep -i pasteshelf
```

Expected output:

```
attribute: name: PasteShelf Enterprise Configuration
attribute: identifier: com.company.pasteshelf
```

**Read the managed preference domain to confirm keys are applied:**

```bash
defaults read com.pasteshelf.PasteShelf
```

Expected output (will vary based on your profile configuration):

```
{
    CloudSyncEnabled = 1;
    DLPEnabled = 0;
    ExcludePrivateBrowsing = 1;
    LicenseServer = "https://license.pasteshelf.app";
    MaxHistoryItems = 500;
    OrganizationID = "org_REPLACE_WITH_YOUR_ORG_ID";
    SSODomain = "company.okta.com";
    SSOEnabled = 1;
    SSOProvider = okta;
    Theme = system;
}
```

**Verify PasteShelf is installed:**

```bash
ls -la /Applications/PasteShelf.app
```

**Verify PasteShelf recognizes managed settings** (launch the app and navigate to):

```
PasteShelf menu bar icon > Settings > General
```

Keys delivered via MDM are displayed with a lock icon and are read-only in the settings UI.

---

## Troubleshooting

### Profile Not Deploying to Devices

**Symptom**: The Custom Profile shows **Pending** or **Failed** in Kandji device details.

**Steps to resolve:**

1. Confirm the device is enrolled in Kandji and is assigned to the correct Blueprint:
   ```
   Kandji Admin Portal > Devices > [Device] > Blueprints
   ```

2. Force an immediate MDM check-in from the Kandji Admin Portal:
   ```
   Kandji Admin Portal > Devices > [Device] > Actions > Send MDM Command > Check-In
   ```

3. On the device, force a manual MDM push:
   ```bash
   sudo profiles renew -type enrollment
   ```

4. Verify the `.mobileconfig` file is valid XML and contains a `PayloadScope` of `System`. Profiles with `PayloadScope: User` require the user to be logged in at the time of installation.

5. Check the system log on the device for MDM-related errors:
   ```bash
   log show --predicate 'subsystem == "com.apple.ManagedClient"' \
     --last 30m --level debug
   ```

---

### Blueprint Assignment Not Targeting Correct Devices

**Symptom**: The Blueprint is assigned, but some devices are not receiving the Library Items.

**Steps to resolve:**

1. Verify the device is assigned to the expected Blueprint:
   ```
   Kandji Admin Portal > Devices > [Device] > Blueprints
   ```
   A device can only be in one Blueprint at a time. If the device is in the wrong Blueprint, reassign it under **Devices > [Device] > Edit Blueprint**.

2. Confirm the Assignment Rules in the Blueprint match the device's attributes (Department, device group, OS version). Navigate to:
   ```
   Kandji Admin Portal > Blueprints > [Blueprint] > Rules
   ```

3. If using a device group rule, confirm the device is a member of the expected group:
   ```
   Kandji Admin Portal > Devices > Device Groups
   ```

---

### Custom App Installation Failures

**Symptom**: The Custom App shows a **Failed** or **Error** status in Kandji device details.

**Steps to resolve:**

1. Check the Kandji device activity log for the specific error code:
   ```
   Kandji Admin Portal > Devices > [Device] > Activity
   ```

2. Verify the `.pkg` installer is signed and notarized. On the device, attempt a manual install to see the Gatekeeper response:
   ```bash
   sudo installer -pkg /path/to/PasteShelf-Enterprise.pkg -target /
   ```

3. If the package is blocked by Gatekeeper, verify the package signature:
   ```bash
   pkgutil --check-signature /path/to/PasteShelf-Enterprise.pkg
   ```
   The output should show `Status: signed by a certificate trusted by Mac OS X`. If not, re-download the package from the PasteShelf customer portal.

4. Check for an existing, conflicting installation that may block the upgrade:
   ```bash
   pkgutil --pkgs | grep -i pasteshelf
   ```
   If an older version is installed via a different method, remove it first:
   ```bash
   sudo rm -rf /Applications/PasteShelf.app
   ```
   Then trigger a Kandji re-install from the Admin Portal.

5. Review the system install log on the device:
   ```bash
   log show --predicate 'process == "installer"' \
     --last 1h --level debug | grep -i pasteshelf
   ```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Enterprise Deployment Guide](ENTERPRISE_DEPLOYMENT.md) | Deployment options including Jamf Pro, self-hosted, and air-gapped |
| [Enterprise Admin Guide](ENTERPRISE_ADMIN_GUIDE.md) | Admin console, SSO, DLP policy management |
| [Security](../security/SECURITY.md) | Security architecture and encryption details |
| [Troubleshooting](../operations/TROUBLESHOOTING.md) | General application troubleshooting |

---

*Last updated: 2026-02-28*
