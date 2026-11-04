#!/usr/bin/env python3
"""Rewrite Dart sources to read their copy from ARB (decision 0281).

Usage:
  python3 scripts/l10n/apply.py lib/l10n/fragments/scan.json
  python3 scripts/l10n/apply.py lib/l10n/fragments/*.json --dry-run

For every file a fragment's `where` names, each CJK literal whose zh text is
in the fragment (or in `common.json`) becomes

  context.l10n.<key>            inside `build(` or any function / closure
                                with a `context` parameter
  LoopL10n.current.<key>        everywhere else

and an interpolated literal becomes a call with its expressions as
arguments. The nearest enclosing `const` (constructor call or collection) is
removed — run `dart fix --apply` afterwards to put back the ones that can
stay. A `static const` / top-level `const` / `final` String declared from one
literal becomes a getter.

Tests: a literal in `test/` that is exactly a migrated zh value and sits in
`find.text(` / `find.textContaining(` / `find.widgetWithText(` /
`find.bySemanticsLabel(` / `expect(` / `contains(` / `equals(` is rewritten to
the en value — but only when no file in `lib/` still prints that zh text
(a common phrase still used by an unmigrated page keeps its test as is).

Everything it could not do is printed as `TODO file:line reason`:
enum constructor arguments, switch-case patterns, default parameter values,
literals in a const collection declaration, entries with an empty `en`,
`State` methods outside `build` (written with LoopL10n.current; review), and
test literals that only partly match a migrated value.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import extract as E  # noqa: E402
import l10n_lib as L  # noqa: E402

IMPORT = "import 'package:loop_mobile/l10n/loop_l10n.dart';"
ASSERT_CALLEES = {
    "text",
    "textContaining",
    "widgetWithText",
    "bySemanticsLabel",
    "byTooltip",
    "expect",
    "contains",
    "equals",
    "startsWith",
    "endsWith",
    "isNot",
    "containsAll",
    "containsAllInOrder",
    "orderedEquals",
    "unorderedEquals",
    "matchesSemantics",
}


def norm(zh: str) -> str:
    return re.sub(r"\{\w+\}", "{}", zh)


def placeholder_order(zh: str) -> list[str]:
    return re.findall(r"\{(\w+)\}", zh)


def load_entries(fragments: list[Path]) -> tuple[dict[str, tuple[str, dict]], set[str]]:
    """normalised zh -> (key, entry), and the set of files named by `where`."""

    table: dict[str, tuple[str, dict]] = {}
    files: set[str] = set()
    for frag in fragments:
        for key, entry in L.load_json(frag).items():
            table.setdefault(norm(entry["zh"]), (key, entry))
            for w in str(entry.get("where", "")).split(","):
                w = w.strip()
                if ":" in w:
                    files.add(w.rsplit(":", 1)[0])
    common = L.load_json(L.FRAGMENTS_DIR / "common.json")
    for key, entry in common.items():
        table.setdefault(norm(entry["zh"]), (key, entry))
    return table, files


_FUNC_TAIL = re.compile(r"\)\s*(?:async\*?|sync\*)?\s*$")
_CLASS_HEAD = re.compile(r"\b(class|mixin|extension|enum)\b[^{;]*$")


def access_for(mask: str, pos: int) -> tuple[str, str | None]:
    """('context' | 'current', note)."""

    k = pos - 1
    level = 0
    in_state = False
    # An arrow before a `;` or `,` at this level belongs to a sibling
    # statement, member or argument, not to an enclosing function.
    arrows_blocked = False
    while k >= 0:
        c = mask[k]
        if c in ";," and level == 0:
            arrows_blocked = True
        if c in ")]}":
            level += 1
        elif c in "([{":
            if level:
                level -= 1
                k -= 1
                continue
            arrows_blocked = False
            if c == "{":
                head = mask[max(0, k - 400) : k]
                if _FUNC_TAIL.search(head):
                    j = k - 1
                    while j > 0 and mask[j] != ")":
                        j -= 1
                    open_pos = L.matching_open(mask, j)
                    params = mask[open_pos : j + 1] if open_pos >= 0 else ""
                    kind = context_param(params)
                    if kind == "build":
                        return "context", None
                    if kind == "other":
                        # A `context` that is not a BuildContext shadows any
                        # outer one: `context.l10n` would not compile.
                        return "current", None
                elif _CLASS_HEAD.search(head):
                    seg = head[head.rfind("class") :] if "class" in head else head
                    in_state = bool(re.search(r"\bextends\s+\w*State\s*<", seg))
                    break
        elif c == ">" and k > 0 and mask[k - 1] == "=" and level == 0 and not arrows_blocked:
            # `(...) => expr` at this level.
            j = k - 2
            while j >= 0 and mask[j].isspace():
                j -= 1
            if j >= 0 and mask[j] == ")":
                open_pos = L.matching_open(mask, j)
                kind = context_param(mask[open_pos : j + 1]) if open_pos >= 0 else None
                if kind == "build":
                    return "context", None
                if kind == "other":
                    return "current", None
            k -= 1
        k -= 1
    if in_state:
        return "current", "State method outside build: LoopL10n.current (review)"
    return "current", None


_CONTEXT_PARAM = re.compile(r"(?:^|[(,{\[])\s*(?:required\s+)?(?:final\s+)?([\w.]+[?]?(?:<[^()]*>)?\??)?\s*\bcontext\b\s*(?=[,)}\]=])")


def context_param(params: str) -> str | None:
    """'build' when [params] declare a `context` that is a BuildContext (typed
    so, or untyped as in a builder closure), 'other' when it is typed as
    something else, None when there is no `context` parameter."""

    m = _CONTEXT_PARAM.search(params)
    if m is None:
        return None
    declared = (m.group(1) or "").rstrip("?")
    if declared in ("", "BuildContext", "final", "required"):
        return "build"
    return "other"


def const_edits(source: str, mask: str, pos: int) -> list[tuple[int, int, str]]:
    edits = []
    for op in L.enclosing_openers(mask, pos):
        head = mask[max(0, op - 300) : op]
        m = re.search(r"\bconst\s+(?:[A-Za-z_][\w.]*\s*)?(?:<[^;{}()]*>\s*)?$", head)
        if m:
            start = max(0, op - 300) + m.start()
            edits.append((start, start + len("const") + 1, ""))
    return edits


def const_collection_getter(source: str, mask: str, openers: list[int]) -> tuple[int, int, str] | None:
    """For a literal inside `static const Map<K, V> x = {…};` (or a top-level
    / member `const x = <K, V>{…};`), the edit that turns the declaration into
    a getter: `static Map<K, V> get x => {…};`. Removing only `const` would
    leave a mutable field that reads the locale once."""

    for op in openers:
        if mask[op] not in "[{(":
            continue
        k = op - 1
        while k >= 0 and mask[k] not in ";{}":
            k -= 1
        head = mask[k + 1 : op]
        m = re.match(
            r"^(\s*)(static\s+)?const\s+(?:((?:Map|List|Set|Iterable)\s*<[^;=]*>)\s+)?(\w+)\s*=\s*(const\s+)?(<[^;={}]*>)?\s*$",
            head,
        )
        if not m:
            continue
        if declaration_scope(mask, L.enclosing_openers(mask, k + 1)) == "local":
            return None
        indent, static, declared, name, _, literal_type = m.groups()
        type_text = (declared or "").strip()
        if not type_text and literal_type:
            args = _split_args(literal_type.strip()[1:-1])
            if mask[op] == "[":
                type_text = f"List{literal_type.strip()}"
            elif mask[op] == "{":
                type_text = ("Map" if len(args) == 2 else "Set") + literal_type.strip()
        start = k + 1 + len(indent)
        prefix = f"{static or ''}{type_text + ' ' if type_text else ''}get {name} => {(literal_type or '').strip()}"
        return (start, op, prefix)
    return None


def statement_head(mask: str, pos: int) -> tuple[int, str]:
    k = pos - 1
    while k >= 0 and mask[k] not in ";{}":
        k -= 1
    return k + 1, mask[k + 1 : pos]


_DECL = re.compile(r"^(\s*)(static\s+)?(const|final)\s+(?:String\s+)?(\w+)\s*=\s*$")


def declaration_scope(mask: str, openers: list[int]) -> str:
    """'top' (no enclosing brace), 'member' (directly in a class / mixin /
    extension body) or 'local' (a function body or block)."""

    if not openers:
        return "top"
    inner = openers[0]
    if mask[inner] != "{":
        return "local"
    head = mask[max(0, inner - 400) : inner]
    if _FUNC_TAIL.search(head) or re.search(r"=>\s*$", head):
        return "local"
    if _CLASS_HEAD.search(head):
        return "member"
    return "local"


def dart_quote(text: str) -> str:
    body = text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n")
    return f"'{body}'"


def ensure_import(source: str) -> str:
    if IMPORT in source:
        return source
    if re.search(r"^part\s+of\b", source, flags=re.M):
        # A part file shares its library's imports.
        return source
    imports = list(re.finditer(r"^import '([^']+)'[^;]*;", source, flags=re.M))
    if not imports:
        at = header_end(source)
        sep = "\n" if at and not source[:at].endswith("\n\n") else ""
        return source[:at] + sep + IMPORT + "\n" + ("\n" if source[at:].strip() else "") + source[at:].lstrip("\n")
    for m in imports:
        if m.group(1).startswith("package:loop_mobile/") and m.group(1) > "package:loop_mobile/l10n/loop_l10n.dart":
            return source[: m.start()] + IMPORT + "\n" + source[m.start() :]
    last = imports[-1]
    return source[: last.end()] + "\n" + IMPORT + source[last.end() :]


def header_end(source: str) -> int:
    """Where a first import goes: after the `library` directive, else after
    the leading comment block, never between an annotation and its
    declaration."""

    lib = re.search(r"^library\b[^;]*;[ \t]*\n?", source, flags=re.M)
    if lib:
        return lib.end()
    k = 0
    while True:
        m = re.match(r"[ \t]*(//[^\n]*\n|/\*.*?\*/[ \t]*\n?|\n)", source[k:], flags=re.S)
        if not m or source[k:].startswith("///"):
            break
        k += m.end()
    return k


def apply_file(rel: str, table: dict, todo: list[str], migrated: dict[str, str], dry: bool) -> int:
    path = L.ROOT / rel
    original = path.read_text(encoding="utf-8")
    out, count = apply_source(rel, original, table, todo, migrated)
    if out != original and not dry:
        path.write_text(out, encoding="utf-8")
    return count


def apply_source(rel: str, original: str, table: dict, todo: list[str], migrated: dict[str, str]) -> tuple[str, int]:
    """[original] rewritten to read its copy from ARB, and the literal count."""

    source, count = apply_enums(rel, original, table, todo, migrated)
    sites, lexer, mask = L.literal_sites(rel, source)
    edits: list[tuple[int, int, str]] = []
    getters: list[tuple[int, int, str]] = []
    for site in sites:
        if site.skip:
            continue
        where = f"{rel}:{site.group.line}"
        zh, _, exprs, problem = E.message_of(site.group)
        if problem and "outer text" not in problem:
            todo.append(f"TODO {where} {problem}")
            continue
        hit = table.get(norm(zh))
        if hit is None:
            todo.append(f"TODO {where} no key for {zh[:40]!r}")
            continue
        key, entry = hit
        if not entry.get("en"):
            todo.append(f"TODO {where} `{key}` has no en yet")
            continue
        names = placeholder_order(entry["zh"])
        by_name = dict(zip(names, exprs))
        args = [by_name[n] for n in sorted(set(names))]
        start, end = site.group.start, site.group.end
        # Unsupported positions.
        stmt_start, head = statement_head(mask, start)
        openers = L.enclosing_openers(mask, start)
        inner = openers[0] if openers else None
        if re.search(r"\bcase\s*$", mask[max(0, start - 20) : start]) or re.search(
            r"\bcase\b[^:]*$", head
        ):
            todo.append(f"TODO {where} switch-case pattern `{key}`")
            continue
        if inner is not None and mask[inner] in "({" and re.search(r"(?:\bthis\.)?\w+\s*=\s*$", mask[max(0, start - 80) : start]):
            before = mask[max(0, inner - 2) : inner].rstrip()
            if mask[inner] == "{" and (before.endswith("(") or before.endswith(",")):
                todo.append(f"TODO {where} default parameter value `{key}`")
                continue
        enum_body = next((o for o in openers if mask[o] == "{"), None)
        if enum_body is not None and re.search(r"\benum\s+\w+[^{]*$", mask[max(0, enum_body - 200) : enum_body]):
            todo.append(f"TODO {where} enum constructor argument `{key}`")
            continue
        mode, note = access_for(mask, start)
        receiver = "context.l10n" if mode == "context" else "LoopL10n.current"
        call = f"{receiver}.{key}" + (f"({', '.join(args)})" if args else "")
        decl = _DECL.match(head)
        after = source[end : end + 20]
        scope = declaration_scope(mask, openers)
        if decl and after.lstrip().startswith(";") and scope == "local":
            # A local `final x = '…';` stays a local: a getter is not a
            # statement. A local `const` loses its `const`.
            keyword = decl.group(3)
            if keyword == "const":
                kw_at = stmt_start + head.index("const")
                edits.append((kw_at, kw_at + len("const"), "final"))
            edits.append((start, end, call))
            count += 1
            if not args:
                migrated[entry["zh"]] = entry["en"]
            continue
        if decl and after.lstrip().startswith(";") and scope in ("top", "member"):
            indent, static, _, name = decl.groups()
            receiver = "LoopL10n.current"
            call = f"{receiver}.{key}" + (f"({', '.join(args)})" if args else "")
            semi = end + after.index(";")
            # Comments are blank in the mask: start at the declaration itself
            # so a doc comment above it survives.
            decl_start = stmt_start + len(head) - len(head.lstrip())
            edits.append((decl_start, semi + 1, f"{static or ''}String get {name} => {call};"))
            count += 1
            if not args:
                migrated[entry["zh"]] = entry["en"]
            continue
        if decl is None and re.search(r"\b(?:static\s+)?const\s+[\w<>?, ]*\w+\s*=", head):
            todo.append(f"TODO {where} literal inside a const declaration `{key}`")
            continue
        getter = const_collection_getter(source, mask, openers)
        if getter is not None:
            getters.append(getter)
        if note:
            todo.append(f"TODO {where} {note} `{key}`")
        edits.append((start, end, call))
        edits.extend(const_edits(source, mask, start))
        count += 1
        if not args:
            migrated[entry["zh"]] = entry["en"]
    if getters:
        # A const collection that became a getter drops its own `const`
        # keywords with the declaration head.
        spans = set(getters)
        edits = [e for e in edits if not any(g[0] <= e[0] and e[1] <= g[1] for g in spans)]
        edits.extend(spans)
    if not edits and source == original:
        return original, 0
    unique = sorted(set(edits), key=lambda e: (e[0], e[1]), reverse=True)
    out = source
    last_start = len(source) + 1
    for s, e, text in unique:
        if e > last_start:
            continue
        out = out[:s] + text + out[e:]
        last_start = s
    out = ensure_import(out)
    return out, count


def lib_still_prints(text: str) -> bool:
    for path in L.iter_dart([L.ROOT / "lib"]):
        rel = L.rel_of(path)
        if rel.startswith(L.SKIP_PREFIXES):
            continue
        source = path.read_text(encoding="utf-8")
        if text not in source:
            continue
        if rel in L.SKIP_FILES:
            # Stream's Chinese table still prints its words in zh.
            return True
        sites, _, _ = L.literal_sites(rel, source)
        if any(not s.skip and text in s.group.text for s in sites):
            return True
    return False


STREAM_ZH_TABLE = "lib/integrations/communication/stream_chat_localizations_zh.dart"


def protected_test_file(rel: str) -> bool:
    """Shared test support and fixtures carry server / fixture copy that is
    data, not an assertion on LOOP's own strings."""

    name = rel.rsplit("/", 1)[-1]
    return (
        rel.startswith("test/support/")
        or rel.startswith("test/fixtures/")
        or "fixture" in name
    )


_STREAM_ZH: set[str] | None = None


def stream_zh_values() -> set[str]:
    """Every string in Stream's Chinese table: tests that assert it are
    asserting Stream's zh, which ARB never owns."""

    global _STREAM_ZH
    if _STREAM_ZH is None:
        path = L.ROOT / STREAM_ZH_TABLE
        _STREAM_ZH = set()
        if path.is_file():
            source = path.read_text(encoding="utf-8")
            for group in L.groups_of(source, L.Lexer(source).run()):
                if group.text:
                    _STREAM_ZH.add(group.text)
    return _STREAM_ZH


# Calls whose string argument names a test; harness evidence matches by name.
TEST_NAME_CALLEES = {"group", "test", "testWidgets"}


def apply_tests(migrated: dict[str, str], todo: list[str], dry: bool) -> tuple[int, list[str]]:
    safe = {zh: en for zh, en in migrated.items() if not lib_still_prints(zh)}
    for zh in sorted(set(migrated) - set(safe)):
        todo.append(f"TODO test literals of {zh!r} kept: lib still prints it elsewhere")
    changed_files: list[str] = []
    total = 0
    stream_zh = stream_zh_values()
    for path in sorted((L.ROOT / "test").rglob("*.dart")):
        if protected_test_file(L.rel_of(path)):
            continue
        source = path.read_text(encoding="utf-8")
        if not L.CJK.search(source):
            continue
        lexer = L.Lexer(source).run()
        mask = L.mask_source(source, lexer)
        edits = []
        for group in L.groups_of(source, lexer):
            if any(p.kind != "text" for p in group.parts):
                continue
            text = group.text
            if not L.CJK.search(text) or text in stream_zh:
                continue
            openers = L.enclosing_openers(mask, group.start)
            callee = L.callee_before(mask, openers[0]) if openers and mask[openers[0]] == "(" else None
            short = (callee or "").split(".")[-1]
            if text in safe and short in ASSERT_CALLEES:
                edits.append((group.start, group.end, dart_quote(safe[text])))
            elif short in ASSERT_CALLEES and len(text) >= 4 and any(text in zh for zh in safe if text != zh):
                todo.append(f"TODO {L.rel_of(path)}:{group.line} partial match {text[:30]!r}")
        if edits:
            out = source
            for s, e, t in sorted(edits, reverse=True):
                out = out[:s] + t + out[e:]
            total += len(edits)
            changed_files.append(L.rel_of(path))
            if not dry:
                path.write_text(out, encoding="utf-8")
    return total, changed_files


def fixed_cjk(zh: str) -> str:
    """The CJK characters of [zh] outside its `{placeholders}`."""

    return "".join(L.CJK.findall(re.sub(r"\{\w+\}", "", zh)))


def force_template_usable(zh: str) -> bool:
    """A template worth matching against a test literal: its fixed part has
    Chinese, and a template with several placeholders has at least four
    Chinese characters of its own (otherwise `{a}：{b}` swallows anything)."""

    cjk = fixed_cjk(zh)
    if not cjk:
        return False
    if len(placeholder_order(zh)) >= 2 and len(cjk) < 4:
        return False
    return True


_PLURAL = re.compile(r"\{(\w+),\s*plural,")


def expand_icu(en: str, values: dict[str, str]) -> str | None:
    """[en] with every `{name}` filled and every `{name, plural, …}` block
    resolved for the matched number; None when a plural's number is not an
    integer (the assertion is left for a human)."""

    out = []
    k = 0
    while k < len(en):
        m = _PLURAL.match(en, k)
        if not m:
            out.append(en[k])
            k += 1
            continue
        name = m.group(1)
        # The whole block: balance braces from its opening one.
        level = 0
        j = k
        while j < len(en):
            if en[j] == "{":
                level += 1
            elif en[j] == "}":
                level -= 1
                if level == 0:
                    break
            j += 1
        body = en[m.end() : j]
        raw = values.get(name, "").strip().replace(",", "")
        if not re.fullmatch(r"-?\d+", raw):
            return None
        n = int(raw)
        forms: dict[str, str] = {}
        for fm in re.finditer(r"\s*(=\d+|zero|one|two|few|many|other)\s*\{", body):
            level = 1
            e = fm.end()
            while e < len(body) and level:
                level += {"{": 1, "}": -1}.get(body[e], 0)
                e += 1
            forms.setdefault(fm.group(1), body[fm.end() : e - 1])
        chosen = forms.get(f"={n}") or (forms.get("one") if n == 1 else None) or forms.get("other")
        if chosen is None:
            return None
        out.append(chosen.replace("#", str(n)))
        k = j + 1
    text = "".join(out)
    for name, value in values.items():
        text = text.replace("{" + name + "}", value)
    return text


def force_templates(fragments: list[Path]) -> list[tuple[re.Pattern, list[str], str, str]]:
    templates = []
    for frag in fragments:
        for key, entry in L.load_json(frag).items():
            zh, en = entry["zh"], entry.get("en", "")
            if not en or not force_template_usable(zh):
                continue
            names = placeholder_order(zh)
            pattern = re.escape(zh)
            for name in names:
                pattern = pattern.replace(re.escape("{" + name + "}"), f"(?P<{name}>.+?)", 1)
            templates.append((re.compile("^" + pattern + "$", re.S), names, en, zh))
    # The most specific template wins: most fixed Chinese first, so `已选 {n} 条`
    # beats `已选 {n}`.
    templates.sort(key=lambda t: (-len(fixed_cjk(t[3])), len(t[1])))
    return templates


def force_rewrite(text: str, templates) -> str | None:
    """The en value for test literal [text], or None."""

    for pattern, names, en, _ in templates:
        m = pattern.match(text)
        if not m:
            continue
        values = {name: m.group(name) for name in names}
        # A placeholder that captured Chinese means a wrong template: the
        # result would be half Chinese, half English.
        if any(L.CJK.search(v) for v in values.values()):
            continue
        value = expand_icu(en, values)
        if value is None:
            return None
        return value
    return None


def force_tests(fragments: list[Path], files: list[str], dry: bool) -> int:
    """Rewrite every literal in [files] that is exactly a fragment's zh value
    (or its template filled in) to the en value — for the tests a migration
    broke, after reading why. Common phrases are left alone, and so are
    test support / fixture files, Stream's own Chinese table and test names."""

    templates = force_templates(fragments)
    stream_zh = stream_zh_values()
    total = 0
    for rel in files:
        if protected_test_file(rel):
            print(f"  {rel}: skipped (test support / fixture)")
            continue
        path = L.ROOT / rel
        source = path.read_text(encoding="utf-8")
        out, n = force_source(source, templates, stream_zh)
        if n:
            print(f"  {rel}: {n}")
            total += n
            if not dry:
                path.write_text(out, encoding="utf-8")
    return total


def force_source(source: str, templates, stream_zh: set[str]) -> tuple[str, int]:
    lexer = L.Lexer(source).run()
    mask = L.mask_source(source, lexer)
    edits = []
    for group in L.groups_of(source, lexer):
        if any(p.kind != "text" for p in group.parts) or not L.CJK.search(group.text):
            continue
        if group.text in stream_zh:
            continue
        openers = L.enclosing_openers(mask, group.start)
        calls = [o for o in openers if mask[o] == "("]
        callees = [(L.callee_before(mask, o) or "").split(".")[-1] for o in calls]
        if callees and callees[0] in TEST_NAME_CALLEES:
            continue
        # The first call around it, through any list / set literal.
        if not callees or callees[0] not in ASSERT_CALLEES:
            continue
        value = force_rewrite(group.text, templates)
        if value is not None:
            edits.append((group.start, group.end, dart_quote(value)))
    out = source
    for a, b, t in sorted(edits, reverse=True):
        out = out[:a] + t + out[b:]
    return out, len(edits)


def sibling_files(files: set[str]) -> set[str]:
    """Every non-generated .dart file in the directories [files] live in: a
    file whose only Chinese is a `common.json` phrase is in no fragment's
    `where`, but still has to move."""

    out = set(files)
    for rel in files:
        folder = (L.ROOT / rel).parent
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.dart")):
            other = L.rel_of(path)
            if not L.is_skipped_file(other):
                out.add(other)
    return out


def already_migrated(fragments: list[Path]) -> dict[str, str]:
    """zh -> en of the fragment entries lib/ already reads by key, so a second
    run still brings the tests along (the first run left no literal to
    record)."""

    entries = {}
    for frag in fragments:
        for key, entry in L.load_json(frag).items():
            if entry.get("en") and not placeholder_order(entry["zh"]):
                entries[key] = entry
    if not entries:
        return {}
    read: set[str] = set()
    pattern = re.compile(r"(?:\bl10n|\bLoopL10n\s*\.\s*current)\s*\.\s*([a-z]\w*)")
    for path in L.iter_dart([L.ROOT / "lib"]):
        rel = L.rel_of(path)
        if rel.startswith(L.SKIP_PREFIXES):
            continue
        read.update(pattern.findall(path.read_text(encoding="utf-8")))
    return {e["zh"]: e["en"] for k, e in entries.items() if k in read}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("fragments", nargs="+", type=Path)
    parser.add_argument("--files", nargs="*", help="limit to these lib files (default: the fragments' `where`)")
    parser.add_argument("--no-tests", action="store_true", help="leave test/ alone")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--force-tests",
        nargs="+",
        metavar="TEST",
        help="only rewrite these test files: every exact (or template) match of a fragment zh",
    )
    args = parser.parse_args()
    if args.force_tests:
        n = force_tests(args.fragments, [L.rel_of(Path(f)) for f in args.force_tests], args.dry_run)
        print(f"test: {n} literals")
        return 0
    table, files = load_entries(args.fragments)
    if args.files:
        files = {L.rel_of(Path(f)) for f in args.files}
    else:
        files = sibling_files(files)
    todo: list[str] = []
    migrated: dict[str, str] = already_migrated(args.fragments)
    changed = []
    total = 0
    for rel in sorted(files):
        n = apply_file(rel, table, todo, migrated, args.dry_run)
        if n:
            changed.append(f"{rel} ({n})")
            total += n
    print(f"lib: {total} literals in {len(changed)} files")
    for line in changed:
        print(f"  {line}")
    if not args.no_tests:
        n, test_files = apply_tests(migrated, todo, args.dry_run)
        print(f"test: {n} assertions in {len(test_files)} files")
        for line in test_files:
            print(f"  {line}")
    for line in todo:
        print(line)
    print("next: python3 scripts/l10n/merge.py && bin/dart fix --apply && bin/flutter analyze")
    return 0



# ---------------------------------------------------------------------------
# Enums whose values carry copy as constructor arguments.
# ---------------------------------------------------------------------------

def _split_args(text: str) -> list[tuple[int, int]]:
    """(start, end) spans of the top-level comma-separated pieces of [text]."""

    spans = []
    level = 0
    start = 0
    for k, c in enumerate(text):
        if c in "([{":
            level += 1
        elif c in ")]}":
            level -= 1
        elif c == "," and level == 0:
            spans.append((start, k))
            start = k + 1
    if text[start:].strip():
        spans.append((start, len(text)))
    return spans


def apply_enums(rel: str, source: str, table: dict, todo: list[str], migrated: dict[str, str]) -> tuple[str, int]:
    """Move CJK constructor arguments of enum values into switch getters.

    `chat('chat', '聊天')` with `const E(this.slug, this.label)` and
    `final String label;` becomes `chat('chat')`, `const E(this.slug)` and
    `String get label => switch (this) { E.chat => LoopL10n.current.k, ... };`.
    Only positional `this.x` parameters are handled; anything else is a TODO.
    """

    count = 0
    while True:
        lexer = L.Lexer(source).run()
        mask = L.mask_source(source, lexer)
        lits = {lit.start: lit for lit in lexer.top}
        changed = False
        for m in re.finditer(r"\benum\s+(\w+)[^{;]*\{", mask):
            name = m.group(1)
            body_open = m.end() - 1
            body_close = L.matching_close(mask, body_open)
            body = mask[body_open + 1 : body_close]
            # Values end at the first top-level `;`.
            level = 0
            values_end = None
            for k, c in enumerate(body):
                if c in "([{":
                    level += 1
                elif c in ")]}":
                    level -= 1
                elif c == ";" and level == 0:
                    values_end = k
                    break
            if values_end is None:
                continue
            values_abs = body_open + 1
            values: list[tuple[str, int, int]] = []  # name, open paren, close paren
            for a, b in _split_args(body[:values_end]):
                piece = body[a:b]
                vm = re.match(r"\s*(?:@\w+(?:\([^)]*\))?\s*)*([a-zA-Z_]\w*)\s*(\()?", piece)
                if not vm:
                    continue
                if vm.group(2) is None:
                    values.append((vm.group(1), -1, -1))
                    continue
                op = values_abs + a + vm.end(2) - 1
                cl = L.matching_close(mask, op)
                values.append((vm.group(1), op, cl))
            ctor = re.search(r"\bconst\s+" + re.escape(name) + r"\s*\(", mask[body_open:body_close])
            if not ctor or not values:
                continue
            ctor_open = body_open + ctor.end() - 1
            ctor_close = L.matching_close(mask, ctor_open)
            params_text = mask[ctor_open + 1 : ctor_close]
            if "{" in params_text or "[" in params_text:
                if any(_cjk_arg(source, mask, lits, v) for v in values):
                    todo.append(f"TODO {rel}:{L.line_of(source, body_open)} enum {name}: named/optional constructor parameters")
                continue
            params = [params_text[a:b].strip() for a, b in _split_args(params_text)]
            for position, param in enumerate(params):
                pm = re.fullmatch(r"this\.(\w+)", param)
                if not pm:
                    continue
                field = pm.group(1)
                entries = []
                ok = True
                any_cjk = False
                for vname, op, cl in values:
                    if op < 0:
                        ok = False
                        break
                    spans = _split_args(mask[op + 1 : cl])
                    if position >= len(spans):
                        ok = False
                        break
                    a, b = spans[position]
                    raw = source[op + 1 + a : op + 1 + b].strip()
                    lit = lits.get(op + 1 + a + (len(source[op + 1 + a : op + 1 + b]) - len(source[op + 1 + a : op + 1 + b].lstrip())))
                    if raw == "null":
                        entries.append((vname, "null", None))
                    elif lit is not None and all(p.kind == "text" for p in lit.parts) and lit.end - lit.start == len(raw):
                        text = lit.text
                        if L.CJK.search(text):
                            any_cjk = True
                            hit = table.get(norm(text))
                            if hit is None or not hit[1].get("en"):
                                ok = False
                                todo.append(f"TODO {rel}: enum {name}.{vname} `{text[:30]}` has no key/en")
                                break
                            entries.append((vname, f"LoopL10n.current.{hit[0]}", hit[1]))
                        else:
                            entries.append((vname, raw, None))
                    else:
                        ok = False
                        break
                if not ok or not any_cjk:
                    if any_cjk and not ok:
                        todo.append(f"TODO {rel}:{L.line_of(source, body_open)} enum {name}.{field}: mixed argument kinds")
                    continue
                fd = re.search(r"\n(\s*)final\s+(String\??)\s+" + re.escape(field) + r"\s*;", source[body_open:body_close])
                if not fd:
                    todo.append(f"TODO {rel}: enum {name}.{field}: no `final String {field};`")
                    continue
                nullable = any(e[1] == "null" for e in entries) or fd.group(2).endswith("?")
                indent = fd.group(1)
                arms = "".join(f"{indent}  {name}.{v} => {expr},\n" for v, expr, _ in entries)
                getter = (
                    f"\n{indent}String{'?' if nullable else ''} get {field} => switch (this) {{\n"
                    f"{arms}{indent}}};"
                )
                edits = [(body_open + fd.start(), body_open + fd.end(), getter)]
                # Constructor parameter.
                a, b = _split_args(params_text)[position]
                edits.append(_arg_removal(source, ctor_open + 1, params_text, position))
                for vname, op, cl in values:
                    edits.append(_arg_removal(source, op + 1, source[op + 1 : cl], position))
                for s, e, t in sorted(edits, reverse=True):
                    source = source[:s] + t + source[e:]
                for _, _, entry in entries:
                    if entry is not None:
                        migrated[entry["zh"]] = entry["en"]
                count += sum(1 for e in entries if e[2] is not None)
                changed = True
                break
            if changed:
                break
        if not changed:
            break
    # `name()` left with no arguments reads as `name`.
    return source, count


def _cjk_arg(source, mask, lits, value) -> bool:
    _, op, cl = value
    return op >= 0 and bool(L.CJK.search(source[op:cl]))


def _arg_removal(source: str, base: int, text: str, position: int) -> tuple[int, int, str]:
    spans = _split_args(text)
    a, b = spans[position]
    if position + 1 < len(spans):
        return (base + a, base + spans[position + 1][0], "" if position == 0 else " ")
    if position > 0:
        prev_end = spans[position - 1][1]
        # Drop the comma before it and keep a trailing comma if one followed.
        tail = text[b:]
        return (base + prev_end, base + b, "")
    return (base + a, base + len(text), "")


if __name__ == "__main__":
    sys.exit(main())
