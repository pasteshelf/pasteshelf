# Deployment Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Guide for distributing PasteShelf to end users.

---

## Table of Contents

- [Distribution Channels](#distribution-channels)
- [Mac App Store](#mac-app-store)
- [Direct Distribution](#direct-distribution)
- [Release Process](#release-process)
- [Update Mechanism](#update-mechanism)

---

## Distribution Channels

| Channel | Tier | Description |
|---------|------|-------------|
| Mac App Store | 🆓 ⭐ 🏢 | Primary distribution |
| Direct Download | ⭐ 🏢 | DMG from website |
| Enterprise | 🏢 | MDM deployment |
| Homebrew | 🆓 | Community cask |

---

## Mac App Store

### Submission Requirements

- Signed with Apple Distribution certificate
- Sandboxed with required entitlements
- App Review compliant
- Privacy policy provided

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.application-identifier</key>
    <string>$(TeamIdentifierPrefix)com.pasteshelf.PasteShelf</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.pasteshelf.PasteShelf</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)com.pasteshelf.PasteShelf</string>
</dict>
</plist>
```

---

## Direct Distribution

### Code Signing

```bash
# Sign the app
codesign --sign "Developer ID Application: PasteShelf Inc (TEAMID)" \
    --options runtime \
    --timestamp \
    --deep \
    PasteShelf.app

# Create DMG
hdiutil create -volname "PasteShelf" \
    -srcfolder PasteShelf.app \
    -ov -format UDZO \
    PasteShelf-1.0.0.dmg

# Sign DMG
codesign --sign "Developer ID Application: PasteShelf Inc (TEAMID)" \
    PasteShelf-1.0.0.dmg

# Notarize
xcrun notarytool submit PasteShelf-1.0.0.dmg \
    --apple-id "developer@pasteshelf.app" \
    --password "@keychain:AC_PASSWORD" \
    --team-id "TEAMID" \
    --wait

# Staple
xcrun stapler staple PasteShelf-1.0.0.dmg
```

### Update System (Sparkle)

```xml
<!-- appcast.xml -->
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>PasteShelf Updates</title>
        <item>
            <title>Version 1.0.0</title>
            <sparkle:version>1.0.0</sparkle:version>
            <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            <enclosure url="https://download.pasteshelf.app/PasteShelf-1.0.0.dmg"
                       sparkle:edSignature="..."
                       length="12345678"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
```

---

## Release Process

1. **Version bump** - Update version in project
2. **Build** - Create release build
3. **Test** - QA verification
4. **Sign** - Code signing and notarization
5. **Publish** - Upload to distribution channels
6. **Announce** - Release notes and communications

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Build System](BUILD_SYSTEM.md) | Build configuration |
| [CI/CD](CI_CD.md) | Automation |

---

*Last updated: 2026-02-03*
