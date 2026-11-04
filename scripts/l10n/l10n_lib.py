"""Shared Dart lexing and key rules for LOOP's l10n tools (decision 0281).

Nothing here imports outside the standard library, so `check_harness.py`
can load it with `python3 -I`.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
L10N_DIR = ROOT / "lib" / "l10n"
FRAGMENTS_DIR = L10N_DIR / "fragments"
PENDING_DIRS_FILE = Path(__file__).resolve().parent / "pending_dirs.txt"

CJK = re.compile(r"[㐀-䶿一-鿿豈-﫿]")

# Calls whose string arguments are never shown to a reader.
SKIP_CALLEES = {
    "Key",
    "ValueKey",
    "ObjectKey",
    "GlobalKey",
    "PageStorageKey",
    "UniqueKey",
    "log",
    "debugPrint",
    "print",
    "assert",
    "RegExp",
    "Deprecated",
    "debugLog",
    "developer.log",
}
# Named arguments that are identifiers, not copy.
SKIP_LABELS = {"identifier", "debugLabel", "restorationId", "restorationScopeId"}
# Files whose CJK is data, not copy: the generated ARB code itself and the
# language picker's self-names.
SKIP_FILES = {
    "lib/l10n/loop_l10n.dart",
    # Stream's Chinese translation table: it is the zh side by nature.
    "lib/integrations/communication/stream_chat_localizations_zh.dart",
}
SKIP_PREFIXES = ("lib/l10n/gen/",)


@dataclass
class Part:
    kind: str  # 'text' | 'expr' | 'ident'
    value: str


@dataclass
class StringLit:
    start: int
    end: int
    raw: bool
    parts: list[Part]
    nested: list["StringLit"] = field(default_factory=list)
    depth: int = 0

    @property
    def text(self) -> str:
        return "".join(p.value for p in self.parts if p.kind == "text")

    def has_cjk(self) -> bool:
        return bool(CJK.search(self.text)) or any(n.has_cjk() for n in self.nested)


@dataclass
class Group:
    """Adjacent string literals Dart concatenates into one value."""

    lits: list[StringLit]
    line: int = 0

    @property
    def start(self) -> int:
        return self.lits[0].start

    @property
    def end(self) -> int:
        return self.lits[-1].end

    @property
    def parts(self) -> list[Part]:
        merged: list[Part] = []
        for lit in self.lits:
            for part in lit.parts:
                if part.kind == "text" and merged and merged[-1].kind == "text":
                    merged[-1] = Part("text", merged[-1].value + part.value)
                else:
                    merged.append(Part(part.kind, part.value))
        return merged

    @property
    def text(self) -> str:
        return "".join(p.value for p in self.parts if p.kind == "text")

    def cjk_in_text(self) -> bool:
        return bool(CJK.search(self.text))

    def cjk_only_nested(self) -> bool:
        return not self.cjk_in_text() and any(
            n.has_cjk() for lit in self.lits for n in lit.nested
        )


_IDENT_START = re.compile(r"[A-Za-z_]")
_IDENT_CHAR = re.compile(r"[A-Za-z0-9_]")
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f", "v": "\v"}


class Lexer:
    def __init__(self, source: str) -> None:
        self.src = source
        self.n = len(source)
        self.top: list[StringLit] = []
        self.comments: list[tuple[int, int]] = []

    def run(self) -> "Lexer":
        self._code(0, False, 0, self.top)
        return self

    def _code(self, i: int, until_brace: bool, depth: int, sink: list[StringLit]) -> int:
        src, n = self.src, self.n
        braces = 0
        while i < n:
            c = src[i]
            nxt = src[i + 1] if i + 1 < n else ""
            if c == "/" and nxt == "/":
                j = src.find("\n", i)
                j = n if j < 0 else j
                self.comments.append((i, j))
                i = j
                continue
            if c == "/" and nxt == "*":
                start = i
                level = 1
                i += 2
                while i < n and level:
                    if src.startswith("/*", i):
                        level += 1
                        i += 2
                    elif src.startswith("*/", i):
                        level -= 1
                        i += 2
                    else:
                        i += 1
                self.comments.append((start, i))
                continue
            if c in "'\"" or (
                c in "rR"
                and nxt in "'\""
                and (i == 0 or not _IDENT_CHAR.match(src[i - 1]))
            ):
                lit, i = self._string(i, depth)
                sink.append(lit)
                continue
            if c == "{":
                braces += 1
            elif c == "}":
                if until_brace and braces == 0:
                    return i
                braces -= 1
            i += 1
        return i

    def _string(self, i: int, depth: int) -> tuple[StringLit, int]:
        src, n = self.src, self.n
        start = i
        raw = src[i] in "rR"
        if raw:
            i += 1
        q = src[i]
        triple = src.startswith(q * 3, i)
        close = q * 3 if triple else q
        i += len(close)
        parts: list[Part] = []
        nested: list[StringLit] = []
        buf: list[str] = []

        def flush() -> None:
            if buf:
                parts.append(Part("text", "".join(buf)))
                buf.clear()

        while i < n:
            if src.startswith(close, i):
                i += len(close)
                break
            c = src[i]
            if not triple and c == "\n":
                break
            if c == "\\" and not raw:
                e = src[i + 1] if i + 1 < n else ""
                if e in _ESCAPES:
                    buf.append(_ESCAPES[e])
                    i += 2
                elif e == "x":
                    buf.append(chr(int(src[i + 2 : i + 4], 16)))
                    i += 4
                elif e == "u":
                    if src[i + 2 : i + 3] == "{":
                        j = src.index("}", i)
                        buf.append(chr(int(src[i + 3 : j], 16)))
                        i = j + 1
                    else:
                        buf.append(chr(int(src[i + 2 : i + 6], 16)))
                        i += 6
                elif e == "\n":
                    i += 2
                else:
                    buf.append(e)
                    i += 2
                continue
            if c == "$" and not raw:
                nxt = src[i + 1] if i + 1 < n else ""
                if nxt == "{":
                    flush()
                    inner: list[StringLit] = []
                    j = self._code(i + 2, True, depth + 1, inner)
                    parts.append(Part("expr", src[i + 2 : j]))
                    nested.extend(inner)
                    i = j + 1
                    continue
                if _IDENT_START.match(nxt):
                    flush()
                    j = i + 1
                    while j < n and _IDENT_CHAR.match(src[j]):
                        j += 1
                    parts.append(Part("ident", src[i + 1 : j]))
                    i = j
                    continue
            buf.append(c)
            i += 1
        flush()
        return StringLit(start, i, raw, parts, nested, depth), i


def line_of(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def mask_source(source: str, lexer: Lexer) -> str:
    """The source with comments and top-level strings blanked (newlines kept)."""

    chars = list(source)
    spans = list(lexer.comments) + [(lit.start, lit.end) for lit in lexer.top]
    for a, b in spans:
        for k in range(a, b):
            if chars[k] != "\n":
                chars[k] = " "
    # Mark string positions with a placeholder so `'a' 'b'` stays a value.
    for lit in lexer.top:
        chars[lit.start] = "S"
    return "".join(chars)


def groups_of(source: str, lexer: Lexer) -> list[Group]:
    groups: list[Group] = []
    comment_starts = {a: b for a, b in lexer.comments}
    current: list[StringLit] = []
    for lit in lexer.top:
        if current:
            gap = source[current[-1].end : lit.start]
            # Strip comments inside the gap.
            k = current[-1].end
            cleaned = []
            while k < lit.start:
                if k in comment_starts:
                    k = comment_starts[k]
                    continue
                cleaned.append(source[k])
                k += 1
            if "".join(cleaned).strip() == "":
                current.append(lit)
                continue
            groups.append(Group(current, line_of(source, current[0].start)))
            current = []
            del gap
        current = [lit]
    if current:
        groups.append(Group(current, line_of(source, current[0].start)))
    return groups


_OPEN = "([{"
_CLOSE = ")]}"


def enclosing_openers(mask: str, pos: int, limit: int = 20000) -> list[int]:
    """Offsets of the unmatched openers around [pos], innermost first."""

    out: list[int] = []
    level = 0
    k = pos - 1
    stop = max(0, pos - limit)
    while k >= stop:
        c = mask[k]
        if c in _CLOSE:
            level += 1
        elif c in _OPEN:
            if level:
                level -= 1
            else:
                out.append(k)
        k -= 1
    return out


def matching_close(mask: str, open_pos: int) -> int:
    level = 0
    for k in range(open_pos, len(mask)):
        c = mask[k]
        if c in _OPEN:
            level += 1
        elif c in _CLOSE:
            level -= 1
            if level == 0:
                return k
    return -1


def matching_open(mask: str, close_pos: int) -> int:
    level = 0
    for k in range(close_pos, -1, -1):
        c = mask[k]
        if c in _CLOSE:
            level += 1
        elif c in _OPEN:
            level -= 1
            if level == 0:
                return k
    return -1


_CALLEE = re.compile(r"([A-Za-z_][\w.]*)\s*(?:<[^()]*>)?\s*$")


def callee_before(mask: str, open_pos: int) -> str | None:
    head = mask[max(0, open_pos - 200) : open_pos]
    m = _CALLEE.search(head)
    return m.group(1) if m else None


def label_before(mask: str, open_pos: int, pos: int) -> str | None:
    """The named-argument label the literal at [pos] is the value of."""

    seg = mask[open_pos + 1 : pos]
    # Last top-level comma.
    level = 0
    cut = 0
    for k, c in enumerate(seg):
        if c in _OPEN:
            level += 1
        elif c in _CLOSE:
            level -= 1
        elif c == "," and level == 0:
            cut = k + 1
    piece = seg[cut:]
    m = re.match(r"\s*([A-Za-z_]\w*)\s*:", piece)
    return m.group(1) if m else None


@dataclass
class Site:
    group: Group
    callee: str | None
    label: str | None
    skip: str | None  # reason, when not copy


def literal_sites(rel: str, source: str) -> tuple[list[Site], Lexer, str]:
    lexer = Lexer(source).run()
    mask = mask_source(source, lexer)
    sites: list[Site] = []
    for group in groups_of(source, lexer):
        if not (group.cjk_in_text() or group.cjk_only_nested()):
            continue
        openers = enclosing_openers(mask, group.start)
        callee = label = None
        skip = None
        line_start = source.rfind("\n", 0, group.start) + 1
        line_text = source[line_start : source.find("\n", group.start)]
        if re.match(r"\s*(import|export|part)\b", line_text):
            skip = "directive"
        for idx, op in enumerate(openers):
            if mask[op] != "(":
                continue
            name = callee_before(mask, op)
            if name is None:
                continue
            short = name.split(".")[-1]
            if idx == 0 or (callee is None):
                if callee is None:
                    callee = name
                    label = label_before(mask, op, group.start)
            if name in SKIP_CALLEES or short in SKIP_CALLEES:
                skip = skip or f"inside {name}("
            if short == "Semantics" and label_before(mask, op, group.start) in SKIP_LABELS:
                skip = skip or "Semantics identifier"
            break_labels = label_before(mask, op, group.start)
            if break_labels in SKIP_LABELS:
                skip = skip or f"{break_labels}:"
            # Only the innermost call decides `Key(` style skips; outer calls
            # are scanned for log/assert wrappers too.
        head = mask[max(0, group.start - 3) : group.start]
        if head.rstrip().endswith("@"):
            skip = skip or "annotation"
        sites.append(Site(group, callee, label, skip))
    return sites, lexer, mask


def is_skipped_file(rel: str) -> bool:
    return rel in SKIP_FILES or rel.startswith(SKIP_PREFIXES) or "/test/" in rel or rel.startswith("test/")


def iter_dart(paths: list[Path]):
    for base in paths:
        if base.is_file() and base.suffix == ".dart":
            yield base
        elif base.is_dir():
            yield from sorted(base.rglob("*.dart"))


def rel_of(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def load_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def pending_dirs() -> list[str]:
    if not PENDING_DIRS_FILE.is_file():
        return []
    out = []
    for line in PENDING_DIRS_FILE.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            out.append(line.rstrip("/"))
    return out


def feature_of(rel: str) -> str:
    """`lib/features/profile/settings/x.dart` -> `profileSettings`."""

    parts = rel.split("/")
    if parts[:2] == ["lib", "features"]:
        segs = parts[2:-1]
    else:
        segs = parts[1:-1]
    words: list[str] = []
    for seg in segs:
        words.extend(w for w in re.split(r"[_\-]", seg) if w)
    if not words:
        words = ["app"]
    return words[0].lower() + "".join(w[:1].upper() + w[1:] for w in words[1:])


def camel(words: list[str]) -> str:
    words = [w for w in words if w]
    if not words:
        return ""
    head = words[0][:1].lower() + words[0][1:]
    return head + "".join(w[:1].upper() + w[1:] for w in words[1:])


def split_ident(name: str) -> list[str]:
    name = name.strip("_")
    out: list[str] = []
    for chunk in re.split(r"[_\W]+", name):
        out.extend(re.findall(r"[A-Z]+(?=[A-Z][a-z]|\b|\d)|[A-Z]?[a-z]+|[A-Z]+|\d+", chunk))
    return out


def arb_messages(locale: str) -> dict[str, str]:
    data = load_json(L10N_DIR / f"app_{locale}.arb")
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}
