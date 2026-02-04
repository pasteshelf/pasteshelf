# PasteShelfPluginKit API Reference

Complete API documentation for the PasteShelf Plugin SDK.

---

## Protocols

### PasteShelfPlugin

The base protocol all plugins must implement.

```swift
@objc public protocol PasteShelfPlugin: NSObjectProtocol {
    @objc func didLoad(with context: any PluginContext)
    @objc optional func willUnload()
    @objc optional func menuItems() -> [PluginMenuItem]
}
```

#### didLoad(with:)

Called when the plugin is loaded by PasteShelf.

```swift
func didLoad(with context: any PluginContext)
```

**Parameters:**
- `context`: The plugin context providing access to host APIs

**Discussion:**
Store a reference to the context for later use. Initialize your plugin state here.

#### willUnload()

Called before the plugin is unloaded.

```swift
optional func willUnload()
```

**Discussion:**
Clean up resources, cancel pending operations, and unregister handlers.

#### menuItems()

Returns menu items to add to the PasteShelf UI.

```swift
optional func menuItems() -> [PluginMenuItem]
```

**Returns:**
Array of `PluginMenuItem` objects, or empty array if none.

---

### PasteShelfPluginExtended

Protocol for plugins that transform clipboard content.

```swift
public protocol PasteShelfPluginExtended: PasteShelfPlugin {
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?
    func supports(contentType: ContentType) -> Bool
}
```

#### transform(content:)

Transforms clipboard content.

```swift
func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?
```

**Parameters:**
- `content`: The content to transform

**Returns:**
Transformed content, or `nil` to indicate no transformation occurred.

**Throws:**
Any error if transformation fails.

#### supports(contentType:)

Checks if the plugin supports the given content type.

```swift
func supports(contentType: ContentType) -> Bool
```

**Parameters:**
- `contentType`: The content type to check

**Returns:**
`true` if the plugin can handle this content type.

---

### PasteShelfPluginWithSettings

Protocol for plugins that provide a settings view.

```swift
public protocol PasteShelfPluginWithSettings: PasteShelfPlugin {
    func settingsView() -> AnyView?
}
```

#### settingsView()

Returns a SwiftUI view for plugin settings.

```swift
func settingsView() -> AnyView?
```

**Returns:**
A SwiftUI view wrapped in `AnyView`, or `nil` if no settings.

**Example:**
```swift
func settingsView() -> AnyView? {
    AnyView(MyPluginSettingsView(storage: context?.storage))
}
```

---

### PluginContext

Context provided to plugins, giving access to host APIs.

```swift
@objc public protocol PluginContext: NSObjectProtocol {
    var storage: any PluginStorage { get }
    var logger: PluginLogger { get }
    var hostVersion: String { get }
    var network: (any PluginNetwork)? { get }
    var clipboard: (any PluginClipboardAccess)? { get }
    func requestPermission(_ permission: String) async -> Bool
    func hasPermission(_ permission: String) -> Bool
}
```

#### storage

Persistent storage for plugin data.

```swift
var storage: any PluginStorage { get }
```

#### logger

Logger for debugging and diagnostics.

```swift
var logger: PluginLogger { get }
```

#### hostVersion

Current PasteShelf version string.

```swift
var hostVersion: String { get }
```

#### network

Network access (requires `network` permission).

```swift
var network: (any PluginNetwork)? { get }
```

**Returns:**
Network API instance, or `nil` if permission not granted.

#### clipboard

Clipboard access (requires `clipboard.read` or `clipboard.write` permission).

```swift
var clipboard: (any PluginClipboardAccess)? { get }
```

**Returns:**
Clipboard API instance, or `nil` if permissions not granted.

#### requestPermission(_:)

Request an additional permission at runtime.

```swift
func requestPermission(_ permission: String) async -> Bool
```

**Parameters:**
- `permission`: The permission identifier (e.g., `"network"`)

**Returns:**
`true` if permission was granted.

**Discussion:**
Only permissions declared in Info.plist can be requested.

#### hasPermission(_:)

Checks if a permission is currently granted.

```swift
func hasPermission(_ permission: String) -> Bool
```

**Parameters:**
- `permission`: The permission identifier

**Returns:**
`true` if the permission is granted.

---

### PluginStorage

Persistent storage for plugin data.

```swift
@objc public protocol PluginStorage: NSObjectProtocol {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func setString(_ value: String?, forKey key: String)
    func setData(_ value: Data?, forKey key: String)
    func setBool(_ value: Bool, forKey key: String)
    func setInteger(_ value: Int, forKey key: String)
    func setDouble(_ value: Double, forKey key: String)
    func removeObject(forKey key: String)
    func clear()
}
```

#### Swift Extension for Codable

```swift
extension PluginStorage {
    func get<T: Codable>(_ key: String) -> T?
    func set<T: Codable>(_ key: String, value: T?)
}
```

**Example:**
```swift
struct MySettings: Codable {
    var apiKey: String
    var enabled: Bool
}

// Save
let settings = MySettings(apiKey: "abc", enabled: true)
storage.set("settings", value: settings)

// Load
let loaded: MySettings? = storage.get("settings")
```

---

### PluginNetwork

Network access for plugins.

```swift
@objc public protocol PluginNetwork: NSObjectProtocol {
    func request(_ request: URLRequest) async throws -> (Data, URLResponse)
}
```

#### request(_:)

Performs an HTTP request.

```swift
func request(_ request: URLRequest) async throws -> (Data, URLResponse)
```

**Parameters:**
- `request`: The URL request to perform

**Returns:**
Tuple of response data and URL response.

**Throws:**
Network errors or permission errors.

#### Swift Extensions

```swift
extension PluginNetwork {
    func get(_ url: URL) async throws -> Data
    func post(_ url: URL, body: Data, contentType: String) async throws -> Data
}
```

---

### PluginClipboardAccess

Clipboard access for plugins.

```swift
@objc public protocol PluginClipboardAccess: NSObjectProtocol {
    func recentItems(limit: Int) async -> [PluginClipboardContent]
    func currentContent() -> PluginClipboardContent?
    func writeToClipboard(_ content: PluginClipboardContent)
}
```

#### recentItems(limit:)

Gets recent clipboard items.

```swift
func recentItems(limit: Int) async -> [PluginClipboardContent]
```

**Parameters:**
- `limit`: Maximum number of items to return

**Returns:**
Array of recent clipboard content.

#### currentContent()

Gets the current clipboard content.

```swift
func currentContent() -> PluginClipboardContent?
```

**Returns:**
Current clipboard content, or `nil` if empty.

#### writeToClipboard(_:)

Writes content to the clipboard.

```swift
func writeToClipboard(_ content: PluginClipboardContent)
```

**Parameters:**
- `content`: The content to write

---

## Classes

### PluginLogger

Logger for plugin diagnostics.

```swift
@objc public final class PluginLogger: NSObject, Sendable {
    public init(pluginId: String)
    @objc public func debug(_ message: String)
    @objc public func info(_ message: String)
    @objc public func warning(_ message: String)
    @objc public func error(_ message: String)
}
```

**Example:**
```swift
context.logger.info("Processing content...")
context.logger.error("Failed to connect: \(error)")
```

---

### PluginClipboardContent

Clipboard content representation for plugins.

```swift
@objc public class PluginClipboardContent: NSObject, @unchecked Sendable {
    // Text content
    @objc public var text: String?
    @objc public var rtfData: Data?
    @objc public var html: String?

    // Image content
    @objc public var imageData: Data?
    @objc public var image: NSImage?

    // URL content
    @objc public var fileURLs: [URL]?
    @objc public var url: URL?

    // Metadata
    @objc public var contentTypeIdentifier: String
    @objc public var sourceAppBundleId: String?
    @objc public var timestamp: Date
    @objc public var metadata: [String: Any]

    // Initializers
    @objc public init(text: String)
    @objc public init(image: NSImage)
    @objc public init(url: URL)
    @objc public override init()

    // Swift property
    public var contentType: ContentType?
}
```

**Example:**
```swift
// Create text content
let content = PluginClipboardContent(text: "Hello, World!")
content.metadata["source"] = "MyPlugin"

// Create URL content
let urlContent = PluginClipboardContent(url: URL(string: "https://example.com")!)

// Create image content
let imageContent = PluginClipboardContent(image: myImage)
```

---

### PluginMenuItem

Menu item for the PasteShelf UI.

```swift
@objc public class PluginMenuItem: NSObject, @unchecked Sendable {
    @objc public let title: String
    @objc public let iconName: String?
    @objc public let shortcutKey: String?
    @objc public var isEnabled: Bool
    @objc public var submenuItems: [PluginMenuItem]?

    // Objective-C initializer (without action)
    @objc public init(
        title: String,
        iconName: String? = nil,
        shortcutKey: String? = nil,
        isEnabled: Bool = true
    )

    // Swift initializer (with action)
    public init(
        title: String,
        iconName: String? = nil,
        shortcutKey: String? = nil,
        isEnabled: Bool = true,
        action: @escaping (PluginClipboardContent) async throws -> PluginClipboardContent?
    )
}
```

**Shortcut Key Format:**
- Single key with modifiers: `"U+command+shift"` (Cmd+Shift+U)
- Modifiers: `command`, `shift`, `option`, `control`

**Example:**
```swift
PluginMenuItem(
    title: "Transform Text",
    iconName: "wand.and.stars",
    shortcutKey: "T+command+shift"
) { content in
    // Transform and return new content
    return PluginClipboardContent(text: content.text?.uppercased() ?? "")
}
```

---

## Enumerations

### ContentType

Supported clipboard content types.

```swift
public enum ContentType: String, CaseIterable, Codable, Sendable {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case jpeg = "public.jpeg"
    case tiff = "public.tiff"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"

    public var displayName: String
}
```

---

### PluginPermission

Permissions that plugins can request.

```swift
public enum PluginPermission: String, Codable, Hashable, CaseIterable, Sendable {
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case network = "network"
    case notifications = "notifications"
    case storage = "storage"
    case automation = "automation"

    public var displayName: String
}
```

| Permission | Display Name | Description |
|------------|--------------|-------------|
| `clipboardRead` | Read Clipboard | Access clipboard history |
| `clipboardWrite` | Write Clipboard | Modify clipboard content |
| `network` | Network Access | Make HTTP requests |
| `notifications` | Notifications | Show system notifications |
| `storage` | Storage | Persist plugin data |
| `automation` | Automation | Integrate with automation |

---

## Info.plist Keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `PSPluginIdentifier` | String | Yes | Unique reverse-DNS identifier |
| `PSPluginName` | String | Yes | Display name |
| `PSPluginVersion` | String | Yes | Semantic version (e.g., "1.0.0") |
| `NSPrincipalClass` | String | Yes | Class name (must match @objc) |
| `PSMinimumVersion` | String | Yes | Minimum PasteShelf version |
| `PSPluginPermissions` | Array | Yes | Required permissions |
| `PSPluginAuthor` | String | No | Author name |
| `PSPluginWebsite` | String | No | Author website URL |
| `PSPluginDescription` | String | No | Brief description |
| `PSPluginSupportedTypes` | Array | No | Supported UTI types |

---

## Error Handling

Plugins should throw descriptive errors that PasteShelf can display to users:

```swift
enum MyPluginError: Error, LocalizedError {
    case noContent
    case invalidFormat
    case networkFailed(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No content to process"
        case .invalidFormat:
            return "Content format is not supported"
        case .networkFailed(let message):
            return "Network request failed: \(message)"
        case .permissionDenied(let permission):
            return "\(permission) permission is required"
        }
    }
}
```

---

## Thread Safety

- Plugin methods may be called on any thread
- UI updates must be dispatched to the main thread
- Use `@MainActor` for UI-related code
- Storage operations are thread-safe
- Network requests are async and don't block

---

## Version Compatibility

| SDK Version | Min PasteShelf | Min macOS |
|-------------|----------------|-----------|
| 1.0.0 | 1.3.0 | 14.0 |

---

*PasteShelfPluginKit v1.0.0*
