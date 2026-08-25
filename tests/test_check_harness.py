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

    def test_feature_cannot_own_backend_transport(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "wallet" / "unsafe_api.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import 'package:dio/dio.dart';\n"
                "const route = '/v1/transfer/reviews';\n",
                encoding="utf-8",
            )
            result = check_harness.check_providerless_application_contract(root)
        self.assertTrue(any("imports transport" in error for error in result))
        self.assertTrue(any("backend route literal" in error for error in result))

    def test_production_main_cannot_compose_preview_fixtures(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "main.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "final chat = MemoryCommunicationGateway();\n"
                "final watchlist = MemoryWatchlistGateway();\n"
                "final market = HyperliquidFixtureAdapter();\n"
                "final wallet = PrivyFixtureAdapter();\n",
                encoding="utf-8",
            )
            result = check_harness.check_providerless_application_contract(root)
        self.assertEqual(4, len(result))
        self.assertTrue(
            all("tests or lib/main_preview.dart" in error for error in result)
        )

    def test_watchlist_provider_must_default_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gateway = root / check_harness.WATCHLIST_GATEWAY_PATH
            gateway.parent.mkdir(parents=True)
            gateway.write_text(
                "final watchlistGatewayProvider = Provider<WatchlistGateway>(\n"
                "  (ref) => MemoryWatchlistGateway(),\n"
                ");\n",
                encoding="utf-8",
            )

            result = check_harness.check_watchlist_application_contract(root)

        self.assertTrue(
            any("must default directly" in error for error in result),
            msg=f"expected unavailable Watchlist provider guard: {result}",
        )

    def test_watchlist_model_cannot_store_market_facts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.WATCHLIST_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "final class WatchlistItem {\n"
                "  const WatchlistItem(this.assetKey, this.markPrice);\n"
                "  final String assetKey;\n"
                "  final String markPrice;\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_watchlist_application_contract(root)

        self.assertTrue(
            any("volatile market facts" in error for error in result),
            msg=f"expected Watchlist fact-boundary guard: {result}",
        )

    def test_watchlist_memory_gateway_cannot_be_composed_by_a_feature(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = (
                root / "lib" / "features" / "market" / "unsafe_watchlist.dart"
            )
            source.parent.mkdir(parents=True)
            source.write_text(
                "final gateway = MemoryWatchlistGateway();\n",
                encoding="utf-8",
            )

            result = check_harness.check_watchlist_application_contract(root)

        self.assertTrue(
            any("constructs MemoryWatchlistGateway" in error for error in result),
            msg=f"expected Preview-only Watchlist fake guard: {result}",
        )

    def test_notification_global_handler_must_be_centralized(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "chat" / "unsafe_push.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "FirebaseMessaging\n  .onBackgroundMessage(backgroundHandler);\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any(
                "only lib/integrations/notifications/firebase_notification_ingress.dart"
                in error
                for error in result
            )
        )

    def test_notification_router_rejects_payload_selected_routes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            router = root / check_harness.NOTIFICATION_ROUTER_PATH
            router.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.NOTIFICATION_ROUTER_PATH
            ).read_text(encoding="utf-8")
            router.write_text(
                source + "\nfinal unsafeRoute = data['route'];\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("payload routes" in error and "data['route']" in error for error in result)
        )

    def test_notification_router_rejects_provider_sdk_imports(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            router = root / check_harness.NOTIFICATION_ROUTER_PATH
            router.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.NOTIFICATION_ROUTER_PATH
            ).read_text(encoding="utf-8")
            router.write_text(
                "import 'package:firebase_messaging/firebase_messaging.dart';\n" + source,
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("provider-neutral allowlist" in error for error in result)
        )

    def test_notification_provider_import_cannot_hide_outside_ingress(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "chat" / "aliased_push.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import 'package:firebase_messaging/firebase_messaging.dart' as messaging;\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("only the compatibility probe" in error for error in result)
        )

    def test_compatibility_probe_cannot_own_a_split_global_handler(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "app" / "bootstrap" / "sdk_compatibility.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import 'package:firebase_messaging/firebase_messaging.dart';\n"
                "FirebaseMessaging\n  .onBackgroundMessage(backgroundHandler);\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("global notification ingress" in error for error in result)
        )

    def test_notification_router_rejects_a_fourth_intent_and_route(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            router = root / check_harness.NOTIFICATION_ROUTER_PATH
            router.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.NOTIFICATION_ROUTER_PATH
            ).read_text(encoding="utf-8")
            router.write_text(
                source
                + "\nfinal class WalletIntent extends LoopNotificationNavigationIntent {\n"
                + "  const WalletIntent();\n"
                + "  @override String get location => '/wallet';\n"
                + "}\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("three-class allowlist" in error for error in result)
        )
        self.assertTrue(
            any("three-route allowlist" in error for error in result)
        )

    def test_feature_cannot_forge_notification_identity_or_router(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "chat" / "unsafe_router.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';\n"
                "final router = LoopNotificationRouter();\n"
                "const session = LoopNotificationSessionContext.authenticated('loop_forged123');\n",
                encoding="utf-8",
            )
            result = check_harness.check_notification_contract(root)
        self.assertTrue(
            any("imports the notification router directly" in error for error in result)
        )
        self.assertTrue(
            any("constructs notification routing identity directly" in error for error in result)
        )

    def test_production_notification_source_cannot_be_enabled_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._copy_notification_application_contract(root)
            source_path = root / check_harness.NOTIFICATION_EVENT_SOURCE_PATH
            source = source_path.read_text(encoding="utf-8")
            mutated = source.replace(
                "(ref) => const DisabledLoopNotificationEventSource(),",
                "(ref) => EnabledLoopNotificationEventSource(),",
            )
            self.assertNotEqual(source, mutated)
            source_path.write_text(mutated, encoding="utf-8")

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("must default directly" in error for error in result),
            msg=f"expected disabled production source guard: {result}",
        )

    def test_production_main_cannot_override_disabled_notification_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            main = root / "lib" / "main.dart"
            main.parent.mkdir(parents=True)
            main.write_text(
                "final override = loopNotificationEventSourceProvider.overrideWithValue("
                "EnabledNotificationSource());\n",
                encoding="utf-8",
            )

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("must not override the disabled" in error for error in result),
            msg=f"expected production entrypoint guard: {result}",
        )

    def test_notification_coordinator_rejects_forged_identity_and_second_slot(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._copy_notification_application_contract(root)
            coordinator_path = root / check_harness.NOTIFICATION_COORDINATOR_PATH
            source = coordinator_path.read_text(encoding="utf-8")
            mutated = source.replace(
                "LoopNotificationSessionContext.authenticated(identity.streamUserId)",
                "LoopNotificationSessionContext.authenticated("
                "session.account!.privyUserId)",
            ).replace(
                "_DeferredInteraction? _deferredInteraction;",
                "_DeferredInteraction? _deferredInteraction;\n"
                "  final List<_DeferredInteraction> _unsafeDeferredQueue = [];",
            )
            self.assertNotEqual(source, mutated)
            coordinator_path.write_text(mutated, encoding="utf-8")

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("bootstrap-derived stream identity" in error for error in result),
            msg=f"expected bootstrap identity guard: {result}",
        )
        self.assertTrue(
            any("at most one deferred interaction" in error for error in result),
            msg=f"expected single deferred slot guard: {result}",
        )

    def test_notification_coordinator_cannot_retain_payload_across_authorization(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._copy_notification_application_contract(root)
            coordinator_path = root / check_harness.NOTIFICATION_COORDINATOR_PATH
            source = coordinator_path.read_text(encoding="utf-8")
            mutated = source.replace(
                "Future<void> _resolveIdentity({\n"
                "    required LoopBootstrapSession bootstrap,",
                "Future<void> _resolveIdentity({\n"
                "    required _DeferredInteraction deferred,\n"
                "    required LoopBootstrapSession bootstrap,",
            )
            self.assertNotEqual(source, mutated)
            coordinator_path.write_text(mutated, encoding="utf-8")

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("must not retain a deferred payload" in error for error in result),
            msg=f"expected in-flight payload-retention guard: {result}",
        )

    def test_feature_cannot_construct_a_competing_notification_coordinator(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._copy_notification_application_contract(root)
            feature = root / "lib" / "features" / "chat" / "unsafe_coordinator.dart"
            feature.parent.mkdir(parents=True)
            feature.write_text(
                "import 'package:loop_mobile/app/notifications/"
                "loop_notification_coordinator.dart';\n"
                "final duplicate = LoopNotificationCoordinator();\n",
                encoding="utf-8",
            )

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("imports the notification coordinator directly" in error for error in result),
            msg=f"expected coordinator import guard: {result}",
        )
        self.assertTrue(
            any("constructs a competing" in error for error in result),
            msg=f"expected competing coordinator guard: {result}",
        )

    def test_root_notification_navigation_cannot_be_arbitrary_or_repeated(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._copy_notification_application_contract(root)
            application_path = root / check_harness.NOTIFICATION_APPLICATION_PATH
            source = application_path.read_text(encoding="utf-8")
            mutated = source.replace(
                "navigate: (intent) => router.go(intent.location),",
                "navigate: (intent) {\n"
                "        router.go('/wallet');\n"
                "        router.go(intent.location);\n"
                "      },",
            )
            self.assertNotEqual(source, mutated)
            application_path.write_text(mutated, encoding="utf-8")

            result = check_harness.check_notification_contract(root)

        self.assertTrue(
            any("exactly one typed root navigation" in error for error in result),
            msg=f"expected typed root navigation guard: {result}",
        )

    def _copy_notification_application_contract(self, root: Path) -> None:
        for relative in (
            check_harness.NOTIFICATION_ROUTER_PATH,
            check_harness.NOTIFICATION_EVENT_SOURCE_PATH,
            check_harness.NOTIFICATION_COORDINATOR_PATH,
            check_harness.NOTIFICATION_APPLICATION_PATH,
        ):
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(
                (REPOSITORY_ROOT / relative).read_text(encoding="utf-8"),
                encoding="utf-8",
            )

    def test_preview_chat_route_without_guard_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "lib" / "app.dart"
            app.parent.mkdir(parents=True)
            app.write_text(
                "GoRoute(\n"
                "  path: '/chat/group',\n"
                "  // ChatPreviewRouteGuard( must not satisfy the policy.\n"
                "  /* builder: (context, state) => const ChatPreviewRouteGuard( */\n"
                "  builder: (context, state) => const GroupChatPage(),\n"
                "),\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any(
                "preview-only route `/chat/group` must be wrapped by ChatPreviewRouteGuard"
                in error
                for error in result
            )
        )

    def test_duplicate_preview_chat_route_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "lib" / "app.dart"
            app.parent.mkdir(parents=True)
            app.write_text(
                "GoRoute(\n"
                "  path: '/chat/group',\n"
                "  builder: (context, state) => const ChatPreviewRouteGuard(\n"
                "    child: GroupChatPage(),\n"
                "  ),\n"
                "),\n"
                "GoRoute(\n"
                "  path: '/chat/group',\n"
                "  builder: (context, state) => const GroupChatPage(),\n"
                "),\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any(
                "preview-only route `/chat/group` must be declared exactly once"
                in error
                for error in result
            )
        )

    def test_token_card_mutable_payload_key_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            model = root / "lib" / "features" / "chat" / "attachments" / "token_card_attachment.dart"
            model.parent.mkdir(parents=True)
            model.write_text(
                "static const Set<String> extraDataKeys = <String>{\n"
                "  'loop_schema',\n"
                "  'asset_id',\n"
                "  'chain_id',\n"
                "  'contract_id',\n"
                "  'snapshot_at',\n"
                "  'price',\n"
                "};\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any("token_card.v1 extraDataKeys must be exactly identifier-only" in error for error in result)
        )

    def test_token_card_key_spread_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            model = root / "lib" / "features" / "chat" / "attachments" / "token_card_attachment.dart"
            model.parent.mkdir(parents=True)
            model.write_text(
                "static const Set<String> extraDataKeys = <String>{\n"
                "  'loop_schema',\n"
                "  'asset_id',\n"
                "  'chain_id',\n"
                "  'contract_id',\n"
                "  'snapshot_at',\n"
                "  ...mutableKeys,\n"
                "};\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(any("spreads and computed entries are forbidden" in error for error in result))

    def test_token_card_view_network_source_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            view = root / "lib" / "features" / "chat" / "widgets" / "token_card_view.dart"
            view.parent.mkdir(parents=True)
            view.write_text("import 'dart:io';\nfinal client = HttpClient();\n", encoding="utf-8")
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(any("token_card_view.dart (`dart:io`)" in error for error in result))

    def test_token_card_renderer_helper_import_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            builder = (
                root
                / "lib"
                / "features"
                / "chat"
                / "attachments"
                / "stream_token_card_attachment_builder.dart"
            )
            builder.parent.mkdir(parents=True)
            expected_imports = sorted(
                check_harness.TOKEN_CARD_RENDER_IMPORTS[
                    "lib/features/chat/attachments/stream_token_card_attachment_builder.dart"
                ]
            )
            builder.write_text(
                "".join(f"import {directive};\n" for directive in expected_imports)
                + "import 'token_card_network_helper.dart' as helper;\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any(
                "stream_token_card_attachment_builder.dart imports must stay"
                in error
                for error in result
            )
        )

    def test_token_card_renderer_stream_client_access_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            builder = (
                root
                / "lib"
                / "features"
                / "chat"
                / "attachments"
                / "stream_token_card_attachment_builder.dart"
            )
            builder.parent.mkdir(parents=True)
            expected_imports = sorted(
                check_harness.TOKEN_CARD_RENDER_IMPORTS[
                    "lib/features/chat/attachments/stream_token_card_attachment_builder.dart"
                ]
            )
            builder.write_text(
                "".join(f"import {directive};\n" for directive in expected_imports)
                + "final request = StreamChat.maybeOf(context)?.client.getMessage(message.id);\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any(
                "stream_token_card_attachment_builder.dart (`StreamChat.`)"
                in error
                for error in result
            )
        )

    def test_token_card_renderer_flutter_network_image_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            view = (
                root
                / "lib"
                / "features"
                / "chat"
                / "widgets"
                / "token_card_view.dart"
            )
            view.parent.mkdir(parents=True)
            expected_imports = sorted(
                check_harness.TOKEN_CARD_RENDER_IMPORTS[
                    "lib/features/chat/widgets/token_card_view.dart"
                ]
            )
            view.write_text(
                "".join(f"import {directive};\n" for directive in expected_imports)
                + "final image = Image.network('https://attacker.example/token.png');\n",
                encoding="utf-8",
            )
            result = check_harness.check_chat_attachment_contract(root)
        self.assertTrue(
            any(
                "token_card_view.dart (`Image.network(`)" in error
                for error in result
            )
        )

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
