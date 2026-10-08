import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s7_page_harness.dart';
import 'support/s88d_meta_server.dart';

/// S88d · decision 0099: the forced capability refresh in front of every
/// signing sheet, the retained mining read, and the offline card that only
/// claims a cache when it has one.
void main() {
  // The wallet page and the cards below are mounted by this file directly.
  loopWatchGround();

  group('the signing exits read the capability document first', () {
    testWidgets('send · a request pair goes out before the sheet, and the '
        'action is pending meanwhile', (tester) async {
      final server = S88dMetaServer(_moneyDocument());
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
        metaRepository: server,
      );
      expect(server.log, <String>['policy', 'capabilities']);

      server.hold = true;
      await tester.tap(_key('send-confirm-sign'));
      await tester.pump();
      await tester.pump();
      expect(server.log, hasLength(4));
      expect(server.log.sublist(2), <String>['policy', 'capabilities']);
      final pending = tester.widget<LoopButton>(_key('send-confirm-sign'));
      expect(pending.label, moneyCapabilityCheckingLabel);
      expect(pending.onPressed, isNull);
      expect(_key('money-sign-sheet'), findsNothing);

      server.release();
      await tester.pumpAndSettle();
      expect(_key('money-sign-sheet'), findsOneWidget);
    });

    testWidgets('send · a gate closed since the page opened keeps the sheet '
        'shut and takes the existing block', (tester) async {
      final server = S88dMetaServer(_moneyDocument());
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
        metaRepository: server,
      );

      server.document = _moneyDocument(
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
      );
      await tester.tap(_key('send-confirm-sign'));
      await tester.pumpAndSettle();
      expect(server.log, hasLength(4));
      expect(_key('money-sign-sheet'), findsNothing);
      expect(_key('send-confirm-capability-block'), findsOneWidget);
    });

    testWidgets('send · a refresh that fails keeps the answer on hand and '
        'the sheet opens as before', (tester) async {
      final server = S88dMetaServer(_moneyDocument());
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
        metaRepository: server,
      );
      server.failing = true;
      await tester.tap(_key('send-confirm-sign'));
      await tester.pumpAndSettle();
      expect(server.log, hasLength(4));
      expect(_key('money-sign-sheet'), findsOneWidget);
    });

    testWidgets('swap · a request pair goes out before the intent and the '
        'sheet, and the action is pending meanwhile', (tester) async {
      final server = S88dMetaServer(_moneyDocument());
      final intents = FakeWalletIntentsGateway(prepared: s6SwapIntent());
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        quotes: FakeSwapQuoteGateway(),
        intents: intents,
        metaRepository: server,
      );
      await _quote(tester);
      expect(server.log, <String>['policy', 'capabilities']);

      server.hold = true;
      await tester.tap(_key('swap-confirm-action'));
      await tester.pump();
      await tester.pump();
      expect(server.log, hasLength(4));
      final pending = tester.widget<LoopButton>(_key('swap-confirm-action'));
      expect(pending.label, moneyCapabilityCheckingLabel);
      expect(pending.onPressed, isNull);
      expect(intents.prepareCalls, 0);
      expect(_key('money-sign-sheet'), findsNothing);

      server.release();
      await tester.pumpAndSettle();
      expect(intents.prepareCalls, 1);
      expect(_key('money-sign-sheet'), findsOneWidget);
    });

    testWidgets('swap · a gate closed since the quote prepares nothing and '
        'takes the existing block', (tester) async {
      final server = S88dMetaServer(_moneyDocument());
      final intents = FakeWalletIntentsGateway(prepared: s6SwapIntent());
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        quotes: FakeSwapQuoteGateway(),
        intents: intents,
        metaRepository: server,
      );
      await _quote(tester);

      server.document = _moneyDocument(
        privySwap: LoopV2CapabilityAvailability.unavailable,
      );
      await tester.tap(_key('swap-confirm-action'));
      await tester.pumpAndSettle();
      expect(server.log, hasLength(4));
      expect(intents.prepareCalls, 0);
      expect(_key('money-sign-sheet'), findsNothing);
      expect(_key('swap-capability-block'), findsOneWidget);
    });
  });

  group('the mining read on the wallet page is retained (decision 0095)', () {
    testWidgets('a second visit sends nothing; the tag reads the summary', (
      tester,
    ) async {
      final mining = _CountingMining();
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      loopArmGroundProbe(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            miningGatewayProvider.overrideWithValue(mining),
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) =>
                  show ? const WalletScreen() : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Decision 0119: the rows no longer carry a per-asset power figure, so
      // the page reads no mining composition at all. The account's power is
      // read when the 「产生算力」 tag is opened.
      expect(mining.assetsCalls, 0);
      expect(mining.summaryCalls, 0);
      await tester.tap(_key('wallet-power-tag'));
      await tester.pumpAndSettle();
      expect(mining.summaryCalls, 1);
      await tester.tap(_key('wallet-power-sheet-close'));
      await tester.pumpAndSettle();

      // Leave the page and come back inside the revisit floor, and open the
      // note again: the summary is retained, nothing is sent.
      visible.value = false;
      await tester.pumpAndSettle();
      visible.value = true;
      await tester.pumpAndSettle();
      await tester.tap(_key('wallet-power-tag'));
      await tester.pumpAndSettle();
      expect(mining.summaryCalls, 1);
      expect(mining.assetsCalls, 0);
    });
  });

  group('the offline card claims a cache only when it has one', () {
    testWidgets('cached · offline, with the cache time', (tester) async {
      await _pumpCard(tester, const LoopOfflineState(cachedAtLabel: '09:38'));
      expect(find.text('离线 · 显示缓存'), findsOneWidget);
      expect(find.text('缓存 09:38'), findsOneWidget);
      expect(find.textContaining('缓存值可能已过期'), findsOneWidget);
      expect(find.text('重试连接'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('缓存时间 09:38')), findsOneWidget);
    });

    testWidgets('no cache · cannot reach LOOP, no cache stamp, retry kept', (
      tester,
    ) async {
      var retries = 0;
      await _pumpCard(tester, LoopOfflineState(onRetry: () => retries += 1));
      expect(find.text('连不上 LOOP'), findsOneWidget);
      expect(find.text('离线 · 显示缓存'), findsNothing);
      expect(find.textContaining('缓存 '), findsNothing);
      expect(_key('loop-offline-cached-at'), findsNothing);
      expect(find.textContaining('这次读取没有完成，还没有可显示的缓存。'), findsOneWidget);
      await tester.tap(find.text('重试连接'));
      expect(retries, 1);
    });

    testWidgets('timeout · LOOP did not answer in time', (tester) async {
      await _pumpCard(
        tester,
        LoopOfflineState(cause: LoopOfflineCause.timeout, onRetry: () {}),
      );
      expect(find.text('LOOP 响应超时'), findsOneWidget);
      expect(find.text('连不上 LOOP'), findsNothing);
      expect(find.textContaining('这次读取没有完成，还没有可显示的缓存。'), findsOneWidget);
      expect(find.text('重试连接'), findsOneWidget);
    });

    testWidgets('a chain read that timed out reaches the page as a timeout', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        const LoopChainStateBlock(
          phase: LoopChainViewPhase.offline,
          failureKind: LoopChainFailureKind.timedOut,
          keyPrefix: 'wallet-balances',
        ),
      );
      expect(_key('wallet-balances-state-offline'), findsOneWidget);
      expect(find.text('LOOP 响应超时'), findsOneWidget);
    });

    test('a read timeout is worded apart; a write timeout stays offline', () {
      const timeout = LoopBackendFailure(LoopBackendFailureKind.timeout);
      const connection = LoopBackendFailure(LoopBackendFailureKind.connection);
      expect(
        loopChainFailureKindForV2(timeout, write: false),
        LoopChainFailureKind.timedOut,
      );
      expect(
        loopChainFailureKindForV2(timeout, write: true),
        LoopChainFailureKind.offline,
      );
      expect(
        loopChainFailureKindForV2(connection, write: false),
        LoopChainFailureKind.offline,
      );
      expect(
        loopChainPhaseForFailure(LoopChainFailureKind.timedOut),
        LoopChainViewPhase.offline,
      );
      expect(
        launchFailureKindForV2(timeout, write: false),
        LaunchFailureKind.timedOut,
      );
      expect(
        launchFailureKindForV2(timeout, write: true),
        LaunchFailureKind.offline,
      );
      expect(
        launchPhaseForFailure(LaunchFailureKind.timedOut),
        LaunchViewPhase.offline,
      );
      expect(
        communityFailureKindForV2(timeout, write: false),
        CommunityFailureKind.timedOut,
      );
      expect(
        communityFailureKindForV2(timeout, write: true),
        CommunityFailureKind.offline,
      );
    });
  });
}

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _draft = SendDraft(
  walletId: s5WalletId,
  assetId: s5NativeAssetId,
  symbol: 'BNB',
  recipientAddress: s6RecipientChecksum,
  amount: '0.01',
);

DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);

LoopV2MetaSnapshot _moneyDocument({
  LoopV2CapabilityAvailability sendApprovals =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability privySwap =
      LoopV2CapabilityAvailability.available,
}) => s5MetaSnapshot(
  sendApprovals: sendApprovals,
  privySwap: privySwap,
  swapEvidencePending: false,
);

/// Counts the mining reads the wallet page makes.
final class _CountingMining implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();
  int assetsCalls = 0;
  int summaryCalls = 0;

  @override
  LaunchGatewayMode get mode => _inner.mode;

  @override
  Future<MiningSummary> loadSummary() {
    summaryCalls += 1;
    return _inner.loadSummary();
  }

  @override
  Future<MiningAssets> loadAssets() {
    assetsCalls += 1;
    return _inner.loadAssets();
  }

  @override
  Future<MiningRewards> loadRewards() => _inner.loadRewards();

  @override
  Future<MiningRank> loadRank(MiningRankScope scope) => _inner.loadRank(scope);

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: ListView(children: <Widget>[card])),
    ),
  );
  await tester.pumpAndSettle();
}

FakeWalletReadGateway _twoAssetWallet() => FakeWalletReadGateway(
  balances: S5Answer<LoopWalletBalances>(
    value: s5Balances(
      rows: <LoopAssetBalanceRow>[
        s5Row(),
        s5Row(assetId: s5WbnbAssetId),
      ],
    ),
  ),
);

/// Chooses both assets, types an amount and asks for the quote.
Future<void> _quote(WidgetTester tester) async {
  await tester.tap(_key('swap-source-pick'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-pick-$s5NativeAssetId'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-destination-pick'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-pick-$s5WbnbAssetId'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('swap-source-amount'), '0.005');
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-quote-action'));
  await tester.pumpAndSettle();
}
