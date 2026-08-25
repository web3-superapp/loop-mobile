#!/usr/bin/env python3
"""Validate Loop Mobile's repository-level engineering harness."""

from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PRIMARY_DESTINATIONS = ["Home", "Market", "Launch", "Chat", "Wallet", "Profile"]
PINNED_DEPENDENCIES = {
    "cupertino_icons": "1.0.8",
    "decimal": "3.2.6",
    "dio": "5.11.0",
    "firebase_core": "4.13.0",
    "firebase_messaging": "16.5.0",
    "flutter_lints": "6.0.0",
    "flutter_riverpod": "3.4.2",
    "go_router": "17.5.0",
    "privy_flutter": "0.10.1",
    "stream_chat_flutter": "10.3.0",
    "stream_chat_persistence": "10.3.0",
    "stream_video_flutter": "1.4.3",
    "uuid": "4.6.0",
}
REQUIRED_FILES = (
    ".gitignore",
    ".metadata",
    "README.md",
    "AGENTS.md",
    "harness.json",
    "pubspec.yaml",
    "pubspec.lock",
    "bin/dart",
    "bin/flutter",
    "bin/loop-sdk",
    "ios/Podfile",
    "ios/Podfile.lock",
    "scripts/check_harness.py",
    "tests/test_check_harness.py",
    "docs/product-decisions.md",
    "docs/product/implementation-constraints.md",
    "docs/decisions/0001-merge-verified-mobile-foundation.md",
    "docs/decisions/0006-use-identifier-only-stream-token-cards.md",
    "docs/decisions/0007-centralize-notification-intents-before-provider-ingress.md",
    "docs/failures/flutter-gradle-version-floor.md",
    "docs/failures/providerless-notification-fixtures.md",
    "docs/failures/privy-android-compile-sdk.md",
    "docs/failures/production-chat-preview-route-leak.md",
    "docs/failures/swiftpm-file-picker-cold-cache.md",
    "docs/harness/adoption-report.md",
    "docs/open-source-attribution.md",
    "docs/phase-0/compatibility-report.md",
    "docs/phase-1/frontend-integration-report.md",
    "lib/core/navigation/stream_channel_route.dart",
    "lib/integrations/notifications/loop_notification_router.dart",
    "test/loop_notification_router_test.dart",
    "test/notifications_screen_test.dart",
)
CHAT_PREVIEW_ONLY_ROUTES = (
    "/chat/group",
    "/chat/dm",
    "/chat/group-info",
    "/chat/requests",
    "/chat/search",
    "/preview/token-card",
    "/preview/contract-facts",
    "/preview/asset-message",
)
TOKEN_CARD_EXTRA_DATA_KEYS = frozenset(
    {
        "loop_schema",
        "asset_id",
        "chain_id",
        "contract_id",
        "snapshot_at",
    }
)
TOKEN_CARD_RENDER_IMPORTS = {
    "lib/features/chat/attachments/token_card_attachment.dart": frozenset(
        {"'package:flutter/foundation.dart' show immutable"}
    ),
    "lib/features/chat/attachments/stream_token_card_attachment_policy.dart": frozenset(
        {
            "'package:loop_mobile/features/chat/attachments/token_card_attachment.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show Attachment",
        }
    ),
    "lib/features/chat/attachments/stream_token_card_attachment_builder.dart": frozenset(
        {
            "'package:flutter/widgets.dart' show BuildContext, Widget",
            "'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart'",
            "'package:loop_mobile/features/chat/widgets/token_card_view.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show Attachment, Message, StreamAttachmentWidgetBuilder",
        }
    ),
    "lib/features/chat/attachments/stream_token_card_message_preview_formatter.dart": frozenset(
        {
            "'package:flutter/widgets.dart' show BuildContext, TextSpan",
            "'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show ChannelModel, DraftMessage, Message, MessageState, StreamMessagePreviewFormatter, User",
        }
    ),
    "lib/features/chat/widgets/token_card_view.dart": frozenset(
        {
            (
                "'package:flutter/material.dart' show Alignment, Border, BoxDecoration, BoxShape, "
                "BuildContext, ClipRRect, Column, Color, Container, CrossAxisAlignment, "
                "DecoratedBox, EdgeInsets, Expanded, FontWeight, Icon, IconData, Icons, "
                "MainAxisSize, OutlinedButton, Padding, Positioned, Row, Semantics, SizedBox, "
                "Stack, StatelessWidget, Text, TextOverflow, Theme, ValueKey, Widget, immutable"
            ),
            (
                "'package:loop_mobile/core/theme/loop_theme.dart' show "
                "LoopColors, LoopRadius"
            ),
            "'package:loop_mobile/features/chat/attachments/token_card_attachment.dart'",
        }
    ),
}
DECISION_SECTIONS = ("Status", "Context", "Decision", "Consequences")
FAILURE_SECTIONS = ("Summary", "Root Cause", "Detection", "Prevention", "Evidence")
ADOPTION_SECTIONS = (
    "Baseline",
    "Adopted surfaces",
    "Rules and checks",
    "Verification",
    "Assumptions and follow-up",
    "Failure memory",
    "Effectiveness",
)
ANDROID_NAME = "{http://schemas.android.com/apk/res/android}name"
ANDROID_TOOLS_NODE = "{http://schemas.android.com/tools}node"
ANDROID_AUDIO_ROOM_PERMISSIONS = frozenset(
    {
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS",
    }
)
ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS = frozenset(
    {
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.USE_FULL_SCREEN_INTENT",
        "android.permission.DISABLE_KEYGUARD",
        "android.permission.VIBRATE",
        "android.permission.WAKE_LOCK",
        "android.permission.ACCESS_NOTIFICATION_POLICY",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.MANAGE_OWN_CALLS",
        "android.permission.FOREGROUND_SERVICE_PHONE_CALL",
        "android.permission.FOREGROUND_SERVICE_MICROPHONE",
        "android.permission.FOREGROUND_SERVICE_CAMERA",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION",
        "${applicationId}.PERMISSION_CALL",
    }
)
ANDROID_AUDIO_ROOM_REMOVED_DECLARED_PERMISSIONS = frozenset(
    {"${applicationId}.PERMISSION_CALL"}
)
ANDROID_AUDIO_ROOM_REMOVED_COMPONENTS = {
    "activity": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallActivity",
            "io.getstream.video.flutter.stream_video_push_notification.TransparentActivity",
        }
    ),
    "receiver": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallBroadcastReceiver",
        }
    ),
    "service": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallNotificationService",
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallConnectionService",
            "io.getstream.video.flutter.stream_video_flutter.service.StreamCallService",
            "io.getstream.video.flutter.stream_video_flutter.service.StreamScreenShareService",
        }
    ),
}
ANDROID_AUDIO_ROOM_FORBIDDEN_ACTIVE_PERMISSIONS = frozenset(
    {*ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS, "android.permission.CAMERA"}
)
IOS_AUDIO_ROOM_FORBIDDEN_ENTITLEMENTS = frozenset(
    {
        "aps-environment",
        "com.apple.developer.aps-environment",
        "com.apple.developer.background-modes",
        "com.apple.developer.usernotifications.communication",
        "com.apple.developer.voip",
    }
)
IOS_AUDIO_ROOM_FORBIDDEN_RUNNER_MARKERS = (
    "import CallKit",
    "import PushKit",
    "CXProvider",
    "CXCallController",
    "PKPushRegistry",
)
NOTIFICATION_ROUTER_PATH = Path(
    "lib/integrations/notifications/loop_notification_router.dart"
)
NOTIFICATION_PROVIDER_INGRESS_PATH = Path(
    "lib/integrations/notifications/firebase_notification_ingress.dart"
)
NOTIFICATION_COORDINATOR_PATH = Path(
    "lib/app/notifications/loop_notification_coordinator.dart"
)
NOTIFICATION_GLOBAL_INGRESS_PATTERNS = (
    (re.compile(r"\bFirebaseMessaging\s*\.\s*instance\b"), "FirebaseMessaging.instance"),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onBackgroundMessage\s*\("),
        "FirebaseMessaging.onBackgroundMessage",
    ),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onMessageOpenedApp\b"),
        "FirebaseMessaging.onMessageOpenedApp",
    ),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onMessage\b"),
        "FirebaseMessaging.onMessage",
    ),
    (re.compile(r"\.\s*getInitialMessage\s*\("), ".getInitialMessage("),
)
NOTIFICATION_ROUTER_IMPORTS = frozenset(
    {
        "'dart:collection'",
        "'package:loop_mobile/core/navigation/stream_channel_route.dart'",
    }
)
NOTIFICATION_PROVIDER_IMPORT_ALLOWED_PATHS = frozenset(
    {
        Path("lib/app/bootstrap/sdk_compatibility.dart"),
        NOTIFICATION_PROVIDER_INGRESS_PATH,
    }
)
NOTIFICATION_PROVIDER_IMPORT_MARKERS = (
    "package:firebase_core/firebase_core.dart",
    "package:firebase_messaging/firebase_messaging.dart",
)
NOTIFICATION_KIND_MEMBERS = frozenset(
    {"chatMessage", "audioRoomActivity", "systemNotice"}
)
NOTIFICATION_INTENT_CLASSES = frozenset(
    {
        "LoopChatNotificationIntent",
        "LoopAudioRoomNotificationIntent",
        "LoopNotificationCenterIntent",
    }
)
NOTIFICATION_ROUTE_LITERALS = frozenset(
    {
        "/chat/channel/${Uri.encodeComponent(channel.cid)}",
        "/chat/voice",
        "/notifications",
    }
)
NOTIFICATION_ROUTER_CONSUMER_PATHS = frozenset(
    {NOTIFICATION_ROUTER_PATH, NOTIFICATION_COORDINATOR_PATH}
)
NOTIFICATION_ROUTER_IMPORT = (
    "package:loop_mobile/integrations/notifications/loop_notification_router.dart"
)
NOTIFICATION_ROUTER_CONSTRUCTION_PATTERN = re.compile(
    r"\b(?:LoopNotificationRouter|LoopNotificationSessionContext\s*\.\s*authenticated)\s*\("
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_dart_comments(text: str) -> str:
    """Remove Dart comments while preserving strings and line boundaries."""

    output: list[str] = []
    index = 0
    quote: str | None = None
    triple = False
    while index < len(text):
        if quote is not None:
            closing = quote * (3 if triple else 1)
            if text.startswith(closing, index):
                output.append(closing)
                index += len(closing)
                quote = None
                triple = False
                continue
            character = text[index]
            output.append(character)
            index += 1
            if not triple and character == "\\" and index < len(text):
                output.append(text[index])
                index += 1
            continue

        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            if newline < 0:
                output.extend(" " * (len(text) - index))
                break
            output.extend(" " * (newline - index))
            output.append("\n")
            index = newline + 1
            continue

        if text.startswith("/*", index):
            depth = 1
            output.extend("  ")
            index += 2
            while index < len(text) and depth:
                if text.startswith("/*", index):
                    depth += 1
                    output.extend("  ")
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    output.extend("  ")
                    index += 2
                else:
                    output.append("\n" if text[index] == "\n" else " ")
                    index += 1
            continue

        if text.startswith("'''", index) or text.startswith('\"\"\"', index):
            quote = text[index]
            triple = True
            output.append(quote * 3)
            index += 3
            continue
        if text[index] in ("'", '"'):
            quote = text[index]
            output.append(text[index])
            index += 1
            continue
        output.append(text[index])
        index += 1
    return "".join(output)


def strip_dart_comments_and_strings(text: str) -> str:
    """Remove comments and string bodies before matching executable Dart."""

    source = strip_dart_comments(text)
    output: list[str] = []
    index = 0
    quote: str | None = None
    triple = False
    while index < len(source):
        if quote is not None:
            closing = quote * (3 if triple else 1)
            if source.startswith(closing, index):
                output.extend(" " * len(closing))
                index += len(closing)
                quote = None
                triple = False
                continue
            character = source[index]
            output.append("\n" if character == "\n" else " ")
            index += 1
            if not triple and character == "\\" and index < len(source):
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
            continue

        if source.startswith("'''", index) or source.startswith('\"\"\"', index):
            quote = source[index]
            triple = True
            output.extend("   ")
            index += 3
            continue
        if source[index] in ("'", '"'):
            quote = source[index]
            output.append(" ")
            index += 1
            continue
        output.append(source[index])
        index += 1
    return "".join(output)


def git_visible_paths(root: Path) -> tuple[list[Path], str | None]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return [], result.stderr.decode("utf-8", errors="replace").strip()
    return [
        Path(item.decode("utf-8", errors="surrogateescape"))
        for item in result.stdout.split(b"\0")
        if item
    ], None


def load_profile(root: Path) -> tuple[dict[str, Any] | None, list[str]]:
    path = root / "harness.json"
    if not path.is_file():
        return None, ["missing required harness file: harness.json"]
    try:
        value = json.loads(read_text(path))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return None, [f"harness.json is not valid UTF-8 JSON: {error}"]
    if not isinstance(value, dict):
        return None, ["harness.json must contain a JSON object"]
    return value, []


def check_required_files(root: Path) -> list[str]:
    return [f"missing required harness file: {path}" for path in REQUIRED_FILES if not (root / path).is_file()]


def check_profile(root: Path, profile: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if type(profile.get("schema_version")) is not int or profile.get("schema_version") != 1:
        errors.append("harness.json `schema_version` must be 1")

    project = profile.get("project")
    application = profile.get("application")
    commands = profile.get("commands")
    if not isinstance(project, dict):
        return errors + ["harness.json `project` must be an object"]
    if not isinstance(application, dict):
        return errors + ["harness.json `application` must be an object"]
    if not isinstance(commands, dict):
        return errors + ["harness.json `commands` must be an object"]

    if project.get("phase") != "active":
        errors.append("harness.json project phase must remain `active`")
    purpose = project.get("purpose")
    if not isinstance(purpose, str) or not purpose.strip():
        errors.append("harness.json project purpose must be non-empty")
    if project.get("primary_destinations") != PRIMARY_DESTINATIONS:
        errors.append("harness.json must preserve Home / Market / Launch / Chat / Wallet / Profile in order")

    for field in ("ownership_boundaries",):
        value = project.get(field)
        if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
            errors.append(f"harness.json project `{field}` must be a non-empty string list")

    for field in ("stack", "package_managers", "manifests", "lockfiles", "source_roots", "generated_paths"):
        value = application.get(field)
        if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
            errors.append(f"harness.json application `{field}` must be a non-empty string list")

    for field in ("manifests", "lockfiles", "source_roots"):
        values = application.get(field)
        if isinstance(values, list):
            for value in values:
                if isinstance(value, str) and not (root / value).exists():
                    errors.append(f"registered application path does not exist: {value}")

    expected_commands = {
        "setup": "bin/flutter pub get",
        "lint": "bin/dart format --output=none --set-exit-if-changed lib test",
        "typecheck": "bin/flutter analyze",
        "test": "bin/flutter test",
        "build": "bin/flutter build apk --debug",
        "run": "bin/flutter run",
    }
    for name, expected in expected_commands.items():
        if commands.get(name) != expected:
            errors.append(f"harness.json `commands.{name}` must equal `{expected}`")

    expected_native = [
        "bin/flutter build apk --release",
        "bin/flutter build ios --debug --no-codesign",
        "bin/flutter build ios --release --no-codesign",
    ]
    if commands.get("native_release_matrix") != expected_native:
        errors.append("harness.json native release matrix has drifted")
    expected_harness = [
        "python3 scripts/check_harness.py",
        "python3 -m unittest discover -s tests -p 'test_*.py'",
    ]
    if commands.get("harness") != expected_harness:
        errors.append("harness.json harness command contract has drifted")
    return errors


def lockfile_versions(text: str) -> dict[str, str]:
    versions: dict[str, str] = {}
    current: str | None = None
    for line in text.splitlines():
        package = re.fullmatch(r"  ([a-z0-9_]+):", line)
        if package:
            current = package.group(1)
            continue
        version = re.fullmatch(r'    version: "([^"]+)"', line)
        if current and version:
            versions[current] = version.group(1)
            current = None
    return versions


def check_dependency_pins(root: Path) -> list[str]:
    errors: list[str] = []
    pubspec = root / "pubspec.yaml"
    lockfile = root / "pubspec.lock"
    if not pubspec.is_file():
        return errors
    text = read_text(pubspec)
    for package, version in PINNED_DEPENDENCIES.items():
        if not re.search(rf"^  {re.escape(package)}: {re.escape(version)}$", text, re.MULTILINE):
            errors.append(f"pubspec.yaml must pin `{package}` exactly to `{version}`")
    if "sdk: '>=3.13.1 <4.0.0'" not in text:
        errors.append("pubspec.yaml must require Dart >=3.13.1 <4.0.0")
    if "enable-swift-package-manager: false" not in text:
        errors.append("pubspec.yaml must disable Swift Package Manager per project")

    if lockfile.is_file():
        versions = lockfile_versions(read_text(lockfile))
        for package, version in PINNED_DEPENDENCIES.items():
            if versions.get(package) != version:
                errors.append(f"pubspec.lock must resolve `{package}` to `{version}`, found `{versions.get(package)}`")
    return errors


def require_fragments(root: Path, contracts: dict[str, tuple[str, ...]]) -> list[str]:
    errors: list[str] = []
    for relative, fragments in contracts.items():
        path = root / relative
        if not path.is_file():
            errors.append(f"missing compatibility contract file: {relative}")
            continue
        text = read_text(path)
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{relative} is missing locked value `{fragment}`")
    return errors


def check_native_matrix(root: Path) -> list[str]:
    errors = require_fragments(
        root,
        {
            ".metadata": ('revision: "6655482ec06e547f90abf8ae7590466f4415978d"',),
            "bin/loop-sdk": (
                "LOOP_FLUTTER_ROOT",
                "6655482ec06e547f90abf8ae7590466f4415978d",
                '\"dartSdkVersion\": \"3.13.1\"',
            ),
            "android/settings.gradle.kts": (
                'id("com.android.application") version "8.13.2" apply false',
                'id("org.jetbrains.kotlin.android") version "2.3.20" apply false',
            ),
            "android/gradle/wrapper/gradle-wrapper.properties": ("gradle-8.14-all.zip",),
            "android/app/build.gradle.kts": (
                'id("org.jetbrains.kotlin.android")',
                'namespace = "com.cywd.loop"',
                'applicationId = "com.cywd.loop"',
                "compileSdk = 36",
                "minSdk = 28",
                "targetSdk = 36",
                "JavaVersion.VERSION_17",
                "JvmTarget.JVM_17",
            ),
            "android/build.gradle.kts": (
                "afterEvaluate",
                'plugins.hasPlugin("com.android.library")',
                "extensions.configure<com.android.build.api.dsl.LibraryExtension>",
                "compileSdk = 36",
            ),
            "android/app/src/main/kotlin/com/cywd/loop/MainActivity.kt": ("package com.cywd.loop",),
            "ios/Podfile": ("platform :ios, '17.0'",),
            "ios/Podfile.lock": ("COCOAPODS: 1.16.2",),
            "ios/Runner.xcodeproj/project.pbxproj": (
                "PRODUCT_BUNDLE_IDENTIFIER = com.cywd.loop;",
                "PRODUCT_BUNDLE_IDENTIFIER = com.cywd.loop.RunnerTests;",
            ),
            "ios/Runner/Info.plist": ("<string>Loop</string>", "<string>loop</string>"),
        },
    )
    for relative in ("bin/flutter", "bin/dart", "bin/loop-sdk"):
        path = root / relative
        if path.is_file() and not path.stat().st_mode & 0o111:
            errors.append(f"{relative} must be executable")

    xcode = root / "ios/Runner.xcodeproj/project.pbxproj"
    if xcode.is_file():
        text = read_text(xcode)
        targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", text)
        if not targets or any(target != "17.0" for target in targets):
            errors.append(f"every iOS deployment target must be 17.0, found {sorted(set(targets))}")
        if "FlutterGeneratedPluginSwiftPackage" in text or "XCLocalSwiftPackageReference" in text:
            errors.append("iOS project still contains Flutter Swift Package Manager references")
    android_app = root / "android/app/build.gradle.kts"
    if android_app.is_file() and 'signingConfigs.getByName("debug")' in read_text(android_app):
        errors.append("Android release must not fall back to the development debug signing key")
    return errors


def _parse_xml(path: Path, label: str) -> tuple[ElementTree.Element | None, list[str]]:
    if not path.is_file():
        return None, [f"missing {label}: {path.relative_to(path.parents[3])}"]
    try:
        return ElementTree.parse(path).getroot(), []
    except (OSError, ElementTree.ParseError) as error:
        return None, [f"{label} is not valid XML: {error}"]


def _parse_plist(path: Path, label: str) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"missing {label}: {path}"]
    try:
        with path.open("rb") as stream:
            value = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        return None, [f"{label} is not a valid property list: {error}"]
    if not isinstance(value, dict):
        return None, [f"{label} must contain a dictionary"]
    return value, []


def _require_android_removals(
    elements: list[ElementTree.Element],
    expected_names: frozenset[str],
    label: str,
) -> list[str]:
    errors: list[str] = []
    by_name: dict[str, list[ElementTree.Element]] = {}
    for element in elements:
        name = element.get(ANDROID_NAME)
        if name:
            by_name.setdefault(name, []).append(element)
    for name in sorted(expected_names):
        matches = by_name.get(name, [])
        if not any(element.get(ANDROID_TOOLS_NODE) == "remove" for element in matches):
            errors.append(f"Android foreground Audio Room must remove {label} `{name}` with tools:node=\"remove\"")
        if any(element.get(ANDROID_TOOLS_NODE) != "remove" for element in matches):
            errors.append(f"Android foreground Audio Room must not activate {label} `{name}`")
    return errors


def check_audio_room_native_contract(root: Path) -> list[str]:
    """Keep the first Audio Room slice microphone-only and foreground-only."""

    errors: list[str] = []
    for relative in ("pubspec.yaml", "pubspec.lock"):
        package_file = root / relative
        if package_file.is_file() and "stream_video_push_notification" in read_text(package_file):
            errors.append(
                f"Foreground Audio Room must not link the auto-registering "
                f"`stream_video_push_notification` plugin in {relative}"
            )
    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, manifest_errors = _parse_xml(manifest_path, "Android main manifest")
    errors.extend(manifest_errors)
    if manifest is not None:
        permissions = list(manifest.findall("uses-permission"))
        by_name: dict[str, list[ElementTree.Element]] = {}
        for permission in permissions:
            name = permission.get(ANDROID_NAME)
            if name:
                by_name.setdefault(name, []).append(permission)

        for name in sorted(ANDROID_AUDIO_ROOM_PERMISSIONS):
            active = [
                permission
                for permission in by_name.get(name, [])
                if permission.get(ANDROID_TOOLS_NODE) != "remove"
            ]
            if len(active) != 1:
                errors.append(
                    f"Android foreground Audio Room must explicitly declare active permission `{name}` exactly once"
                )

        for name in sorted(ANDROID_AUDIO_ROOM_FORBIDDEN_ACTIVE_PERMISSIONS):
            if any(
                permission.get(ANDROID_TOOLS_NODE) != "remove"
                for permission in by_name.get(name, [])
            ):
                errors.append(f"Android foreground Audio Room must not activate permission `{name}`")

        errors.extend(
            _require_android_removals(
                permissions,
                ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS,
                "permission",
            )
        )
        errors.extend(
            _require_android_removals(
                list(manifest.findall("permission")),
                ANDROID_AUDIO_ROOM_REMOVED_DECLARED_PERMISSIONS,
                "declared permission",
            )
        )

        for feature in manifest.findall("uses-feature"):
            name = feature.get(ANDROID_NAME, "")
            if name.startswith("android.hardware.camera") and feature.get(ANDROID_TOOLS_NODE) != "remove":
                errors.append(f"Android foreground Audio Room must not activate camera feature `{name}`")

        application = manifest.find("application")
        if application is None:
            errors.append("Android main manifest must contain an application element")
        else:
            for tag, names in ANDROID_AUDIO_ROOM_REMOVED_COMPONENTS.items():
                errors.extend(
                    _require_android_removals(
                        list(application.findall(tag)),
                        names,
                        tag,
                    )
                )

    info_path = root / "ios/Runner/Info.plist"
    info, info_errors = _parse_plist(info_path, "iOS Runner Info.plist")
    errors.extend(info_errors)
    if info is not None:
        microphone_description = info.get("NSMicrophoneUsageDescription")
        if not isinstance(microphone_description, str) or not microphone_description.strip():
            errors.append("iOS foreground Audio Room requires a non-empty NSMicrophoneUsageDescription")
        if "NSCameraUsageDescription" in info:
            errors.append("iOS foreground Audio Room must not declare NSCameraUsageDescription")
        if "UIBackgroundModes" in info:
            errors.append("iOS foreground Audio Room must not declare UIBackgroundModes")

    ios_root = root / "ios"
    if ios_root.is_dir():
        for path in sorted(ios_root.rglob("*.entitlements")):
            entitlements, entitlement_errors = _parse_plist(
                path,
                f"iOS entitlements {path.relative_to(root)}",
            )
            errors.extend(entitlement_errors)
            if entitlements is None:
                continue
            for key in sorted(IOS_AUDIO_ROOM_FORBIDDEN_ENTITLEMENTS.intersection(entitlements)):
                errors.append(
                    f"iOS foreground Audio Room must not declare entitlement `{key}` in {path.relative_to(root)}"
                )

    runner_root = root / "ios/Runner"
    if runner_root.is_dir():
        for path in sorted(runner_root.rglob("*.swift")):
            text = read_text(path)
            for marker in IOS_AUDIO_ROOM_FORBIDDEN_RUNNER_MARKERS:
                if marker in text:
                    errors.append(
                        f"iOS foreground Audio Room must not initialize CallKit/PushKit in "
                        f"{path.relative_to(root)} (`{marker}`)"
                    )

    xcode_project = root / "ios/Runner.xcodeproj/project.pbxproj"
    if xcode_project.is_file():
        text = read_text(xcode_project)
        for capability in ("com.apple.BackgroundModes", "com.apple.Push"):
            if capability in text:
                errors.append(f"iOS foreground Audio Room must not enable Xcode capability `{capability}`")
    return errors


def markdown_sections(path: Path) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in read_text(path).splitlines():
        match = re.fullmatch(r"##\s+(.+?)\s*", line)
        if match:
            current = match.group(1).strip()
            sections.setdefault(current, [])
        elif current:
            sections[current].append(line)
    return {name: "\n".join(lines).strip() for name, lines in sections.items()}


def check_records(root: Path) -> list[str]:
    errors: list[str] = []
    for path in sorted((root / "docs/decisions").glob("*.md")):
        if not re.fullmatch(r"[0-9]{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md", path.name):
            errors.append(f"decision filename is invalid: {path.relative_to(root)}")
        sections = markdown_sections(path)
        for name in DECISION_SECTIONS:
            if not sections.get(name):
                errors.append(f"{path.relative_to(root)} requires non-empty `## {name}`")
    for path in sorted((root / "docs/failures").glob("*.md")):
        sections = markdown_sections(path)
        for name in FAILURE_SECTIONS:
            if not sections.get(name):
                errors.append(f"{path.relative_to(root)} requires non-empty `## {name}`")
    adoption = root / "docs/harness/adoption-report.md"
    if adoption.is_file():
        sections = markdown_sections(adoption)
        for name in ADOPTION_SECTIONS:
            if not sections.get(name):
                errors.append(f"{adoption.relative_to(root)} requires non-empty `## {name}`")
    return errors


def check_product_contract(root: Path) -> list[str]:
    errors = require_fragments(
        root,
        {
            "README.md": (
                "Repository phase: `active`.",
                "Home / Market / Launch / Chat / Wallet / Profile",
                "harness.json",
                "python3 scripts/check_harness.py",
            ),
            "AGENTS.md": (
                "Repository phase: `active`.",
                "Home / Market / Launch / Chat / Wallet / Profile",
                "Launchpad remains a first-class destination",
                "python3 scripts/check_harness.py",
            ),
            "docs/product/implementation-constraints.md": (
                "Never use `double` for trading calculations.",
                "A client timeout is not a confirmed failure",
                "`while (hasMore)`/recursive full-history fetches",
                "Stream `Call`, `CallState`, and its push notification manager are the call source of truth.",
                "Generate a new UUID call ID for every outgoing call.",
            ),
            "lib/app/app_config.dart": (
                "cmt2t8k4n00780cjsxjqk0dkq",
                "client-WY6ctzX8CSMMKhbvz8exuLovn1dTJyq8hReY1x63pBFfd",
                "qpwjdy8zjbdu",
            ),
            "lib/integrations/communication/stream_video_sdk_session.dart": (
                "muteAudioWhenInBackground: false",
                "muteVideoWhenInBackground: false",
                "keepConnectionsAliveWhenInBackground: false",
            ),
            "lib/features/chat/calls/audio_room_call.dart": (
                "Future<void> retireForBackground()",
                "AudioRoomCallCommandCoordinator",
                "unawaited(_suspendAudioIgnoringFailure())",
                "unawaited(_muteIgnoringFailure())",
                "await _leave()",
                "await _microphoneTail",
                "await _muteIgnoringFailure()",
                "_microphoneEnableRequested",
                "bool get retirementStarted",
                "getTrack(trackIdPrefix, SfuTrackType.audio)",
                "activeCalls.asStream().firstWhere",
                "identical(candidate, _call)",
                "return _commands.retire()",
            ),
            "lib/features/chat/calls/stream_voice_room_page.dart": (
                "AppLifecycleState.paused",
                "AppLifecycleState.hidden",
                "AppLifecycleState.detached",
                "_retireForBackground()",
                "_resumeAfterBackgroundRetirement",
                "Retry cleanup",
            ),
            "lib/features/chat/calls/stream_foreground_call_view.dart": (
                "required this.retirementStarted",
                "Leave retry required",
            ),
        },
    )
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        purpose = profile.get("project", {}).get("purpose")
        if isinstance(purpose, str):
            for relative in ("README.md", "AGENTS.md"):
                if purpose not in read_text(root / relative):
                    errors.append(f"{relative} must mirror the harness project purpose")
    return errors


def check_chat_attachment_contract(root: Path) -> list[str]:
    """Keep preview conversations out of production and token cards fail-closed."""

    errors = require_fragments(
        root,
        {
            "lib/app.dart": (
                "LoopStreamTokenCardAttachmentBuilder()",
                "LoopStreamTokenCardMessagePreviewFormatter()",
                "configData: _loopStreamConfiguration",
            ),
            "lib/features/chat/chat_preview_route_guard.dart": (
                "gateway.mode == CommunicationMode.preview",
                "chat-preview-route-blocked",
                "Offline preview only",
            ),
            "lib/features/chat/attachments/token_card_attachment.dart": (
                "static const String attachmentType = 'token_card';",
                "static const String schema = 'token_card.v1';",
                "extraData.length != extraDataKeys.length",
                "!extraData.keys.every(extraDataKeys.contains)",
            ),
            "lib/features/chat/attachments/stream_token_card_attachment_builder.dart": (
                "extends StreamAttachmentWidgetBuilder",
                "LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard",
                "LoopStreamTokenCardAttachmentPolicy.tryParse",
                "LoopTokenCardViewState.unavailable",
                "LoopTokenCardViewState.malformed",
                "This builder performs no network request",
            ),
            "lib/features/chat/attachments/stream_token_card_attachment_policy.dart": (
                "attachment.rawType == LoopTokenCardAttachment.attachmentType",
                "_hasIdentifierOnlyTopLevelFields",
                "materialized.length != 1",
            ),
            "lib/features/chat/attachments/stream_token_card_message_preview_formatter.dart": (
                "extends StreamMessagePreviewFormatter",
                "LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard",
                "unsupportedTokenCardLabel",
                "formatMessageSemanticsLabel",
                "formatDraftMessageSemanticsLabel",
            ),
            "lib/features/chat/widgets/token_card_view.dart": (
                "Current facts unavailable",
                "The message stores identifiers only",
                "开发预览",
            ),
            "test/stream_token_card_attachment_builder_test.dart": (
                "official Stream message renderer uses the configured builder",
                "raw token card cannot escape into the default link renderer",
                "find.byType(StreamLinkPreviewAttachment), findsNothing",
                "find.text('Buy'), findsNothing",
            ),
            "test/stream_token_card_message_preview_formatter_test.dart": (
                "compact Stream preview hides malicious token-card fields",
                "draft preview also strips token-card attachment fields",
                "find.textContaining('attacker.example'), findsNothing",
            ),
        },
    )

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        app_text = strip_dart_comments(read_text(app_path))
        for route in CHAT_PREVIEW_ONLY_ROUTES:
            route_marker = f"path: '{route}'"
            starts = [match.start() for match in re.finditer(re.escape(route_marker), app_text)]
            if not starts:
                errors.append(f"lib/app.dart must preserve preview-only route `{route}`")
                continue
            if len(starts) != 1:
                errors.append(
                    f"lib/app.dart preview-only route `{route}` must be declared exactly once"
                )
                continue
            start = starts[0]
            next_route = app_text.find("GoRoute(", start + len(route_marker))
            route_block = app_text[start : next_route if next_route >= 0 else len(app_text)]
            first_builder = re.search(r"\bbuilder\s*:", route_block)
            guarded_builder = re.match(
                r"builder\s*:\s*\([^)]*\)\s*=>\s*const\s+ChatPreviewRouteGuard\s*\(",
                route_block[first_builder.start() :] if first_builder else "",
            )
            if guarded_builder is None:
                errors.append(
                    f"lib/app.dart preview-only route `{route}` must be wrapped by ChatPreviewRouteGuard"
                )

    model_path = root / "lib/features/chat/attachments/token_card_attachment.dart"
    if model_path.is_file():
        model_text = read_text(model_path)
        match = re.search(
            r"static const Set<String> extraDataKeys\s*=\s*<String>\{(?P<body>.*?)\};",
            model_text,
            re.DOTALL,
        )
        if match is None:
            errors.append("token_card.v1 must declare a static exact extraDataKeys set")
        else:
            actual_keys = frozenset(re.findall(r"'([^']+)'", match.group("body")))
            if actual_keys != TOKEN_CARD_EXTRA_DATA_KEYS:
                errors.append(
                    "token_card.v1 extraDataKeys must be exactly identifier-only: "
                    f"expected {sorted(TOKEN_CARD_EXTRA_DATA_KEYS)}, found {sorted(actual_keys)}"
                )
            residual = re.sub(r"'[^']+'", "", match.group("body"))
            if re.sub(r"[\s,]", "", residual):
                errors.append(
                    "token_card.v1 extraDataKeys must contain only the five literal keys; "
                    "spreads and computed entries are forbidden"
                )

    for relative, allowed_imports in TOKEN_CARD_RENDER_IMPORTS.items():
        render_path = root / relative
        if not render_path.is_file():
            continue
        render_text = read_text(render_path)
        executable_text = strip_dart_comments(render_text)
        directives = tuple(
            re.finditer(
                r"^\s*(?P<kind>import|export|part)\b(?P<body>.*?);",
                executable_text,
                re.MULTILINE | re.DOTALL,
            )
        )
        actual_imports: list[str] = []
        invalid_directives: list[str] = []
        for directive in directives:
            body = " ".join(directive.group("body").split())
            if directive.group("kind") != "import":
                invalid_directives.append(directive.group(0).strip())
                continue
            actual_imports.append(body)
        actual_import_set = frozenset(actual_imports)
        if (
            invalid_directives
            or len(actual_imports) != len(actual_import_set)
            or actual_import_set != allowed_imports
        ):
            errors.append(
                f"{relative} imports must stay on the reviewed synchronous allowlist: "
                f"expected {sorted(allowed_imports)}, found {sorted(actual_imports)}"
            )
        forbidden_builder_fragments = (
            "Future<",
            " async",
            "await ",
            "Dio",
            "package:http",
            "dart:io",
            "HttpClient",
            "StreamMessageListView",
            "StreamChat.",
            "StreamChatCore",
            "StreamChatClient",
            "StreamChannel.",
            ".client",
            "getMessage(",
            "queryChannels(",
            "Image.network(",
            "NetworkImage",
            "FadeInImage",
            "NetworkAssetBundle",
        )
        for fragment in forbidden_builder_fragments:
            if fragment in executable_text:
                errors.append(
                    "Stream token-card rendering must stay synchronous and must not create a "
                    f"second message/network source in {render_path.relative_to(root)} (`{fragment}`)"
                )
    return errors


def check_source_guards(root: Path) -> list[str]:
    forbidden = {
        "PrivyLogLevel.debug": "Privy debug logging can expose OTPs and access tokens",
        "PrivyLogLevel.verbose": "Privy verbose logging can expose OTPs and access tokens",
        ".devToken(": "Stream development tokens bypass backend identity validation",
        "connectGuestUser(": "Stream guest users bypass the Privy identity boundary",
        "Firebase.initializeApp(": "Firebase must wait for real mobile configs and push-provider names",
    }
    errors: list[str] = []
    for path in sorted((root / "lib").rglob("*.dart")):
        text = read_text(path)
        for fragment, reason in forbidden.items():
            if fragment in text:
                errors.append(f"{path.relative_to(root)} contains forbidden `{fragment}`: {reason}")
    return errors


def check_notification_contract(root: Path) -> list[str]:
    """Keep provider callbacks behind one adapter and routing provider-neutral."""

    errors: list[str] = []
    router_path = root / NOTIFICATION_ROUTER_PATH
    if not router_path.is_file():
        errors.append(f"missing centralized notification router: {NOTIFICATION_ROUTER_PATH}")
    else:
        executable = strip_dart_comments(read_text(router_path))
        executable_code = strip_dart_comments_and_strings(read_text(router_path))
        directives = list(
            re.finditer(
                r"^\s*(?P<kind>import|export|part)\s+(?P<body>[^;]+);",
                executable,
                re.MULTILINE,
            )
        )
        actual_imports: list[str] = []
        invalid_directives: list[str] = []
        for directive in directives:
            body = " ".join(directive.group("body").split())
            if directive.group("kind") != "import":
                invalid_directives.append(directive.group(0).strip())
                continue
            actual_imports.append(body)
        actual_import_set = frozenset(actual_imports)
        if (
            invalid_directives
            or len(actual_imports) != len(actual_import_set)
            or actual_import_set != NOTIFICATION_ROUTER_IMPORTS
        ):
            errors.append(
                "notification routing imports must stay on the provider-neutral allowlist: "
                f"expected {sorted(NOTIFICATION_ROUTER_IMPORTS)}, found {sorted(actual_imports)}"
            )

        required_fragments = (
            "class LoopNotificationRouter",
            "static const String schema = 'notification.v1'",
            "static const String chatMessageKind = 'chat.message'",
            "static const String audioRoomActivityKind = 'audio_room.activity'",
            "static const String systemNoticeKind = 'system.notice'",
            "'recipient_stream_user_id'",
            "LoopNotificationIngress.foreground",
            "LoopNotificationIngress.background",
            "LoopNotificationIngress.interaction",
            "LoopNotificationSessionMode.authenticated",
            "LoopNotificationDisposition.duplicateInteraction",
            "Uri.encodeComponent(channel.cid)",
            "String get location => '/chat/voice'",
            "String get location => '/notifications'",
        )
        for fragment in required_fragments:
            if fragment not in executable:
                errors.append(
                    "centralized notification routing contract is missing reviewed fragment "
                    f"`{fragment}`"
                )

        forbidden_fragments = (
            "package:firebase",
            "package:stream_chat",
            "package:stream_video",
            "package:go_router",
            "FirebaseMessaging",
            "RemoteMessage",
            "BuildContext",
            "Navigator",
            "dart:io",
            "debugPrint(",
            "print(",
            "data['route']",
            'data["route"]',
            "data['path']",
            'data["path"]',
            "deep_link",
            "call_cid",
            "room_id",
        )
        for fragment in forbidden_fragments:
            if fragment in executable:
                errors.append(
                    "centralized notification routing must reject provider SDKs, payload "
                    f"routes, room locators, and payload logging (`{fragment}`)"
                )

        kind_match = re.search(
            r"enum\s+_LoopNotificationKind\s*\{(?P<body>[^}]*)\}",
            executable_code,
            re.DOTALL,
        )
        kind_members = (
            frozenset(
                member.strip()
                for member in kind_match.group("body").split(",")
                if member.strip()
            )
            if kind_match
            else frozenset()
        )
        if kind_members != NOTIFICATION_KIND_MEMBERS:
            errors.append(
                "notification kinds must stay on the reviewed three-kind allowlist: "
                f"expected {sorted(NOTIFICATION_KIND_MEMBERS)}, found {sorted(kind_members)}"
            )

        intent_classes = frozenset(
            re.findall(
                r"final\s+class\s+(\w+)\s+extends\s+LoopNotificationNavigationIntent\b",
                executable_code,
            )
        )
        if intent_classes != NOTIFICATION_INTENT_CLASSES:
            errors.append(
                "notification intents must stay on the reviewed three-class allowlist: "
                f"expected {sorted(NOTIFICATION_INTENT_CLASSES)}, "
                f"found {sorted(intent_classes)}"
            )

        route_literals = frozenset(
            match.group("route")
            for match in re.finditer(
                r"(?P<quote>['\"])(?P<route>/[^'\"\r\n]*)(?P=quote)",
                executable,
            )
        )
        if route_literals != NOTIFICATION_ROUTE_LITERALS:
            errors.append(
                "notification route literals must stay on the reviewed three-route allowlist: "
                f"expected {sorted(NOTIFICATION_ROUTE_LITERALS)}, "
                f"found {sorted(route_literals)}"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in sorted(lib_root.rglob("*.dart")):
            executable = strip_dart_comments(read_text(path))
            executable_code = strip_dart_comments_and_strings(read_text(path))
            relative = path.relative_to(root)
            for marker in NOTIFICATION_PROVIDER_IMPORT_MARKERS:
                if (
                    marker in executable
                    and relative not in NOTIFICATION_PROVIDER_IMPORT_ALLOWED_PATHS
                ):
                    errors.append(
                        f"{relative} imports notification provider SDK `{marker}`; only the "
                        "compatibility probe and centralized provider ingress may import it"
                    )
            if relative not in NOTIFICATION_ROUTER_CONSUMER_PATHS:
                if NOTIFICATION_ROUTER_IMPORT in executable:
                    errors.append(
                        f"{relative} imports the notification router directly; only "
                        f"{NOTIFICATION_COORDINATOR_PATH} may bind it to application identity"
                    )
                if NOTIFICATION_ROUTER_CONSTRUCTION_PATTERN.search(executable_code):
                    errors.append(
                        f"{relative} constructs notification routing identity directly; only "
                        f"{NOTIFICATION_COORDINATOR_PATH} may derive it from verified bootstrap state"
                    )
            for pattern, marker in NOTIFICATION_GLOBAL_INGRESS_PATTERNS:
                if (
                    pattern.search(executable_code)
                    and relative != NOTIFICATION_PROVIDER_INGRESS_PATH
                ):
                    errors.append(
                        f"{relative} contains global notification ingress `{marker}`; "
                        f"only {NOTIFICATION_PROVIDER_INGRESS_PATH} may own provider callbacks"
                    )
    return errors


def check_secret_paths(paths: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in paths:
        name = path.name.casefold()
        if name == ".env" or (name.startswith(".env.") and not name.endswith((".example", ".sample", ".template"))):
            errors.append(f"repository environment-secret file is forbidden: {path}")
        if path.suffix.casefold() in {".key", ".p8", ".p12", ".pem"}:
            errors.append(f"repository privileged-credential path is forbidden: {path}")
        if any(marker in name for marker in ("firebase-adminsdk", "service-account", "service_account")):
            errors.append(f"repository privileged-credential path is forbidden: {path}")
    return errors


def check_gitignore(root: Path) -> list[str]:
    expectations = {".env": True, ".env.local": True, ".env.example": False, ".gitnexus/index": True}
    errors: list[str] = []
    for candidate, expected in expectations.items():
        result = subprocess.run(
            ["git", "-C", str(root), "check-ignore", "--no-index", "--quiet", "--", candidate],
            check=False,
        )
        ignored = result.returncode == 0
        if result.returncode not in (0, 1):
            errors.append(f"unable to evaluate .gitignore for `{candidate}`")
        elif ignored != expected:
            errors.append(f".gitignore expectation failed for `{candidate}`")
    return errors


def validate(root: Path = ROOT) -> list[str]:
    errors = check_required_files(root)
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        errors.extend(check_profile(root, profile))
    errors.extend(check_dependency_pins(root))
    errors.extend(check_native_matrix(root))
    errors.extend(check_audio_room_native_contract(root))
    errors.extend(check_product_contract(root))
    errors.extend(check_chat_attachment_contract(root))
    errors.extend(check_notification_contract(root))
    errors.extend(check_source_guards(root))
    errors.extend(check_records(root))
    visible, visible_error = git_visible_paths(root)
    if visible_error:
        errors.append(f"unable to inspect Git-visible paths: {visible_error}")
    else:
        errors.extend(check_secret_paths(visible))
    errors.extend(check_gitignore(root))
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Harness check failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Harness check passed: profile, six-destination contract, pins, native matrix, records, and secret rules are consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
