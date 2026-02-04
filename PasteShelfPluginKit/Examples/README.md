# PasteShelfPluginKit Examples

This directory contains example plugins demonstrating how to use the PasteShelfPluginKit SDK.

## ExamplePlugin

A complete example showing common plugin patterns:

- **Text transformation**: Reverses text content
- **Settings view**: SwiftUI-based configuration UI
- **Menu items**: Primary and secondary actions with shortcuts
- **Error handling**: Proper error types with localized descriptions
- **Metadata tracking**: Adding metadata to transformed content

### Files

- `ExamplePlugin.swift` - Main plugin implementation
- `Info.plist` - Plugin manifest template

### Using as a Template

1. Copy the `ExamplePlugin` folder to your project
2. Rename files and classes
3. Update `@objc(YourClassName)` to match your class name
4. Update `Info.plist` with your plugin's metadata
5. Update `NSPrincipalClass` to match your `@objc` name
6. Replace the transformation logic
7. Build as a bundle target with `.pasteshelfplugin` extension

## Building Examples

To build an example as a working plugin:

1. Create a new Xcode project (macOS > Bundle)
2. Add PasteShelfPluginKit as a dependency
3. Copy the example code into your project
4. Configure Info.plist
5. Build and export the `.pasteshelfplugin` bundle

## Installation

Copy the built `.pasteshelfplugin` bundle to:

```
~/Library/Application Support/PasteShelf/Plugins/
```

Or use PasteShelf's plugin installation UI.

## More Examples

See the built-in plugins in the main PasteShelf codebase for more complex examples:

- `JSONBeautifierPlugin` - JSON formatting without network
- `MarkdownFormatterPlugin` - HTML to Markdown conversion
- `URLShortenerPlugin` - Network API integration
- `GitHubGistPlugin` - OAuth and API integration
- `NotionPlugin` - Complex API integration with settings
