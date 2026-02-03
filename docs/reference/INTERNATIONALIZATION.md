# Internationalization (i18n) Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Localization strategy and implementation for PasteShelf.

---

## Table of Contents

- [Overview](#overview)
- [String Catalogs](#string-catalogs)
- [Implementation](#implementation)
- [Best Practices](#best-practices)
- [Testing](#testing)
- [Supported Languages](#supported-languages)

---

## Overview

### Localization Strategy

PasteShelf uses Apple's modern localization system:

1. **String Catalogs** (.xcstrings): Primary localization format
2. **Automatic extraction**: Xcode extracts localizable strings
3. **Pluralization**: Built-in plural rules
4. **Format strings**: Type-safe formatting

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Localization Flow                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Source Code          String Catalog         Runtime        │
│   ───────────          ──────────────         ───────        │
│                                                              │
│   String(localized:)   Localizable.xcstrings  NSLocalizedString│
│         │                    │                      │        │
│         └─────► Extract ─────┘                      │        │
│                      │                              │        │
│                      ▼                              │        │
│              Translation                            │        │
│                      │                              │        │
│                      └──────────► Load ────────────►│        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## String Catalogs

### File Structure

```
PasteShelf/
├── Localizable.xcstrings       # Main strings
├── InfoPlist.xcstrings         # App metadata
└── Intents.xcstrings           # Shortcuts strings
```

### String Catalog Format

```json
{
  "sourceLanguage": "en",
  "strings": {
    "clipboard.empty": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "No clipboard items"
          }
        },
        "de": {
          "stringUnit": {
            "state": "translated",
            "value": "Keine Zwischenablage-Elemente"
          }
        },
        "ja": {
          "stringUnit": {
            "state": "translated",
            "value": "クリップボードアイテムがありません"
          }
        }
      }
    },
    "items.count": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "variations": {
            "plural": {
              "one": {
                "stringUnit": {
                  "state": "translated",
                  "value": "%lld item"
                }
              },
              "other": {
                "stringUnit": {
                  "state": "translated",
                  "value": "%lld items"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## Implementation

### Basic Strings

```swift
// ✅ Use String(localized:) for SwiftUI
struct EmptyStateView: View {
    var body: some View {
        Text("clipboard.empty", comment: "Shown when clipboard history is empty")
    }
}

// ✅ Or explicit localized initializer
Text(String(localized: "clipboard.empty"))
```

### String Interpolation

```swift
// ✅ Use string interpolation with localized strings
let appName = "PasteShelf"
Text("Welcome to \(appName)")

// In String Catalog:
// "Welcome to %@" -> "Willkommen bei %@" (German)
```

### Pluralization

```swift
// ✅ Automatic pluralization
struct ItemCountView: View {
    let count: Int

    var body: some View {
        Text("items.count \(count)", comment: "Number of clipboard items")
    }
}

// String Catalog handles plural forms:
// English: "1 item" / "5 items"
// Russian: "1 элемент" / "2 элемента" / "5 элементов"
// Arabic: Different forms for 0, 1, 2, few, many, other
```

### Formatted Values

```swift
// ✅ Use formatters for dates, numbers, etc.
struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        VStack {
            Text(item.content)
            Text(item.createdDate, format: .relative(presentation: .named))
                .foregroundColor(.secondary)
        }
    }
}

// Output adapts to locale:
// English: "5 minutes ago"
// German: "vor 5 Minuten"
// Japanese: "5分前"
```

### Attributed Strings

```swift
// ✅ Localized attributed strings
var attributedMessage: AttributedString {
    var result = AttributedString(localized: "Copied **\(itemName)** to clipboard")
    // Markdown formatting preserved across translations
    return result
}
```

---

## Best Practices

### String Keys

```swift
// ✅ Good: Descriptive, namespaced keys
"clipboard.empty"
"search.placeholder"
"settings.general.title"
"error.sync.failed"

// ❌ Bad: Ambiguous keys
"empty"
"title"
"error"
```

### Comments

```swift
// ✅ Always provide context for translators
Text("Delete", comment: "Button to delete a clipboard item")
Text("Delete", comment: "Menu item to delete selected items")

// These might be translated differently in some languages
```

### Avoid Concatenation

```swift
// ❌ Bad: Concatenation breaks translation
let message = String(localized: "Copied") + " " + itemName

// ✅ Good: Single string with placeholder
let message = String(localized: "Copied \(itemName)")
```

### Handle Text Length

```swift
// ✅ Use flexible layouts
struct ButtonView: View {
    var body: some View {
        Button(action: {}) {
            Text("settings.clear_history")
        }
        .fixedSize(horizontal: false, vertical: true) // Allow wrapping
    }
}

// German text is often 30% longer than English
// "Clear History" -> "Verlauf löschen"
```

### Right-to-Left Support

```swift
// ✅ Use semantic layout directions
HStack {
    Image(systemName: "doc.on.clipboard")
    Text(item.content)
    Spacer()
    Text(item.date, format: .dateTime)
}
// Automatically mirrors for RTL languages (Arabic, Hebrew)

// ✅ Use .leading/.trailing instead of .left/.right
.padding(.leading, 16)

// ✅ Check layout direction if needed
@Environment(\.layoutDirection) var layoutDirection
```

---

## Testing

### Preview Localization

```swift
// ✅ Preview in different locales
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.locale, Locale(identifier: "en"))
            .previewDisplayName("English")

        ContentView()
            .environment(\.locale, Locale(identifier: "de"))
            .previewDisplayName("German")

        ContentView()
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("Arabic (RTL)")
    }
}
```

### Pseudo-Localization

```swift
// Enable in scheme:
// Edit Scheme → Run → Options → App Language → "Accented Pseudolanguage"

// Transforms "Hello" → "[Ĥéļļö]"
// Helps identify:
// - Hardcoded strings
// - Truncation issues
// - Layout problems
```

### UI Testing

```swift
func testLocalizedUI() {
    let app = XCUIApplication()
    app.launchArguments += ["-AppleLanguages", "(de)"]
    app.launchArguments += ["-AppleLocale", "de_DE"]
    app.launch()

    // Verify German strings appear
    XCTAssertTrue(app.buttons["Einstellungen"].exists)
}
```

### Export for Translation

```bash
# Export localizable strings
xcodebuild -exportLocalizations \
    -project PasteShelf.xcodeproj \
    -localizationPath ./Localizations \
    -exportLanguage de \
    -exportLanguage ja

# Import translations
xcodebuild -importLocalizations \
    -project PasteShelf.xcodeproj \
    -localizationPath ./Localizations/de.xcloc
```

---

## Supported Languages

### Launch Languages

| Language | Code | Status |
|----------|------|--------|
| English | en | ✅ Complete |
| German | de | 🚧 In Progress |
| French | fr | 📋 Planned |
| Spanish | es | 📋 Planned |
| Japanese | ja | 📋 Planned |
| Chinese (Simplified) | zh-Hans | 📋 Planned |
| Chinese (Traditional) | zh-Hant | 📋 Planned |
| Korean | ko | 📋 Planned |
| Portuguese (Brazil) | pt-BR | 📋 Planned |
| Russian | ru | 📋 Planned |

### Contribution

Community translations welcome! See [Contributing](../contributing/CONTRIBUTING.md) for guidelines.

### Translation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                   Translation Process                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   1. Export strings    xcodebuild -exportLocalizations      │
│   2. Translate         Using Xcode or external tools        │
│   3. Review            Native speaker review                │
│   4. Import            xcodebuild -importLocalizations      │
│   5. Test              Run app in target locale             │
│   6. Release           Include in next version              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Localization Checklist

### Development

- [ ] All user-visible strings use String(localized:)
- [ ] Comments provided for context
- [ ] No hardcoded strings
- [ ] Flexible layouts accommodate text expansion
- [ ] RTL layouts tested

### Translation

- [ ] Strings exported for translators
- [ ] Context/comments provided
- [ ] Pluralization rules defined
- [ ] Screenshots for context

### Testing

- [ ] All languages previewed
- [ ] Pseudo-localization tested
- [ ] RTL layout verified
- [ ] Date/number formatting checked

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Accessibility](ACCESSIBILITY.md) | VoiceOver localization |
| [Development Guide](../getting-started/DEVELOPMENT_GUIDE.md) | Setup |
| [Contributing](../contributing/CONTRIBUTING.md) | Translation guidelines |

---

*Last updated: 2026-02-03*
