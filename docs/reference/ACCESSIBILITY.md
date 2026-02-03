# Accessibility Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Accessibility implementation and best practices for PasteShelf.

---

## Table of Contents

- [Accessibility Commitment](#accessibility-commitment)
- [VoiceOver Support](#voiceover-support)
- [Keyboard Navigation](#keyboard-navigation)
- [Visual Accessibility](#visual-accessibility)
- [Motor Accessibility](#motor-accessibility)
- [Testing](#testing)

---

## Accessibility Commitment

### Principles

PasteShelf is committed to being accessible to all users:

1. **WCAG 2.1 AA Compliance**: Meet or exceed guidelines
2. **Native Integration**: Use Apple's accessibility APIs
3. **Inclusive Design**: Consider accessibility from the start
4. **Continuous Improvement**: Regular accessibility audits

### macOS Accessibility Features Supported

| Feature | Support |
|---------|---------|
| VoiceOver | ✅ Full |
| Keyboard Navigation | ✅ Full |
| Reduce Motion | ✅ Supported |
| Increase Contrast | ✅ Supported |
| Reduce Transparency | ✅ Supported |
| Switch Control | ✅ Compatible |
| Voice Control | ✅ Compatible |

---

## VoiceOver Support

### Basic Labels

```swift
// ✅ Provide clear accessibility labels
struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack {
            contentPreview
            Spacer()
            dateLabel
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to copy to clipboard")
    }

    private var accessibilityDescription: String {
        let type = item.contentType.localizedDescription
        let preview = item.preview.prefix(100)
        let date = item.createdDate.formatted(.relative(presentation: .named))
        return "\(type): \(preview). Copied \(date)"
    }
}
```

### Custom Actions

```swift
// ✅ Add custom accessibility actions
struct ClipboardRow: View {
    let item: ClipboardItem
    @Binding var selectedItem: ClipboardItem?

    var body: some View {
        rowContent
            .accessibilityAction(named: "Copy") {
                copyToClipboard(item)
            }
            .accessibilityAction(named: "Delete") {
                deleteItem(item)
            }
            .accessibilityAction(named: "Add to Favorites") {
                toggleFavorite(item)
            }
    }
}
```

### Rotor Support

```swift
// ✅ Support VoiceOver rotor navigation
struct ClipboardListView: View {
    let items: [ClipboardItem]

    var body: some View {
        List(items) { item in
            ClipboardRow(item: item)
        }
        .accessibilityRotor("Favorites") {
            ForEach(items.filter { $0.isFavorite }) { item in
                AccessibilityRotorEntry(item.preview, id: item.id)
            }
        }
        .accessibilityRotor("Images") {
            ForEach(items.filter { $0.contentType == .image }) { item in
                AccessibilityRotorEntry("Image from \(item.sourceApp)", id: item.id)
            }
        }
    }
}
```

### Announcements

```swift
// ✅ Announce important changes
class ClipboardViewModel: ObservableObject {
    func copyItem(_ item: ClipboardItem) {
        // Perform copy
        pasteboard.setString(item.content, forType: .string)

        // Announce to VoiceOver
        UIAccessibility.post(
            notification: .announcement,
            argument: "Copied to clipboard"
        )
    }

    func deleteItems(_ items: [ClipboardItem]) {
        // Perform delete
        storage.delete(items)

        // Announce result
        let message = items.count == 1
            ? "Item deleted"
            : "\(items.count) items deleted"
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
    }
}
```

### Images and Icons

```swift
// ✅ Describe meaningful images
Image(systemName: "star.fill")
    .accessibilityLabel("Favorite")

// ✅ Hide decorative images
Image("decorative-background")
    .accessibilityHidden(true)

// ✅ Describe content images
AsyncImage(url: item.thumbnailURL) { image in
    image
        .accessibilityLabel(item.imageDescription ?? "Clipboard image")
} placeholder: {
    ProgressView()
        .accessibilityLabel("Loading image")
}
```

---

## Keyboard Navigation

### Focus Management

```swift
// ✅ Proper focus handling
struct FloatingPanelView: View {
    @FocusState private var focusedField: Field?

    enum Field {
        case search
        case list
    }

    var body: some View {
        VStack {
            SearchField(text: $searchText)
                .focused($focusedField, equals: .search)

            ClipboardList(items: items)
                .focused($focusedField, equals: .list)
        }
        .onAppear {
            focusedField = .search // Focus search on open
        }
    }
}
```

### Keyboard Shortcuts

```swift
// ✅ Support standard keyboard shortcuts
struct ContentView: View {
    var body: some View {
        NavigationView {
            content
        }
        .keyboardShortcut("f", modifiers: .command) // ⌘F for search
        .keyboardShortcut(.delete, modifiers: .command) // ⌘⌫ for delete
    }
}

// ✅ Document keyboard shortcuts for users
struct ShortcutsHelpView: View {
    let shortcuts: [(String, String)] = [
        ("⌘⇧V", "Open PasteShelf panel"),
        ("⌘F", "Focus search"),
        ("⌘1-9", "Paste item 1-9"),
        ("↑↓", "Navigate items"),
        ("⏎", "Paste selected item"),
        ("⌘⌫", "Delete selected item"),
        ("⌘,", "Open preferences")
    ]

    var body: some View {
        List(shortcuts, id: \.0) { shortcut in
            HStack {
                Text(shortcut.0)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(shortcut.1)
            }
        }
    }
}
```

### Tab Navigation

```swift
// ✅ Logical tab order
struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .accessibilityIdentifier("launchAtLogin")

                Picker("History Limit", selection: $historyLimit) {
                    // options
                }
                .accessibilityIdentifier("historyLimit")
            }

            Section("Shortcuts") {
                HotkeyField(hotkey: $globalHotkey)
                    .accessibilityIdentifier("globalHotkey")
            }
        }
        // Tab order follows visual order automatically
    }
}
```

---

## Visual Accessibility

### Dynamic Type

```swift
// ✅ Support Dynamic Type
struct ClipboardRow: View {
    @ScaledMetric var iconSize: CGFloat = 24

    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .frame(width: iconSize, height: iconSize)

            Text(item.preview)
                .font(.body) // Scales with Dynamic Type
                .lineLimit(3)
        }
    }
}

// ✅ Test with largest accessibility sizes
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}
```

### Color and Contrast

```swift
// ✅ Use semantic colors that adapt
struct StatusBadge: View {
    let status: Status

    var body: some View {
        Text(status.label)
            .foregroundColor(status == .error ? .red : .primary)
            .background(
                Color(status == .error ? .systemRed : .secondarySystemBackground)
                    .opacity(0.2)
            )
    }
}

// ✅ Support high contrast mode
struct ThemedView: View {
    @Environment(\.accessibilityContrast) var contrast

    var body: some View {
        Rectangle()
            .stroke(
                contrast == .increased ? Color.primary : Color.secondary,
                lineWidth: contrast == .increased ? 2 : 1
            )
    }
}

// ✅ Don't rely on color alone
struct StatusIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isActive ? "Active" : "Inactive") // Text backup
        }
    }
}
```

### Reduce Motion

```swift
// ✅ Respect Reduce Motion setting
struct AnimatedView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ContentView()
            .opacity(isVisible ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.3),
                value: isVisible
            )
    }
}
```

### Reduce Transparency

```swift
// ✅ Respect Reduce Transparency
struct FloatingPanel: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    var body: some View {
        content
            .background(
                reduceTransparency
                    ? Color(.windowBackgroundColor)
                    : Color(.windowBackgroundColor).opacity(0.9)
            )
    }
}
```

---

## Motor Accessibility

### Large Touch Targets

```swift
// ✅ Ensure adequate tap target size (44x44 minimum)
struct ActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .frame(width: 44, height: 44)
        }
        .contentShape(Rectangle()) // Entire frame is tappable
    }
}
```

### Drag and Drop Alternatives

```swift
// ✅ Provide keyboard alternatives to drag actions
struct ReorderableList: View {
    @State var items: [ClipboardItem]

    var body: some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
                    // Drag and drop for mouse users
                    .draggable(item)
            }
            .onMove(perform: moveItems)
        }
        // Keyboard alternative: Edit mode with move actions
        .toolbar {
            EditButton()
        }
    }
}
```

### Switch Control Compatibility

```swift
// ✅ Group related elements
struct ClipboardRow: View {
    var body: some View {
        HStack {
            content
            actions
        }
        .accessibilityElement(children: .combine)
        // Switch Control users scan one element instead of many
    }
}
```

---

## Testing

### Accessibility Inspector

```bash
# Open Accessibility Inspector
# Xcode → Open Developer Tool → Accessibility Inspector

# Check:
# - Labels are descriptive
# - Hints provide guidance
# - Traits are correct
# - Actions are available
```

### VoiceOver Testing

```
# Enable VoiceOver
# System Settings → Accessibility → VoiceOver → Enable

# Test:
# 1. Navigate all elements with VO+Arrow keys
# 2. Verify labels make sense out of context
# 3. Test custom actions with VO+Shift+M
# 4. Check rotor options with VO+U
```

### Automated Testing

```swift
import XCTest

class AccessibilityTests: XCTestCase {

    func testClipboardRowAccessibility() {
        let item = ClipboardItem(content: "Test content")
        let row = ClipboardRow(item: item)

        // Verify accessibility label exists
        XCTAssertFalse(row.accessibilityLabel.isEmpty)

        // Verify hint exists
        XCTAssertFalse(row.accessibilityHint.isEmpty)
    }

    func testKeyboardNavigation() {
        let app = XCUIApplication()
        app.launch()

        // Tab through all interactive elements
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.searchFields.firstMatch.hasFocus)

        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.tables.firstMatch.hasFocus)
    }
}
```

### Accessibility Audit

```swift
// ✅ Run automated accessibility audit
func testAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()

    try app.performAccessibilityAudit()
}
```

---

## Accessibility Checklist

### VoiceOver

- [ ] All interactive elements have labels
- [ ] Labels are concise and descriptive
- [ ] Hints explain non-obvious actions
- [ ] Images have descriptions or are hidden
- [ ] Announcements for important changes
- [ ] Rotor support for large lists

### Keyboard

- [ ] All functions accessible via keyboard
- [ ] Logical tab order
- [ ] Focus indicators visible
- [ ] Shortcuts documented
- [ ] No keyboard traps

### Visual

- [ ] Supports Dynamic Type
- [ ] Minimum 4.5:1 contrast ratio
- [ ] Works without color
- [ ] Respects Reduce Motion
- [ ] Respects Reduce Transparency

### Motor

- [ ] 44x44pt minimum touch targets
- [ ] Alternatives to drag/drop
- [ ] No time-limited interactions
- [ ] Switch Control compatible

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Internationalization](INTERNATIONALIZATION.md) | Localized accessibility |
| [Testing](../testing/TESTING.md) | Accessibility testing |
| [Development Guide](../getting-started/DEVELOPMENT_GUIDE.md) | Implementation |

---

*Last updated: 2026-02-03*
