#!/usr/bin/env python3
"""Extract hard-coded CJK copy from Dart sources into an l10n fragment.

Usage:
  python3 scripts/l10n/extract.py lib/features/scan
  python3 scripts/l10n/extract.py lib/features/profile/settings --feature profileSettings
  python3 scripts/l10n/extract.py --stats lib            # counts per directory, writes nothing

For each directory (or file) it scans every non-test `.dart` file for string
literals that carry CJK text — single/double/triple quotes, raw strings,
adjacent literals Dart concatenates, `$name` / `${expr}` interpolation — and
skips comments, doc comments, `Key(...)` / `ValueKey(...)`,
`Semantics(identifier:)`, `log(` / `debugPrint(` / `assert(` / `RegExp(` and
annotations.

It writes `lib/l10n/fragments/<feature>.json`:

  {"<feature>_<slug>": {"zh": "...", "en": "", "placeholders": {...}, "where": "file:line"}}

Keys are `<feature>_<slug>`: the feature is the directory under
`lib/features/` (camelCase), the slug comes from the file name and the
nearest identifier (the call's `ValueKey`, the named argument, the variable,
getter or switch arm). The same zh text in one feature gets one key; a zh text
already in `common.json` is not repeated. An existing fragment is merged:
keys, `en` values and renamed keys are kept, new strings are added.

Literals it cannot turn into a message (CJK only inside an interpolated
expression, literal braces) are listed on stdout as `UNHANDLED`.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import l10n_lib as L  # noqa: E402

_DART_KEYWORDS = {
    "if", "else", "true", "false", "null", "this", "new", "const", "final",
    "var", "return", "is", "as", "in", "await", "async", "super", "toString",
    "length", "value", "isEmpty", "isNotEmpty", "toStringAsFixed", "round",
    "floor", "ceil", "abs", "toInt", "trim",
}


def placeholder_name(part: L.Part, taken: set[str]) -> str:
    if part.kind == "ident":
        base = part.value
    else:
        expr = part.value.strip()
        idents = [i for i in re.findall(r"[A-Za-z_]\w*", expr) if i not in _DART_KEYWORDS]
        if re.fullmatch(r"[\w.!?\s]+", expr) and idents:
            base = idents[-1]
        elif idents:
            base = idents[0]
            if base.startswith("loop") and len(base) > 4:
                base = base[4:5].lower() + base[5:]
            if base.startswith("_"):
                base = base.lstrip("_")
        else:
            base = "value"
    base = base.lstrip("_") or "value"
    if not re.match(r"[a-z]", base):
        base = "v" + base[:1].upper() + base[1:]
    name = base
    k = 2
    while name in taken:
        name = f"{base}{k}"
        k += 1
    taken.add(name)
    return name


def message_of(group: L.Group) -> tuple[str, dict, list[str], str | None]:
    """zh message, placeholders, placeholder expressions, problem."""

    taken: set[str] = set()
    out: list[str] = []
    placeholders: dict[str, dict] = {}
    exprs: list[str] = []
    problem = None
    for part in group.parts:
        if part.kind == "text":
            if "{" in part.value or "}" in part.value:
                problem = "literal braces in copy"
            out.append(part.value)
        else:
            name = placeholder_name(part, taken)
            expr = part.value.strip() if part.kind == "expr" else part.value
            placeholders[name] = {"type": "Object", "example": expr}
            exprs.append(expr)
            out.append("{" + name + "}")
    if group.cjk_only_nested():
        problem = "CJK only inside an interpolated expression"
    elif any(n.has_cjk() for lit in group.lits for n in lit.nested):
        problem = "CJK inside an interpolated expression (outer text extracted)"
    return "".join(out), placeholders, exprs, problem


_KEY_IN_CALL = re.compile(
    r"\bkey\s*:\s*(?:const\s+)?(?:Value|Object)?Key(?:<String>)?\(\s*'([^'$]+)'"
)


def nearest_identifier(source: str, mask: str, site: L.Site) -> list[str]:
    start = site.group.start
    openers = L.enclosing_openers(mask, start)
    words: list[str] = []
    if openers and mask[openers[0]] == "(":
        op = openers[0]
        close = L.matching_close(mask, op)
        args = source[op : close if close > 0 else start]
        m = _KEY_IN_CALL.search(args)
        if m:
            words = re.split(r"[-_.:/\s]+", m.group(1))
        if site.label:
            words = words + L.split_ident(site.label)
        if words:
            return words
    head = mask[max(0, start - 240) : start]
    for pattern in (
        r"\bget\s+(\w+)\s*=>\s*$",
        r"(\w+)\s*\([^()]*\)\s*(?:async\s*)?=>\s*$",
        r"(\w+)\s*(?:\?\?)?=\s*$",
        r"(\w+)\s*:\s*$",
        r"\.(\w+)\s*(?:when[^=]*)?=>\s*$",
        r"\bcase\s+[\w.]*?(\w+)\s*:\s*(?:return\s*)?$",
    ):
        m = re.search(pattern, head)
        if m:
            return L.split_ident(m.group(1))
    if site.callee:
        name = site.callee.split(".")[-1]
        if name not in {"Text", "TextSpan", "Padding", "Center", "Row", "Column"}:
            return L.split_ident(name)
    # The enclosing function or getter.
    m = None
    for m in re.finditer(r"(?:\bget\s+(\w+)|(\w+)\s*\([^()]*\)\s*(?:async\s*)?\{)", mask[max(0, start - 3000) : start]):
        pass
    if m:
        return L.split_ident(m.group(1) or m.group(2))
    return ["text"]


def file_words(rel: str, feature: str) -> list[str]:
    stem = Path(rel).stem
    feat = {w.lower() for w in L.split_ident(feature)}
    feat |= {w.rstrip("s") for w in feat}
    words = [w for w in stem.split("_") if w and w.lower() not in feat and w.rstrip("s").lower() not in feat]
    for noise in ("screen", "loop", "v2", "page", "widgets"):
        if len(words) > 1 and noise in words:
            words.remove(noise)
    return words or [stem.split("_")[-1]]


def load_common() -> dict[str, str]:
    common = L.load_json(L.FRAGMENTS_DIR / "common.json")
    return {entry["zh"]: key for key, entry in common.items()}


def extract(paths: list[Path], feature: str | None) -> tuple[dict, list[str]]:
    common = load_common()
    fragments: dict[str, dict] = defaultdict(dict)
    unhandled: list[str] = []
    for path in L.iter_dart(paths):
        rel = L.rel_of(path)
        if L.is_skipped_file(rel):
            continue
        source = path.read_text(encoding="utf-8")
        sites, _, mask = L.literal_sites(rel, source)
        feat = feature or L.feature_of(rel)
        frag = fragments[feat]
        for site in sites:
            where = f"{rel}:{site.group.line}"
            if site.skip:
                continue
            zh, placeholders, _, problem = message_of(site.group)
            if problem and "outer text" not in problem:
                unhandled.append(f"UNHANDLED {where} {problem}: {site.group.text[:50]!r}")
                continue
            if problem:
                unhandled.append(f"UNHANDLED {where} {problem}: {zh[:50]!r}")
            if zh in common:
                continue
            existing = next((k for k, v in frag.items() if v["zh"] == zh), None)
            if existing:
                if where not in frag[existing]["where"]:
                    frag[existing]["where"] += ", " + where
                continue
            slug = L.camel(file_words(rel, feat) + nearest_identifier(source, mask, site))
            base = f"{feat}_{slug}"
            key = base
            k = 2
            while key in frag:
                key = f"{base}{k}"
                k += 1
            frag[key] = {"zh": zh, "en": "", "placeholders": placeholders, "where": where}
    return fragments, unhandled


def merge_into_existing(feat: str, fresh: dict) -> dict:
    path = L.FRAGMENTS_DIR / f"{feat}.json"
    old = L.load_json(path)
    by_zh = {v["zh"]: k for k, v in old.items()}
    merged = dict(old)
    for key, entry in fresh.items():
        if entry["zh"] in by_zh:
            prior = merged[by_zh[entry["zh"]]]
            prior["where"] = entry["where"]
            prior.setdefault("placeholders", entry["placeholders"])
            continue
        while key in merged:
            key += "X"
        merged[key] = entry
    return merged


def stats(paths: list[Path]) -> None:
    per_dir: Counter[str] = Counter()
    per_dir_unique: dict[str, set[str]] = defaultdict(set)
    files: Counter[str] = Counter()
    kinds: Counter[str] = Counter()
    for path in L.iter_dart(paths):
        rel = L.rel_of(path)
        if L.is_skipped_file(rel):
            continue
        sites, _, _ = L.literal_sites(rel, path.read_text(encoding="utf-8"))
        parts = rel.split("/")
        bucket = "/".join(parts[:3]) if parts[1] == "features" else "/".join(parts[:2])
        live = [s for s in sites if not s.skip]
        if live:
            files[bucket] += 1
        for site in sites:
            if site.skip:
                kinds["skipped: " + site.skip.split("(")[0]] += 1
                continue
            zh, _, _, problem = message_of(site.group)
            if problem:
                kinds["unhandled: " + problem] += 1
            per_dir[bucket] += 1
            per_dir_unique[bucket].add(zh)
    total = sum(per_dir.values())
    print(f"{'directory':48} {'literals':>8} {'unique':>7} {'files':>6}")
    for bucket, count in per_dir.most_common():
        print(f"{bucket:48} {count:8} {len(per_dir_unique[bucket]):7} {files[bucket]:6}")
    print(f"{'TOTAL':48} {total:8} {len(set().union(*per_dir_unique.values()) if per_dir_unique else set()):7} {sum(files.values()):6}")
    for kind, count in kinds.most_common():
        print(f"  {kind}: {count}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--feature", help="fragment / key prefix (default: from the directory)")
    parser.add_argument("--stats", action="store_true", help="print counts per directory and write nothing")
    parser.add_argument("--dry-run", action="store_true", help="print the fragment instead of writing it")
    args = parser.parse_args()
    if args.stats:
        stats(args.paths)
        return 0
    fragments, unhandled = extract(args.paths, args.feature)
    for feat, fresh in fragments.items():
        merged = merge_into_existing(feat, fresh)
        path = L.FRAGMENTS_DIR / f"{feat}.json"
        if args.dry_run:
            print(f"--- {path} ({len(merged)} keys)")
        else:
            L.dump_json(path, merged)
            print(f"wrote {L.rel_of(path)}: {len(merged)} keys ({len(fresh)} found now)")
    for line in unhandled:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
