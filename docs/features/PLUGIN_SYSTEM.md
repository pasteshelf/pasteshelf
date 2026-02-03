# Plugin System

> **Last Updated**: 2026-02-03 | **Reading Time**: 18 minutes

Complete guide to developing and using PasteShelf plugins.

---

## Table of Contents

- [Overview](#overview)
- [Plugin Architecture](#plugin-architecture)
- [Creating Plugins](#creating-plugins)
- [Plugin API](#plugin-api)
- [Distribution](#distribution)
- [Security](#security)
- [Examples](#examples)

---

## Overview

The Plugin System enables extending PasteShelf with custom functionality ⭐.

| Feature | Tier | Description |
|---------|------|-------------|
| Use Plugins | ⭐ Pro | Install and use community plugins |
| Create Plugins | ⭐ Pro | Develop custom plugins |
| Plugin Store | ⭐ Pro | Browse and install plugins |
| Enterprise Plugins | 🏢 Enterprise | Private plugin distribution |

### What Plugins Can Do

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Plugin Capabilities                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   CONTENT TRANSFORMATION                                                 │
│   ──────────────────────                                                 │
│   • Transform text (format, convert, encode)                             │
│   • Process images (resize, convert, extract)                            │
│   • Parse structured data (JSON, XML, CSV)                               │
│                                                                          │
│   UI EXTENSIONS                                                          │
│   ─────────────                                                          │
│   • Add menu items                                                       │
│   • Add context menu actions                                             │
│   • Custom preview renderers                                             │
│                                                                          │
│   INTEGRATIONS                                                           │
│   ────────────                                                           │
│   • Connect to external services                                         │
│   • Import/export formats                                                │
│   • Sync with third-party apps                                           │
│                                                                          │
│   AUTOMATION                                                             │
│   ──────────                                                             │
│   • Custom automation actions                                            │
│   • Scheduled tasks                                                      │
│   • Event handlers                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Plugin Architecture

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Plugin Architecture                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    PasteShelf Host                               │   │
│   │                                                                  │   │
│   │   ┌───────────────────────────────────────────────────────────┐ │   │
│   │   │                  Plugin Manager                            │ │   │
│   │   │                                                            │ │   │
│   │   │   • Load/unload plugins                                    │ │   │
│   │   │   • Validate signatures                                    │ │   │
│   │   │   • Manage permissions                                     │ │   │
│   │   │   • Route events                                           │ │   │
│   │   └───────────────────────────────────────────────────────────┘ │   │
│   │                              │                                   │   │
│   │   ┌──────────────────────────▼───────────────────────────────┐  │   │
│   │   │                   Plugin Sandbox                          │  │   │
│   │   │                                                           │  │   │
│   │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │  │   │
│   │   │  │  Plugin A   │  │  Plugin B   │  │    Plugin C     │  │  │   │
│   │   │  │  (Bundle)   │  │  (Bundle)   │  │    (Bundle)     │  │  │   │
│   │   │  │             │  │             │  │                 │  │  │   │
│   │   │  │  Isolated   │  │  Isolated   │  │    Isolated     │  │  │   │
│   │   │  │  Process    │  │  Process    │  │    Process      │  │  │   │
│   │   │  └─────────────┘  └─────────────┘  └─────────────────┘  │  │   │
│   │   │                                                           │  │   │
│   │   │  ─────────────────────────────────────────────────────── │  │   │
│   │   │                    Plugin API                             │  │   │
│   │   │  • Clipboard access (read/write)                          │  │   │
│   │   │  • Storage (per-plugin)                                   │  │   │
│   │   │  • Network (with permissions)                             │  │   │
│   │   │  • UI (menu items, views)                                 │  │   │
│   │   └───────────────────────────────────────────────────────────┘  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Plugin Bundle Structure

```
MyPlugin.pasteshelfplugin/
├── Contents/
│   ├── Info.plist              # Plugin metadata
│   ├── MacOS/
│   │   └── MyPlugin            # Compiled binary
│   ├── Resources/
│   │   ├── icon.png            # Plugin icon (128x128)
│   │   ├── Localizable.strings # Localization
│   │   └── assets/             # Additional resources
│   └── _CodeSignature/         # Code signature
└── README.md                    # Documentation (optional)
```

---

## Creating Plugins

### 1. Create Xcode Project

```bash
# Create new project
mkdir MyPlugin && cd MyPlugin

# Initialize Swift package
swift package init --type library --name MyPlugin
```

### 2. Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required -->
    <key>CFBundleIdentifier</key>
    <string>com.example.myplugin</string>

    <key>CFBundleName</key>
    <string>My Plugin</string>

    <key>CFBundleVersion</key>
    <string>1.0.0</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>

    <key>PSPluginClass</key>
    <string>MyPlugin.MyPlugin</string>

    <!-- Plugin Metadata -->
    <key>PSPluginDescription</key>
    <string>A useful plugin for PasteShelf</string>

    <key>PSPluginAuthor</key>
    <string>Your Name</string>

    <key>PSPluginWebsite</key>
    <string>https://example.com/myplugin</string>

    <key>PSMinimumPasteShelfVersion</key>
    <string>1.0.0</string>

    <!-- Capabilities -->
    <key>PSSupportedContentTypes</key>
    <array>
        <string>public.plain-text</string>
        <string>public.utf8-plain-text</string>
    </array>

    <key>PSRequiredPermissions</key>
    <array>
        <string>clipboard.read</string>
        <string>clipboard.write</string>
        <string>network</string>
    </array>
</dict>
</plist>
```

### 3. Plugin Implementation

```swift
import Foundation
import PasteShelfPluginKit

@objc(MyPlugin)
public final class MyPlugin: NSObject, PasteShelfPlugin {

    // MARK: - Plugin Metadata

    public static let identifier = "com.example.myplugin"
    public static let name = "My Plugin"
    public static let version = "1.0.0"
    public static let supportedTypes: [ContentType] = [.plainText, .richText]

    // MARK: - Storage

    private var storage: PluginStorage!

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Lifecycle

    public func didLoad(with context: PluginContext) {
        self.storage = context.storage
        Logger.plugin.info("\(Self.name) loaded")
    }

    public func willUnload() {
        Logger.plugin.info("\(Self.name) unloading")
    }

    // MARK: - Content Transformation

    public func transform(content: ClipboardContent) async throws -> ClipboardContent? {
        guard let text = content.text else { return nil }

        // Your transformation logic
        let transformed = text.uppercased()

        return ClipboardContent(text: transformed)
    }

    public func supports(contentType: ContentType) -> Bool {
        Self.supportedTypes.contains(contentType)
    }

    // MARK: - Menu Items

    public func menuItems() -> [PluginMenuItem] {
        return [
            PluginMenuItem(
                title: "Transform to Uppercase",
                icon: "textformat.abc.dottedunderline",
                shortcut: KeyboardShortcut("U", modifiers: [.command, .shift]),
                action: { [weak self] content in
                    try await self?.transform(content: content)
                }
            ),
            PluginMenuItem(
                title: "Settings",
                icon: "gear",
                action: { [weak self] _ in
                    self?.showSettings()
                    return nil
                }
            )
        ]
    }

    // MARK: - Settings UI

    public func settingsView() -> AnyView? {
        AnyView(MyPluginSettingsView(storage: storage))
    }

    private func showSettings() {
        // Open settings window
    }
}

// Settings View
struct MyPluginSettingsView: View {
    let storage: PluginStorage

    @State private var isEnabled = true

    var body: some View {
        Form {
            Toggle("Enable feature", isOn: $isEnabled)
        }
        .padding()
        .onAppear {
            isEnabled = storage.get("isEnabled") ?? true
        }
        .onChange(of: isEnabled) { newValue in
            storage.set("isEnabled", value: newValue)
        }
    }
}
```

### 4. Build Plugin

```bash
# Build for release
xcodebuild -scheme MyPlugin -configuration Release build

# Create plugin bundle
mkdir -p MyPlugin.pasteshelfplugin/Contents/MacOS
cp build/Release/MyPlugin MyPlugin.pasteshelfplugin/Contents/MacOS/
cp Info.plist MyPlugin.pasteshelfplugin/Contents/

# Sign the plugin
codesign --sign "Developer ID Application: Your Name" \
    --options runtime \
    MyPlugin.pasteshelfplugin
```

---

## Plugin API

### PluginContext

```swift
/// Context provided to plugins on load
public protocol PluginContext {
    /// Persistent storage for the plugin
    var storage: PluginStorage { get }

    /// Logger for the plugin
    var logger: Logger { get }

    /// Current PasteShelf version
    var hostVersion: String { get }

    /// Request additional permissions
    func requestPermission(_ permission: PluginPermission) async -> Bool
}
```

### ClipboardContent

```swift
/// Content that plugins can read and transform
public struct ClipboardContent {
    /// Plain text content
    public var text: String?

    /// Rich text (RTF) data
    public var rtfData: Data?

    /// HTML content
    public var html: String?

    /// Image data
    public var imageData: Data?

    /// Image representation
    public var image: NSImage?

    /// File URLs
    public var fileURLs: [URL]?

    /// Web URL
    public var url: URL?

    /// Primary content type
    public var contentType: ContentType

    /// Custom metadata
    public var metadata: [String: Any]

    /// Create text content
    public init(text: String) {
        self.text = text
        self.contentType = .plainText
        self.metadata = [:]
    }

    /// Create image content
    public init(image: NSImage) {
        self.image = image
        self.imageData = image.tiffRepresentation
        self.contentType = .image
        self.metadata = [:]
    }
}
```

### PluginStorage

```swift
/// Persistent storage for plugin data
public protocol PluginStorage {
    /// Get value for key
    func get<T: Codable>(_ key: String) -> T?

    /// Set value for key
    func set<T: Codable>(_ key: String, value: T)

    /// Remove value for key
    func remove(_ key: String)

    /// Clear all storage
    func clear()
}
```

### PluginMenuItem

```swift
/// Menu item displayed in PasteShelf UI
public struct PluginMenuItem {
    /// Menu item title
    public let title: String

    /// SF Symbol icon name
    public let icon: String?

    /// Keyboard shortcut
    public let shortcut: KeyboardShortcut?

    /// Whether item is enabled
    public var isEnabled: Bool

    /// Submenu items
    public var submenu: [PluginMenuItem]?

    /// Action to perform
    public let action: (ClipboardContent) async throws -> ClipboardContent?
}
```

### Network API

```swift
/// Network access for plugins (requires permission)
public protocol PluginNetwork {
    /// Perform HTTP request
    func request(_ request: URLRequest) async throws -> (Data, URLResponse)

    /// Simple GET request
    func get(_ url: URL) async throws -> Data

    /// Simple POST request
    func post(_ url: URL, body: Data) async throws -> Data
}
```

---

## Distribution

### Plugin Store ⭐

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Plugin Store                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  [Search plugins...]                               [Categories ▼]        │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  Featured                                                                │
│                                                                          │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐        │
│  │ [Icon]           │ │ [Icon]           │ │ [Icon]           │        │
│  │ URL Shortener    │ │ JSON Formatter   │ │ Code Highlighter │        │
│  │ ★★★★★ (125)      │ │ ★★★★☆ (89)       │ │ ★★★★★ (203)      │        │
│  │ Free             │ │ Free             │ │ $2.99            │        │
│  │ [Install]        │ │ [Install]        │ │ [Purchase]       │        │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘        │
│                                                                          │
│  Popular                                                                 │
│                                                                          │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐        │
│  │ [Icon]           │ │ [Icon]           │ │ [Icon]           │        │
│  │ Translator       │ │ Markdown Convert │ │ Image Optimizer  │        │
│  │ ★★★★☆ (456)      │ │ ★★★★★ (312)      │ │ ★★★★☆ (178)      │        │
│  │ $4.99            │ │ Free             │ │ Free             │        │
│  │ [Purchase]       │ │ [Installed ✓]    │ │ [Install]        │        │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Submission Guidelines

1. **Code Signing**: Plugin must be signed with Developer ID
2. **Privacy**: Must declare all required permissions
3. **Documentation**: Include README and changelog
4. **Testing**: Must pass automated tests
5. **Review**: Manual review for security and quality

### Enterprise Distribution 🏢

```yaml
# enterprise-plugins.yaml
plugins:
  - id: com.company.custom-transform
    name: Company Transform
    version: 1.2.0
    url: https://internal.company.com/plugins/custom-transform.pasteshelfplugin
    checksum: sha256:abc123...
    required: true  # Auto-install for all users

  - id: com.company.slack-integration
    name: Slack Integration
    version: 2.0.0
    url: https://internal.company.com/plugins/slack.pasteshelfplugin
    checksum: sha256:def456...
    required: false
```

---

## Security

### Sandboxing

Plugins run in isolated sandboxes:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Plugin Sandbox                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Allowed:                                                               │
│   • Read/write to plugin storage directory                               │
│   • Access clipboard via Plugin API                                      │
│   • Network access (if permitted)                                        │
│   • Display UI in plugin context                                         │
│                                                                          │
│   Blocked:                                                               │
│   • File system access outside sandbox                                   │
│   • Direct system API calls                                              │
│   • Interprocess communication                                           │
│   • Loading external code                                                │
│   • Accessing other plugins' data                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Permissions

```swift
enum PluginPermission: String {
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case network = "network"
    case notifications = "notifications"
    case storage = "storage"
    case automation = "automation"
}
```

### Code Signing

```bash
# Sign plugin for distribution
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
    --options runtime \
    --timestamp \
    --deep \
    MyPlugin.pasteshelfplugin

# Verify signature
codesign --verify --deep --strict MyPlugin.pasteshelfplugin

# Notarize plugin
xcrun notarytool submit MyPlugin.pasteshelfplugin.zip \
    --apple-id "developer@example.com" \
    --password "@keychain:AC_PASSWORD" \
    --team-id "TEAMID" \
    --wait
```

---

## Examples

### URL Shortener Plugin

```swift
@objc(URLShortener)
public final class URLShortener: NSObject, PasteShelfPlugin {
    public static let identifier = "com.example.urlshortener"
    public static let name = "URL Shortener"
    public static let version = "1.0.0"
    public static let supportedTypes: [ContentType] = [.plainText, .url]

    private var network: PluginNetwork!

    public func didLoad(with context: PluginContext) {
        self.network = context.network
    }

    public func transform(content: ClipboardContent) async throws -> ClipboardContent? {
        guard let text = content.text,
              let url = URL(string: text),
              url.scheme != nil else {
            return nil
        }

        // Call URL shortener API
        let shortened = try await shortenURL(url)

        return ClipboardContent(text: shortened.absoluteString)
    }

    private func shortenURL(_ url: URL) async throws -> URL {
        let apiURL = URL(string: "https://api.short.io/links")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["originalURL": url.absoluteString])

        let (data, _) = try await network.request(request)
        let response = try JSONDecoder().decode(ShortenResponse.self, from: data)

        return URL(string: response.shortURL)!
    }

    public func menuItems() -> [PluginMenuItem] {
        [
            PluginMenuItem(
                title: "Shorten URL",
                icon: "link.badge.plus",
                shortcut: KeyboardShortcut("S", modifiers: [.command, .option]),
                action: { [weak self] content in
                    try await self?.transform(content: content)
                }
            )
        ]
    }
}
```

### JSON Formatter Plugin

```swift
@objc(JSONFormatter)
public final class JSONFormatter: NSObject, PasteShelfPlugin {
    public static let identifier = "com.example.jsonformatter"
    public static let name = "JSON Formatter"
    public static let version = "1.0.0"
    public static let supportedTypes: [ContentType] = [.plainText]

    public func transform(content: ClipboardContent) async throws -> ClipboardContent? {
        guard let text = content.text else { return nil }

        // Parse and reformat JSON
        let data = Data(text.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        let formatted = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )

        guard let formattedString = String(data: formatted, encoding: .utf8) else {
            return nil
        }

        var result = ClipboardContent(text: formattedString)
        result.metadata["isJSON"] = true
        return result
    }

    public func menuItems() -> [PluginMenuItem] {
        [
            PluginMenuItem(
                title: "Format JSON",
                icon: "curlybraces",
                action: { [weak self] content in
                    try await self?.transform(content: content)
                }
            ),
            PluginMenuItem(
                title: "Minify JSON",
                icon: "arrow.down.right.and.arrow.up.left",
                action: { [weak self] content in
                    try await self?.minify(content: content)
                }
            )
        ]
    }

    private func minify(content: ClipboardContent) async throws -> ClipboardContent? {
        guard let text = content.text else { return nil }

        let data = Data(text.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        let minified = try JSONSerialization.data(withJSONObject: json)

        guard let minifiedString = String(data: minified, encoding: .utf8) else {
            return nil
        }

        return ClipboardContent(text: minifiedString)
    }
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [API Documentation](../api/API_DOCUMENTATION.md) | Full API reference |
| [Automation Engine](AUTOMATION_ENGINE.md) | Automation features |
| [Security](../security/SECURITY.md) | Security details |

---

*Last updated: 2026-02-03*
