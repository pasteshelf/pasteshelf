#!/usr/bin/env python3
"""Add a list of new keys to Localizable.xcstrings if missing.

Keys are the English source strings introduced by Phase 2 code refactors
(LocalizedStringResource literals in enum displayNameKey properties, and
String(localized:) calls wrapping NSAlert/NSMenuItem strings).

Each new key is inserted as an empty entry `{}` — the translation pass will fill
in localizations. If a key already exists, it is left unchanged.
"""

from __future__ import annotations

from _catalog import load_catalog, save_catalog

NEW_KEYS = [
    # AppTheme.displayNameKey
    "System",
    "Light",
    "Dark",
    # PanelWidth.displayNameKey
    "Narrow",
    "Normal",
    "Wide",
    # HistoryLimit.displayNameKey
    "100 items",
    "500 items",
    "1,000 items",
    "Unlimited",
    # PreferencesTab.displayNameKey (only keys not already in catalog)
    "Search",
    "Sync",
    "Enterprise",
    # DeviceEnrollmentStatus.displayNameKey
    "Not Enrolled",
    "Enrolling...",
    "Enrolled",
    "Suspended",
    "Revoked",
    # PreferencesWindowController (NSTabViewController title, NSWindow title)
    "Preferences",
    # HotkeyRecorderView NSAlert
    "Shortcut Conflict",
    "This shortcut is reserved by the system. Please choose a different combination.",
    "OK",
    # URLSchemeHandler NSAlert
    "Invalid URL",
    "The URL '%@' is not a valid PasteShelf URL.",
    # MenuBarController NSMenuItem titles
    "No recent items",
    "Show PasteShelf",
    "Resume Monitoring",
    "Pause Monitoring",
    "Preferences...",
]


def main() -> int:
    cat = load_catalog()
    strings = cat.setdefault("strings", {})
    added = []
    existed = []
    for key in NEW_KEYS:
        if key in strings:
            existed.append(key)
        else:
            strings[key] = {}
            added.append(key)

    save_catalog(cat)
    print(f"Added {len(added)} new keys; {len(existed)} already existed.")
    for k in added:
        print(f"  + {k!r}")
    if existed:
        print("\nAlready in catalog:")
        for k in existed:
            print(f"  = {k!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
