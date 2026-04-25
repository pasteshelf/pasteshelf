#!/usr/bin/env python3
"""Audit Localizable.xcstrings: per-language coverage and overall health."""

from __future__ import annotations

import argparse
import sys
from collections import Counter

from _catalog import (
    ALL_LANGS,
    SOURCE_LANG,
    TARGET_LANGS,
    has_translated_value,
    is_stale,
    lang_state,
    load_catalog,
    plural_forms,
    should_translate,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true", help="Print per-key detail")
    args = parser.parse_args(argv)

    cat = load_catalog()
    strings = cat.get("strings", {})
    total = len(strings)

    stale = sum(1 for e in strings.values() if is_stale(e))
    manual = sum(1 for e in strings.values() if e.get("extractionState") == "manual")
    no_localizations = sum(1 for e in strings.values() if not e.get("localizations"))
    do_not_translate = sum(1 for e in strings.values() if not should_translate(e))

    has_plural = 0
    for e in strings.values():
        for lang_entry in (e.get("localizations") or {}).values():
            if plural_forms(lang_entry):
                has_plural += 1
                break

    print("=" * 70)
    print(f"Catalog: {total} keys  |  source={cat.get('sourceLanguage')!r}")
    print(f"  stale extraction   : {stale}")
    print(f"  manual extraction  : {manual}")
    print(f"  no localizations   : {no_localizations}  (falls back to English for all locales)")
    print(f"  shouldTranslate=false: {do_not_translate}")
    print(f"  has plural variations: {has_plural}")
    print()

    # Per-language coverage
    header = f"{'lang':<9}  {'present':>7}  {'translated':>10}  {'new':>4}  {'needs_review':>12}  {'fully_translated':>16}"
    print(header)
    print("-" * len(header))
    for lang in ALL_LANGS:
        counts = Counter()
        fully = 0
        for e in strings.values():
            loc = (e.get("localizations") or {}).get(lang)
            if not loc:
                counts["missing"] += 1
                continue
            counts["present"] += 1
            state = lang_state(loc)
            counts[state] += 1
            if has_translated_value(loc):
                fully += 1
        print(
            f"{lang:<9}  {counts['present']:>7}  {counts['translated']:>10}  {counts['new']:>4}  {counts['needs_review']:>12}  {fully:>16}"
        )
    print()

    # Translatable vs untranslatable
    translatable_keys = [k for k, e in strings.items() if should_translate(e) and not is_stale(e)]
    print(f"Translatable (non-stale, shouldTranslate!=false) keys: {len(translatable_keys)}")
    print()

    # Per-lang coverage within translatable set
    header2 = f"{'lang':<9}  {'fully_translated':>16}  {'missing':>8}  {'deficit':>8}"
    print(header2)
    print("-" * len(header2))
    for lang in TARGET_LANGS:
        fully = 0
        for key in translatable_keys:
            loc = (strings[key].get("localizations") or {}).get(lang)
            if loc and has_translated_value(loc):
                fully += 1
        missing = len(translatable_keys) - fully
        print(f"{lang:<9}  {fully:>16}  {missing:>8}  {missing:>8}")
    print()

    if args.verbose:
        print("Keys with no localizations block:")
        for k, e in sorted(strings.items()):
            if not e.get("localizations"):
                print(f"  - {k!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
