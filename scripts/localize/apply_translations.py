#!/usr/bin/env python3
"""Apply translations from one or more Python modules to Localizable.xcstrings.

Each input module must define a module-level `TRANSLATIONS` dict:
    TRANSLATIONS = {
        "English Source Key": {
            "de": "...", "es": "...", "fr": "...", "ja": "...", "ko": "...",
            "pt": "...", "ru": "...", "tr": "...", "zh-Hans": "...", "zh-Hant": "...",
        },
        ...
    }

Empty values (`""` or `None`) are SKIPPED (existing catalog value left intact).
For every non-empty value, the catalog is updated with state=translated.

Usage:
    python3 apply_translations.py translations/*.py
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from _catalog import (
    CATALOG_PATH,
    TARGET_LANGS,
    load_catalog,
    save_catalog,
)


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def apply_module_to_catalog(module, catalog) -> tuple[int, int, list[str]]:
    """Return (keys_touched, cells_written, warnings)."""
    warnings: list[str] = []
    keys_touched = 0
    cells_written = 0

    translations = getattr(module, "TRANSLATIONS", None)
    if not isinstance(translations, dict):
        return 0, 0, [f"{module.__name__}: no TRANSLATIONS dict"]

    for key, lang_map in translations.items():
        entry = catalog["strings"].get(key)
        if entry is None:
            warnings.append(f"{module.__name__}: key {key!r} not in catalog")
            continue
        keys_touched += 1
        locs = entry.setdefault("localizations", {})
        for lang, value in lang_map.items():
            if lang not in TARGET_LANGS:
                warnings.append(f"{module.__name__}: unknown lang {lang!r} for key {key!r}")
                continue
            if not value:
                continue
            loc = locs.setdefault(lang, {})
            loc.pop("variations", None)
            loc["stringUnit"] = {"state": "translated", "value": value}
            cells_written += 1

    return keys_touched, cells_written, warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    catalog = load_catalog()
    total_keys = 0
    total_cells = 0
    all_warnings: list[str] = []

    for path in args.files:
        if not path.exists():
            print(f"SKIP (not found): {path}")
            continue
        module = load_module(path)
        keys, cells, warnings = apply_module_to_catalog(module, catalog)
        total_keys += keys
        total_cells += cells
        all_warnings.extend(warnings)
        print(f"{path.name}: keys_touched={keys} cells_written={cells}")

    if all_warnings:
        print("\nWarnings:")
        for w in all_warnings[:50]:
            print(f"  - {w}")
        if len(all_warnings) > 50:
            print(f"  ... and {len(all_warnings) - 50} more")

    if args.dry_run:
        print(f"\n[dry-run] Would update {total_cells} cells across {total_keys} keys")
        return 0

    save_catalog(catalog)
    print(f"\nWrote {total_cells} cells across {total_keys} keys to {CATALOG_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
