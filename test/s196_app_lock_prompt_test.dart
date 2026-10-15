import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_prompt.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_app_lock_prompt_store.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Decision 0186: the first arrival of an installation offers the App lock.
void main() {
  group('who is offered the lock', () {
    testWidgets('an available lock that is off is offered once', (
      tester,
    ) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final host = await _pumpHost(tester, prompts: prompts);

      expect(await _offer(tester, host), isTrue);
      expect(find.text('开启应用锁'), findsOneWidget);
      expect(find.text(loopAppLockPromptBody), findsOneWidget);
      expect(find.text('开启'), findsOneWidget);
      expect(find.text('以后再说'), findsOneWidget);
      // One Lime body on screen: 开启. 以后再说 is the plain button.
      final primaries = tester
          .widgetList<LoopButton>(find.byType(LoopButton))
          .where((button) => button.primary);
      expect(primaries, hasLength(1));
      expect(primaries.single.label, '开启');

      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();
      expect(find.text('开启应用锁'), findsNothing);
      expect(prompts.prompted, isTrue);

      // The same run never asks again, and neither does the next one.
      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);

      final next = await _pumpHost(tester, prompts: prompts);
      expect(await _offer(tester, next), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
    });

    testWidgets('an enabled lock is not offered', (tester) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final host = await _pumpHost(
        tester,
        prompts: prompts,
        lockStore: InMemoryLoopAppLockStore(true),
      );

      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
      expect(prompts.prompted, isNull);
    });

    testWidgets('an unavailable lock is not offered and nothing is recorded', (
      tester,
    ) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final host = await _pumpHost(
        tester,
        prompts: prompts,
        authenticator: _FakeAuthenticator(
          capability: const LoopDeviceAuthCapability.unavailable(
            LoopDeviceAuthUnavailableReason.noCredentialSet,
          ),
        ),
      );

      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
      expect(prompts.prompted, isNull);
    });

    testWidgets('Preview is never offered the lock', (tester) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final host = await _pumpHost(
        tester,
        prompts: prompts,
        mode: LoopSessionMode.preview,
      );

      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
      expect(prompts.prompted, isNull);
    });

    testWidgets('an installation that was already asked is not asked again', (
      tester,
    ) async {
      final host = await _pumpHost(
        tester,
        prompts: InMemoryLoopAppLockPromptStore(true),
      );

      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
    });

    testWidgets('a failed read is not asked yet but still once per run', (
      tester,
    ) async {
      final prompts = _ThrowingPromptStore();
      final host = await _pumpHost(tester, prompts: prompts);

      expect(await _offer(tester, host), isTrue);
      expect(find.text('开启应用锁'), findsOneWidget);
      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();
      expect(prompts.writes, 1);

      expect(await _offer(tester, host), isFalse);
      expect(find.text('开启应用锁'), findsNothing);
    });

    testWidgets('a read that never answers is not asked yet', (tester) async {
      final host = await _pumpHost(tester, prompts: _HangingPromptStore());

      final offered = _offer(tester, host, settle: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await offered, isTrue);
      expect(find.text('开启应用锁'), findsOneWidget);
    });
  });

  group('the answer', () {
    testWidgets("开启 runs the lock's own switch", (tester) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final lockStore = InMemoryLoopAppLockStore();
      final authenticator = _FakeAuthenticator();
      final host = await _pumpHost(
        tester,
        prompts: prompts,
        lockStore: lockStore,
        authenticator: authenticator,
      );

      expect(await _offer(tester, host), isTrue);
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(authenticator.reasons, <String>['验证身份以开启应用锁']);
      expect(host.container.read(loopAppLockProvider).enabled, isTrue);
      expect(await lockStore.read(), isTrue);
      expect(prompts.prompted, isTrue);
      expect(find.text('开启应用锁'), findsNothing);
    });

    testWidgets('a refused prompt keeps the sheet and says so', (tester) async {
      final prompts = InMemoryLoopAppLockPromptStore();
      final authenticator = _FakeAuthenticator(
        outcomes: <LoopDeviceAuthOutcome>[LoopDeviceAuthOutcome.canceled],
      );
      final host = await _pumpHost(
        tester,
        prompts: prompts,
        authenticator: authenticator,
      );

      expect(await _offer(tester, host), isTrue);
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(host.container.read(loopAppLockProvider).enabled, isFalse);
      expect(find.text('开启应用锁'), findsOneWidget);
      expect(find.text('你取消了这次验证。'), findsOneWidget);
      // Asking was the answer to "was this installation offered it".
      expect(prompts.prompted, isTrue);

      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();
      expect(find.text('开启应用锁'), findsNothing);
    });
  });

  group('the adapter', () {
    test('the prompt adapter uses one namespaced Boolean key', () async {
      final values = <String, bool>{};
      final store = SharedPreferencesLoopAppLockPromptStore.forTesting(
        (key) async => values[key],
        (key, value) async => values[key] = value,
      );

      expect(
        SharedPreferencesLoopAppLockPromptStore.promptedKey,
        'loop.display.v1.app_lock_prompted',
      );
      expect(await store.readPrompted(), isNull);
      await store.writePrompted();
      expect(values, <String, bool>{'loop.display.v1.app_lock_prompted': true});
      expect(await store.readPrompted(), isTrue);
    });
  });
}

final class _Host {
  _Host(this.container, this.context, this.ref);

  final ProviderContainer container;
  final BuildContext context;
  final WidgetRef ref;
}

Future<_Host> _pumpHost(
  WidgetTester tester, {
  required LoopAppLockPromptStore prompts,
  LoopAppLockStore? lockStore,
  _FakeAuthenticator? authenticator,
  LoopSessionMode mode = LoopSessionMode.authenticated,
}) async {
  final container = ProviderContainer(
    overrides: [
      loopSessionProvider.overrideWith(() => _FixedSession(mode)),
      loopAppLockStoreProvider.overrideWithValue(
        lockStore ?? InMemoryLoopAppLockStore(),
      ),
      loopDeviceAuthenticatorProvider.overrideWithValue(
        authenticator ?? _FakeAuthenticator(),
      ),
      loopAppLockPromptStoreProvider.overrideWithValue(prompts),
    ],
  );
  addTearDown(container.dispose);
  late BuildContext context;
  late WidgetRef ref;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // A fresh key per host: a second host is a second run.
        key: UniqueKey(),
        theme: LoopTheme.dark,
        home: Consumer(
          builder: (inner, innerRef, _) {
            context = inner;
            ref = innerRef;
            return const Scaffold(body: Center(child: Text('聊天')));
          },
        ),
      ),
    ),
  );
  // The application starts this read at launch, before any arrival.
  unawaited(container.read(loopAppLockProvider.notifier).load());
  await tester.pumpAndSettle();
  return _Host(container, context, ref);
}

Future<bool> _offer(
  WidgetTester tester,
  _Host host, {
  bool settle = true,
}) async {
  final offered = loopOfferAppLock(host.context, host.ref);
  if (!settle) return offered;
  await tester.pumpAndSettle();
  return offered;
}

final class _FixedSession extends LoopSessionController {
  _FixedSession(this.mode);

  final LoopSessionMode mode;

  @override
  LoopSessionState build() => LoopSessionState(mode: mode);
}

final class _ThrowingPromptStore implements LoopAppLockPromptStore {
  int writes = 0;

  @override
  Future<bool?> readPrompted() async => throw StateError('device refused');

  @override
  Future<void> writePrompted() async {
    writes += 1;
    throw StateError('device refused');
  }
}

final class _HangingPromptStore implements LoopAppLockPromptStore {
  @override
  Future<bool?> readPrompted() => Completer<bool?>().future;

  @override
  Future<void> writePrompted() async {}
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
