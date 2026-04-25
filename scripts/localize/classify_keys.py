#!/usr/bin/env python3
"""Classify every catalog key as `translate` or `skip` and write classification.json.

Skip rules (order matters):
  - empty string
  - pure format tokens (combinations of %lld, %@, %d, %f, %s, %u with spaces / punctuation)
  - single-glyph symbols / tokens that are not words ("•", "[Image]", "(%lld)", "%lld.", etc.)
  - numeric/bullet-style tokens that are their own English source (e.g. "%lld")

Everything else -> translate.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from _catalog import is_stale, load_catalog, should_translate

OUT_PATH = Path(__file__).resolve().parent / "classification.json"

# A "format token" is %@, %lld, %d, %f, %s, %u, optionally with position (%1$@, %2$lld) and width/precision.
FORMAT_TOKEN = r"%(?:\d+\$)?[-+# 0]?\d*(?:\.\d+)?(?:ll|l)?[@dfisu]"
PURE_FORMAT = re.compile(
    rf"^[\s.,:;()\[\]/-]*(?:{FORMAT_TOKEN}[\s.,:;()\[\]/-]*)+$"
)

# Single-char or very short symbol-only keys.
SYMBOLS_ONLY = re.compile(r"^[\s.,:;()\[\]/•·…\-—–•]+$")

# Known specific keys to skip that aren't caught by the rules above.
EXPLICIT_SKIP = {
    "[Image]",          # placeholder that's intentionally untranslated
}


def classify(key: str) -> str:
    if key == "":
        return "skip"
    if key in EXPLICIT_SKIP:
        return "skip"
    if PURE_FORMAT.match(key):
        return "skip"
    if SYMBOLS_ONLY.match(key):
        return "skip"
    return "translate"


def main(argv: list[str] | None = None) -> int:
    cat = load_catalog()
    strings = cat.get("strings", {})

    translate: list[str] = []
    skip: list[str] = []
    stale: list[str] = []
    do_not_translate: list[str] = []

    for key, entry in strings.items():
        if is_stale(entry):
            stale.append(key)
            continue
        if not should_translate(entry):
            do_not_translate.append(key)
            continue
        verdict = classify(key)
        if verdict == "translate":
            translate.append(key)
        else:
            skip.append(key)

    translate.sort()
    skip.sort()
    stale.sort()
    do_not_translate.sort()

    result = {
        "translate": translate,
        "skip": skip,
        "stale_excluded": stale,
        "shouldTranslate_false_excluded": do_not_translate,
        "counts": {
            "translate": len(translate),
            "skip": len(skip),
            "stale_excluded": len(stale),
            "shouldTranslate_false_excluded": len(do_not_translate),
            "total": len(strings),
        },
    }

    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False, sort_keys=False)
        f.write("\n")

    print(f"Wrote classification to {OUT_PATH}")
    for name, count in result["counts"].items():
        print(f"  {name:<34s} {count:>5}")

    # Print a small preview
    print("\nFirst 20 skip entries:")
    for k in skip[:20]:
        print(f"  skip: {k!r}")
    print("\nFirst 10 translate entries:")
    for k in translate[:10]:
        print(f"  tr  : {k!r}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
