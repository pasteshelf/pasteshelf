#!/usr/bin/env python3
"""Verify full parity: every translate-classified key has translated value in all target languages.

Exits 0 on success, 1 on any gap.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from _catalog import (
    TARGET_LANGS,
    has_translated_value,
    is_stale,
    load_catalog,
    should_translate,
)

CLASSIFICATION = Path(__file__).resolve().parent / "classification.json"


def main(argv: list[str] | None = None) -> int:
    if not CLASSIFICATION.exists():
        print("classification.json not found. Run classify_keys.py first.", file=sys.stderr)
        return 2
    with CLASSIFICATION.open("r", encoding="utf-8") as f:
        classification = json.load(f)

    translate_keys = classification.get("translate", [])
    cat = load_catalog()
    strings = cat.get("strings", {})

    gaps: dict[str, list[str]] = {lang: [] for lang in TARGET_LANGS}
    skipped_keys = 0

    for key in translate_keys:
        entry = strings.get(key)
        if entry is None:
            skipped_keys += 1
            continue
        if is_stale(entry) or not should_translate(entry):
            skipped_keys += 1
            continue
        locs = entry.get("localizations") or {}
        for lang in TARGET_LANGS:
            lang_entry = locs.get(lang)
            if not lang_entry or not has_translated_value(lang_entry):
                gaps[lang].append(key)

    total_translatable = len(translate_keys) - skipped_keys
    print(f"Verifying {total_translatable} translate-classified keys against {len(TARGET_LANGS)} target languages.")
    print()

    any_gap = False
    for lang in TARGET_LANGS:
        missing = gaps[lang]
        state = "OK" if not missing else "GAP"
        print(f"  {lang:<9} {state}  missing={len(missing)}")
        if missing and len(missing) <= 30:
            for k in missing:
                print(f"      - {k!r}")
        if missing:
            any_gap = True

    if any_gap:
        print("\nFAIL: parity incomplete.")
        return 1
    print("\nPASS: all target languages fully translated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
