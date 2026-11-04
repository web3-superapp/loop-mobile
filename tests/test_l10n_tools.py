"""Unit tests for scripts/l10n (decision 0281). Run: python3 -m unittest tests.test_l10n_tools"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts" / "l10n"))

import apply as A  # noqa: E402
import check as C  # noqa: E402
import extract as E  # noqa: E402
import harness_rules as H  # noqa: E402
import l10n_lib as L  # noqa: E402

import json  # noqa: E402
import tempfile  # noqa: E402
from unittest import mock  # noqa: E402


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

    def test_a_sibling_member_arrow_is_not_enclosing(self):
        src = (
            "class W extends StatelessWidget {\n  Widget build(BuildContext context) => X();\n\n"
            "  Widget _body() => switch (s) {\n    a => Text('中'),\n  };\n}\n"
        )
        self.assertEqual(self.access(src), "current")

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


# ---------------------------------------------------------------------------
# S358 / decision 0283: tool fixes.
# ---------------------------------------------------------------------------

TABLE = {
    "中文": ("x_k", {"zh": "中文", "en": "Text"}),
    "甲": ("x_a", {"zh": "甲", "en": "A"}),
}


def run(src: str, table=TABLE):
    todo: list[str] = []
    out, count = A.apply_source("lib/features/x/y.dart", src, table, todo, {})
    return out, count, todo


class DeclarationTest(unittest.TestCase):
    def test_local_final_stays_a_local(self):
        src = (
            "class W extends StatelessWidget {\n"
            "  Widget build(BuildContext context) {\n"
            "    final title = '中文';\n"
            "    return Text(title);\n  }\n}\n"
        )
        out, count, _ = run(src)
        self.assertEqual(count, 1)
        self.assertIn("final title = context.l10n.x_k;", out)
        self.assertNotIn("get title", out)

    def test_local_const_becomes_final(self):
        src = "void f() {\n  const label = '中文';\n  print(label);\n}\n"
        out, _, _ = run(src)
        self.assertIn("final label = LoopL10n.current.x_k;", out)

    def test_member_and_top_level_const_become_getters(self):
        src = "const top = '中文';\n\nclass C {\n  static const label = '甲';\n}\n"
        out, count, _ = run(src)
        self.assertEqual(count, 2)
        self.assertIn("String get top => LoopL10n.current.x_k;", out)
        self.assertIn("static String get label => LoopL10n.current.x_a;", out)

    def test_static_const_map_becomes_a_getter(self):
        src = (
            "class C {\n"
            "  static const Map<String, String> labels = {'a': '甲', 'b': 'B'};\n"
            "}\n"
        )
        out, _, _ = run(src)
        self.assertIn(
            "static Map<String, String> get labels => {'a': LoopL10n.current.x_a, 'b': 'B'};",
            out,
        )
        self.assertNotIn("static Map<String, String> labels", out)

    def test_typed_const_collection_literal_becomes_a_getter(self):
        src = "const labels = <String, String>{'a': '甲'};\n"
        out, _, _ = run(src)
        self.assertIn("Map<String, String> get labels => <String, String>{'a': LoopL10n.current.x_a};", out)


class ContextParamTest(unittest.TestCase):
    def test_non_build_context_param_reads_current(self):
        src = (
            "String describe(NetworkDiagnosticsContext context) {\n"
            "  return '中文';\n}\n"
        )
        out, _, _ = run(src)
        self.assertIn("LoopL10n.current.x_k", out)
        self.assertNotIn("context.l10n", out)

    def test_build_context_and_untyped_closure_read_context(self):
        self.assertEqual(A.context_param("(BuildContext context)"), "build")
        self.assertEqual(A.context_param("(context, ref)"), "build")
        self.assertEqual(A.context_param("(BuildContext? context)"), "build")
        self.assertEqual(A.context_param("(Foo context)"), "other")
        self.assertIsNone(A.context_param("(String contextId)"))


class ImportPlacementTest(unittest.TestCase):
    def test_import_goes_after_library(self):
        src = "/// Doc.\nlibrary;\n\nconst a = 1;\n"
        out = A.ensure_import(src)
        self.assertLess(out.index("library;"), out.index(A.IMPORT))

    def test_import_goes_after_a_leading_comment_not_inside_annotations(self):
        src = "// Copyright.\n\n@immutable\nclass C {}\n"
        out = A.ensure_import(src)
        self.assertLess(out.index("// Copyright."), out.index(A.IMPORT))
        self.assertLess(out.index(A.IMPORT), out.index("@immutable"))
        self.assertIn("@immutable\nclass C {}", out)

    def test_part_file_gets_no_import(self):
        src = "part of 'a.dart';\n\nconst a = '中文';\n"
        self.assertEqual(A.ensure_import(src), src)


class FileScopeTest(unittest.TestCase):
    def test_sibling_files_are_scanned(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            folder = root / "lib" / "features" / "x"
            folder.mkdir(parents=True)
            (folder / "a.dart").write_text("final a = '中文';\n", encoding="utf-8")
            (folder / "b.dart").write_text("final b = '开发预览';\n", encoding="utf-8")
            with mock.patch.object(L, "ROOT", root):
                files = A.sibling_files({"lib/features/x/a.dart"})
            self.assertEqual(files, {"lib/features/x/a.dart", "lib/features/x/b.dart"})

    def test_second_run_still_knows_migrated_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root / "lib").mkdir()
            (root / "lib" / "a.dart").write_text("final a = LoopL10n.current.x_k;\n", encoding="utf-8")
            frag = root / "x.json"
            frag.write_text(
                json.dumps(
                    {
                        "x_k": {"zh": "中文", "en": "Text"},
                        "x_unused": {"zh": "未用", "en": "Unused"},
                        "x_t": {"zh": "共 {n} 条", "en": "{n} items"},
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            with mock.patch.object(L, "ROOT", root):
                self.assertEqual(A.already_migrated([frag]), {"中文": "Text"})


class ForceTestsTest(unittest.TestCase):
    def templates(self, entries: dict) -> list:
        with tempfile.TemporaryDirectory() as tmp:
            frag = Path(tmp) / "f.json"
            frag.write_text(json.dumps(entries, ensure_ascii=False), encoding="utf-8")
            return A.force_templates([frag])

    def test_template_without_fixed_chinese_is_skipped(self):
        self.assertFalse(A.force_template_usable("{a} · {b}"))
        self.assertFalse(A.force_template_usable("{a}：{b}"))
        self.assertTrue(A.force_template_usable("已选 {n} 条"))
        self.assertFalse(A.force_template_usable("{a}的{b}"))

    def test_most_specific_template_wins_and_cjk_captures_are_refused(self):
        t = self.templates(
            {
                "a": {"zh": "已选 {n}", "en": "{n} selected"},
                "b": {"zh": "已选 {n} 条", "en": "{n} selected"},
            }
        )
        self.assertEqual(A.force_rewrite("已选 1 条", t), "1 selected")
        t2 = self.templates({"a": {"zh": "已选 {n}", "en": "{n} selected"}})
        self.assertIsNone(A.force_rewrite("已选 1 条", t2))

    def test_icu_plural_is_expanded(self):
        en = "{count, plural, =1{1 member} other{{count} members}}"
        self.assertEqual(A.expand_icu(en, {"count": "1"}), "1 member")
        self.assertEqual(A.expand_icu(en, {"count": "12"}), "12 members")
        self.assertEqual(A.expand_icu("{n, plural, one{# day} other{# days}} left", {"n": "3"}), "3 days left")
        self.assertIsNone(A.expand_icu(en, {"count": "x"}))
        t = self.templates({"a": {"zh": "{count} 位成员", "en": en}})
        self.assertEqual(A.force_rewrite("3 位成员", t), "3 members")

    def test_test_names_and_stream_zh_are_left_alone(self):
        t = self.templates({"a": {"zh": "发送消息", "en": "Send message"}})
        src = (
            "void main() {\n"
            "  testWidgets('发送消息', (tester) async {\n"
            "    expect(find.text('发送消息'), findsOneWidget);\n"
            "    expect(find.text('流的中文'), findsOneWidget);\n"
            "  });\n}\n"
        )
        out, n = A.force_source(src, t, {"发送消息X", "流的中文"})
        self.assertEqual(n, 1)
        self.assertIn("testWidgets('发送消息'", out)
        self.assertIn("find.text('Send message')", out)
        out2, n2 = A.force_source(src, t, {"发送消息"})
        self.assertEqual(n2, 0)

    def test_support_and_fixture_files_are_protected(self):
        self.assertTrue(A.protected_test_file("test/support/s7_page_harness.dart"))
        self.assertTrue(A.protected_test_file("test/s171_launch2_dynamic_testnet_fixtures_test.dart"))
        self.assertTrue(A.protected_test_file("test/fixtures/a.dart"))
        self.assertFalse(A.protected_test_file("test/s7_referral_test.dart"))


class ExtractEmptyFragmentTest(unittest.TestCase):
    def test_a_directory_without_copy_writes_no_fragment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            folder = root / "lib" / "core" / "empty"
            folder.mkdir(parents=True)
            (folder / "a.dart").write_text("final a = 'plain';\nfinal k = ValueKey('键');\n", encoding="utf-8")
            with mock.patch.object(L, "ROOT", root):
                fragments, _ = E.extract([folder], None)
            self.assertEqual(dict(fragments), {})


class CjkRangeTest(unittest.TestCase):
    def test_full_width_punctuation_counts_but_full_width_latin_does_not(self):
        for ch in "，。：；？！（）「」、　":
            self.assertTrue(L.CJK.search(ch), ch)
        for ch in "ａｅｚＡ０9a·…—":
            self.assertFalse(L.CJK.search(ch), ch)

    def test_punctuation_only_literal_is_reported(self):
        src = "final s = items.join('；');\n"
        self.assertEqual([s.group.text for s in sites(src) if not s.skip], ["；"])


class CopyPresentTest(unittest.TestCase):
    def setUp(self):
        self.root = Path("/nonexistent-s358")
        H._ARB_CACHE[self.root] = (
            {
                "x_count": "共 {count} 条 · {time}",
                "x_name": "社区 {name}",
                "x_plain": "推送尚不可用",
            },
            {"x_count": "{count} items · {time}", "x_name": "Community {name}", "x_plain": "Push isn't available yet"},
        )

    def tearDown(self):
        H._ARB_CACHE.pop(self.root, None)

    def test_template_copy_counts_when_read(self):
        text = "Text(context.l10n.x_count(n, t))"
        self.assertTrue(H.copy_present(self.root, text, "共 3 条"))
        self.assertTrue(H.copy_present(self.root, text, "共 3 条 · 刚刚"))
        self.assertFalse(H.copy_present(self.root, "Text(other)", "共 3 条"))
        self.assertTrue(H.copy_present(self.root, "LoopL10n.current.x_plain", "推送尚不可用"))

    def test_forbidden_phrases_do_not_match_through_a_placeholder(self):
        text = "context.l10n.x_name(name)"
        self.assertFalse(H.copy_mentions(self.root, text, "社区 Tab"))
        self.assertTrue(H.copy_mentions(self.root, "LoopL10n.current.x_plain", "尚不可用"))

    def test_copy_read_defaults_to_zh(self):
        text = "context.l10n.x_plain"
        self.assertEqual(H.copy_read(self.root, text), ["推送尚不可用"])
        self.assertEqual(H.copy_read(self.root, text, ("zh", "en")), ["推送尚不可用", "Push isn't available yet"])


if __name__ == "__main__":
    unittest.main()
