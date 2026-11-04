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


def copy_present(root: Path, text: str, fragment: str) -> bool:
    """Whether [fragment] is in [text], directly or as ARB copy it reads.

    A required Chinese phrase that moved to ARB still counts when the source
    reads a key (`l10n.<key>` / `LoopL10n.current.<key>`) whose zh value
    contains it, or when the fragment is a key reference itself.
    """

    if fragment in text:
        return True
    if not L.CJK.search(fragment):
        return False
    zh, _ = arb_tables(root)
    for key, value in zh.items():
        if fragment in value and re.search(r"(?:l10n|LoopL10n\.current)\s*\.\s*" + re.escape(key) + r"\b", text):
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
