# PasteShelf App Store Screenshots

This directory contains App Store screenshots for PasteShelf.

## Screenshot Specifications

| Property | Value |
|----------|-------|
| Resolution | 2880 x 1800 px (Retina MacBook Pro 16:10) |
| Format | PNG (no alpha channel) |
| Color Space | sRGB |
| Count | 5 screenshots per locale |

## Screenshot Set

| # | Name | Description | File |
|---|------|-------------|------|
| 1 | Floating Panel Overview | Main panel with 8-10 items, mixed types | `PasteShelf_Screenshot_1_FloatingPanel_[locale].png` |
| 2 | Search in Action | Active search with filtered results | `PasteShelf_Screenshot_2_Search_[locale].png` |
| 3 | Preferences - Privacy | Privacy tab with excluded apps | `PasteShelf_Screenshot_3_Privacy_[locale].png` |
| 4 | Menu Bar Integration | Dropdown with recent items | `PasteShelf_Screenshot_4_MenuBar_[locale].png` |
| 5 | Keyboard Shortcuts | Shortcuts configuration | `PasteShelf_Screenshot_5_Shortcuts_[locale].png` |

## Generating Screenshots

### Automated Generation

Run the extraction script:

```bash
# English (default)
./scripts/extract-screenshots.sh

# Other locales
./scripts/extract-screenshots.sh de        # German
./scripts/extract-screenshots.sh ja        # Japanese
./scripts/extract-screenshots.sh zh-Hans   # Chinese (Simplified)

# Dark mode
./scripts/extract-screenshots.sh en dark
```

### Manual Generation

1. Build and run PasteShelf
2. Set up sample data (copy various items to clipboard)
3. Use macOS Screenshot (Cmd+Shift+4, then Space to capture window)
4. Save to appropriate locale directory

### Running Tests Directly

```bash
xcodebuild test \
    -scheme PasteShelf \
    -destination 'platform=macOS' \
    -only-testing:PasteShelfUITests/ScreenshotUITests
```

## Directory Structure

```
screenshots/
├── README.md           # This file
├── en/                 # English screenshots
│   ├── PasteShelf_Screenshot_1_FloatingPanel_en.png
│   ├── PasteShelf_Screenshot_2_Search_en.png
│   ├── PasteShelf_Screenshot_3_Privacy_en.png
│   ├── PasteShelf_Screenshot_4_MenuBar_en.png
│   └── PasteShelf_Screenshot_5_Shortcuts_en.png
├── de/                 # German screenshots
├── ja/                 # Japanese screenshots
└── zh-Hans/            # Chinese (Simplified) screenshots
```

## Notes

- Screenshot 4 (Menu Bar) may require manual capture due to NSStatusItem limitations in UI tests
- The app should be launched with `--screenshot-mode` to populate realistic sample data
- Screenshots are excluded from git (see `.gitignore`)
- For final App Store submission, review screenshots against `docs/appstore/SCREENSHOTS.md`

## Localization

Supported locales for App Store:
- `en` - English (Required)
- `de` - German
- `fr` - French
- `es` - Spanish
- `ja` - Japanese
- `zh-Hans` - Chinese (Simplified)
- `zh-Hant` - Chinese (Traditional)
- `ko` - Korean
- `ru` - Russian
- `pt` - Portuguese

## Submission Checklist

- [ ] All 5 screenshots captured at correct resolution
- [ ] No personal or sensitive data visible
- [ ] Text is readable at thumbnail size
- [ ] Consistent visual style across set
- [ ] Files named correctly per convention
- [ ] PNG format, no transparency
