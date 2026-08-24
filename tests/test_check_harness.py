from __future__ import annotations

import copy
import importlib.util
import plistlib
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


def write_audio_room_native_fixture(
    root: Path,
    *,
    include_android_microphone: bool = True,
    include_ios_microphone: bool = True,
) -> None:
    (root / "pubspec.yaml").write_text("name: fixture\n", encoding="utf-8")
    (root / "pubspec.lock").write_text("packages: {}\n", encoding="utf-8")
    manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    manifest.parent.mkdir(parents=True)
    permission_lines: list[str] = []
    for name in sorted(check_harness.ANDROID_AUDIO_ROOM_PERMISSIONS):
        if name == "android.permission.RECORD_AUDIO" and not include_android_microphone:
            continue
        permission_lines.append(f'    <uses-permission android:name="{name}" />')
    permission_lines.extend(
        f'    <uses-permission android:name="{name}" tools:node="remove" />'
        for name in sorted(check_harness.ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS)
    )
    declared_permission_lines = [
        f'    <permission android:name="{name}" tools:node="remove" />'
        for name in sorted(check_harness.ANDROID_AUDIO_ROOM_REMOVED_DECLARED_PERMISSIONS)
    ]
    component_lines: list[str] = []
    for tag, names in check_harness.ANDROID_AUDIO_ROOM_REMOVED_COMPONENTS.items():
        component_lines.extend(
            f'        <{tag} android:name="{name}" tools:node="remove" />'
            for name in sorted(names)
        )
    manifest.write_text(
        "\n".join(
            [
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
                '    xmlns:tools="http://schemas.android.com/tools">',
                *permission_lines,
                *declared_permission_lines,
                "    <application>",
                *component_lines,
                "    </application>",
                "</manifest>",
                "",
            ]
        ),
        encoding="utf-8",
    )

    info_path = root / "ios" / "Runner" / "Info.plist"
    info_path.parent.mkdir(parents=True)
    info: dict[str, object] = {}
    if include_ios_microphone:
        info["NSMicrophoneUsageDescription"] = "用于在 Loop 语音房中发言"
    with info_path.open("wb") as stream:
        plistlib.dump(info, stream)
    (info_path.parent / "AppDelegate.swift").write_text("import UIKit\n", encoding="utf-8")


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

    def test_foreground_audio_room_native_contract_accepts_minimum_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            write_audio_room_native_fixture(root)
            result = check_harness.check_audio_room_native_contract(root)
        self.assertEqual([], result)

    def test_foreground_audio_room_native_contract_detects_missing_microphone_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            write_audio_room_native_fixture(
                root,
                include_android_microphone=False,
                include_ios_microphone=False,
            )
            result = check_harness.check_audio_room_native_contract(root)
        self.assertTrue(any("RECORD_AUDIO" in error for error in result))
        self.assertTrue(any("NSMicrophoneUsageDescription" in error for error in result))

    def test_foreground_audio_room_native_contract_rejects_dangerous_native_items(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            write_audio_room_native_fixture(root)

            manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
            manifest_text = manifest.read_text(encoding="utf-8")
            manifest_text = manifest_text.replace(
                '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" tools:node="remove" />',
                '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
            )
            manifest_text = manifest_text.replace(
                '<activity android:name="io.getstream.video.flutter.stream_video_push_notification.IncomingCallActivity" tools:node="remove" />',
                '<activity android:name="io.getstream.video.flutter.stream_video_push_notification.IncomingCallActivity" />',
            )
            manifest_text = manifest_text.replace(
                "    <application>",
                '    <uses-permission android:name="android.permission.CAMERA" />\n'
                '    <uses-feature android:name="android.hardware.camera" />\n'
                "    <application>",
            )
            manifest.write_text(manifest_text, encoding="utf-8")

            info_path = root / "ios" / "Runner" / "Info.plist"
            with info_path.open("rb") as stream:
                info = plistlib.load(stream)
            info["NSCameraUsageDescription"] = "camera"
            info["UIBackgroundModes"] = ["audio", "voip"]
            with info_path.open("wb") as stream:
                plistlib.dump(info, stream)

            entitlements_path = root / "ios" / "Runner" / "Runner.entitlements"
            with entitlements_path.open("wb") as stream:
                plistlib.dump({"aps-environment": "development"}, stream)
            (root / "ios" / "Runner" / "AppDelegate.swift").write_text(
                "import CallKit\nimport PushKit\nlet provider: CXProvider? = nil\n",
                encoding="utf-8",
            )
            (root / "pubspec.yaml").write_text(
                "name: fixture\ndependencies:\n  stream_video_push_notification: 1.4.3\n",
                encoding="utf-8",
            )
            result = check_harness.check_audio_room_native_contract(root)

        expected_fragments = (
            "POST_NOTIFICATIONS",
            "IncomingCallActivity",
            "android.permission.CAMERA",
            "android.hardware.camera",
            "NSCameraUsageDescription",
            "UIBackgroundModes",
            "aps-environment",
            "import CallKit",
            "import PushKit",
            "CXProvider",
            "stream_video_push_notification",
        )
        for fragment in expected_fragments:
            self.assertTrue(
                any(fragment in error for error in result),
                msg=f"expected foreground Audio Room guard error containing {fragment!r}: {result}",
            )


if __name__ == "__main__":
    unittest.main()
