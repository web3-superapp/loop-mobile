from __future__ import annotations

import copy
import importlib.util
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_harness",
    REPOSITORY_ROOT / "scripts" / "check_harness.py",
)
assert SPEC is not None and SPEC.loader is not None
check_harness = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check_harness)


class HarnessTests(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual([], check_harness.validate(REPOSITORY_ROOT))

    def test_navigation_contract_requires_launch(self) -> None:
        profile, errors = check_harness.load_profile(REPOSITORY_ROOT)
        self.assertEqual([], errors)
        assert profile is not None
        changed = copy.deepcopy(profile)
        changed["project"]["primary_destinations"].remove("Launch")
        result = check_harness.check_profile(REPOSITORY_ROOT, changed)
        self.assertTrue(any("preserve Home / Market / Launch" in error for error in result))

    def test_dependency_pin_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            text = (REPOSITORY_ROOT / "pubspec.yaml").read_text(encoding="utf-8")
            (root / "pubspec.yaml").write_text(text.replace("  dio: 5.11.0", "  dio: ^5.11.0"), encoding="utf-8")
            result = check_harness.check_dependency_pins(root)
        self.assertIn("pubspec.yaml must pin `dio` exactly to `5.11.0`", result)

    def test_lock_parser_reads_exact_versions(self) -> None:
        versions = check_harness.lockfile_versions(
            'packages:\n  dio:\n    dependency: "direct main"\n    version: "5.11.0"\n'
        )
        self.assertEqual("5.11.0", versions["dio"])

    def test_provider_shortcuts_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "unsafe.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "final log = PrivyLogLevel.verbose;\n"
                "final token = client.devToken('arbitrary-user');\n"
                "await Firebase.initializeApp();\n",
                encoding="utf-8",
            )
            result = check_harness.check_source_guards(root)
        self.assertEqual(3, len(result))

    def test_privileged_secret_paths_are_rejected(self) -> None:
        result = check_harness.check_secret_paths(
            [Path(".env.local"), Path("AuthKey_example.p8"), Path("firebase-adminsdk.json")]
        )
        self.assertEqual(3, len(result))

    def test_markdown_sections_require_real_content(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "decision.md"
            path.write_text("# Decision\n\n## Status\n\n## Context\nEvidence\n", encoding="utf-8")
            sections = check_harness.markdown_sections(path)
        self.assertEqual("", sections["Status"])
        self.assertEqual("Evidence", sections["Context"])

    def test_native_identity_drift_is_detected(self) -> None:
        contracts = {"identity.txt": ('applicationId = "com.cywd.loop"',)}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "identity.txt").write_text('applicationId = "com.example.loop"\n', encoding="utf-8")
            result = check_harness.require_fragments(root, contracts)
        self.assertTrue(any("com.cywd.loop" in error for error in result))

    def test_android_release_debug_signing_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gradle = root / "android" / "app" / "build.gradle.kts"
            gradle.parent.mkdir(parents=True)
            gradle.write_text(
                'release { signingConfig = signingConfigs.getByName("debug") }\n',
                encoding="utf-8",
            )
            result = check_harness.check_native_matrix(root)
        self.assertTrue(any("debug signing key" in error for error in result))


if __name__ == "__main__":
    unittest.main()
