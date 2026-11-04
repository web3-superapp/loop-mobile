#!/usr/bin/env python3
"""List the CJK copy still hard-coded in lib/ (decision 0281).

Usage:
  python3 scripts/l10n/check.py                 # every remaining literal, by directory
  python3 scripts/l10n/check.py --enforce       # exit 1 on any outside pending_dirs.txt
  python3 scripts/l10n/check.py lib/features/scan

Uses the same rules as extract.py (comments, keys, Semantics identifiers,
log / assert / RegExp arguments and annotations are not copy).
`scripts/l10n/pending_dirs.txt` lists the directories not migrated yet: one
path prefix per line, `!prefix` to carve a migrated sub-directory out of a
pending one. S355 deletes a line as each directory lands.
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import l10n_lib as L  # noqa: E402


def is_pending(rel: str, entries: list[str]) -> bool:
    pending = False
    best = -1
    for entry in entries:
        neg = entry.startswith("!")
        prefix = entry[1:] if neg else entry
        if rel == prefix or rel.startswith(prefix + "/"):
            if len(prefix) > best:
                best = len(prefix)
                pending = not neg
    return pending


def remaining(paths: list[Path]) -> list[tuple[str, int, str]]:
    out = []
    for path in L.iter_dart(paths):
        rel = L.rel_of(path)
        if L.is_skipped_file(rel):
            continue
        source = path.read_text(encoding="utf-8")
        if not L.CJK.search(source):
            continue
        sites, _, _ = L.literal_sites(rel, source)
        for site in sites:
            if site.skip:
                continue
            out.append((rel, site.group.line, site.group.text or "<nested>"))
    return out


def violations(root: Path | None = None) -> list[str]:
    """Hard-coded CJK outside the pending directories, as harness errors."""

    entries = L.pending_dirs()
    errors = []
    for rel, line, text in remaining([(root or L.ROOT) / "lib"]):
        if is_pending(rel, entries):
            continue
        excerpt = text if len(text) <= 40 else text[:40] + "…"
        errors.append(
            f"{rel}:{line} hard-codes `{excerpt}`; copy goes through "
            "context.l10n / LoopL10n.current (decision 0281, scripts/l10n)"
        )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", type=Path)
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    if args.enforce:
        errors = violations()
        for error in errors:
            print(error)
        print(f"{len(errors)} hard-coded literals outside pending_dirs.txt")
        return 1 if errors else 0
    found = remaining(args.paths or [L.ROOT / "lib"])
    by_dir: dict[str, int] = defaultdict(int)
    for rel, line, text in found:
        by_dir[str(Path(rel).parent)] += 1
        if args.paths:
            print(f"{rel}:{line} {text[:60]}")
    entries = L.pending_dirs()
    for d, n in sorted(by_dir.items()):
        flag = "pending" if is_pending(d + "/x.dart", entries) else "MIGRATED?"
        print(f"{n:6} {d}  [{flag}]")
    print(f"{len(found)} literals")
    return 0


if __name__ == "__main__":
    sys.exit(main())
