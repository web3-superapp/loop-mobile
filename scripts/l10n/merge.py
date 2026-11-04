#!/usr/bin/env python3
"""Assemble lib/l10n/app_en.arb and app_zh.arb from the fragments, then
run `flutter gen-l10n` (decision 0281).

Usage:
  python3 scripts/l10n/merge.py            # merge + gen-l10n
  python3 scripts/l10n/merge.py --no-gen   # merge only
  python3 scripts/l10n/merge.py --check    # fail if the ARB files are stale

Every `lib/l10n/fragments/*.json` entry becomes one ARB message: `en` in the
English template (with `@key.description` = where it is used and each
placeholder typed `Object?`), `zh` in the Chinese file. Keys are sorted. It
refuses a key defined twice, an entry with an empty `en`, and an `en` / `zh`
pair whose `{placeholders}` differ.

The ARB files are build output of this script; edit the fragments.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import l10n_lib as L  # noqa: E402

FLUTTER_ROOT_DEFAULT = "/Users/chenyang/Documents/LOOP/loop-mobile/.tooling/flutter"


def build() -> tuple[dict, dict, list[str]]:
    errors: list[str] = []
    en: dict = {"@@locale": "en"}
    zh: dict = {"@@locale": "zh"}
    owner: dict[str, str] = {}
    entries: dict[str, dict] = {}
    for frag in sorted(L.FRAGMENTS_DIR.glob("*.json")):
        for key, entry in L.load_json(frag).items():
            if key in owner:
                errors.append(f"{key} is in both {owner[key]} and {frag.name}")
                continue
            if not re.fullmatch(r"[a-z][A-Za-z0-9_]*", key):
                errors.append(f"{frag.name}: `{key}` is not a valid ARB key")
                continue
            owner[key] = frag.name
            entries[key] = entry
    for key in sorted(entries):
        entry = entries[key]
        en_text = entry.get("en", "")
        zh_text = entry.get("zh", "")
        if not en_text:
            errors.append(f"{owner[key]}: `{key}` has no en")
            continue
        names_en = set(re.findall(r"\{(\w+)\}", en_text))
        names_zh = set(re.findall(r"\{(\w+)\}", zh_text))
        if names_en != names_zh:
            errors.append(f"{owner[key]}: `{key}` placeholders differ: en {sorted(names_en)} zh {sorted(names_zh)}")
            continue
        meta: dict = {"description": str(entry.get("where", ""))}
        if names_zh:
            meta["placeholders"] = {
                name: {"type": "Object?"} for name in sorted(names_zh)
            }
        en[key] = en_text
        en["@" + key] = meta
        zh[key] = zh_text
    return en, zh, errors


def dump(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--no-gen", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    en, zh, errors = build()
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    en_path = L.L10N_DIR / "app_en.arb"
    zh_path = L.L10N_DIR / "app_zh.arb"
    if args.check:
        stale = [p.name for p, d in ((en_path, en), (zh_path, zh)) if not p.is_file() or p.read_text(encoding="utf-8") != dump(d)]
        if stale:
            print("stale: " + ", ".join(stale) + " (run scripts/l10n/merge.py)")
            return 1
        return 0
    en_path.write_text(dump(en), encoding="utf-8")
    zh_path.write_text(dump(zh), encoding="utf-8")
    print(f"wrote {L.rel_of(en_path)} and {L.rel_of(zh_path)}: {(len(en) - 1) // 2} messages")
    if args.no_gen:
        return 0
    env = {k: v for k, v in os.environ.items() if k not in ("PUB_HOSTED_URL", "FLUTTER_STORAGE_BASE_URL")}
    env.setdefault("LOOP_FLUTTER_ROOT", FLUTTER_ROOT_DEFAULT)
    result = subprocess.run([str(L.ROOT / "bin/flutter"), "gen-l10n"], cwd=L.ROOT, env=env)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
