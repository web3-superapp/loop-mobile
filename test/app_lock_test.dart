import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s8_harness.dart';

void main() {
  loopWatchGround();

  group('reading the lock at start', () {
    test('a device with nothing to ask with offers no lock', () async {
      final container = _container(
        authenticator: _FakeAuthenticator(
          capability: const LoopDeviceAuthCapability.unavailable(
            LoopDeviceAuthUnavailableReason.noCredentialSet,
          ),
        ),
      );

      await container.read(loopAppLockProvider.notifier).load();

      final state = container.read(loopAppLockProvider);
      expect(state.isAvailable, isFalse);
      expect(state.enabled, isFalse);
      expect(state.locked, isFalse);
    });

    test('a stored on is locked before anything is readable', () async {
      final container = _container(store: InMemoryLoopAppLockStore(true));

      await container.read(loopAppLockProvider.notifier).load();

      final state = container.read(loopAppLockProvider);
      expect(state.enabled, isTrue);
      expect(state.locked, isTrue);
    });

    test('a stored on whose credential is gone is not enabled', () async {
      // The owner removed their screen lock between two runs. The choice is
      // still on the device; the protection is not, and claiming it would
      // leave the App shut with nothing able to open it.
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        authenticator: _FakeAuthenticator(
          capability: const LoopDeviceAuthCapability.unavailable(
            LoopDeviceAuthUnavailableReason.noCredentialSet,
          ),
        ),
      );

      await container.read(loopAppLockProvider.notifier).load();

      expect(container.read(loopAppLockProvider).enabled, isFalse);
      expect(container.read(loopAppLockProvider).locked, isFalse);
    });

    test('a store that cannot be read is no choice, never an on', () async {
      final container = _container(store: const UnavailableLoopAppLockStore());

      await container.read(loopAppLockProvider.notifier).load();

      expect(container.read(loopAppLockProvider).enabled, isFalse);
    });
  });

  group('turning it on and off', () {
    test('it is on only after the device said yes, and it persists', () async {
      final store = InMemoryLoopAppLockStore();
      final authenticator = _FakeAuthenticator();
      final container = _container(store: store, authenticator: authenticator);
      await container.read(loopAppLockProvider.notifier).load();

      expect(
        await container.read(loopAppLockProvider.notifier).enable(),
        isTrue,
      );

      expect(container.read(loopAppLockProvider).enabled, isTrue);
      expect(container.read(loopAppLockProvider).persisted, isTrue);
      expect(await store.read(), isTrue);
      expect(authenticator.reasons.single, '验证身份以开启应用锁');
    });

    test('a refused prompt turns nothing on and stores nothing', () async {
      final store = InMemoryLoopAppLockStore();
      final container = _container(
        store: store,
        authenticator: _FakeAuthenticator(
          outcomes: <LoopDeviceAuthOutcome>[LoopDeviceAuthOutcome.failed],
        ),
      );
      await container.read(loopAppLockProvider.notifier).load();

      expect(
        await container.read(loopAppLockProvider.notifier).enable(),
        isFalse,
      );

      expect(container.read(loopAppLockProvider).enabled, isFalse);
      expect(
        container.read(loopAppLockProvider).lastOutcome,
        LoopDeviceAuthOutcome.failed,
      );
      expect(await store.read(), isNull);
    });

    test('turning it off needs the same proof as turning it on', () async {
      final store = InMemoryLoopAppLockStore(true);
      final authenticator = _FakeAuthenticator(
        outcomes: <LoopDeviceAuthOutcome>[
          LoopDeviceAuthOutcome.succeeded,
          LoopDeviceAuthOutcome.canceled,
        ],
      );
      final container = _container(store: store, authenticator: authenticator);
      await container.read(loopAppLockProvider.notifier).load();
      await container.read(loopAppLockProvider.notifier).unlock();

      expect(
        await container.read(loopAppLockProvider.notifier).disable(),
        isFalse,
      );

      expect(container.read(loopAppLockProvider).enabled, isTrue);
      expect(await store.read(), isTrue);
      expect(authenticator.reasons.last, '验证身份以关闭应用锁');
    });

    test(
      'a device that cannot save says the choice will not be remembered',
      () async {
        final container = _container(
          store: const UnavailableLoopAppLockStore(),
        );
        await container.read(loopAppLockProvider.notifier).load();

        await container.read(loopAppLockProvider.notifier).enable();

        final state = container.read(loopAppLockProvider);
        expect(state.enabled, isTrue);
        expect(state.persisted, isFalse);
      },
    );
  });

  group('the curtain', () {
    test('a cancelled unlock leaves the App shut', () async {
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        authenticator: _FakeAuthenticator(
          outcomes: <LoopDeviceAuthOutcome>[LoopDeviceAuthOutcome.canceled],
        ),
      );
      await container.read(loopAppLockProvider.notifier).load();

      expect(
        await container.read(loopAppLockProvider.notifier).unlock(),
        isFalse,
      );

      expect(container.read(loopAppLockProvider).locked, isTrue);
    });

    test(
      'a credential removed under the lock opens it and turns it off',
      () async {
        final store = InMemoryLoopAppLockStore(true);
        final container = _container(
          store: store,
          authenticator: _FakeAuthenticator(
            outcomes: <LoopDeviceAuthOutcome>[
              LoopDeviceAuthOutcome.unavailable,
            ],
          ),
        );
        await container.read(loopAppLockProvider.notifier).load();

        await container.read(loopAppLockProvider.notifier).unlock();

        final state = container.read(loopAppLockProvider);
        expect(state.locked, isFalse, reason: 'nobody may be locked out');
        expect(state.enabled, isFalse);
        expect(state.isAvailable, isFalse);
        expect(await store.read(), isFalse);
      },
    );

    test('two unlock attempts at once run one prompt', () async {
      final authenticator = _FakeAuthenticator();
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        authenticator: authenticator,
      );
      await container.read(loopAppLockProvider.notifier).load();

      final controller = container.read(loopAppLockProvider.notifier);
      await Future.wait(<Future<bool>>[
        controller.unlock(),
        controller.unlock(),
      ]);

      expect(authenticator.reasons.length, 1);
      expect(container.read(loopAppLockProvider).locked, isFalse);
    });
  });

  group('the sixty-second window', () {
    test('a short trip away does not lock', () async {
      var now = DateTime.utc(2026, 9, 21, 12);
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        clock: () => now,
      );
      await container.read(loopAppLockProvider.notifier).load();
      final controller = container.read(loopAppLockProvider.notifier);
      await controller.unlock();

      controller.onLeftForeground();
      now = now.add(const Duration(seconds: 59));
      controller.onEnteredForeground();

      expect(container.read(loopAppLockProvider).locked, isFalse);
    });

    test('a minute away closes the curtain', () async {
      var now = DateTime.utc(2026, 9, 21, 12);
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        clock: () => now,
      );
      await container.read(loopAppLockProvider.notifier).load();
      final controller = container.read(loopAppLockProvider.notifier);
      await controller.unlock();

      controller.onLeftForeground();
      now = now.add(loopAppLockGrace);
      controller.onEnteredForeground();

      expect(container.read(loopAppLockProvider).locked, isTrue);
    });

    test('the moment away is the first one, not the last', () async {
      // The system's own prompt backgrounds LOOP as well. A later mark would
      // restart the window and the lock would never close.
      var now = DateTime.utc(2026, 9, 21, 12);
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        clock: () => now,
      );
      await container.read(loopAppLockProvider.notifier).load();
      final controller = container.read(loopAppLockProvider.notifier);
      await controller.unlock();

      controller.onLeftForeground();
      now = now.add(const Duration(seconds: 90));
      controller.onLeftForeground();
      controller.onEnteredForeground();

      expect(container.read(loopAppLockProvider).locked, isTrue);
    });

    test('a short trip leaves no moment for the next one to measure', () async {
      var now = DateTime.utc(2026, 9, 21, 12);
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        clock: () => now,
      );
      await container.read(loopAppLockProvider.notifier).load();
      final controller = container.read(loopAppLockProvider.notifier);
      await controller.unlock();

      controller.onLeftForeground();
      now = now.add(const Duration(seconds: 5));
      controller.onEnteredForeground();
      now = now.add(const Duration(minutes: 10));
      controller.onEnteredForeground();

      expect(container.read(loopAppLockProvider).locked, isFalse);
    });

    test('a lock that is off never measures anything', () async {
      var now = DateTime.utc(2026, 9, 21, 12);
      final container = _container(clock: () => now);
      await container.read(loopAppLockProvider.notifier).load();
      final controller = container.read(loopAppLockProvider.notifier);

      controller.onLeftForeground();
      now = now.add(const Duration(hours: 1));
      controller.onEnteredForeground();

      expect(container.read(loopAppLockProvider).locked, isFalse);
    });
  });

  group('the gate', () {
    testWidgets('a locked App is covered and offers one way through', (
      tester,
    ) async {
      final container = _container(
        store: InMemoryLoopAppLockStore(true),
        authenticator: _FakeAuthenticator(
          outcomes: <LoopDeviceAuthOutcome>[
            LoopDeviceAuthOutcome.canceled,
            LoopDeviceAuthOutcome.succeeded,
          ],
        ),
      );
      await container.read(loopAppLockProvider.notifier).load();

      await _pumpGate(tester, container);

      expect(
        find.byKey(const ValueKey<String>('loop-app-lock-curtain')),
        findsOneWidget,
      );
      expect(find.text('LOOP 已锁定'), findsOneWidget);
      // The page under it is still in the tree — unlocking returns the owner
      // to it — and cannot be read or reached.
      expect(find.text('账户余额'), findsOneWidget);
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey<String>('loop-app-lock-curtain')),
            )
            .color,
        LoopColors.ink,
      );

      // The automatic prompt was cancelled: the curtain stays and says so.
      await tester.pumpAndSettle();
      expect(find.text('你取消了这次验证。'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-app-lock-unlock')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('loop-app-lock-curtain')),
        findsNothing,
      );
    });

    testWidgets('an unlocked App is not covered at all', (tester) async {
      final container = _container();
      await container.read(loopAppLockProvider.notifier).load();

      await _pumpGate(tester, container);

      expect(
        find.byKey(const ValueKey<String>('loop-app-lock-curtain')),
        findsNothing,
      );
    });
  });

  group('设置 keeps the switch where the owner can find it', () {
    testWidgets('the row reports the lock and can turn it off', (tester) async {
      final store = InMemoryLoopAppLockStore(true);
      final authenticator = _FakeAuthenticator();
      await _pumpSettings(tester, store: store, authenticator: authenticator);

      final row = find.byKey(const ValueKey<String>('settings-app-lock'));
      final container = ProviderScope.containerOf(tester.element(row));
      // A widget test's clock only moves when it is pumped, so the prompt is
      // started here and the frames that let it answer are pumped below.
      unawaited(container.read(loopAppLockProvider.notifier).load());
      await tester.pumpAndSettle();
      unawaited(container.read(loopAppLockProvider.notifier).unlock());
      await tester.pumpAndSettle();

      expect(tester.widget<LoopRecordRow>(row).semanticLabel, contains('已开启'));

      await tester.tap(row);
      await tester.pumpAndSettle();

      // Turning it off went through the system's prompt, and the device's
      // answer is what changed the state.
      expect(authenticator.reasons.last, '验证身份以关闭应用锁');
      expect(container.read(loopAppLockProvider).enabled, isFalse);
      expect(await store.read(), isFalse);
    });
  });

  group('04 says what the lock is', () {
    testWidgets('an available lock can be switched on from the step', (
      tester,
    ) async {
      var toggles = 0;
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          appLock: const LoopAppLockState(
            capability: LoopDeviceAuthCapability.available(
              LoopDeviceAuthFactor.biometric,
            ),
          ),
          onToggleAppLock: () => toggles += 1,
        ),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-app-lock')),
      );
      expect(row.trailing, '未开启');
      expect(row.subtitle, contains('生物识别'));
      expect(row.subtitle, contains('设备密码'));

      await tester.tap(find.byKey(const ValueKey<String>('security-app-lock')));
      await tester.pumpAndSettle();
      expect(toggles, 1);
    });

    testWidgets('an enabled lock says so, and the page still continues', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          appLock: const LoopAppLockState(
            enabled: true,
            capability: LoopDeviceAuthCapability.available(
              LoopDeviceAuthFactor.deviceCredential,
            ),
          ),
          onToggleAppLock: () {},
          onNavigate: destinations.add,
        ),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-app-lock')),
      );
      expect(row.trailing, '已开启');
      expect(row.subtitle, contains('锁屏密码'));

      await tester.tap(
        find.byKey(const ValueKey<String>('security-setup-continue')),
      );
      await tester.pumpAndSettle();
      expect(destinations, <String>['loop-id-setup']);
    });

    testWidgets('a device with no screen lock is told what to do about it', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'security-setup',
          appLock: LoopAppLockState(
            capability: LoopDeviceAuthCapability.unavailable(
              LoopDeviceAuthUnavailableReason.noCredentialSet,
            ),
          ),
        ),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-app-lock')),
      );
      expect(row.trailing, '不可用');
      expect(row.onTap, isNull);
      expect(row.subtitle, contains('先在系统设置里加上'));
    });

    testWidgets('a page with no lock composed claims none', (tester) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('security-setup'),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-app-lock')),
      );
      expect(row.trailing, '不可用');
      expect(row.onTap, isNull);
      // 已开启 belongs to the lock alone; nothing else on the page may wear it.
      expect(find.text('已开启'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------

ProviderContainer _container({
  LoopAppLockStore? store,
  _FakeAuthenticator? authenticator,
  DateTime Function()? clock,
}) {
  final container = ProviderContainer(
    overrides: [
      loopAppLockStoreProvider.overrideWithValue(
        store ?? InMemoryLoopAppLockStore(),
      ),
      loopDeviceAuthenticatorProvider.overrideWithValue(
        authenticator ?? _FakeAuthenticator(),
      ),
      if (clock != null) loopAppLockClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpGate(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const LoopAppLockGate(
          child: Scaffold(body: Center(child: Text('账户余额'))),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Mounts 设置 with the two ports the lock row reads.
///
/// The S8 harness composes the account half of the page; the device half is
/// this file's business, so the overrides are local rather than a parameter
/// every other S8 page would have to ignore.
Future<void> _pumpSettings(
  WidgetTester tester, {
  required LoopAppLockStore store,
  required LoopDeviceAuthenticator authenticator,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 3200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  loopArmGroundProbe(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountSettingsGatewayProvider.overrideWithValue(
          FakeAccountSettingsGateway(),
        ),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => s8MetaSnapshot(),
        ),
        loopAppLockStoreProvider.overrideWithValue(store),
        loopDeviceAuthenticatorProvider.overrideWithValue(authenticator),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: GeneralSettingsScreen(onNavigate: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

final class _FakeAuthenticator implements LoopDeviceAuthenticator {
  _FakeAuthenticator({
    this.capability = const LoopDeviceAuthCapability.available(
      LoopDeviceAuthFactor.biometric,
    ),
    List<LoopDeviceAuthOutcome>? outcomes,
  }) : _outcomes = outcomes ?? <LoopDeviceAuthOutcome>[];

  final LoopDeviceAuthCapability capability;
  final List<LoopDeviceAuthOutcome> _outcomes;

  /// Every prompt this device was actually asked to show.
  final List<String> reasons = <String>[];

  @override
  Future<LoopDeviceAuthCapability> readCapability() async => capability;

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async {
    reasons.add(reason);
    await Future<void>.delayed(Duration.zero);
    final outcome = _outcomes.isEmpty
        ? LoopDeviceAuthOutcome.succeeded
        : _outcomes.removeAt(0);
    return LoopDeviceAuthResult(outcome);
  }
}
