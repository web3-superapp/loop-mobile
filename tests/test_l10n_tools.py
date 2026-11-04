"""Unit tests for scripts/l10n (decision 0281). Run: python3 -m unittest tests.test_l10n_tools"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts" / "l10n"))

import apply as A  # noqa: E402
import check as C  # noqa: E402
import extract as E  # noqa: E402
import l10n_lib as L  # noqa: E402


def sites(source: str):
    return [s for s in L.literal_sites("lib/features/x/y.dart", source)[0]]


class LexerTest(unittest.TestCase):
    def test_skips_comments_keys_and_logs(self):
        src = (
            "// 注释 '不是'\n"
            "/// 文档\n"
            "final a = ValueKey<String>('键');\n"
            "void f() { debugPrint('日志'); assert(x, '断言'); }\n"
            "final b = Semantics(identifier: '标识', label: '标签');\n"
            "final c = Text('文案');\n"
        )
        live = [s.group.text for s in sites(src) if not s.skip]
        self.assertEqual(live, ["标签", "文案"])

    def test_interpolation_and_adjacent_concatenation(self):
        src = "final t = '你好 $name，' '共 ${items.length} 条';\n"
        (site,) = [s for s in sites(src) if not s.skip]
        zh, placeholders, exprs, problem = E.message_of(site.group)
        self.assertEqual(zh, "你好 {name}，共 {items} 条")
        self.assertEqual(exprs, ["name", "items.length"])
        self.assertIsNone(problem)

    def test_nested_cjk_is_reported(self):
        src = "final t = '${on ? '开' : '关'}';\n"
        (site,) = sites(src)
        self.assertIn("only inside", E.message_of(site.group)[3])

    def test_raw_and_triple_strings(self):
        src = "final a = r'原样$x';\nfinal b = '''多\n行''';\n"
        texts = [s.group.text for s in sites(src)]
        self.assertEqual(texts, ["原样$x", "多\n行"])


class AccessTest(unittest.TestCase):
    def access(self, src: str) -> str:
        lexer = L.Lexer(src).run()
        mask = L.mask_source(src, lexer)
        return A.access_for(mask, src.index("'中"))[0]

    def test_build_uses_context(self):
        self.assertEqual(
            self.access("class W extends StatelessWidget {\n  Widget build(BuildContext context) {\n    return Text('中');\n  }\n}\n"),
            "context",
        )

    def test_builder_closure_uses_context(self):
        self.assertEqual(self.access("final w = Builder(builder: (context) => Text('中'));\n"), "context")

    def test_top_level_uses_current(self):
        self.assertEqual(self.access("String label() => '中';\n"), "current")


class EnumTest(unittest.TestCase):
    def test_enum_label_becomes_switch_getter(self):
        src = (
            "enum S {\n  a('a', '甲'),\n  b('b', 'B');\n\n"
            "  const S(this.wire, this.label);\n\n  final String wire;\n  final String label;\n}\n"
        )
        table = {"甲": ("x_a", {"zh": "甲", "en": "A"})}
        out, count = A.apply_enums("lib/x.dart", src, table, [], {})
        self.assertEqual(count, 1)
        self.assertIn("a('a')", out)
        self.assertIn("const S(this.wire)", out)
        self.assertIn("S.a => LoopL10n.current.x_a", out)
        self.assertIn("S.b => 'B'", out)
        self.assertNotIn("'甲'", out)


class PendingTest(unittest.TestCase):
    def test_negation_carves_out_a_subdirectory(self):
        entries = ["lib/features/profile", "!lib/features/profile/settings"]
        self.assertTrue(C.is_pending("lib/features/profile/x.dart", entries))
        self.assertFalse(C.is_pending("lib/features/profile/settings/y.dart", entries))
        self.assertFalse(C.is_pending("lib/features/scan/z.dart", entries))


if __name__ == "__main__":
    unittest.main()
