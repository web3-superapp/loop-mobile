"""Decision 0281 rules for scripts/check_harness.py.

Kept beside the l10n tools so the harness and the tools share one reading of
what counts as hard-coded copy.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check as _check  # noqa: E402
import l10n_lib as L  # noqa: E402
import merge as _merge  # noqa: E402

LOCALE_STORE_OWNER = Path(
    "lib/integrations/personalization/shared_preferences_locale_store.dart"
)

_ARB_CACHE: dict[Path, tuple[dict[str, str], dict[str, str]]] = {}


def arb_tables(root: Path) -> tuple[dict[str, str], dict[str, str]]:
    """(key -> zh, key -> en) from the checked-in ARB files."""

    if root not in _ARB_CACHE:
        import json

        def read(name: str) -> dict[str, str]:
            path = root / "lib/l10n" / name
            if not path.is_file():
                return {}
            data = json.loads(path.read_text(encoding="utf-8"))
            return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}

        _ARB_CACHE[root] = (read("app_zh.arb"), read("app_en.arb"))
    return _ARB_CACHE[root]


_KEY_READ = re.compile(r"(?:\bl10n|\bLoopL10n\s*\.\s*current)\s*\.\s*([a-z][A-Za-z0-9_]*)")


def keys_read(text: str) -> list[str]:
    """ARB keys [text] reads through `context.l10n.<key>` / `LoopL10n.current.<key>`."""

    return list(dict.fromkeys(_KEY_READ.findall(text)))


def copy_read(root: Path, text: str, locales: tuple[str, ...] = ("zh",)) -> list[str]:
    """The ARB values (zh by default) of every key [text] reads.

    Rules that look for (or forbid) a phrase in a page's visible strings run
    over these as well, so a phrase that moved to ARB is still seen. The
    default is zh because those rules were reviewed against the zh copy the
    source held before decision 0281; their English word lists predate it
    and would misread English that never was a save claim (`Success` as a
    network probe result).
    """

    zh, en = arb_tables(root)
    tables = {"zh": zh, "en": en}
    out: list[str] = []
    for key in keys_read(text):
        for locale in locales:
            value = tables[locale].get(key)
            if value:
                out.append(value)
    return out


def copy_present(root: Path, text: str, fragment: str) -> bool:
    """Whether [fragment] is in [text], directly or as ARB copy it reads.

    A required Chinese phrase that moved to ARB still counts when the source
    reads a key (`l10n.<key>` / `LoopL10n.current.<key>`) whose zh value
    contains it, or when the fragment is a key reference itself. A key whose
    zh value is an interpolation template (`共 {count} 条`) counts when the
    fragment, with the interpolated part taken out, matches the template's
    fixed pieces in order.
    """

    if fragment in text:
        return True
    if not L.CJK.search(fragment):
        return False
    zh, _ = arb_tables(root)
    read = set(keys_read(text))
    for key in read:
        value = zh.get(key, "")
        if not value:
            continue
        if fragment in value:
            return True
        if "{" in value and _template_matches(value, fragment):
            return True
    return False


def copy_mentions(root: Path, text: str, fragment: str) -> bool:
    """For a forbidden phrase: [fragment] is in [text] or in the zh value of
    a key [text] reads, as plain text. No template matching: a placeholder
    would let `社区 {name}` "say" `社区 Tab`."""

    if fragment in text:
        return True
    if not L.CJK.search(fragment):
        return False
    zh, _ = arb_tables(root)
    return any(fragment in zh.get(key, "") for key in keys_read(text))


def _template_matches(template: str, fragment: str) -> bool:
    """[fragment] is an instance of [template], or of a stretch of it that
    carries CJK fixed text: each fixed piece appears in order, anything stands
    in for the placeholders (`共 3 条` against `共 {n} 条 · {t}`)."""

    parts = [p for p in re.split(r"(\{[^{}]*\})", template) if p]

    def is_slot(piece: str) -> bool:
        return re.fullmatch(r"\{[^{}]*\}", piece) is not None

    for k in range(len(parts)):
        for j in range(len(parts), k, -1):
            sub = parts[k:j]
            if not any(not is_slot(p) and L.CJK.search(p) for p in sub):
                continue
            regex = "".join(".+?" if is_slot(p) else re.escape(p) for p in sub)
            if re.fullmatch(regex, fragment, flags=re.S):
                return True
    return False


def check_no_hardcoded_cjk(root: Path, vocabulary, step_ids) -> list[str]:
    errors = list(_check.violations(root))
    en, zh, merge_errors = _merge.build()
    errors.extend(f"lib/l10n/fragments: {e}" for e in merge_errors)
    for name, data in (("app_en.arb", en), ("app_zh.arb", zh)):
        path = root / "lib/l10n" / name
        if not path.is_file() or path.read_text(encoding="utf-8") != _merge.dump(data):
            errors.append(
                f"lib/l10n/{name} is stale against lib/l10n/fragments; run "
                "python3 scripts/l10n/merge.py (decision 0281)"
            )
    # Decision 0070's vocabulary rules read zh copy wherever it lives.
    zh_values, en_values = arb_tables(root)
    for key, value in sorted(zh_values.items()):
        for pattern in step_ids:
            if pattern.search(value):
                errors.append(f"lib/l10n/app_zh.arb `{key}` shows a step id")
                break
        for pattern, label in vocabulary:
            if pattern.search(value):
                errors.append(
                    f"lib/l10n/app_zh.arb `{key}` shows {label}: see docs/copy-glossary.md"
                )
    for key, value in sorted(en_values.items()):
        if L.CJK.search(value) and not key.startswith("common_language"):
            errors.append(f"lib/l10n/app_en.arb `{key}` is not English: `{value[:30]}`")
    # The generated code must be the output of the checked-in ARB files.
    gen = root / "lib/l10n/gen/loop_localizations.dart"
    if gen.is_file():
        generated = gen.read_text(encoding="utf-8")
        for key in en_values:
            if not re.search(r"\b" + re.escape(key) + r"\b", generated):
                errors.append(
                    f"lib/l10n/gen is stale: `{key}` is missing; run bin/flutter gen-l10n"
                )
                break
    return errors


def check_l10n_locale_contract(root: Path) -> list[str]:
    errors: list[str] = []
    store = root / LOCALE_STORE_OWNER
    if not store.is_file():
        return [f"missing {LOCALE_STORE_OWNER} (decision 0281)"]
    source = store.read_text(encoding="utf-8")
    if "static const String localeKey = 'loop.locale';" not in source:
        errors.append("the locale store must keep its one `loop.locale` key (decision 0281)")
    code = re.sub(r"//[^\n]*", "", source)
    members = re.findall(r"\bpreferences\.(\w+)\b", code)
    if members != ["getString", "setString"]:
        errors.append("the locale store may call only SharedPreferencesAsync getString/setString")
    if re.search(r"\b(?:clear|remove|getAll|getKeys|getBool|setBool|getInt|setInt)\s*\(", code):
        errors.append("the locale store may only read or write its `loop.locale` key")
    settings = root / "lib/features/profile/settings/settings_screen.dart"
    if settings.is_file():
        text = settings.read_text(encoding="utf-8")
        at = text.find("ValueKey<String>('settings-language')")
        row = text[at : at + 600] if at >= 0 else ""
        if "showLoopLanguageSheet(" not in row:
            errors.append(
                "settings `settings-language` must open the language picker "
                "(`showLoopLanguageSheet`, decision 0281)"
            )
    locale = root / "lib/app/loop_locale.dart"
    if locale.is_file() and "LoopL10n.fallbackLocale" not in locale.read_text(encoding="utf-8"):
        errors.append("lib/app/loop_locale.dart must default to LoopL10n.fallbackLocale (decision 0281)")
    return errors
