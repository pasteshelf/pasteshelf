#!/usr/bin/env python3
"""Emit a TSV batch of untranslated keys for translation.

Usage:
  python3 emit_batch.py --all --out-dir batches/
      -> emits multiple batch_XX.tsv files, chunked by --chunk-size (default 60)

  python3 emit_batch.py --keys-file keys.txt --out one_batch.tsv
      -> emit a single TSV for explicit keys (one per line)

TSV format (tab-separated):
  key\tform\ten\tde\tes\tfr\tja\tko\tpt\tru\ttr\tzh-Hans\tzh-Hant

Where `form` is:
  - `single`                   for non-plural keys
  - `plural:one`, `plural:other`, ... for plural keys (one row per form per language family; we emit English plural categories `one` and `other` as the canonical source form).

Notes:
  - The script only EMITS rows that need filling. A row needs filling if any target language has no translated value.
  - Rows already fully translated across all target languages are skipped.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from _catalog import (
    SOURCE_LANG,
    TARGET_LANGS,
    has_translated_value,
    is_stale,
    lang_state,
    load_catalog,
    plural_forms,
    should_translate,
)

CLASSIFICATION = Path(__file__).resolve().parent / "classification.json"

HEADER = ["key", "form", "en"] + TARGET_LANGS


def _source_value_single(key: str, entry: dict) -> str:
    loc = (entry.get("localizations") or {}).get(SOURCE_LANG, {})
    if isinstance(loc, dict):
        su = loc.get("stringUnit")
        if isinstance(su, dict) and su.get("value"):
            return su["value"]
    return key


def _escape(value: str) -> str:
    # TSV-safe: replace tabs/newlines with visible placeholders (shouldn't occur but be safe).
    return value.replace("\t", " ").replace("\r", " ").replace("\n", "\\n")


def _unescape(value: str) -> str:
    return value.replace("\\n", "\n")


def _lang_value(lang_entry: dict, form: str) -> str:
    if not isinstance(lang_entry, dict):
        return ""
    if form == "single":
        su = lang_entry.get("stringUnit")
        if isinstance(su, dict):
            v = su.get("value") or ""
            if su.get("state") == "translated":
                return v
            return ""  # empty = needs fill
        return ""
    # plural:xyz
    _, plural_form = form.split(":", 1)
    plurals = plural_forms(lang_entry) or {}
    pf = plurals.get(plural_form)
    if isinstance(pf, dict):
        su = pf.get("stringUnit")
        if isinstance(su, dict):
            v = su.get("value") or ""
            if su.get("state") == "translated":
                return v
            return ""
    return ""


def build_rows_for_key(key: str, entry: dict) -> list[list[str]]:
    """Return the TSV rows for a single key. Empty list if already complete."""
    rows: list[list[str]] = []
    source_loc = (entry.get("localizations") or {}).get(SOURCE_LANG, {})
    source_plurals = plural_forms(source_loc)

    if source_plurals:
        for form_name in sorted(source_plurals.keys()):
            form = f"plural:{form_name}"
            en_val = (
                source_plurals.get(form_name, {}).get("stringUnit", {}).get("value", "")
                if isinstance(source_plurals.get(form_name), dict)
                else ""
            )
            row = [key, form, en_val]
            needs = False
            for lang in TARGET_LANGS:
                lang_loc = (entry.get("localizations") or {}).get(lang, {})
                v = _lang_value(lang_loc, form)
                row.append(v)
                if not v:
                    needs = True
            if needs:
                rows.append(row)
    else:
        form = "single"
        en_val = _source_value_single(key, entry)
        row = [key, form, en_val]
        needs = False
        for lang in TARGET_LANGS:
            lang_loc = (entry.get("localizations") or {}).get(lang, {})
            v = _lang_value(lang_loc, form)
            row.append(v)
            if not v:
                needs = True
        if needs:
            rows.append(row)

    return rows


def write_tsv(rows: list[list[str]], path: Path) -> None:
    with path.open("w", encoding="utf-8") as f:
        f.write("\t".join(HEADER) + "\n")
        for row in rows:
            f.write("\t".join(_escape(c) for c in row) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Emit all translate-classified keys, chunked")
    parser.add_argument("--keys-file", type=Path, help="File of keys to emit (one per line)")
    parser.add_argument("--out-dir", type=Path, default=Path("batches"), help="Output directory for chunks")
    parser.add_argument("--out", type=Path, help="Single output file (for --keys-file mode)")
    parser.add_argument("--chunk-size", type=int, default=60, help="Rows per chunk in --all mode")
    args = parser.parse_args(argv)

    cat = load_catalog()
    strings = cat.get("strings", {})

    if args.all:
        if not CLASSIFICATION.exists():
            print("classification.json not found. Run classify_keys.py first.")
            return 2
        with CLASSIFICATION.open("r", encoding="utf-8") as f:
            classification = json.load(f)
        wanted = classification.get("translate", [])
    elif args.keys_file:
        wanted = [
            line.strip()
            for line in args.keys_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
    else:
        parser.error("Use --all OR --keys-file")

    # Build rows
    all_rows: list[list[str]] = []
    for key in wanted:
        entry = strings.get(key)
        if entry is None:
            continue
        if is_stale(entry) or not should_translate(entry):
            continue
        all_rows.extend(build_rows_for_key(key, entry))

    if not all_rows:
        print("Nothing to emit — all target rows already translated.")
        return 0

    if args.all:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        chunk = args.chunk_size
        n_chunks = (len(all_rows) + chunk - 1) // chunk
        for i in range(n_chunks):
            part = all_rows[i * chunk : (i + 1) * chunk]
            path = args.out_dir / f"batch_{i+1:03d}.tsv"
            write_tsv(part, path)
        print(f"Wrote {n_chunks} chunks ({len(all_rows)} rows total) to {args.out_dir}")
    else:
        if not args.out:
            parser.error("--out required with --keys-file")
        write_tsv(all_rows, args.out)
        print(f"Wrote {len(all_rows)} rows to {args.out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
