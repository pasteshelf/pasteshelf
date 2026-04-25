"""Shared helpers for working with Localizable.xcstrings.

The catalog JSON shape (simplified):

{
  "sourceLanguage": "en",
  "strings": {
    "<key>": {
      "comment": "...",               # optional
      "extractionState": "stale" | "manual" | absent,
      "shouldTranslate": true | false | absent,
      "localizations": {
        "<lang>": {
          "stringUnit": {             # single-form strings
            "state": "translated" | "new" | "needs_review",
            "value": "..."
          }
          # OR
          "variations": {             # plural-bearing strings
            "plural": {
              "one":   { "stringUnit": { ... } },
              "other": { "stringUnit": { ... } },
              ...
            }
          }
        }
      }
    }
  }
}
"""

from __future__ import annotations

import json
from pathlib import Path

CATALOG_PATH = Path(__file__).resolve().parent.parent.parent / "PasteShelf" / "Resources" / "Localizable.xcstrings"

SOURCE_LANG = "en"
TARGET_LANGS = ["de", "es", "fr", "ja", "ko", "pt", "ru", "tr", "zh-Hans", "zh-Hant"]
ALL_LANGS = [SOURCE_LANG] + TARGET_LANGS


def load_catalog(path: Path = CATALOG_PATH) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_catalog(data: dict, path: Path = CATALOG_PATH) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.write("\n")


def get_entry(catalog: dict, key: str) -> dict:
    return catalog["strings"].get(key, {})


def is_stale(entry: dict) -> bool:
    return entry.get("extractionState") == "stale"


def should_translate(entry: dict) -> bool:
    flag = entry.get("shouldTranslate")
    if flag is False:
        return False
    return True


def plural_forms(lang_entry: dict) -> dict | None:
    """Return the plural-form dict for a language entry, or None if non-plural."""
    variations = lang_entry.get("variations")
    if isinstance(variations, dict) and "plural" in variations:
        return variations["plural"]
    return None


def has_translated_value(lang_entry: dict) -> bool:
    """True iff the given language entry is fully translated (single or all plural forms)."""
    if not isinstance(lang_entry, dict):
        return False
    plurals = plural_forms(lang_entry)
    if plurals is not None:
        if not plurals:
            return False
        for form in plurals.values():
            su = form.get("stringUnit") if isinstance(form, dict) else None
            if not su:
                return False
            if su.get("state") != "translated":
                return False
            if not su.get("value"):
                return False
        return True
    su = lang_entry.get("stringUnit")
    if not isinstance(su, dict):
        return False
    if su.get("state") != "translated":
        return False
    if not su.get("value"):
        return False
    return True


def lang_state(lang_entry: dict) -> str:
    """Return a coarse state string for an entry: translated / new / needs_review / mixed / missing."""
    if not isinstance(lang_entry, dict):
        return "missing"
    plurals = plural_forms(lang_entry)
    if plurals is not None:
        states = set()
        for form in plurals.values():
            su = form.get("stringUnit") if isinstance(form, dict) else None
            states.add(su.get("state") if su else "missing")
        if states == {"translated"}:
            return "translated"
        if "new" in states:
            return "new"
        if "needs_review" in states:
            return "needs_review"
        return "mixed"
    su = lang_entry.get("stringUnit")
    if not isinstance(su, dict):
        return "missing"
    return su.get("state", "missing")


def source_value(key: str, entry: dict, source_lang: str = SOURCE_LANG) -> str:
    """Return the English source value. Falls back to the key itself if no override."""
    loc = entry.get("localizations", {}).get(source_lang, {})
    if isinstance(loc, dict):
        plurals = plural_forms(loc)
        if plurals is not None:
            forms = []
            for name, form in plurals.items():
                su = form.get("stringUnit", {}) if isinstance(form, dict) else {}
                v = su.get("value")
                if v:
                    forms.append(f"[{name}: {v}]")
            if forms:
                return " ".join(forms)
        su = loc.get("stringUnit")
        if isinstance(su, dict) and su.get("value"):
            return su["value"]
    return key
