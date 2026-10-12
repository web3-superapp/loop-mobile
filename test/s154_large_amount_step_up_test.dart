import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_signing.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/integrations/device/secure_storage_step_up_store.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/meme_fixtures.dart';
import 'support/s6_fixtures.dart';

// ---------------------------------------------------------------------------
// S154 · large-amount step-up (client decision 0152)
// ---------------------------------------------------------------------------

const String _principal = 'did:privy:owner-a';
const String _otherPrincipal = 'did:privy:owner-b';

/// The device: what it offers, and what each prompt answers.
final class _Device implements LoopDeviceAuthenticator {
  _Device({
    this.capability = const LoopDeviceAuthCapability.available(
      LoopDeviceAuthFactor.biometric,
    ),
    List<LoopDeviceAuthOutcome>? answers,
    this.events,
  }) : answers = answers ?? <LoopDeviceAuthOutcome>[];

  LoopDeviceAuthCapability capability;
  final List<LoopDeviceAuthOutcome> answers;
  final List<String>? events;
  final List<String> reasons = <String>[];

  @override
  Future<LoopDeviceAuthCapability> readCapability() async => capability;

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async {
    reasons.add(reason);
    events?.add('auth');
    final outcome = answers.isEmpty
        ? LoopDeviceAuthOutcome.succeeded
        : answers.removeAt(0);
    return LoopDeviceAuthResult(outcome);
  }
}

/// The wallet behind the step-up: it records what reached it.
final class _Wallet implements WalletSigningGateway {
  _Wallet({this.events});

  final List<String>? events;
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    events?.add('wallet');
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value:
          '0x3000000000000000000000000000000000000000000000000000000000000003',
    );
  }
}

final DateTime _now = DateTime.utc(2026, 10, 12, 8);

SigningIntent _intent({
  Decimal? usd1,
  DateTime? expiresAt,
  String revision = 'intent-1',
}) => SigningIntent.backendCanonical(
  revision: revision,
  payloadDigest: 'a' * 64,
  title: '确认发送',
  kind: IntentKind.transfer,
  chainId: loopPrimaryChainId,
  payload: const DeviceTransactionPayload(
    fromAddress: '0x000000000000000000000000000000000000000a',
    transaction: <String, Object?>{'chainId': 56},
  ),
  observedAt: _now,
  expiresAt: expiresAt ?? _now.add(const Duration(minutes: 1)),
  fields: const <IntentField>[],
  stepUpUsd1: usd1,
);

ProviderContainer _container({
  required _Device device,
  LoopStepUpSettingsStore? store,
  String? principal = _principal,
  WalletSigningGateway? wallet,
}) {
  final container = ProviderContainer(
    overrides: [
      loopDeviceAuthenticatorProvider.overrideWithValue(device),
      loopStepUpSettingsStoreProvider.overrideWithValue(
        store ?? InMemoryLoopStepUpSettingsStore(),
      ),
      loopAccountScopeProvider.overrideWithValue(principal),
      if (wallet != null)
        walletSigningGatewayProvider.overrideWithValue(wallet),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Launch2Intent _poolBuy({String path = 's150-launch2/pool_prepare_buy_ready'}) {
  final record = jsonDecode(
    File('test/fixtures/$path.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return LoopV2Launch2PoolCodec.prepared(
    record['body'],
    instanceId: l2InstanceA,
    side: Launch2Side.buy,
    mode: Launch2PoolMode.exactIn,
    walletId: l2WalletId,
  ).intent;
}

void main() {
  group('the threshold', () {
    test('equal reaches it, below does not, no amount never does', () {
      const settings = LoopStepUpSettings(thresholdUsd1: 1000);
      expect(settings.reaches(Decimal.parse('1000')), isTrue);
      expect(
        settings.reaches(Decimal.parse('1000.000000000000000001')),
        isTrue,
      );
      expect(
        settings.reaches(Decimal.parse('999.999999999999999999')),
        isFalse,
      );
      expect(settings.reaches(Decimal.zero), isFalse);
      expect(settings.reaches(null), isFalse);
    });

    test('defaults to on at 1000 USD1', () {
      const settings = LoopStepUpSettings();
      expect(settings.enabled, isTrue);
      expect(settings.thresholdUsd1, 1000);
      expect(loopStepUpSubtitle(1000), '达到 1,000 USD1 时再验一次身份');
    });

    test('accepts whole USD1 from 1 to 1,000,000 only', () {
      expect(loopStepUpParseThreshold('500'), 500);
      expect(loopStepUpParseThreshold('1,000'), 1000);
      expect(loopStepUpParseThreshold('12.5'), isNull);
      expect(loopStepUpParseThreshold('-3'), isNull);
      expect(loopStepUpParseThreshold(''), isNull);
      expect(loopStepUpThresholdError(1), isNull);
      expect(loopStepUpThresholdError(1000000), isNull);
      expect(loopStepUpThresholdError(0), '金额需在 1 到 1,000,000 USD1 之间');
      expect(loopStepUpThresholdError(1000001), '金额需在 1 到 1,000,000 USD1 之间');
      expect(loopStepUpThresholdError(null), '请输入整数金额');
    });

    test('the stored form round-trips and anything else is the default', () {
      const settings = LoopStepUpSettings(enabled: false, thresholdUsd1: 5000);
      expect(settings.encode(), '0:5000');
      expect(LoopStepUpSettings.tryDecode('0:5000'), settings);
      expect(LoopStepUpSettings.tryDecode('1:0'), isNull);
      expect(LoopStepUpSettings.tryDecode('1:2000000'), isNull);
      expect(LoopStepUpSettings.tryDecode('yes'), isNull);
      expect(LoopStepUpSettings.tryDecode(null), isNull);
    });
  });

  group('what each intent is worth in USD1', () {
    test('a MEME buy pays its USD1, a sell receives its expected USD1', () {
      final buy = memeIntent();
      expect(memeIntentStepUpUsd1(buy), Decimal.parse('10'));
      final sell = memeIntent(kind: 'sell');
      expect(memeIntentStepUpUsd1(sell), memeUnits(sell.expectedOut));
    });

    test('a MEME v2 buy is its most-pay amount', () {
      final buy = _poolBuy();
      expect(launch2IntentStepUpUsd1(buy), Decimal.parse('100'));
    });

    test(
      'a send of another token is its server valuation (price x amount)',
      () {
        final send = LoopV2IntentCodec.intent(s6IntentBody());
        expect(send.review.asset.symbol, 'WBNB');
        expect(moneyIntentStepUpUsd1(send), Decimal.parse('7.50014'));
      },
    );

    test('a USD1 send is its own amount', () {
      final body = s6IntentBody();
      final review = body['review']! as Map<String, Object?>;
      review['asset'] = s6Asset(symbol: 'USD1');
      final send = LoopV2IntentCodec.intent(body);
      expect(moneyIntentStepUpUsd1(send), send.review.amount.value);
    });

    test('a send the server could not price has no amount', () {
      final body = s6IntentBody();
      final policy = body['policy']! as Map<String, Object?>;
      policy['valueUsd'] = null;
      policy['priceSource'] = null;
      policy['priceFetchedAt'] = null;
      final send = LoopV2IntentCodec.intent(body);
      expect(moneyIntentStepUpUsd1(send), isNull);
    });
  });

  group('the signing exit', () {
    test('below the threshold the wallet opens and nothing is asked', () async {
      final device = _Device();
      final wallet = _Wallet();
      final container = _container(device: device, wallet: wallet);
      final exit = container.read(loopGuardedWalletSigningGatewayProvider);

      final result = await exit.handoff(
        _intent(usd1: Decimal.parse('999.99')),
        now: _now,
      );

      expect(result.accepted, isTrue);
      expect(device.reasons, isEmpty);
      expect(wallet.handed, hasLength(1));
    });

    test('an intent with no amount is not asked for', () async {
      final device = _Device();
      final wallet = _Wallet();
      final container = _container(device: device, wallet: wallet);
      final exit = container.read(loopGuardedWalletSigningGatewayProvider);

      final result = await exit.handoff(_intent(), now: _now);

      expect(result.accepted, isTrue);
      expect(device.reasons, isEmpty);
    });

    test(
      'at the threshold the device is asked first, then the wallet',
      () async {
        final events = <String>[];
        final device = _Device(events: events);
        final wallet = _Wallet(events: events);
        final container = _container(device: device, wallet: wallet);
        final exit = container.read(loopGuardedWalletSigningGatewayProvider);

        final result = await exit.handoff(
          _intent(usd1: Decimal.parse('1000')),
          now: _now,
        );

        expect(result.accepted, isTrue);
        expect(events, <String>['auth', 'wallet']);
        expect(device.reasons.single, '验证身份以签名这笔大额交易');
      },
    );

    test('a cancelled prompt signs nothing and says so', () async {
      final device = _Device(answers: [LoopDeviceAuthOutcome.canceled]);
      final wallet = _Wallet();
      final container = _container(device: device, wallet: wallet);
      final exit = container.read(loopGuardedWalletSigningGatewayProvider);

      final result = await exit.handoff(
        _intent(usd1: Decimal.parse('5000')),
        now: _now,
      );

      expect(result.accepted, isFalse);
      expect(result.value, isNull);
      expect(result.code, loopStepUpCancelledCode);
      expect(wallet.handed, isEmpty);
      expect(
        loopStepUpFailureKind(result.code),
        LoopChainFailureKind.stepUpCancelled,
      );
      expect(
        loopChainFailureReason(LoopChainFailureKind.stepUpCancelled),
        '已取消，没有发生任何变化。',
      );
      expect(loopStepUpReasonText(result.code), '已取消，没有发生任何变化。');
    });

    test('a failed prompt signs nothing either', () async {
      for (final outcome in <LoopDeviceAuthOutcome>[
        LoopDeviceAuthOutcome.failed,
        LoopDeviceAuthOutcome.lockedOut,
        LoopDeviceAuthOutcome.error,
      ]) {
        final device = _Device(answers: [outcome]);
        final wallet = _Wallet();
        final container = _container(device: device, wallet: wallet);
        final exit = container.read(loopGuardedWalletSigningGatewayProvider);

        final result = await exit.handoff(
          _intent(usd1: Decimal.parse('5000')),
          now: _now,
        );

        expect(result.code, loopStepUpFailedCode, reason: outcome.name);
        expect(wallet.handed, isEmpty, reason: outcome.name);
        expect(
          loopStepUpFailureKind(result.code),
          LoopChainFailureKind.stepUpCancelled,
        );
      }
    });

    test('one prompt covers the rest of the operation, not more', () async {
      final device = _Device();
      final wallet = _Wallet();
      final container = _container(device: device, wallet: wallet);
      final exit = container.read(loopGuardedWalletSigningGatewayProvider);

      await exit.handoff(_intent(usd1: Decimal.parse('2000')), now: _now);
      // The trade after its approval, or a re-quoted trade no larger.
      await exit.handoff(
        _intent(usd1: Decimal.parse('1500'), revision: 'intent-1:main'),
        now: _now,
      );
      expect(device.reasons, hasLength(1));
      // Larger than what was verified: asked again.
      await exit.handoff(_intent(usd1: Decimal.parse('2500')), now: _now);
      expect(device.reasons, hasLength(2));
      // Released when the sheet closes: asked again.
      container.read(loopStepUpProvider.notifier).release();
      await exit.handoff(_intent(usd1: Decimal.parse('1500')), now: _now);
      expect(device.reasons, hasLength(3));
      expect(wallet.handed, hasLength(4));
    });

    test('an intent the exit refuses anyway is never asked for', () async {
      final device = _Device();
      final wallet = _Wallet();
      final container = _container(device: device, wallet: wallet);
      final exit = container.read(loopGuardedWalletSigningGatewayProvider);

      final result = await exit.handoff(
        _intent(
          usd1: Decimal.parse('5000'),
          expiresAt: _now.subtract(const Duration(seconds: 1)),
        ),
        now: _now,
      );

      expect(result.code, 'intent_stale');
      expect(device.reasons, isEmpty);
    });

    test(
      'switched off, or on a device with no screen lock, it does not run',
      () async {
        final store = InMemoryLoopStepUpSettingsStore(
          <String, LoopStepUpSettings>{
            _principal: const LoopStepUpSettings(enabled: false),
          },
        );
        final off = _Device();
        final offContainer = _container(
          device: off,
          store: store,
          wallet: _Wallet(),
        );
        await offContainer
            .read(loopGuardedWalletSigningGatewayProvider)
            .handoff(_intent(usd1: Decimal.parse('5000')), now: _now);
        expect(off.reasons, isEmpty);

        final bare = _Device(
          capability: const LoopDeviceAuthCapability.unavailable(
            LoopDeviceAuthUnavailableReason.noCredentialSet,
          ),
        );
        final bareContainer = _container(device: bare, wallet: _Wallet());
        final result = await bareContainer
            .read(loopGuardedWalletSigningGatewayProvider)
            .handoff(_intent(usd1: Decimal.parse('5000')), now: _now);
        expect(result.accepted, isTrue);
        expect(bare.reasons, isEmpty);
      },
    );

    test('a MEME v2 trade is signed only after the prompt passed', () async {
      final events = <String>[];
      final device = _Device(events: events);
      final wallet = _Wallet(events: events);
      final container = _container(
        device: device,
        wallet: wallet,
        store: InMemoryLoopStepUpSettingsStore(<String, LoopStepUpSettings>{
          _principal: const LoopStepUpSettings(thresholdUsd1: 100),
        }),
      );
      final signer = container.read(launch2IntentSignerProvider);

      final outcome = await signer.sign(
        _poolBuy(),
        fromAddress: l2WalletAddress,
        ticker: 'FROG',
        now: l2Now,
      );
      expect(outcome.broadcast, isTrue);
      expect(events, <String>['auth', 'wallet']);
      expect(wallet.handed.single.stepUpUsd1, Decimal.parse('100'));

      device.answers.add(LoopDeviceAuthOutcome.canceled);
      container.read(loopStepUpProvider.notifier).release();
      final cancelled = await signer.sign(
        _poolBuy(),
        fromAddress: l2WalletAddress,
        ticker: 'FROG',
        now: l2Now,
      );
      expect(cancelled.broadcast, isFalse);
      expect(cancelled.reasonCode, loopStepUpCancelledCode);
      expect(launch2SignReasonText(cancelled.reasonCode), '已取消，没有发生任何变化。');
      expect(wallet.handed, hasLength(1));
    });
  });

  group('the settings', () {
    test('are kept per account', () async {
      final store = InMemoryLoopStepUpSettingsStore();
      final device = _Device();
      final a = _container(device: device, store: store);
      final controller = a.read(loopStepUpProvider.notifier);
      await controller.load();
      expect(a.read(loopStepUpProvider).settings, const LoopStepUpSettings());

      expect(await controller.setThreshold(500), isTrue);
      expect(await controller.setEnabled(false), isTrue);
      expect(
        store.values[_principal],
        const LoopStepUpSettings(enabled: false, thresholdUsd1: 500),
      );

      final b = _container(
        device: device,
        store: store,
        principal: _otherPrincipal,
      );
      await b.read(loopStepUpProvider.notifier).load();
      expect(b.read(loopStepUpProvider).settings, const LoopStepUpSettings());

      final again = _container(device: device, store: store);
      await again.read(loopStepUpProvider.notifier).load();
      expect(
        again.read(loopStepUpProvider).settings,
        const LoopStepUpSettings(enabled: false, thresholdUsd1: 500),
      );
    });

    test('switching it either way asks the device first', () async {
      final device = _Device(answers: [LoopDeviceAuthOutcome.canceled]);
      final store = InMemoryLoopStepUpSettingsStore();
      final container = _container(device: device, store: store);
      final controller = container.read(loopStepUpProvider.notifier);

      expect(await controller.setEnabled(false), isFalse);
      expect(container.read(loopStepUpProvider).settings.enabled, isTrue);
      expect(store.values, isEmpty);

      expect(await controller.setEnabled(false), isTrue);
      expect(device.reasons.last, '验证身份以关闭大额交易二次验证');
      expect(await controller.setEnabled(true), isTrue);
      expect(device.reasons.last, '验证身份以开启大额交易二次验证');
    });

    test('raising the threshold asks first, lowering does not', () async {
      final device = _Device();
      final container = _container(device: device);
      final controller = container.read(loopStepUpProvider.notifier);

      expect(await controller.setThreshold(500), isTrue);
      expect(device.reasons, isEmpty);
      expect(await controller.setThreshold(5000), isTrue);
      expect(device.reasons.single, '验证身份以提高大额交易的验证金额');
      expect(await controller.setThreshold(0), isFalse);
      expect(container.read(loopStepUpProvider).settings.thresholdUsd1, 5000);
    });

    test('cannot be switched on where the device cannot verify', () async {
      final device = _Device(
        capability: const LoopDeviceAuthCapability.unavailable(
          LoopDeviceAuthUnavailableReason.noCredentialSet,
        ),
      );
      final store = InMemoryLoopStepUpSettingsStore(
        <String, LoopStepUpSettings>{
          _principal: const LoopStepUpSettings(enabled: false),
        },
      );
      final container = _container(device: device, store: store);
      final controller = container.read(loopStepUpProvider.notifier);

      expect(await controller.setEnabled(true), isFalse);
      expect(device.reasons, isEmpty);
      final state = container.read(loopStepUpProvider);
      expect(state.isActive, isFalse);
      expect(state.settings.enabled, isFalse);
    });

    test(
      'the device store partitions by account and never keeps the raw key',
      () async {
        final written = <String, String>{};
        final store = SecureStorageLoopStepUpSettingsStore.forTesting(
          (key) async => written[key],
          (key, value) async => written[key] = value,
        );
        await store.write(
          _principal,
          const LoopStepUpSettings(enabled: false, thresholdUsd1: 5000),
        );
        await store.write(_otherPrincipal, const LoopStepUpSettings());

        final keyA =
            'loop.step_up.v1.${LoopV2OwnerPartition.fromPrincipal(_principal)}';
        expect(written[keyA], '0:5000');
        expect(written, hasLength(2));
        expect(written.keys.any((key) => key.contains('owner-a')), isFalse);
        expect(
          await store.read(_principal),
          const LoopStepUpSettings(enabled: false, thresholdUsd1: 5000),
        );
        expect(await store.read(_otherPrincipal), const LoopStepUpSettings());

        written[keyA] = 'garbage';
        expect(await store.read(_principal), isNull);
      },
    );
  });

  group('the setting row', () {
    Future<ProviderContainer> pumpRow(
      WidgetTester tester, {
      required _Device device,
      LoopStepUpSettingsStore? store,
    }) async {
      final container = _container(device: device, store: store);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const Scaffold(body: Center(child: LoopStepUpSettingRow())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    LoopRecordRow row(WidgetTester tester) =>
        tester.widget<LoopRecordRow>(find.byKey(LoopStepUpSettingRow.rowKey));

    testWidgets('a switch, the threshold, and no 即将推出', (tester) async {
      final device = _Device();
      await pumpRow(tester, device: device);

      expect(row(tester).subtitle, '达到 1,000 USD1 时再验一次身份');
      expect(find.textContaining('即将推出'), findsNothing);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(device.reasons.single, '验证身份以关闭大额交易二次验证');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the sheet edits the threshold, with presets and checks', (
      tester,
    ) async {
      final device = _Device();
      final store = InMemoryLoopStepUpSettingsStore();
      await pumpRow(tester, device: device, store: store);

      await tester.tap(find.text('大额交易二次验证'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('step-up-threshold-sheet')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('step-up-threshold-field')),
        '0',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('step-up-threshold-save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('金额需在 1 到 1,000,000 USD1 之间'), findsOneWidget);
      expect(store.values, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('step-up-preset-5000')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('step-up-threshold-save')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('step-up-threshold-sheet')),
        findsNothing,
      );
      expect(device.reasons.single, '验证身份以提高大额交易的验证金额');
      expect(store.values[_principal]?.thresholdUsd1, 5000);
      expect(row(tester).subtitle, '达到 5,000 USD1 时再验一次身份');
    });

    testWidgets('a device with no screen lock offers no switch, and says why', (
      tester,
    ) async {
      final device = _Device(
        capability: const LoopDeviceAuthCapability.unavailable(
          LoopDeviceAuthUnavailableReason.noCredentialSet,
        ),
      );
      await pumpRow(tester, device: device);

      expect(find.byType(Switch), findsNothing);
      expect(find.text('不可用'), findsOneWidget);
      expect(
        row(tester).subtitle,
        '达到 1,000 USD1 时再验一次身份 · 这台设备还没有设置锁屏密码或生物识别，先在系统设置里加上',
      );
      expect(row(tester).onTap, isNull);
    });
  });

  group('the signing sheet', () {
    Future<(ProviderContainer, _Device, _Wallet)> pumpSheet(
      WidgetTester tester, {
      required List<LoopDeviceAuthOutcome> answers,
      int threshold = 100,
      Launch2Intent? intent,
    }) async {
      final events = <String>[];
      final device = _Device(answers: answers, events: events);
      final wallet = _Wallet(events: events);
      final container = _container(
        device: device,
        wallet: wallet,
        store: InMemoryLoopStepUpSettingsStore(<String, LoopStepUpSettings>{
          _principal: LoopStepUpSettings(thresholdUsd1: threshold),
        }),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Launch2SignSheet(
                  intent: intent ?? _poolBuy(),
                  signer: container.read(launch2IntentSignerProvider),
                  fromAddress: l2WalletAddress,
                  ticker: 'FROG',
                  clock: () => l2Now,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, device, wallet);
    }

    testWidgets('shows 验证身份 before the wallet and signs after it', (
      tester,
    ) async {
      final (_, device, wallet) = await pumpSheet(tester, answers: []);

      expect(
        find.byKey(const ValueKey<String>('loop-sign-step-verify-waiting')),
        findsOneWidget,
      );
      expect(find.text('下一步，待验证'), findsOneWidget);

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(device.reasons, hasLength(1));
      expect(wallet.handed, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('loop-sign-step-verify-done')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-sign-step-sign-done')),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled prompt opens no wallet and can be tried again', (
      tester,
    ) async {
      final (_, device, wallet) = await pumpSheet(
        tester,
        answers: [LoopDeviceAuthOutcome.canceled],
      );

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(device.reasons, hasLength(1));
      expect(wallet.handed, isEmpty);
      expect(find.text('已取消，没有发生任何变化。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-sign-step-verify-failed')),
        findsOneWidget,
      );
      expect(find.text('已取消'), findsOneWidget);
      // Nothing was opened: the confirmation is live again.
      final confirm = tester.widget<LoopButton>(
        find.widgetWithText(LoopButton, '确认签名'),
      );
      expect(confirm.onPressed, isNotNull);

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(device.reasons, hasLength(2));
      expect(wallet.handed, hasLength(1));
    });

    testWidgets('with an approval the strip is 验证身份 → 授权 → 买入', (tester) async {
      await pumpSheet(
        tester,
        answers: [],
        threshold: 1,
        intent: _poolBuy(path: 's146-launch2-pool/pool_prepare_buy_approval'),
      );

      for (final key in <String>[
        'launch2-sign-step-verify-waiting',
        'launch2-sign-step-approval-waiting',
        'launch2-sign-step-main-waiting',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
      }
      expect(find.text('下一步，待验证'), findsOneWidget);
      expect(find.text('下一步，待签名'), findsNothing);
    });

    testWidgets('below the threshold the sheet is the one it always was', (
      tester,
    ) async {
      final (_, device, wallet) = await pumpSheet(
        tester,
        answers: [],
        threshold: 101,
      );

      expect(
        find.byKey(const ValueKey<String>('loop-sign-steps')),
        findsNothing,
      );
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(device.reasons, isEmpty);
      expect(wallet.handed, hasLength(1));
    });
  });

  test('every exit speaks the step-up in the same words', () {
    expect(memeSignReasonText(loopStepUpFailedCode), '身份验证没有通过，没有发生任何变化。');
    expect(loopStepUpStopped('wallet_outcome_unknown'), isFalse);
    expect(loopStepUpFailureKind('privy_broadcast_rejected'), isNull);
    expect(LoopStepUpVerdict.notRequired.allowsSigning, isTrue);
    expect(LoopStepUpVerdict.cancelled.refusalCode, loopStepUpCancelledCode);
  });
}
