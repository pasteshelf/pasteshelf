#!/usr/bin/env python3
"""Merge a filled TSV batch back into Localizable.xcstrings.

Expected TSV format (from emit_batch.py):
  key\tform\ten\tde\tes\tfr\tja\tko\tpt\tru\ttr\tzh-Hans\tzh-Hant

Where `form` is `single` or `plural:<one|few|many|other|zero|two>`.

Any non-empty cell in a target-lang column is merged into the catalog with
state="translated". Empty cells are left as-is (existing values in the catalog
are NOT overwritten unless the new value is non-empty).

Usage:
  python3 merge_batch.py batch_001.tsv [batch_002.tsv ...]
  python3 merge_batch.py batches/*.tsv
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from _catalog import (
    CATALOG_PATH,
    SOURCE_LANG,
    TARGET_LANGS,
    load_catalog,
    save_catalog,
)

HEADER = ["key", "form", "en"] + TARGET_LANGS


def _unescape(value: str) -> str:
    return value.replace("\\n", "\n")


def _set_single(entry: dict, lang: str, value: str) -> None:
    entry.setdefault("localizations", {}).setdefault(lang, {})
    loc = entry["localizations"][lang]
    # Drop any variations if we're writing a single.
    loc.pop("variations", None)
    loc["stringUnit"] = {"state": "translated", "value": value}


def _set_plural(entry: dict, lang: str, form: str, value: str) -> None:
    entry.setdefault("localizations", {}).setdefault(lang, {})
    loc = entry["localizations"][lang]
    loc.pop("stringUnit", None)
    loc.setdefault("variations", {}).setdefault("plural", {})
    loc["variations"]["plural"][form] = {
        "stringUnit": {"state": "translated", "value": value}
    }


def merge_file(catalog: dict, path: Path) -> tuple[int, int, list[str]]:
    """Return (rows_seen, cells_applied, warnings)."""
    warnings: list[str] = []
    rows_seen = 0
    cells_applied = 0

    with path.open("r", encoding="utf-8") as f:
        header_line = f.readline().rstrip("\n").split("\t")
        if header_line != HEADER:
            warnings.append(
                f"{path.name}: header mismatch. Got {header_line!r}, expected {HEADER!r}"
            )
            return rows_seen, cells_applied, warnings

        for lineno, line in enumerate(f, start=2):
            line = line.rstrip("\n")
            if not line:
                continue
            cells = line.split("\t")
            if len(cells) != len(HEADER):
                warnings.append(f"{path.name}:{lineno}: wrong column count ({len(cells)})")
                continue
            rows_seen += 1
            key = cells[0]
            form = cells[1]
            # cells[2] is 'en' source — we don't overwrite the source, just use it for validation.
            target_values = cells[3:]

            entry = catalog["strings"].get(key)
            if entry is None:
                warnings.append(f"{path.name}:{lineno}: key {key!r} not in catalog; skipped")
                continue

            for lang, raw in zip(TARGET_LANGS, target_values):
                if not raw:
                    continue  # leave existing value alone
                value = _unescape(raw)
                if form == "single":
                    _set_single(entry, lang, value)
                elif form.startswith("plural:"):
                    plural_form = form.split(":", 1)[1]
                    _set_plural(entry, lang, plural_form, value)
                else:
                    warnings.append(f"{path.name}:{lineno}: unknown form {form!r}; skipped lang={lang}")
                    continue
                cells_applied += 1

    return rows_seen, cells_applied, warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path, help="TSV batch files to merge")
    parser.add_argument("--dry-run", action="store_true", help="Report changes without writing")
    args = parser.parse_args(argv)

    catalog = load_catalog()

    total_rows = 0
    total_cells = 0
    all_warnings: list[str] = []

    for path in args.files:
        if not path.exists():
            print(f"SKIP (not found): {path}")
            continue
        rows, cells, warnings = merge_file(catalog, path)
        total_rows += rows
        total_cells += cells
        all_warnings.extend(warnings)
        print(f"{path.name}: {rows} rows, {cells} cells applied")

    if all_warnings:
        print("\nWarnings:")
        for w in all_warnings:
            print(f"  - {w}")

    if args.dry_run:
        print(f"\n[dry-run] would write {total_cells} cells across {total_rows} rows to {CATALOG_PATH}")
        return 0

    save_catalog(catalog)
    print(f"\nWrote {total_cells} cells across {total_rows} rows to {CATALOG_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
