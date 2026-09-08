import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

/// `settings` · the device-local Reduce motion preference.
///
/// The account half of the page is covered by `s8_security_pages_test.dart`;
/// this file guards the one preference that never leaves the device.
void main() {
  const reduceMotionRow = ValueKey<String>('settings-reduce-motion');

  testWidgets(
    'Reduce motion remains truthful when local saving is unavailable',
    (tester) async {
      await _pumpSettings(tester);

      final setting = find.byKey(reduceMotionRow);
      final container = ProviderScope.containerOf(tester.element(setting));
      expect(
        container.read(loopDisplayPreferencesProvider).reduceMotion,
        isFalse,
      );
      expect(find.text('本次运行内生效；本机保存当前不可用'), findsOneWidget);
      expect(find.text('本机保存不可用'), findsOneWidget);

      await tester.tap(setting);
      await tester.pumpAndSettle();

      expect(
        container.read(loopDisplayPreferencesProvider).reduceMotion,
        isTrue,
      );
      expect(MediaQuery.disableAnimationsOf(tester.element(setting)), isTrue);
    },
  );

  testWidgets('Retry reads the existing device preference after load failure', (
    tester,
  ) async {
    final store = _RecoveringDisplayStore();
    await _pumpSettings(tester, store: store);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-retry-display-storage')),
    );
    await tester.pumpAndSettle();

    final setting = find.byKey(reduceMotionRow);
    final container = ProviderScope.containerOf(tester.element(setting));
    expect(container.read(loopDisplayPreferencesProvider).reduceMotion, isTrue);
    expect(store.writes, isEmpty);
    expect(MediaQuery.disableAnimationsOf(tester.element(setting)), isTrue);
    expect(find.text('本机保存不可用'), findsNothing);
  });

  testWidgets('restored device preference disables animations globally', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      initial: const LoopDisplayPreferences(
        reduceMotion: true,
        persistence: LoopDisplayPreferencesPersistence.available,
      ),
    );

    final setting = find.byKey(reduceMotionRow);
    expect(MediaQuery.disableAnimationsOf(tester.element(setting)), isTrue);
    expect(find.text('只保存在本机，不写入账号，也不调用后端'), findsOneWidget);
  });

  testWidgets('system animation setting remains stricter than stored false', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await _pumpSettings(
      tester,
      initial: const LoopDisplayPreferences(
        persistence: LoopDisplayPreferencesPersistence.available,
      ),
    );

    final setting = find.byKey(reduceMotionRow);
    final container = ProviderScope.containerOf(tester.element(setting));
    expect(
      container.read(loopDisplayPreferencesProvider).reduceMotion,
      isFalse,
    );
    expect(MediaQuery.disableAnimationsOf(tester.element(setting)), isTrue);
  });

  testWidgets('the prototype data-usage row has no source and is absent', (
    tester,
  ) async {
    await _pumpSettings(tester);

    expect(find.textContaining('142MB'), findsNothing);
    expect(find.text('数据用量'), findsNothing);
    expect(find.text('没有"数据用量"'), findsOneWidget);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  LoopDisplayPreferencesStore? store,
  LoopDisplayPreferences? initial,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        if (store != null)
          loopDisplayPreferencesStoreProvider.overrideWithValue(store),
        if (initial != null)
          loopDisplayPreferencesInitialProvider.overrideWithValue(initial),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();

  final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
  router.go('/profile/settings');
  await tester.pumpAndSettle();
}

class _RecoveringDisplayStore implements LoopDisplayPreferencesStore {
  final List<bool> writes = <bool>[];

  @override
  Future<bool?> readReduceMotion() async => true;

  @override
  Future<void> writeReduceMotion(bool value) async {
    writes.add(value);
  }
}
