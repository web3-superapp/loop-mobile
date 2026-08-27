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

    def test_routine_verification_is_android_debug_only(self) -> None:
        profile, errors = check_harness.load_profile(REPOSITORY_ROOT)
        self.assertEqual([], errors)
        assert profile is not None
        self.assertIn(
            "docs/decisions/0015-use-debug-only-routine-verification.md",
            check_harness.REQUIRED_FILES,
        )
        self.assertEqual(
            {
                "routine_native_gate": "bin/flutter build apk --debug",
                "routine_build_frequency": "feature_checkpoint_only",
                "release_matrix": "explicit_user_request_only",
                "device_validation": "user_owned",
                "retain_build_artifacts": False,
            },
            profile["verification"],
        )

        changed = copy.deepcopy(profile)
        changed["verification"]["routine_native_gate"] = (
            "bin/flutter build apk --release"
        )
        result = check_harness.check_profile(REPOSITORY_ROOT, changed)

        self.assertTrue(
            any("Android Debug-only" in error for error in result),
            msg=f"expected routine Debug-only guard: {result}",
        )

    def test_release_matrix_cannot_become_automatic(self) -> None:
        profile, errors = check_harness.load_profile(REPOSITORY_ROOT)
        self.assertEqual([], errors)
        assert profile is not None
        changed = copy.deepcopy(profile)
        changed["commands"]["native_release_matrix"] = changed["commands"].pop(
            "manual_release_matrix"
        )

        result = check_harness.check_profile(REPOSITORY_ROOT, changed)

        self.assertTrue(
            any("must not expose an automatic" in error for error in result),
            msg=f"expected manual release-matrix guard: {result}",
        )

    def test_dependency_pin_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            text = (REPOSITORY_ROOT / "pubspec.yaml").read_text(encoding="utf-8")
            (root / "pubspec.yaml").write_text(text.replace("  dio: 5.11.0", "  dio: ^5.11.0"), encoding="utf-8")
            result = check_harness.check_dependency_pins(root)
        self.assertIn("pubspec.yaml must pin `dio` exactly to `5.11.0`", result)

    def test_sqlite3_system_source_hook_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            text = (REPOSITORY_ROOT / "pubspec.yaml").read_text(
                encoding="utf-8"
            )
            (root / "pubspec.yaml").write_text(
                text.replace("      source: system", "      source: sqlite3"),
                encoding="utf-8",
            )
            result = check_harness.check_dependency_pins(root)

        self.assertIn(
            "pubspec.yaml must use the locked sqlite3 system-source hook",
            result,
        )

    def test_sqlite_compatibility_lock_graph_cannot_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "pubspec.yaml").write_text(
                (REPOSITORY_ROOT / "pubspec.yaml").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            lock = (REPOSITORY_ROOT / "pubspec.lock").read_text(
                encoding="utf-8"
            )
            (root / "pubspec.lock").write_text(
                lock.replace('    version: "3.5.2"', '    version: "3.6.0"'),
                encoding="utf-8",
            )
            result = check_harness.check_dependency_pins(root)

        self.assertIn(
            "pubspec.lock must preserve sqlite compatibility package `sqlite3` at `3.5.2`, found `3.6.0`",
            result,
        )

    def test_spot_only_paths_are_required(self) -> None:
        expected = {
            "docs/decisions/0016-make-primary-market-spot-only.md",
            "docs/decisions/0017-use-public-testnet-spot-market-data.md",
            "docs/decisions/0018-use-system-sqlite-for-cold-builds.md",
            "docs/failures/sqlite3-native-hook-download.md",
            "lib/app/loop_display_preferences.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_market.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_market_providers.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_market_repository.dart",
            "test/development_preview_experience_test.dart",
            "test/hyperliquid_spot_market_repository_test.dart",
            "test/local_settings_and_help_test.dart",
            "test/market_screen_test.dart",
        }

        self.assertTrue(expected.issubset(set(check_harness.REQUIRED_FILES)))

    def test_spot_candle_paths_are_required(self) -> None:
        expected = {
            "docs/decisions/0019-use-public-testnet-spot-candles.md",
            "lib/features/market/spot_candle_chart.dart",
            "lib/features/market/spot_candle_section.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart",
            "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart",
            "test/hyperliquid_spot_candle_providers_test.dart",
            "test/hyperliquid_spot_candle_repository_test.dart",
            "test/spot_candle_chart_test.dart",
        }

        self.assertTrue(expected.issubset(set(check_harness.REQUIRED_FILES)))

    def test_monthly_spot_candle_cannot_collapse_to_minutes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace("wireValue: '1M'", "wireValue: '1m'"),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("wire periods must remain exactly" in error for error in result),
            msg=f"expected case-sensitive monthly candle guard: {result}",
        )

    def test_spot_candle_fixed_durations_cannot_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "candleDuration: Duration(days: 30)",
                    "candleDuration: Duration(minutes: 1)",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("fixed durations must remain exactly" in error for error in result),
            msg=f"expected fixed candle-duration guard: {result}",
        )

    def test_spot_candle_row_duration_validation_cannot_be_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository_relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart"
            )
            repository = root / repository_relative
            repository.parent.mkdir(parents=True)
            repository.write_text(
                (REPOSITORY_ROOT / repository_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "closeTimeMilliseconds != expectedCloseTimeMilliseconds",
                    "closeTimeMilliseconds < openTimeMilliseconds",
                ),
                encoding="utf-8",
            )
            test_relative = "test/hyperliquid_spot_candle_repository_test.dart"
            behavior_test = root / test_relative
            behavior_test.parent.mkdir(parents=True, exist_ok=True)
            behavior_test.write_text(
                (REPOSITORY_ROOT / test_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "rejects short and long durations for every mounted interval",
                    "accepts arbitrary row durations",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any(
                "closeTimeMilliseconds != expectedCloseTimeMilliseconds" in error
                for error in result
            ),
            msg=f"expected exact row-duration parser guard: {result}",
        )
        self.assertTrue(
            any("short and long durations" in error for error in result),
            msg=f"expected malformed-duration behavior-evidence guard: {result}",
        )

    def test_spot_candle_window_and_retention_bound_cannot_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            model_relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart"
            )
            model = root / model_relative
            model.parent.mkdir(parents=True)
            model.write_text(
                (REPOSITORY_ROOT / model_relative)
                .read_text(encoding="utf-8")
                .replace("lookback: Duration(days: 3600)", "lookback: Duration(days: 30)"),
                encoding="utf-8",
            )
            repository_relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart"
            )
            repository = root / repository_relative
            repository.parent.mkdir(parents=True, exist_ok=True)
            repository.write_text(
                (REPOSITORY_ROOT / repository_relative)
                .read_text(encoding="utf-8")
                .replace("static const maximumCandles = 120;", "static const maximumCandles = 5000;"),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("approximately 120 rows" in error for error in result),
            msg=f"expected candle request-window guard: {result}",
        )
        self.assertTrue(
            any("maximumCandles = 120" in error for error in result),
            msg=f"expected candle retention guard: {result}",
        )

    def test_spot_candles_must_remain_public_testnet_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart"
            )
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "api.hyperliquid-testnet.xyz",
                    "api.hyperliquid.xyz",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("Testnet-only" in error for error in result),
            msg=f"expected public Testnet candle transport guard: {result}",
        )

    def test_overlapping_first_spot_candle_must_remain_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart"
            )
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "closeTimeMilliseconds < requestedFrom.millisecondsSinceEpoch",
                    "openTimeMilliseconds < requestedFrom.millisecondsSinceEpoch",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("overlapping, empty-history semantics" in error for error in result),
            msg=f"expected overlapping-first-candle guard: {result}",
        )

    def test_spot_candle_provider_edge_behavior_tests_are_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository_relative = (
                "test/hyperliquid_spot_candle_repository_test.dart"
            )
            repository_test = root / repository_relative
            repository_test.parent.mkdir(parents=True)
            repository_test.write_text(
                (REPOSITORY_ROOT / repository_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "accepts an overlapping first candle and gaps without fabrication",
                    "rejects an overlapping first candle and fills every gap",
                ),
                encoding="utf-8",
            )
            market_relative = "test/market_screen_test.dart"
            market_test = root / market_relative
            market_test.parent.mkdir(parents=True, exist_ok=True)
            market_test.write_text(
                (REPOSITORY_ROOT / market_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "marks a final candle still forming at receipt time",
                    "always marks the final candle closed",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("overlapping first candle and gaps" in error for error in result),
            msg=f"expected overlap/gap behavior-evidence guard: {result}",
        )
        self.assertTrue(
            any("final candle still forming" in error for error in result),
            msg=f"expected forming-candle behavior-evidence guard: {result}",
        )

    def test_spot_candle_exact_decimal_fields_cannot_become_double(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "final HyperliquidSpotDecimal open;",
                    "final double open;",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("HyperliquidSpotDecimal open" in error for error in result),
            msg=f"expected exact Decimal OHLCV guard: {result}",
        )

    def test_spot_candle_chart_time_gap_projection_cannot_be_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            chart_relative = "lib/features/market/spot_candle_chart.dart"
            chart = root / chart_relative
            chart.parent.mkdir(parents=True)
            chart.write_text(
                (REPOSITORY_ROOT / chart_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "final centerX = xFor(candle);",
                    "final centerX = plot.center.dx;",
                ),
                encoding="utf-8",
            )
            test_relative = "test/spot_candle_chart_test.dart"
            behavior_test = root / test_relative
            behavior_test.parent.mkdir(parents=True, exist_ok=True)
            behavior_test.write_text(
                (REPOSITORY_ROOT / test_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "projects missing candle intervals as a visible time-axis gap",
                    "projects every candle at an equal slot",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("final centerX = xFor(candle);" in error for error in result),
            msg=f"expected time-axis projection implementation guard: {result}",
        )
        self.assertTrue(
            any("visible time-axis gap" in error for error in result),
            msg=f"expected time-gap behavior-evidence guard: {result}",
        )

    def test_spot_candle_lowest_doji_visibility_cannot_be_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            chart_relative = "lib/features/market/spot_candle_chart.dart"
            chart = root / chart_relative
            chart.parent.mkdir(parents=True)
            chart.write_text(
                (REPOSITORY_ROOT / chart_relative)
                .read_text(encoding="utf-8")
                .replace(
                    ".clamp(plot.top, plot.bottom - minimumBodyHeight)",
                    ".clamp(plot.top, plot.bottom)",
                ),
                encoding="utf-8",
            )
            test_relative = "test/spot_candle_chart_test.dart"
            behavior_test = root / test_relative
            behavior_test.parent.mkdir(parents=True, exist_ok=True)
            behavior_test.write_text(
                (REPOSITORY_ROOT / test_relative)
                .read_text(encoding="utf-8")
                .replace(
                    "keeps a lowest-price doji body inside the plot",
                    "allows a lowest-price doji body outside the plot",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any(
                ".clamp(plot.top, plot.bottom - minimumBodyHeight)" in error
                for error in result
            ),
            msg=f"expected lowest-bound doji implementation guard: {result}",
        )
        self.assertTrue(
            any("lowest-price doji body inside" in error for error in result),
            msg=f"expected lowest-bound doji behavior-evidence guard: {result}",
        )

    def test_spot_candle_polling_and_automatic_retry_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = (
                "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart"
            )
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "retry: (retryCount, error) => null",
                    "retry: (retryCount, error) => const Duration(seconds: 1)",
                )
                + "\nfinal unsafePoll = Timer.periodic;\n",
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("retry: (retryCount, error) => null" in error for error in result),
            msg=f"expected no-auto-retry guard: {result}",
        )
        self.assertTrue(
            any("must not poll" in error for error in result),
            msg=f"expected no-polling guard: {result}",
        )

    def test_preview_cannot_replace_public_spot_candles(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/main_preview.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "hyperliquidSpotCandleRepositoryProvider.overrideWithValue(fake);\n",
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertIn(
            "lib/main_preview.dart must not replace public Spot candles with a Preview repository",
            result,
        )

    def test_invalid_and_absent_spot_indices_keep_zero_candle_requests(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/market_screen_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "expect(candleRepository.requests, isEmpty);",
                    "expect(candleRepository.requests, isNotEmpty);",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("zero candle requests" in error for error in result),
            msg=f"expected invalid/absent-index request guard: {result}",
        )

    def test_spot_candle_execution_navigation_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/market/spot_candle_section.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "FilledButton(onPressed: () => context.push('/trade'));\n",
                encoding="utf-8",
            )

            result = check_harness.check_spot_candle_contract(root)

        self.assertTrue(
            any("read-only without execution navigation" in error for error in result),
            msg=f"expected candle execution-boundary guard: {result}",
        )

    def test_perpetual_policy_cannot_be_reenabled(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/app/app_environment.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "static const perpetualsEnabled = true;\n"
                "static const spotExecutionEnabled = false;\n",
                encoding="utf-8",
            )
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("perpetualsEnabled = false" in error for error in result),
            msg=f"expected disabled perpetual policy guard: {result}",
        )

    def test_primary_feature_cannot_mount_perp_route(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/home/home_screens.dart"
            path.parent.mkdir(parents=True)
            path.write_text("context.push('/perp/account');\n", encoding="utf-8")
            result = check_harness.check_spot_only_product_contract(root)

        self.assertIn(
            "lib/features/home/home_screens.dart must not mount a retained Perp product route",
            result,
        )

    def test_application_router_cannot_remount_retained_perp_screen(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/app.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "import 'package:loop_mobile/features/perp/perp.dart';\n"
                "final page = PerpPositionsScreen();\n",
                encoding="utf-8",
            )
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("must redirect retained Perp" in error for error in result),
            msg=f"expected retained Perp router guard: {result}",
        )

    def test_production_entrypoint_cannot_compose_perp_gateway(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/main.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "final gateway = ref.watch(loopPerpSessionProvider);\n",
                encoding="utf-8",
            )
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("must not compose retained Perp" in error for error in result),
            msg=f"expected production Perp composition guard: {result}",
        )

    def test_providerless_token_preview_cannot_return_to_app_router(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/app.dart"
            path.parent.mkdir(parents=True)
            path.write_text("return TokenDetailScreen();\n", encoding="utf-8")
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("providerless token routes" in error for error in result),
            msg=f"expected providerless token route guard: {result}",
        )

    def test_providerless_source_cannot_build_raw_token_detail_route(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/home/home_screens.dart"
            path.parent.mkdir(parents=True)
            path.write_text("context.go('/market/token');\n", encoding="utf-8")
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("providerless token Preview routes" in error for error in result),
            msg=f"expected raw providerless route guard: {result}",
        )

    def test_providerless_source_cannot_invent_spot_index(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/market/market_secondary_screens.dart"
            path.parent.mkdir(parents=True)
            path.write_text(
                "final route = SpotMarketRoute.location(1035);\n",
                encoding="utf-8",
            )
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("providerless token Preview routes" in error for error in result),
            msg=f"expected invented Spot index guard: {result}",
        )

    def test_mounted_market_cannot_add_a_second_detail_route(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/market/market_screens.dart"
            path.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / "lib/features/market/market_screens.dart"
            ).read_text(encoding="utf-8")
            path.write_text(
                source + "\nfinal unsafeRoute = SpotMarketRoute.location(1035);\n",
                encoding="utf-8",
            )
            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any("exactly one token-detail route" in error for error in result),
            msg=f"expected duplicate Spot route guard: {result}",
        )

    def test_spot_detail_navigation_cannot_be_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "lib/features/market/market_screens.dart"
            path.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / "lib/features/market/market_screens.dart"
            ).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "class SpotMarketDetailScreen",
                    "class RemovedSpotMarketDetailScreen",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_spot_only_product_contract(root)

        self.assertTrue(
            any(
                "class SpotMarketDetailScreen" in error
                for error in result
            ),
            msg=f"expected Spot detail navigation guard: {result}",
        )

    def test_chat_spot_snapshot_cannot_restore_position_language(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "ETH spot market snapshot",
                    "ETH position snapshot",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("visible content must remain Spot-only" in error for error in result),
            msg=f"expected Chat position-language guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_alternate_position_terms(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace("label: 'Reference'", "label: 'Entry price'")
                .replace("label: '24h change'", "label: 'Total return'"),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("visible content must remain Spot-only" in error for error in result),
            msg=f"expected alternate Chat position-language guard: {result}",
        )

    def test_chat_spot_snapshot_cannot_restore_fake_save(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            watch_key = "ValueKey<String>('chat-spot-watch-unavailable')"
            start = source.index(watch_key)
            before = source[:start]
            watch = source[start:]
            watch = watch.replace(
                "onPressed: null",
                "onPressed: () => _showNotice(context, 'Setup saved for review.')",
                1,
            ).replace("Watch unavailable", "Save setup", 1)
            path.write_text(before + watch, encoding="utf-8")

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any(
                "notice-only action" in error
                or "visible content must remain Spot-only" in error
                for error in result
            ),
            msg=f"expected Chat fake-save guard: {result}",
        )

    def test_chat_spot_snapshot_watch_must_remain_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            watch_key = "ValueKey<String>('chat-spot-watch-unavailable')"
            start = source.index(watch_key)
            before = source[:start]
            watch = source[start:].replace("onPressed: null", "onPressed: () {}", 1)
            path.write_text(before + watch, encoding="utf-8")

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("Watch control must remain explicitly disabled" in error for error in result),
            msg=f"expected disabled Chat Watch guard: {result}",
        )

    def test_chat_spot_snapshot_market_action_cannot_become_noop(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "onPressed: () => context.go('/market')",
                    "onPressed: () {}",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("public `/market` ledger exactly once" in error for error in result),
            msg=f"expected exact Chat Market action guard: {result}",
        )

    def test_chat_spot_snapshot_market_route_cannot_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace("context.go('/market')", "context.go('/market/token')"),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any(
                "public `/market` ledger exactly once" in error
                or "invent a detail route" in error
                for error in result
            ),
            msg=f"expected Chat Market route-drift guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_a_second_gesture_action(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "const SizedBox(height: 9),",
                    "GestureDetector(\n"
                    "  onTap: () => context.go('/market/trade'),\n"
                    "  child: const Text('Trade ETH'),\n"
                    "),\n"
                    "const SizedBox(height: 9),",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any(
                "another interaction callback" in error
                or "second gesture" in error
                for error in result
            ),
            msg=f"expected additive Chat gesture guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_interaction_hidden_in_helper(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            source = source.replace(
                "class AssetSnapshotMessageCard extends StatelessWidget {",
                "class _ExtraTapSurface extends StatelessWidget {\n"
                "  const _ExtraTapSurface();\n"
                "  @override\n"
                "  Widget build(BuildContext context) => GestureDetector(\n"
                "    onTap: () => context.go('/market/trade'),\n"
                "    child: const Text('Trade ETH'),\n"
                "  );\n"
                "}\n\n"
                "class AssetSnapshotMessageCard extends StatelessWidget {",
            ).replace(
                "            const SizedBox(height: 13),",
                "            const _ExtraTapSurface(),\n"
                "            const SizedBox(height: 13),",
                1,
            )
            path.write_text(source, encoding="utf-8")

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("composition must stay closed" in error for error in result),
            msg=f"expected transitive Chat interaction guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_interaction_hidden_from_page(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/chat_preview_pages.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            source = source.replace(
                "class AssetMessagePreviewPage extends StatelessWidget {",
                "class _PageTapSurface extends StatelessWidget {\n"
                "  const _PageTapSurface();\n"
                "  @override\n"
                "  Widget build(BuildContext context) => GestureDetector(\n"
                "    onTap: () => context.go('/market/trade'),\n"
                "    child: const Text('Trade ETH'),\n"
                "  );\n"
                "}\n\n"
                "class AssetMessagePreviewPage extends StatelessWidget {",
            ).replace(
                "        const AssetSnapshotMessageCard(),",
                "        const AssetSnapshotMessageCard(),\n"
                "        const _PageTapSurface(),",
                1,
            )
            path.write_text(source, encoding="utf-8")

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("page must match its reviewed closed-source" in error for error in result),
            msg=f"expected closed E9 page interaction guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_buy_price_and_roi_terms(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace("label: 'Reference'", "label: 'Average buy price'")
                .replace("label: '24h change'", "label: 'ROI'"),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("reviewed Spot Preview fact allowlist" in error for error in result),
            msg=f"expected positive Chat fact allowlist guard: {result}",
        )

    def test_chat_spot_snapshot_rejects_external_fact_constants(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "label: 'Reference'",
                    "label: unsupportedAverageBuyPriceLabel",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("card must match its reviewed closed-source" in error for error in result),
            msg=f"expected external Chat fact-constant guard: {result}",
        )

    def test_chat_preview_cannot_claim_saved_address_or_active_alert(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/chat_content.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "I’m reviewing the address manually; transfer alerts are not connected in this preview.",
                    "Address saved; transfer monitoring is active.",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("saved addresses, or active alerts" in error for error in result),
            msg=f"expected Chat fixture capability-claim guard: {result}",
        )

    def test_chat_preview_rejects_unreviewed_localized_capability_claim(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/chat_content.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "  static const voiceRoom = VoiceRoomSummary(",
                    "  static const unsupportedClaim = '地址已收藏，转账提醒已开启。';\n\n"
                    "  static const voiceRoom = VoiceRoomSummary(",
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("saved addresses, or active alerts" in error for error in result),
            msg=f"expected localized Chat capability-claim guard: {result}",
        )

    def test_chat_preview_rejects_capability_copy_imported_from_another_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/chat_content.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "text: 'That unlock schedule is worth watching.',",
                    "text: unsupportedActiveAlertCopy,",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("content must match its reviewed closed-source" in error for error in result),
            msg=f"expected imported Chat capability-copy guard: {result}",
        )

    def test_chat_spot_snapshot_requires_visible_preview_attribution(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/chat/widgets/chat_components.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "Shared at 14:12 · 演示数据",
                    "Shared at 14:12",
                ).replace("SPOT PREVIEW", "SPOT"),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("Shared at 14:12 · 演示数据" in error for error in result),
            msg=f"expected Chat Preview attribution guard: {result}",
        )

    def test_chat_spot_snapshot_behavior_evidence_cannot_be_hollowed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "expect(find.text('SPOT PREVIEW'), findsOneWidget);",
                    "final ignoredPreview = find.text('SPOT PREVIEW');\n"
                    "      expect(true, isTrue);",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("must execute its exact Spot-only assertions directly" in error for error in result),
            msg=f"expected non-hollow Chat Spot evidence guard: {result}",
        )

    def test_chat_spot_snapshot_assertions_cannot_hide_in_dead_branch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            source = source.replace(
                "      expect(\n"
                "        find.byKey(const ValueKey<String>('chat-spot-snapshot-card')),",
                "      if (tester.view.physicalSize.width < 0) {\n"
                "        expect(\n"
                "          find.byKey(const ValueKey<String>('chat-spot-snapshot-card')),",
                1,
            )
            source = source.replace(
                "      expect(watchButton.onPressed, isNull);",
                "        expect(watchButton.onPressed, isNull);\n"
                "      }\n"
                "      expect(true, isTrue);",
                1,
            )
            path.write_text(source, encoding="utf-8")

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("must execute its exact Spot-only assertions directly" in error for error in result),
            msg=f"expected reachable Chat Spot evidence guard: {result}",
        )

    def test_chat_spot_snapshot_behavior_tests_cannot_be_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "    },\n  );",
                    "    },\n    skip: true,\n  );",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("contract tests cannot be skipped" in error for error in result),
            msg=f"expected non-skipped Chat Spot evidence guard: {result}",
        )

    def test_chat_spot_snapshot_cannot_shadow_expect(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "void main() {",
                    "expect(actual, matcher) {}\n\nvoid main() {",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("cannot shadow flutter_test evidence symbols" in error for error in result),
            msg=f"expected non-shadowed Chat Spot evidence guard: {result}",
        )

    def test_chat_spot_snapshot_cannot_shadow_expect_with_callable_type(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "void main() {",
                    "NoopExpect expect = const NoopExpect();\n\nvoid main() {",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("cannot shadow flutter_test evidence symbols" in error for error in result),
            msg=f"expected typed callable-shadow guard: {result}",
        )

    def test_chat_spot_snapshot_cannot_call_mark_test_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "test/chat_spot_snapshot_test.dart"
            path = root / relative
            path.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            path.write_text(
                source.replace(
                    "      await _pumpSpotPreview(tester);",
                    "      markTestSkipped('disabled');\n"
                    "      await _pumpSpotPreview(tester);",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_chat_spot_snapshot_contract(root)

        self.assertTrue(
            any("contract tests cannot be skipped" in error for error in result),
            msg=f"expected markTestSkipped guard: {result}",
        )

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

    def test_wallet_creation_must_remain_principal_bound(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in (
                "lib/integrations/privy/privy_auth_gateway.dart",
                "lib/app/session/loop_session_controller.dart",
                "test/loop_session_controller_test.dart",
            ):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(
                    (REPOSITORY_ROOT / relative).read_text(encoding="utf-8"),
                    encoding="utf-8",
                )
            gateway = root / "lib/integrations/privy/privy_auth_gateway.dart"
            gateway.write_text(
                gateway.read_text(encoding="utf-8").replace(
                    "_walletCreationOwner != expectedPrivyUserId",
                    "false",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_product_contract(root)
        self.assertTrue(
            any("_walletCreationOwner != expectedPrivyUserId" in error for error in result),
            msg=f"expected principal-bound wallet guard: {result}",
        )

    def test_wallet_readiness_must_keep_verified_session_gate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_readiness.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("!session.canUseProviderBackedFeatures", "false"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("!session.canUseProviderBackedFeatures" in error for error in result),
            msg=f"expected verified Wallet gate: {result}",
        )

    def test_wallet_clipboard_must_keep_the_exact_current_address(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_overview_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "ClipboardData(text: address)",
                    "ClipboardData(text: shortenedAddress)",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("copy only the exact current address" in error for error in result),
            msg=f"expected exact Wallet clipboard guard: {result}",
        )

    def test_wallet_identity_cannot_bypass_the_guarded_clipboard_flow(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_overview_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "Text(\n              readiness.ethereumAddress!",
                    "SelectableText(\n              readiness.ethereumAddress!",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("session-revalidated clipboard buttons" in error for error in result),
            msg=f"expected Wallet selection-copy bypass guard: {result}",
        )

    def test_wallet_clipboard_must_revalidate_after_the_platform_write(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_overview_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "final latest = WalletReadiness.fromSession("
                    "ref.read(loopSessionProvider));",
                    "final latest = current;",
                    1,
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("before and after every platform write" in error for error in result),
            msg=f"expected Wallet clipboard revalidation guard: {result}",
        )

    def test_receive_cannot_infer_a_qr_code_from_wallet_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_overview_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source + "\nfinal unsafeQr = Icons.qr_code_2_rounded;\n",
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("must not infer a QR code" in error for error in result),
            msg=f"expected Receive QR guard: {result}",
        )

    def test_wallet_feature_cannot_import_privy_sdk_directly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "lib/features/wallet/unsafe.dart"
            target.parent.mkdir(parents=True)
            target.write_text(
                "import 'package:privy_flutter/privy_flutter.dart';\n",
                encoding="utf-8",
            )
            result = check_harness.check_wallet_identity_readiness_contract(root)

        self.assertTrue(
            any("must use the session boundary" in error for error in result),
            msg=f"expected Privy SDK ownership guard: {result}",
        )

    def test_wallet_asset_route_cannot_default_to_an_unbound_asset(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/app.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "state.extra is WalletPreviewAsset ? null : '/wallet'",
                    "true ? null : '/wallet'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_preview_route_contract(root)

        self.assertTrue(
            any("state.extra is WalletPreviewAsset" in error for error in result),
            msg=f"expected typed Wallet asset route guard: {result}",
        )

    def test_signing_review_route_cannot_restore_a_fallback_intent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/app.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "state.extra is SigningIntent ? null : '/wallet'",
                    "true ? null : '/wallet'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_preview_route_contract(root)

        self.assertTrue(
            any("state.extra is SigningIntent" in error for error in result),
            msg=f"expected Signing Review origin guard: {result}",
        )

    def test_dapp_preview_cannot_restore_a_fixture_wallet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("Current wallet identity", "Selected wallet"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_preview_route_contract(root)

        self.assertTrue(
            any("must not invent a wallet identity" in error for error in result),
            msg=f"expected DApp wallet identity guard: {result}",
        )

    def test_dapp_preview_cannot_use_any_address_literal(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "class ApprovalInterceptScreen",
                    "const unsafeDappWallet = "
                    "'0x6666666666666666666666666666666666666666';\n\n"
                    "class ApprovalInterceptScreen",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_preview_route_contract(root)

        self.assertTrue(
            any("never an address literal" in error for error in result),
            msg=f"expected generic DApp address-literal guard: {result}",
        )

    def test_wallet_catalog_cannot_restore_planned_capability_claims(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/core/navigation/surface_catalog.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "Current Privy wallet identity plus labelled portfolio fixtures; balances and funds actions remain unavailable.",
                    "Portfolio and wallet actions across supported accounts.",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_preview_route_contract(root)

        self.assertTrue(
            any("must report delivery truth" in error for error in result),
            msg=f"expected Wallet catalog truth guard: {result}",
        )

    def test_transfer_amount_cannot_relax_its_exact_regex(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/transfer_amount.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    r"r'^(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$'",
                    r"r'^[0-9.]+$'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("exact positive-decimal regex" in error for error in result),
            msg=f"expected exact transfer regex guard: {result}",
        )

    def test_transfer_amount_regex_must_consume_the_complete_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/transfer_amount.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "match == null || match.start != 0 || match.end != source.length",
                    "match == null",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("consume the complete source String" in error for error in result),
            msg=f"expected full transfer regex consumption guard: {result}",
        )

    def test_transfer_amount_cannot_expand_its_wire_bound(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/transfer_amount.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("maxWireLength = 128", "maxWireLength = 129"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("bounded to 128" in error for error in result),
            msg=f"expected transfer length guard: {result}",
        )

    def test_transfer_amount_cannot_normalize_accepted_trailing_zeros(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/transfer_amount.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "TransferAmount._(wire: source)",
                    "TransferAmount._(wire: value.toString())",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("preserve the accepted source String" in error for error in result),
            msg=f"expected exact transfer wire guard: {result}",
        )

    def test_transfer_review_cannot_remove_single_flight(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/send_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("if (reviewOpening) return;", ""),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("Transfer review navigation must remain single-flight" in error for error in result),
            msg=f"expected transfer review single-flight guard: {result}",
        )

    def test_transfer_input_cannot_silently_truncate_overlong_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/send_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "maxLengthEnforcement: MaxLengthEnforcement.none,",
                    "",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("preserve overlong source text" in error for error in result),
            msg=f"expected non-truncating transfer input guard: {result}",
        )

    def test_swap_edit_cannot_keep_a_stale_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("setState(() => snapshot = null);", "return;"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("edits must invalidate" in error for error in result),
            msg=f"expected Swap invalidation guard: {result}",
        )

    def test_swap_restore_cannot_leave_the_edited_controller(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "payController.value = TextEditingValue",
                    "final ignored = TextEditingValue",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("restore its input controller" in error for error in result),
            msg=f"expected Swap controller restore guard: {result}",
        )

    def test_swap_restore_cannot_leave_the_snapshot_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("snapshot = restored;", "snapshot = null;"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("restore the same immutable snapshot" in error for error in result),
            msg=f"expected Swap snapshot restore guard: {result}",
        )

    def test_swap_route_cannot_accept_missing_typed_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/app.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "state.extra is SwapPreviewSnapshot ? null : '/wallet/swap'",
                    "true ? null : '/wallet/swap'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("state.extra is SwapPreviewSnapshot" in error for error in result),
            msg=f"expected typed Swap route guard: {result}",
        )

    def test_swap_review_cannot_diverge_from_snapshot_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/swap_preview_snapshot.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "receive: receiveLabel",
                    "receive: 'stale fixture'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("derive every field from one snapshot" in error for error in result),
            msg=f"expected Swap snapshot-source guard: {result}",
        )

    def test_swap_review_cannot_remove_snapshot_single_flight(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "if (reviewOpening || !identical(snapshot, currentSnapshot)) return;",
                    "if (!identical(snapshot, currentSnapshot)) return;",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("snapshot-bound and single-flight" in error for error in result),
            msg=f"expected Swap review single-flight guard: {result}",
        )

    def test_swap_quote_navigation_cannot_drop_typed_extra(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "context.push('/wallet/swap/route', extra: currentSnapshot)",
                    "context.push('/wallet/swap/route')",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("second truth source" in error for error in result),
            msg=f"expected typed Swap navigation guard: {result}",
        )

    def test_swap_cannot_restore_a_parallel_quote_boolean(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "SwapPreviewSnapshot? snapshot = SwapPreviewSnapshot.demo;",
                    "bool quoteCurrent = true;\n"
                    "  SwapPreviewSnapshot? snapshot = SwapPreviewSnapshot.demo;",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("bool quoteCurrent" in error for error in result),
            msg=f"expected single Swap validity-state guard: {result}",
        )

    def test_swap_route_cannot_restore_a_static_amount(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "value: snapshot.receiveLabel",
                    "value: '2302.18'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("quote literals belong only" in error for error in result),
            msg=f"expected Swap route literal guard: {result}",
        )

    def test_swap_intent_cannot_become_backend_canonical_locally(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/core/intent/signing_intent.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            swap_start = source.index("factory SigningIntent.swap")
            swap_end = source.index("factory SigningIntent.approval", swap_start)
            swap_source = source[swap_start:swap_end].replace(
                "origin: IntentOrigin.localPreview",
                "origin: IntentOrigin.backendCanonical",
            )
            target.write_text(
                source[:swap_start] + swap_source + source[swap_end:],
                encoding="utf-8",
            )
            result = check_harness.check_wallet_local_draft_contract(root)

        self.assertTrue(
            any("must remain a local Preview intent" in error for error in result),
            msg=f"expected local Swap intent guard: {result}",
        )

    def test_wallet_history_filter_must_drive_rendered_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "WalletPreviewActivity.filteredBy(filter)",
                    "WalletPreviewActivity.all",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("History selection must drive" in error for error in result),
            msg=f"expected active Wallet History filter guard: {result}",
        )

    def test_wallet_history_category_cannot_match_every_activity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_preview_activity.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "activity.kind == WalletPreviewActivityKind.sent",
                    "true",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any(
                "activity.kind == WalletPreviewActivityKind.sent" in error
                for error in result
            ),
            msg=f"expected exact Wallet History category guard: {result}",
        )

    def test_wallet_testnet_switch_must_drive_preview_row(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("if (testnets)", "if (true)"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("testnet selection must drive" in error for error in result),
            msg=f"expected active Wallet testnet filter guard: {result}",
        )

    def test_wallet_testnet_switch_callback_cannot_become_noop(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "setState(() => testnets = value)",
                    "setState(() {})",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("setState(() => testnets = value)" in error for error in result),
            msg=f"expected Wallet testnet callback guard: {result}",
        )

    def test_wallet_revocation_cannot_become_an_enabled_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "onPressed: null,\n"
                    "                  child: const Text('Revocation unavailable'),",
                    "onPressed: () {},\n"
                    "                  child: const Text('Revocation unavailable'),",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("revocation must remain visibly disabled" in error for error in result),
            msg=f"expected disabled Wallet revocation guard: {result}",
        )

    def test_wallet_allowance_preview_cannot_add_an_enabled_action(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/wallet_management_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "class DappListScreen",
                    "final unsafeRevoke = FilledButton(\n"
                    "  onPressed: () {},\n"
                    "  child: const Text('Revoke now'),\n"
                    ");\n\n"
                    "class DappListScreen",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("allowance Preview cannot add" in error for error in result),
            msg=f"expected additive Wallet action guard: {result}",
        )

    def test_bridge_status_route_cannot_accept_missing_typed_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/app.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "state.extra is BridgePreviewSnapshot ? null : '/wallet/bridge'",
                    "true ? null : '/wallet/bridge'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("state.extra is BridgePreviewSnapshot" in error for error in result),
            msg=f"expected typed Bridge status route guard: {result}",
        )

    def test_bridge_preview_navigation_must_carry_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("extra: snapshot", "extra: null"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("must carry its typed snapshot" in error for error in result),
            msg=f"expected Bridge snapshot navigation guard: {result}",
        )

    def test_bridge_status_builder_cannot_fall_back_to_demo(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/app.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "snapshot: state.extra! as BridgePreviewSnapshot",
                    "snapshot: BridgePreviewSnapshot.demo",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any(
                "snapshot: state.extra! as BridgePreviewSnapshot" in error
                for error in result
            ),
            msg=f"expected Bridge builder origin guard: {result}",
        )

    def test_bridge_preview_switch_cannot_become_noop(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace("snapshot.withNeedsClaim(value)", "snapshot"),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("snapshot.withNeedsClaim(value)" in error for error in result),
            msg=f"expected active Bridge Preview switch guard: {result}",
        )

    def test_bridge_facts_cannot_escape_the_typed_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "value: snapshot.sourceLabel",
                    "value: 'Ethereum · 250 USDC'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("Bridge Preview facts belong only" in error for error in result),
            msg=f"expected single Bridge snapshot source guard: {result}",
        )

    def test_bridge_progress_facts_cannot_escape_the_typed_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "title: step.title",
                    "title: 'Source confirmed'",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("Bridge Preview facts belong only" in error for error in result),
            msg=f"expected typed Bridge progress-step guard: {result}",
        )

    def test_bridge_progress_preview_cannot_add_an_enabled_action(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/trade_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "class _BridgeStep",
                    "final unsafeClaim = FilledButton(\n"
                    "  onPressed: () {},\n"
                    "  child: const Text('Claim now'),\n"
                    ");\n\n"
                    "class _BridgeStep",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("Bridge progress Preview cannot add" in error for error in result),
            msg=f"expected additive Bridge action guard: {result}",
        )

    def test_transaction_result_success_cannot_claim_a_transfer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = "lib/features/wallet/send_screens.dart"
            target = root / relative
            target.parent.mkdir(parents=True)
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            target.write_text(
                source.replace(
                    "No transfer occurred or was submitted. No success receipt exists.",
                    "Transfer completed. No transfer occurred or was submitted. No success receipt exists.",
                ),
                encoding="utf-8",
            )
            result = check_harness.check_wallet_providerless_controls_contract(root)

        self.assertTrue(
            any("must not claim provider activity" in error for error in result),
            msg=f"expected transaction-result truth guard: {result}",
        )

    def test_wallet_providerless_behavior_tests_cannot_be_hollowed_out(self) -> None:
        for (
            relative,
            markers,
        ) in check_harness.WALLET_PROVIDERLESS_CONTROL_BEHAVIOR_TEST_MARKERS.items():
            forged_markers = ", ".join(repr(marker) for marker in markers)
            hollow_tests = "\n".join(
                f"test({marker!r}, () {{ final observed = true; }});"
                for marker in markers
            )
            dummy_assertions = "\n".join(
                f"test({marker!r}, () {{ expect(true, isTrue); }});"
                for marker in markers
            )
            hollow_sources = (
                "void main() {}\n",
                f"void main() {{ const markers = <String>[{forged_markers}]; }}\n",
                "void main() {\n" + hollow_tests + "\n}\n",
                "void main() {\n" + dummy_assertions + "\n}\n",
            )
            for source_text in hollow_sources:
                with self.subTest(path=str(relative), source=source_text):
                    with tempfile.TemporaryDirectory() as temporary:
                        root = Path(temporary)
                        test_path = root / relative
                        test_path.parent.mkdir(parents=True)
                        test_path.write_text(source_text, encoding="utf-8")

                        result = (
                            check_harness.check_wallet_providerless_controls_contract(
                                root
                            )
                        )

                    self.assertTrue(
                        any(
                            "missing required behavior evidence" in error
                            or "lacks executable contract evidence" in error
                            for error in result
                        ),
                        msg=f"expected non-hollow Wallet control guard: {result}",
                    )

    def test_wallet_providerless_every_marker_has_executable_evidence(self) -> None:
        for (
            relative,
            markers,
        ) in check_harness.WALLET_PROVIDERLESS_CONTROL_BEHAVIOR_TEST_MARKERS.items():
            configured = (
                check_harness.WALLET_PROVIDERLESS_CONTROL_EXECUTABLE_TEST_EVIDENCE.get(
                    relative,
                    {},
                )
            )
            self.assertEqual(set(markers), set(configured), msg=str(relative))

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
                "final notifications = MemoryNotificationPreferencesGateway();\n"
                "final privacy = MemoryPrivacyGateway();\n"
                "final profile = MemoryProfileGateway();\n"
                "final watchlist = MemoryWatchlistGateway();\n"
                "final market = HyperliquidFixtureAdapter();\n"
                "final wallet = PrivyFixtureAdapter();\n",
                encoding="utf-8",
            )
            result = check_harness.check_providerless_application_contract(root)
        self.assertEqual(7, len(result))
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

    def test_profile_provider_must_default_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gateway = root / check_harness.PROFILE_GATEWAY_PATH
            gateway.parent.mkdir(parents=True)
            gateway.write_text(
                "final profileGatewayProvider = Provider<ProfileGateway>(\n"
                "  (ref) => MemoryProfileGateway(),\n"
                ");\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("must default directly" in error for error in result),
            msg=f"expected unavailable Profile provider guard: {result}",
        )

    def test_profile_values_fields_must_match_exact_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.PROFILE_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "final class ProfileValues {\n"
                "  final String? alias;\n"
                "  final String? avatarRef;\n"
                "  final String? displayName = null;\n"
                "}\n"
                "final class ProfileResource {\n"
                "  final int version;\n"
                "  final ProfileValues values;\n"
                "  final DateTime? updatedAt;\n"
                "  final String? etag = null;\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("fields must be exactly" in error for error in result),
            msg=f"expected exact Profile field guard: {result}",
        )
        self.assertTrue(
            any("ProfileResource fields" in error for error in result),
            msg=f"expected exact Profile resource guard: {result}",
        )

    def test_profile_field_guard_sees_collection_initializer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.PROFILE_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "final class ProfileValues {\n"
                "  final String? alias;\n"
                "  final String? avatarRef;\n"
                "  final Map<String, Object?> metadata = {};\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("ProfileValues fields" in error for error in result),
            msg=f"expected collection-initializer field guard: {result}",
        )

    def test_profile_field_guard_sees_annotated_field(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.PROFILE_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "final class ProfileValues {\n"
                "  final String? alias;\n"
                "  final String? avatarRef;\n"
                "  @Deprecated('not in the contract')\n"
                "  final String? bio;\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("ProfileValues fields" in error for error in result),
            msg=f"expected annotated field guard: {result}",
        )

    def test_profile_field_guard_sees_multi_variable_declaration(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.PROFILE_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "final class ProfileValues {\n"
                "  final String? alias;\n"
                "  final String? avatarRef;\n"
                "  final String? bio, displayName;\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("ProfileValues fields" in error for error in result),
            msg=f"expected multi-variable field guard: {result}",
        )

    def test_profile_ui_cannot_claim_an_unverified_save(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            surface = root / check_harness.PROFILE_SURFACE_PATH
            surface.parent.mkdir(parents=True)
            surface.write_text(
                "class _ProfileEdit {\n"
                "  void save() => SnackBar(content: Text('All set'));\n"
                "}\n"
                "class _PrivacyCenter {}\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("ad-hoc SnackBar" in error for error in result),
            msg=f"expected false Profile save guard: {result}",
        )

    def test_profile_feature_cannot_use_positive_save_language(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = (
                root / "lib" / "features" / "profile" / "success_helper.dart"
            )
            source.parent.mkdir(parents=True)
            source.write_text(
                "final card = LoopStateCard(title: 'Saved successfully');\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("positive Profile save language" in error for error in result),
            msg=f"expected positive Profile save guard: {result}",
        )

    def test_profile_save_guard_detects_exact_and_adjacent_saved_strings(self) -> None:
        examples = (
            "final label = 'Saved';\n",
            "final label = 'Saved!';\n",
            "final label = '\\u0053aved';\n",
            "final label = 'Profile changes ' 'saved';\n",
        )
        for source_text in examples:
            with self.subTest(source=source_text):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    source = (
                        root
                        / "lib"
                        / "features"
                        / "profile"
                        / "success_helper.dart"
                    )
                    source.parent.mkdir(parents=True)
                    source.write_text(source_text, encoding="utf-8")

                    result = check_harness.check_profile_application_contract(root)

                self.assertTrue(
                    any(
                        "positive Profile save language" in error
                        for error in result
                    ),
                    msg=f"expected positive Profile save guard: {result}",
                )

    def test_profile_save_guard_allows_reload_status_language(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = (
                root / "lib" / "features" / "profile" / "reload_status.dart"
            )
            source.parent.mkdir(parents=True)
            source.write_text(
                "final complete = 'Reload successful';\n"
                "final incomplete = 'Reload was not successful';\n"
                "final update = 'Reload update complete';\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertFalse(
            any("positive Profile save language" in error for error in result),
            msg=f"unexpected reload-language rejection: {result}",
        )

    def test_profile_memory_gateway_cannot_be_composed_by_a_feature(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "profile" / "unsafe_profile.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "final gatewayFactory = MemoryProfileGateway.new;\n",
                encoding="utf-8",
            )

            result = check_harness.check_profile_application_contract(root)

        self.assertTrue(
            any("references MemoryProfileGateway" in error for error in result),
            msg=f"expected Preview-only Profile fake guard: {result}",
        )

    def test_privacy_provider_must_default_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gateway = root / check_harness.PRIVACY_GATEWAY_PATH
            gateway.parent.mkdir(parents=True)
            gateway.write_text(
                "final privacyGatewayProvider = Provider<PrivacyGateway>(\n"
                "  (ref) => MemoryPrivacyGateway(),\n"
                ");\n",
                encoding="utf-8",
            )

            result = check_harness.check_privacy_application_contract(root)

        self.assertTrue(
            any("must default directly" in error for error in result),
            msg=f"expected unavailable Privacy provider guard: {result}",
        )

    def test_privacy_models_must_match_exact_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.PRIVACY_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(
                "enum CopyTradeVisibility {\n"
                "  private, followers, public, friends;\n"
                "  String get wireValue => switch (this) {\n"
                "    CopyTradeVisibility.private => 'pri',\n"
                "    CopyTradeVisibility.followers => 'fol',\n"
                "    CopyTradeVisibility.public => 'pub',\n"
                "    CopyTradeVisibility.friends => 'fri',\n"
                "  };\n"
                "  static CopyTradeVisibility fromWire(String value) => switch (value) {\n"
                "    'pri' => CopyTradeVisibility.private,\n"
                "    'fol' => CopyTradeVisibility.followers,\n"
                "    'pub' => CopyTradeVisibility.public,\n"
                "    _ => CopyTradeVisibility.private,\n"
                "  };\n"
                "}\n"
                "final class PrivacyValues {\n"
                "  final bool discoverable;\n"
                "  final CopyTradeVisibility copyTradeVisibility;\n"
                "  final bool activityVisible = false;\n"
                "}\n"
                "final class PrivacyResource {\n"
                "  final int version;\n"
                "  final PrivacyValues values;\n"
                "  final DateTime? updatedAt;\n"
                "  final String? etag = null;\n"
                "}\n",
                encoding="utf-8",
            )

            result = check_harness.check_privacy_application_contract(root)

        self.assertTrue(
            any("CopyTradeVisibility" in error for error in result),
            msg=f"expected exact Privacy enum guard: {result}",
        )
        self.assertTrue(
            any("PrivacyValues fields" in error for error in result),
            msg=f"expected exact Privacy values guard: {result}",
        )
        self.assertTrue(
            any("PrivacyResource fields" in error for error in result),
            msg=f"expected exact Privacy resource guard: {result}",
        )
        self.assertTrue(
            any("wire values" in error for error in result),
            msg=f"expected exact Privacy wire-value guard: {result}",
        )

    def test_privacy_and_copy_surfaces_cannot_restore_fake_controls(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            surface = root / check_harness.PRIVACY_SURFACE_PATH
            surface.parent.mkdir(parents=True)
            surface.write_text(
                "class _PrivacyCenter {\n"
                "  final _portfolioBroadcast = false;\n"
                "  final title = 'Portfolio Broadcast';\n"
                "}\n"
                "class _PrivacyModeBanner {}\n"
                "class _CopyTradePermissions {\n"
                "  void apply() => SnackBar(content: Text('Save permissions'));\n"
                "}\n"
                "class _SecurityCenter {}\n",
                encoding="utf-8",
            )

            result = check_harness.check_privacy_application_contract(root)

        self.assertTrue(
            any("removed non-contract state" in error for error in result),
            msg=f"expected legacy Privacy state guard: {result}",
        )
        self.assertTrue(
            any("non-actionable truthful placeholder" in error for error in result),
            msg=f"expected Copy-trade placeholder guard: {result}",
        )
        self.assertTrue(
            any("unsupported permission UI" in error for error in result),
            msg=f"expected fake Copy permission copy guard: {result}",
        )

    def test_privacy_memory_gateway_cannot_be_composed_by_a_feature(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "lib" / "features" / "profile" / "fake_privacy.dart"
            source.parent.mkdir(parents=True)
            source.write_text(
                "final gatewayFactory = MemoryPrivacyGateway.new;\n",
                encoding="utf-8",
            )

            result = check_harness.check_privacy_application_contract(root)

        self.assertTrue(
            any("references MemoryPrivacyGateway" in error for error in result),
            msg=f"expected Preview-only Privacy fake guard: {result}",
        )

    def test_copy_trade_placeholder_rejects_ordinary_interactions(self) -> None:
        interactions = (
            "FilledButton(onPressed: grantCopyAccess, child: Text('Grant'))",
            "Listener(onPointerDown: grantCopyAccess, child: Text('Grant'))",
        )
        for interaction in interactions:
            with self.subTest(interaction=interaction):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    surface = root / check_harness.PRIVACY_SURFACE_PATH
                    surface.parent.mkdir(parents=True)
                    surface.write_text(
                        "class _PrivacyCenter {}\n"
                        "class _PrivacyModeBanner {}\n"
                        "class _CopyTradePermissions {\n"
                        f"  final action = {interaction};\n"
                        "}\n"
                        "class _SecurityCenter {}\n",
                        encoding="utf-8",
                    )

                    result = check_harness.check_privacy_application_contract(root)

                self.assertTrue(
                    any(
                        "non-actionable truthful placeholder" in error
                        for error in result
                    ),
                    msg=f"expected ordinary Copy-trade interaction guard: {result}",
                )

    def test_privacy_commit_language_requires_resource_evidence(self) -> None:
        examples = (
            ("final label = 'Preferences saved';\n", True),
            ("final label = 'Update succeeded';\n", True),
            ("final label = 'All changes are now live';\n", True),
            ("final label = 'Success';\n", True),
            ("final label = '设置已保存';\n", True),
            ("final label = '保存成功';\n", True),
            ("final label = 'Preferences were not committed';\n", False),
        )
        for source_text, rejected in examples:
            with self.subTest(source=source_text):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    source = (
                        root
                        / "lib"
                        / "features"
                        / "profile"
                        / "privacy_status.dart"
                    )
                    source.parent.mkdir(parents=True)
                    source.write_text(source_text, encoding="utf-8")

                    result = check_harness.check_privacy_application_contract(root)

                detected = any(
                    "positive Privacy commit language" in error
                    for error in result
                )
                self.assertEqual(rejected, detected, msg=f"unexpected guard: {result}")

    def test_privacy_behavior_tests_cannot_be_hollowed_out(self) -> None:
        for relative, markers in check_harness.PRIVACY_BEHAVIOR_TEST_MARKERS.items():
            forged_markers = ", ".join(repr(marker) for marker in markers)
            hollow_sources = (
                "void main() {}\n",
                f"void main() {{ const markers = <String>[{forged_markers}]; }}\n",
            )
            for source_text in hollow_sources:
                with self.subTest(path=str(relative), source=source_text):
                    with tempfile.TemporaryDirectory() as temporary:
                        root = Path(temporary)
                        test_path = root / relative
                        test_path.parent.mkdir(parents=True)
                        test_path.write_text(source_text, encoding="utf-8")

                        result = check_harness.check_privacy_application_contract(
                            root
                        )

                    self.assertTrue(
                        any(
                            "missing required behavior evidence" in error
                            for error in result
                        ),
                        msg=f"expected non-hollow Privacy behavior guard: {result}",
                    )

    def test_notification_preferences_paths_are_required(self) -> None:
        expected = {
            "docs/decisions/0012-model-notification-preferences-before-http-adapter.md",
            "lib/features/profile/notification_preferences/notification_preferences_controller.dart",
            "lib/features/profile/notification_preferences/notification_preferences_gateway.dart",
            "lib/features/profile/notification_preferences/notification_preferences_models.dart",
            "lib/integrations/personalization/memory_notification_preferences_gateway.dart",
            "test/notification_preferences_controller_test.dart",
            "test/notification_preferences_models_test.dart",
            "test/notification_preferences_screen_test.dart",
        }

        self.assertTrue(expected.issubset(set(check_harness.REQUIRED_FILES)))

    def test_notification_preferences_provider_must_default_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gateway = root / check_harness.NOTIFICATION_PREFERENCES_GATEWAY_PATH
            gateway.parent.mkdir(parents=True)
            gateway.write_text(
                "final notificationPreferencesGatewayProvider = "
                "Provider<NotificationPreferencesGateway>(\n"
                "  (ref) => MemoryNotificationPreferencesGateway(),\n"
                ");\n",
                encoding="utf-8",
            )

            result = (
                check_harness.check_notification_preferences_application_contract(
                    root
                )
            )

        self.assertTrue(
            any("must default directly" in error for error in result),
            msg=f"expected unavailable Notification Preferences guard: {result}",
        )

    def test_notification_preferences_models_must_match_exact_contract(
        self,
    ) -> None:
        valid_source = self._notification_preferences_models_source()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            models = root / check_harness.NOTIFICATION_PREFERENCES_MODELS_PATH
            models.parent.mkdir(parents=True)
            models.write_text(valid_source, encoding="utf-8")
            valid_result = (
                check_harness.check_notification_preferences_application_contract(
                    root
                )
            )

            invalid_source = valid_source.replace(
                "  supportUpdate;",
                "  supportUpdate,\n  marketing;",
            ).replace(
                "    NotificationPreferenceEvent.supportUpdate => 'support_update',",
                "    NotificationPreferenceEvent.supportUpdate => 'support_update',\n"
                "    NotificationPreferenceEvent.marketing => 'marketing',",
            ).replace(
                "    'support_update' => NotificationPreferenceEvent.supportUpdate,",
                "    'support_update' => NotificationPreferenceEvent.supportUpdate,\n"
                "    'marketing' => NotificationPreferenceEvent.marketing,",
            ).replace(
                "  unavailable;",
                "  unavailable,\n  available;",
            ).replace(
                "    NotificationDeliveryState.unavailable => 'unavailable',",
                "    NotificationDeliveryState.unavailable => 'unavailable',\n"
                "    NotificationDeliveryState.available => 'available',",
            ).replace(
                "    'unavailable' => NotificationDeliveryState.unavailable,",
                "    'unavailable' => NotificationDeliveryState.unavailable,\n"
                "    'available' => NotificationDeliveryState.available,",
            ).replace(
                "  final bool supportUpdate;",
                "  final bool supportUpdate;\n  final bool marketing;",
            ).replace(
                "  final NotificationDeliveryState delivery;",
                "  final NotificationDeliveryState delivery;\n"
                "  final DateTime? updatedAt;",
            )
            models.write_text(invalid_source, encoding="utf-8")
            invalid_result = (
                check_harness.check_notification_preferences_application_contract(
                    root
                )
            )

        self.assertEqual([], valid_result)
        self.assertTrue(
            any("NotificationPreferenceEvent must contain exactly" in error for error in invalid_result)
        )
        self.assertTrue(
            any("NotificationPreferenceEvent wire values" in error for error in invalid_result)
        )
        self.assertTrue(
            any("NotificationDeliveryState must contain only" in error for error in invalid_result)
        )
        self.assertTrue(
            any("NotificationDeliveryState wire values" in error for error in invalid_result)
        )
        self.assertTrue(
            any("NotificationPreferenceValues fields" in error for error in invalid_result)
        )
        self.assertTrue(
            any("NotificationPreferencesResource fields" in error for error in invalid_result)
        )

    def test_notification_preference_wire_parsers_must_fail_closed(self) -> None:
        examples = (
            (
                "_ => throw Exception(),",
                "_ => NotificationPreferenceEvent.priceAlertTriggered,",
                "NotificationPreferenceEvent wire values",
            ),
            (
                "_ => throw StateError('delivery'),",
                "_ => NotificationDeliveryState.unavailable,",
                "NotificationDeliveryState wire values",
            ),
        )
        for original, replacement, expected_error in examples:
            with self.subTest(expected_error=expected_error):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    models = (
                        root / check_harness.NOTIFICATION_PREFERENCES_MODELS_PATH
                    )
                    models.parent.mkdir(parents=True)
                    source = self._notification_preferences_models_source()
                    self.assertIn(original, source)
                    models.write_text(
                        source.replace(original, replacement, 1),
                        encoding="utf-8",
                    )

                    result = check_harness.check_notification_preferences_application_contract(
                        root
                    )

                self.assertTrue(
                    any(expected_error in error for error in result),
                    msg=f"expected fail-closed wire guard: {result}",
                )

    def test_notification_preferences_memory_gateway_is_preview_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = (
                root
                / "lib"
                / "features"
                / "profile"
                / "notification_preferences"
                / "unsafe_fake.dart"
            )
            source.parent.mkdir(parents=True)
            source.write_text(
                "final gatewayFactory = MemoryNotificationPreferencesGateway.new;\n",
                encoding="utf-8",
            )

            result = (
                check_harness.check_notification_preferences_application_contract(
                    root
                )
            )

        self.assertTrue(
            any(
                "references MemoryNotificationPreferencesGateway" in error
                for error in result
            ),
            msg=f"expected Preview-only Notification Preferences fake guard: {result}",
        )

    def test_notification_preferences_preview_requires_exactly_one_memory_gateway(
        self,
    ) -> None:
        preview_sources = (
            "void main() {}\n",
            "final first = MemoryNotificationPreferencesGateway();\n"
            "final second = MemoryNotificationPreferencesGateway();\n",
        )
        for preview_source in preview_sources:
            with self.subTest(source=preview_source):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    preview = (
                        root
                        / check_harness.NOTIFICATION_PREFERENCES_PREVIEW_ROOT_PATH
                    )
                    preview.parent.mkdir(parents=True)
                    preview.write_text(preview_source, encoding="utf-8")

                    result = check_harness.check_notification_preferences_application_contract(
                        root
                    )

                self.assertTrue(
                    any("must compose exactly one" in error for error in result),
                    msg=f"expected exact Preview construction guard: {result}",
                )

    def test_notification_preferences_surface_rejects_legacy_h9_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            surface = root / check_harness.NOTIFICATION_PREFERENCES_SURFACE_PATH
            surface.parent.mkdir(parents=True)
            surface.write_text(
                "class _NotificationSettings {\n"
                "  final _settings = <String, bool>{};\n"
                "  final labels = <String>[\n"
                "    'Orders ' 'and fills',\n"
                "    'Liquidation risk',\n"
                "    'Community activity',\n"
                "    'System notices',\n"
                "    'System notifications are off',\n"
                "    'Open device settings',\n"
                "    'Quiet hours',\n"
                "  ];\n"
                "}\n",
                encoding="utf-8",
            )

            result = (
                check_harness.check_notification_preferences_application_contract(
                    root
                )
            )

        legacy_errors = [
            error for error in result if "non-contract H9 state/copy" in error
        ]
        self.assertEqual(
            len(check_harness.NOTIFICATION_PREFERENCES_LEGACY_MARKERS),
            len(legacy_errors),
            msg=f"expected every legacy H9 marker to fail: {result}",
        )

    def test_notification_preferences_rejects_positive_save_or_delivery_copy(
        self,
    ) -> None:
        examples = (
            ("final label = 'Preferences saved';\n", True),
            ("final label = 'Preferences have been saved';\n", True),
            ("final label = 'Successfully saved';\n", True),
            ("final label = 'Notifications are now enabled';\n", True),
            ("final label = 'Delivery is available';\n", True),
            ("final label = '\\u0050references saved';\n", True),
            ("final label = 'Notification ' 'delivery is connected';\n", True),
            ("final label = '通知偏好已保存';\n", True),
            (
                "final label = 'Preferences were not saved. Delivery remains unavailable.';\n",
                False,
            ),
        )
        for source_text, rejected in examples:
            with self.subTest(source=source_text):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    surface = (
                        root / check_harness.NOTIFICATION_PREFERENCES_SURFACE_PATH
                    )
                    surface.parent.mkdir(parents=True)
                    surface.write_text(source_text, encoding="utf-8")

                    result = check_harness.check_notification_preferences_application_contract(
                        root
                    )

                detected = any(
                    "positive save or delivery language" in error
                    for error in result
                )
                self.assertEqual(rejected, detected, msg=f"unexpected guard: {result}")

    def test_notification_preferences_behavior_tests_cannot_be_hollowed_out(
        self,
    ) -> None:
        for (
            relative,
            markers,
        ) in check_harness.NOTIFICATION_PREFERENCES_BEHAVIOR_TEST_MARKERS.items():
            forged_markers = ", ".join(repr(marker) for marker in markers)
            hollow_tests = "\n".join(
                f"test({marker!r}, () {{ final observed = true; }});"
                for marker in markers
            )
            hollow_sources = (
                "void main() {}\n",
                f"void main() {{ const markers = <String>[{forged_markers}]; }}\n",
                "void main() {\n" + hollow_tests + "\n}\n",
            )
            for source_text in hollow_sources:
                with self.subTest(path=str(relative), source=source_text):
                    with tempfile.TemporaryDirectory() as temporary:
                        root = Path(temporary)
                        test_path = root / relative
                        test_path.parent.mkdir(parents=True)
                        test_path.write_text(source_text, encoding="utf-8")

                        result = check_harness.check_notification_preferences_application_contract(
                            root
                        )

                    self.assertTrue(
                        any(
                            "missing required behavior evidence" in error
                            for error in result
                        ),
                        msg=(
                            "expected non-hollow Notification Preferences "
                            f"behavior guard: {result}"
                        ),
                    )

    @staticmethod
    def _notification_preferences_models_source() -> str:
        return (
            "enum NotificationPreferenceEvent {\n"
            "  priceAlertTriggered,\n"
            "  providerActivityProjected,\n"
            "  securityNotice,\n"
            "  supportUpdate;\n"
            "  String get wireValue => switch (this) {\n"
            "    NotificationPreferenceEvent.priceAlertTriggered => 'price_alert_triggered',\n"
            "    NotificationPreferenceEvent.providerActivityProjected => 'provider_activity_projected',\n"
            "    NotificationPreferenceEvent.securityNotice => 'security_notice',\n"
            "    NotificationPreferenceEvent.supportUpdate => 'support_update',\n"
            "  };\n"
            "  static NotificationPreferenceEvent fromWire(String value) => switch (value) {\n"
            "    'price_alert_triggered' => NotificationPreferenceEvent.priceAlertTriggered,\n"
            "    'provider_activity_projected' => NotificationPreferenceEvent.providerActivityProjected,\n"
            "    'security_notice' => NotificationPreferenceEvent.securityNotice,\n"
            "    'support_update' => NotificationPreferenceEvent.supportUpdate,\n"
            "    _ => throw Exception(),\n"
            "  };\n"
            "}\n"
            "enum NotificationDeliveryState {\n"
            "  unavailable;\n"
            "  String get wireValue => switch (this) {\n"
            "    NotificationDeliveryState.unavailable => 'unavailable',\n"
            "  };\n"
            "  static NotificationDeliveryState fromWire(String value) => switch (value) {\n"
            "    'unavailable' => NotificationDeliveryState.unavailable,\n"
            "    _ => throw StateError('delivery'),\n"
            "  };\n"
            "}\n"
            "final class NotificationPreferenceValues {\n"
            "  final bool priceAlertTriggered;\n"
            "  final bool providerActivityProjected;\n"
            "  final bool securityNotice;\n"
            "  final bool supportUpdate;\n"
            "}\n"
            "final class NotificationPreferencesResource {\n"
            "  final int version;\n"
            "  final NotificationPreferenceValues values;\n"
            "  final NotificationDeliveryState delivery;\n"
            "}\n"
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

    def test_production_chat_audio_room_entry_cannot_point_elsewhere(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = Path("lib/features/chat/stream_chat_inbox_page.dart")
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            mutated = source.replace(
                "context.push<void>('/chat/voice')",
                "context.push<void>('/chat/meeting')",
            )
            self.assertNotEqual(source, mutated)
            destination = root / relative
            destination.parent.mkdir(parents=True)
            destination.write_text(mutated, encoding="utf-8")

            result = check_harness.check_production_chat_audio_room_entry(root)

        self.assertTrue(
            any(
                "Audio Room entry must open `/chat/voice` exactly once" in error
                for error in result
            ),
            msg=f"expected production Audio Room route guard: {result}",
        )

    def test_production_chat_audio_room_behavior_evidence_cannot_be_hollow(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = Path("test/stream_chat_inbox_page_test.dart")
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            mutated = source.replace(
                "expect(find.byType(StreamVoiceRoomPage), findsOneWidget);",
                "find.byType(StreamVoiceRoomPage);\n"
                "      expect(true, isTrue);",
            )
            self.assertNotEqual(source, mutated)
            destination = root / relative
            destination.parent.mkdir(parents=True)
            destination.write_text(mutated, encoding="utf-8")

            result = check_harness.check_production_chat_audio_room_entry(root)

        self.assertTrue(
            any("lacks exact Audio Room assertions" in error for error in result),
            msg=f"expected production Audio Room behavior guard: {result}",
        )

    def test_production_chat_audio_room_entry_cannot_be_authorization_gated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = Path("lib/features/chat/stream_chat_inbox_page.dart")
            source = (REPOSITORY_ROOT / relative).read_text(encoding="utf-8")
            mutated = source.replace(
                "        actions: <Widget>[\n          Padding(",
                "        actions: <Widget>[\n"
                "          if (!authorization.isLoading)\n"
                "            Padding(",
            )
            self.assertNotEqual(source, mutated)
            destination = root / relative
            destination.parent.mkdir(parents=True)
            destination.write_text(mutated, encoding="utf-8")

            result = check_harness.check_production_chat_audio_room_entry(root)

        self.assertTrue(
            any("must not depend on inbox authorization state" in error for error in result),
            msg=f"expected production Audio Room state-independence guard: {result}",
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

    def test_android_release_network_permission_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = (
                root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
            )
            manifest.parent.mkdir(parents=True)
            manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                "</manifest>\n",
                encoding="utf-8",
            )
            result = check_harness.check_android_release_network_contract(root)
        self.assertTrue(any("android.permission.INTERNET" in error for error in result))

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

    def test_perp_positions_paths_are_required(self) -> None:
        expected = {
            "docs/decisions/0014-connect-perp-positions-projection.md",
            "lib/features/perp/perp_portfolio_screens.dart",
            "lib/features/perp/positions/perp_positions_controller.dart",
            "test/perp_positions_controller_test.dart",
            "test/perp_positions_screen_test.dart",
        }

        self.assertTrue(expected.issubset(set(check_harness.REQUIRED_FILES)))

    def test_perp_positions_behavior_tests_cannot_be_hollowed_out(self) -> None:
        for relative, markers in check_harness.PERP_POSITIONS_BEHAVIOR_TEST_MARKERS.items():
            forged_markers = ", ".join(repr(marker) for marker in markers)
            hollow_tests = "\n".join(
                f"test({marker!r}, () {{ final observed = true; }});"
                for marker in markers
            )
            dummy_assertions = "\n".join(
                f"test({marker!r}, () {{ expect(true, isTrue); }});"
                for marker in markers
            )
            hollow_sources = (
                "void main() {}\n",
                f"void main() {{ const markers = <String>[{forged_markers}]; }}\n",
                "void main() {\n" + hollow_tests + "\n}\n",
                "void main() {\n" + dummy_assertions + "\n}\n",
            )
            for source_text in hollow_sources:
                with self.subTest(path=str(relative), source=source_text):
                    with tempfile.TemporaryDirectory() as temporary:
                        root = Path(temporary)
                        test_path = root / relative
                        test_path.parent.mkdir(parents=True)
                        test_path.write_text(source_text, encoding="utf-8")

                        result = check_harness.check_perp_positions_application_contract(
                            root
                        )

                    self.assertTrue(
                        any(
                            "missing required behavior evidence" in error
                            or "lacks executable contract evidence" in error
                            for error in result
                        ),
                        msg=f"expected non-hollow Perp Positions guard: {result}",
                    )

    def test_perp_positions_every_marker_has_executable_evidence(self) -> None:
        for relative, markers in check_harness.PERP_POSITIONS_BEHAVIOR_TEST_MARKERS.items():
            configured = check_harness.PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE.get(
                relative,
                {},
            )
            self.assertEqual(set(markers), set(configured), msg=str(relative))

    def test_perp_positions_dummy_assertions_fail_for_every_marker(self) -> None:
        for relative, markers in check_harness.PERP_POSITIONS_BEHAVIOR_TEST_MARKERS.items():
            source_text = "void main() {\n" + "\n".join(
                f"test({marker!r}, () {{ expect(true, isTrue); }});"
                for marker in markers
            ) + "\n}\n"
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                test_path = root / relative
                test_path.parent.mkdir(parents=True)
                test_path.write_text(source_text, encoding="utf-8")

                result = check_harness.check_named_executable_test_evidence(
                    root,
                    check_harness.PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE,
                )

            for marker in markers:
                self.assertTrue(
                    any(f"test `{marker}` lacks" in error for error in result),
                    msg=f"expected evidence failure for {relative} / {marker}: {result}",
                )

    def test_perp_positions_malformed_cursor_cases_are_independently_guarded(
        self,
    ) -> None:
        source = (
            REPOSITORY_ROOT
            / "test"
            / "perp_positions_controller_test.dart"
        ).read_text(encoding="utf-8")
        mutations = (
            (
                "empty page with cursor",
                "items: const <PerpPosition>[],\n"
                "              nextCursor: 'cursor-without-progress',",
                "items: <PerpPosition>[_position(PerpCoin.btc)],",
            ),
            (
                "repeated cursor",
                "items: <PerpPosition>[_position(PerpCoin.sol)],\n"
                "                    nextCursor: 'same-cursor',",
                "items: <PerpPosition>[_position(PerpCoin.sol)],",
            ),
        )
        for name, before, after in mutations:
            with self.subTest(case=name):
                self.assertIn(before, source)
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    test_path = root / "test" / "perp_positions_controller_test.dart"
                    test_path.parent.mkdir(parents=True)
                    test_path.write_text(
                        source.replace(before, after, 1),
                        encoding="utf-8",
                    )

                    result = check_harness.check_named_executable_test_evidence(
                        root,
                        check_harness.PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE,
                    )

                self.assertTrue(
                    any(
                        "malformed dataset coverage and cursor pages clear all facts"
                        in error
                        for error in result
                    ),
                    msg=f"expected independent {name} evidence guard: {result}",
                )

    def test_perp_positions_contract_rejects_auto_bind_and_preview_leaks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            controller = root / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            controller.parent.mkdir(parents=True)
            controller_source = (
                REPOSITORY_ROOT / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            ).read_text(encoding="utf-8")
            controller.write_text(
                controller_source.replace(
                    "final page = await gateway.listPositions(limit: initialLimit);",
                    "await gateway.bindWallet();\n"
                    "      final page = await gateway.listPositions(limit: initialLimit);",
                    1,
                ),
                encoding="utf-8",
            )

            surface = root / check_harness.PERP_POSITIONS_SURFACE_PATH
            surface.parent.mkdir(parents=True, exist_ok=True)
            surface_source = (
                REPOSITORY_ROOT / check_harness.PERP_POSITIONS_SURFACE_PATH
            ).read_text(encoding="utf-8")
            surface.write_text(
                surface_source.replace(
                    "        const _PerpPositionsLiveBanner(),",
                    "        Text(PerpPreviewData.ethPosition.toString()),\n"
                    "        const _PerpPositionsLiveBanner(),",
                    1,
                ).replace(
                    "No ETH fixture, mark price",
                    "ETH-PERP fixture, mark price",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_perp_positions_application_contract(root)

        self.assertTrue(
            any("must never perform wallet binding" in error for error in result),
            msg=f"expected wallet-binding guard: {result}",
        )
        self.assertTrue(
            any("PerpPreviewData" in error for error in result),
            msg=f"expected live-preview guard: {result}",
        )
        self.assertTrue(
            any("Production D5" in error and "ETH-PERP" in error for error in result),
            msg=f"expected D5 fail-closed guard: {result}",
        )

    def test_perp_positions_selectors_cannot_invert_preview_and_production(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            surface = root / check_harness.PERP_POSITIONS_SURFACE_PATH
            surface.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.PERP_POSITIONS_SURFACE_PATH
            ).read_text(encoding="utf-8")
            surface.write_text(
                source.replace(
                    "if (!ref.watch(developmentPreviewEnabledProvider)) {",
                    "if (ref.watch(developmentPreviewEnabledProvider)) {",
                    1,
                ).replace(
                    "if (ref.watch(developmentPreviewEnabledProvider)) {",
                    "if (!ref.watch(developmentPreviewEnabledProvider)) {",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_perp_positions_application_contract(root)

        self.assertTrue(
            any("PerpPositionsScreen must select Preview only" in error for error in result),
            msg=f"expected D4 selector guard: {result}",
        )
        self.assertTrue(
            any("PerpPositionScreen must fail closed" in error for error in result),
            msg=f"expected D5 selector guard: {result}",
        )

    def test_perp_positions_continuation_must_remain_cursor_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            controller = root / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            controller.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            ).read_text(encoding="utf-8")
            controller.write_text(
                source.replace(
                    "gateway.listPositions(cursor: cursor)",
                    "gateway.listPositions(limit: initialLimit, cursor: cursor)",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_perp_positions_application_contract(root)

        self.assertTrue(
            any("cursor-only call site" in error for error in result),
            msg=f"expected cursor-only continuation guard: {result}",
        )

    def test_perp_positions_expiry_releases_retired_single_flight(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            controller = root / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            controller.parent.mkdir(parents=True)
            source = (
                REPOSITORY_ROOT / check_harness.PERP_POSITIONS_CONTROLLER_PATH
            ).read_text(encoding="utf-8")
            controller.write_text(
                source.replace(
                    "    _generation += 1;\n"
                    "    _operation = null;\n"
                    "    _cancelExpiry();\n"
                    "    state = PerpPositionsState._(\n"
                    "      mode: state.mode,\n"
                    "      phase: PerpPositionsPhase.stale,",
                    "    _generation += 1;\n"
                    "    _cancelExpiry();\n"
                    "    state = PerpPositionsState._(\n"
                    "      mode: state.mode,\n"
                    "      phase: PerpPositionsPhase.stale,",
                    1,
                ),
                encoding="utf-8",
            )

            result = check_harness.check_perp_positions_application_contract(root)

        self.assertTrue(
            any("release a retired logical single-flight" in error for error in result),
            msg=f"expected expiry single-flight guard: {result}",
        )


if __name__ == "__main__":
    unittest.main()
