# Automation Engine

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Documentation for PasteShelf's automation and workflow capabilities.

---

## Table of Contents

- [Overview](#overview)
- [Rule Engine](#rule-engine)
- [Actions](#actions)
- [Shortcuts Integration](#shortcuts-integration)
- [AppleScript Support](#applescript-support)
- [Webhooks](#webhooks)
- [Examples](#examples)

---

## Overview

The Automation Engine enables powerful clipboard workflows.

| Feature | Description |
|---------|-------------|
| Basic Actions | Copy, paste, delete |
| Custom Actions | JavaScript transformations |
| Auto-Rules | Trigger-based automation |
| Shortcuts | Shortcuts.app integration |
| AppleScript | Script automation |
| Webhooks | External integrations |

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Automation Architecture                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                        Triggers                                  │   │
│   │                                                                  │   │
│   │   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌────────────┐  │   │
│   │   │ Clipboard │  │  Manual   │  │ Schedule  │  │  External  │  │   │
│   │   │  Capture  │  │  Invoke   │  │  (Cron)   │  │  (Webhook) │  │   │
│   │   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └──────┬─────┘  │   │
│   │         │              │              │               │         │   │
│   │         └──────────────┴──────┬───────┴───────────────┘         │   │
│   └───────────────────────────────┼──────────────────────────────────┘   │
│                                   │                                      │
│   ┌───────────────────────────────▼──────────────────────────────────┐   │
│   │                       Rule Engine                                 │   │
│   │                                                                   │   │
│   │   Conditions:                                                     │   │
│   │   • Content type matches                                          │   │
│   │   • Source app is                                                 │   │
│   │   • Content contains                                              │   │
│   │   • Time range is                                                 │   │
│   │                                                                   │   │
│   │   Operators: AND, OR, NOT                                         │   │
│   └───────────────────────────────┬───────────────────────────────────┘   │
│                                   │                                      │
│   ┌───────────────────────────────▼──────────────────────────────────┐   │
│   │                       Action Executor                             │   │
│   │                                                                   │   │
│   │   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌────────────┐   │   │
│   │   │ Transform │  │   Paste   │  │   Move    │  │   Notify   │   │   │
│   │   │  Content  │  │   Auto    │  │ to Folder │  │   User     │   │   │
│   │   └───────────┘  └───────────┘  └───────────┘  └────────────┘   │   │
│   │                                                                   │   │
│   │   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌────────────┐   │   │
│   │   │  Add Tag  │  │  Run      │  │  Open     │  │   HTTP     │   │   │
│   │   │           │  │  Script   │  │   URL     │  │   Request  │   │   │
│   │   └───────────┘  └───────────┘  └───────────┘  └────────────┘   │   │
│   └───────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Rule Engine

### Rule Structure

```swift
struct AutomationRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var trigger: Trigger
    var conditions: [Condition]
    var conditionOperator: ConditionOperator
    var actions: [Action]

    enum Trigger: Codable {
        case onCapture              // When clipboard item captured
        case onPaste                // Before paste action
        case manual                 // User-triggered
        case schedule(CronExpression)  // Time-based
    }

    enum ConditionOperator: String, Codable {
        case and = "AND"
        case or = "OR"
    }
}

struct Condition: Codable {
    let field: ConditionField
    let `operator`: ConditionOperator
    let value: String

    enum ConditionField: String, Codable {
        case contentType
        case sourceApp
        case textContent
        case textLength
        case hasImage
        case isSensitive
        case createdTime
    }

    enum ConditionOperator: String, Codable {
        case equals = "=="
        case notEquals = "!="
        case contains
        case notContains
        case matches  // regex
        case greaterThan = ">"
        case lessThan = "<"
    }
}
```

### Creating Rules

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Rule Builder UI                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Rule Name: [Format Phone Numbers                    ]                   │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  WHEN (Trigger)                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  ● Clipboard item captured                                       │    │
│  │  ○ Before paste                                                  │    │
│  │  ○ Manually triggered                                            │    │
│  │  ○ On schedule                                                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  IF (Conditions)                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  [Content type] [is] [Text                    ] [×]              │    │
│  │  [AND ▼]                                                         │    │
│  │  [Text content] [matches] [\d{10}             ] [×]              │    │
│  │                                                                  │    │
│  │  [+ Add Condition]                                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  THEN (Actions)                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  1. [Transform] → Run JavaScript: formatPhone.js    [×]          │    │
│  │  2. [Add Tag] → "phone"                             [×]          │    │
│  │                                                                  │    │
│  │  [+ Add Action]                                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ☑ Rule enabled                                                         │
│                                                                          │
│  [Cancel]                                            [Save Rule]        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Actions

### Built-in Actions

| Action | Description | Parameters |
|--------|-------------|------------|
| Transform | Modify content | Script or preset |
| Add Tag | Tag the item | Tag name |
| Move to Folder | Organize item | Folder name |
| Mark Favorite | Star the item | - |
| Mark Sensitive | Flag as sensitive | - |
| Notify | Show notification | Title, message |
| Copy to Clipboard | Re-copy modified | - |
| Open URL | Launch URL | URL template |
| Run Script | Execute AppleScript | Script path |
| HTTP Request | Call webhook | URL, method, body |

### Transform Presets

```swift
enum TransformPreset: String, CaseIterable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case trimWhitespace = "Trim Whitespace"
    case removeNewlines = "Remove Newlines"
    case sortLines = "Sort Lines"
    case uniqueLines = "Unique Lines"
    case reverseLines = "Reverse Lines"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case urlEncode = "URL Encode"
    case urlDecode = "URL Decode"
    case formatJSON = "Format JSON"
    case minifyJSON = "Minify JSON"
    case escapeHTML = "Escape HTML"
    case unescapeHTML = "Unescape HTML"
    case md5Hash = "MD5 Hash"
    case sha256Hash = "SHA-256 Hash"

    func transform(_ input: String) -> String {
        switch self {
        case .uppercase:
            return input.uppercased()
        case .lowercase:
            return input.lowercased()
        case .titleCase:
            return input.capitalized
        case .trimWhitespace:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        // ... other implementations
        }
    }
}
```

### Custom JavaScript Actions

```javascript
// Format phone number action
(function() {
    return {
        name: "Format Phone Number",
        description: "Format US phone numbers consistently",

        transform: function(content) {
            const text = content.text;

            // Match various phone formats
            const phoneRegex = /(\d{3})[-.\s]?(\d{3})[-.\s]?(\d{4})/g;

            const formatted = text.replace(phoneRegex, '($1) $2-$3');

            return { text: formatted };
        }
    };
})();
```

---

## Shortcuts Integration

### App Intents

```swift
import AppIntents

// Search clipboard
struct SearchClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Clipboard"
    static var description = IntentDescription("Search your clipboard history")

    @Parameter(title: "Query")
    var query: String

    @Parameter(title: "Limit", default: 10)
    var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[ClipboardItemEntity]> {
        let items = try await ClipboardManager.shared.search(query, limit: limit)
        return .result(value: items.map { ClipboardItemEntity($0) })
    }
}

// Paste specific item
struct PasteItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Paste Clipboard Item"

    @Parameter(title: "Item")
    var item: ClipboardItemEntity

    func perform() async throws -> some IntentResult {
        try await ClipboardManager.shared.paste(item.id)
        return .result()
    }
}

// Transform content
struct TransformContentIntent: AppIntent {
    static var title: LocalizedStringResource = "Transform Content"

    @Parameter(title: "Content")
    var content: String

    @Parameter(title: "Transformation")
    var transformation: TransformationType

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = transformation.transform(content)
        return .result(value: result)
    }
}
```

### Shortcuts Examples

#### Smart Paste Shortcut

```
┌─────────────────────────────────────────────────────────────┐
│  Shortcut: Smart Paste                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Get Clipboard                                            │
│     └── Output: Current clipboard content                    │
│                                                              │
│  2. If [Clipboard] contains "@"                              │
│     └── Transform Content                                    │
│         ├── Content: [Clipboard]                             │
│         └── Transformation: Lowercase                        │
│                                                              │
│  3. Else If [Clipboard] matches "^\d+$"                     │
│     └── Transform Content                                    │
│         ├── Content: [Clipboard]                             │
│         └── Transformation: Format Number                    │
│                                                              │
│  4. Paste to Active App                                      │
│     └── [Transformed Content]                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## AppleScript Support

### AppleScript Dictionary

```applescript
-- PasteShelf AppleScript Dictionary

tell application "PasteShelf"
    -- Properties
    clipboard history     -- list of clipboard items (read-only)
    current item         -- most recent clipboard item
    is monitoring        -- boolean, clipboard monitoring status

    -- Commands
    search for text      -- search clipboard history
    paste item           -- paste a specific item
    delete item          -- remove item from history
    transform item       -- apply transformation
    run automation       -- trigger automation rule
end tell
```

### Examples

#### Search and Paste

```applescript
tell application "PasteShelf"
    -- Search for items containing "meeting"
    set searchResults to search for "meeting" with limit 5

    if (count of searchResults) > 0 then
        -- Get the first result
        set firstResult to item 1 of searchResults

        -- Paste it
        paste item firstResult
    else
        display notification "No results found" with title "PasteShelf"
    end if
end tell
```

#### Process All Text Items

```applescript
tell application "PasteShelf"
    -- Get all text items from last 24 hours
    set textItems to clipboard history whose content type is "text"

    repeat with anItem in textItems
        -- Transform to uppercase
        set transformedItem to transform item anItem using "uppercase"

        -- Log the result
        log "Transformed: " & (text content of transformedItem)
    end repeat
end tell
```

#### Automation with System Events

```applescript
-- Watch for specific content and take action
on idle
    tell application "PasteShelf"
        set latestItem to current item

        if text content of latestItem contains "TODO:" then
            -- Add to Reminders
            tell application "Reminders"
                set todoText to text content of latestItem
                make new reminder with properties {name:todoText}
            end tell

            -- Notify user
            display notification "Added to Reminders" with title "PasteShelf"
        end if
    end tell

    return 5 -- Check every 5 seconds
end idle
```

---

## Webhooks

### Configuration

```
┌─────────────────────────────────────────────────────────────┐
│                    Webhook Configuration                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Admin Console → Integrations → Webhooks                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Webhook Name: [Slack Notification              ]    │    │
│  │                                                      │    │
│  │  URL: [https://hooks.slack.com/services/xxx     ]    │    │
│  │                                                      │    │
│  │  Events:                                             │    │
│  │  ☑ clipboard.created                                │    │
│  │  ☐ clipboard.deleted                                │    │
│  │  ☐ clipboard.synced                                 │    │
│  │                                                      │    │
│  │  Filters:                                            │    │
│  │  • Content type: [Text only        ▼]               │    │
│  │  • Source apps:  [Safari, Chrome   ▼]               │    │
│  │  • Must contain: [project|meeting  ]                │    │
│  │                                                      │    │
│  │  Headers:                                            │    │
│  │  Content-Type: application/json                      │    │
│  │                                                      │    │
│  │  Secret: [••••••••••••] [Regenerate]                │    │
│  │                                                      │    │
│  │  ☑ Enabled                                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Webhook Payload

```json
{
    "event": "clipboard.created",
    "timestamp": "2026-02-03T12:00:00Z",
    "signature": "sha256=abc123...",
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "contentType": "public.plain-text",
        "preview": "Meeting notes from...",
        "sourceApp": {
            "bundleId": "com.apple.Safari",
            "name": "Safari"
        },
        "metadata": {
            "characterCount": 1234,
            "wordCount": 200
        }
    },
    "user": {
        "id": "user_123",
        "email": "user@company.com"
    }
}
```

---

## Examples

### Auto-Organize Downloads

```swift
// Rule: Auto-organize by content type
let organizeRule = AutomationRule(
    name: "Organize by Type",
    trigger: .onCapture,
    conditions: [],
    actions: [
        .moveToFolder(folder: "{contentType}") // Dynamic folder
    ]
)
```

### Clean Up URLs

```javascript
// Action: Clean tracking parameters from URLs
(function() {
    return {
        name: "Clean URL",
        transform: function(content) {
            try {
                const url = new URL(content.text);

                // Remove tracking params
                const trackingParams = [
                    'utm_source', 'utm_medium', 'utm_campaign',
                    'fbclid', 'gclid', 'ref', 'source'
                ];

                trackingParams.forEach(param => {
                    url.searchParams.delete(param);
                });

                return { text: url.toString() };
            } catch {
                return content; // Not a URL, return unchanged
            }
        }
    };
})();
```

### Slack Integration

```swift
// Rule: Notify Slack for important items
let slackRule = AutomationRule(
    name: "Notify Slack",
    trigger: .onCapture,
    conditions: [
        Condition(field: .textContent, operator: .contains, value: "URGENT")
    ],
    actions: [
        .httpRequest(
            url: "https://hooks.slack.com/services/xxx",
            method: .post,
            body: """
            {
                "text": "Urgent content copied: {{preview}}"
            }
            """
        )
    ]
)
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [API Documentation](../api/API_DOCUMENTATION.md) | Full API reference |
| [Plugin System](PLUGIN_SYSTEM.md) | Plugin development |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Webhook setup |

---

*Last updated: 2026-02-03*
