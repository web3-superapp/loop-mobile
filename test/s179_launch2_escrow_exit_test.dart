// S179 · the NFT money's two exit paths on a MEME v2 instance (client
// decision 0162).
//
// loop-api S179 adds `instance.exitPaths` (the snapshot timeout that lets
// anyone open the public round, and the escrow refund for NFT holders when
// the project does not graduate in time) and `instance.viewerNftRefunds`,
// plus `POST …/nft/refund/prepare | report`. The samples are the S134
// fixtures with the fields added by hand — 待后端真实回包核对.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_refund_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:decimal/decimal.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _timeoutAt = '2027-01-21T07:00:00.000Z';
const String _opensAt = '2027-01-28T07:00:00.000Z';
const String _txHash =
    '0x5555555555555555555555555555555555555555555555555555555555555555';

Map<String, Object?> _exit({
  String timeout = 'not_applicable',
  String refund = 'not_applicable',
  int refunded = 0,
  int minted = 3,
}) => <String, Object?>{
  'snapshotTimeoutAt': _timeoutAt,
  'timeoutOpenState': timeout,
  'refundOpensAt': _opensAt,
  'refundState': refund,
  'refundedCount': refunded,
  'totalMinted': minted,
};

Map<String, Object?> _refund(
  String tokenId, {
  bool refunded = false,
  bool claimable = true,
  String amount = '87.5',
}) => <String, Object?>{
  'tokenId': tokenId,
  'refunded': refunded,
  'claimable': claimable,
  'amount': amount,
  'opensAt': _opensAt,
};

/// A detail body with `exitPaths` / `viewerNftRefunds` set by hand; [omit]
/// leaves both keys out.
Launch2InstanceDetail _detail({
  String stage = 'public',
  Object? exit,
  Object? refunds,
  bool omit = false,
  int held = 1,
}) {
  final body = l2DetailJson(
    stage: stage,
    noNextChange: stage == 'graduated',
    viewer: l2ViewerJson(held: held, member: true),
    pool: stage == 'graduated' ? l2PoolSummaryJson() : null,
  );
  if (!omit) {
    final instance = body['instance']! as Map<String, Object?>;
    instance['exitPaths'] = exit;
    instance['viewerNftRefunds'] = refunds;
  }
  return LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null);
}

const String _escrow = '0x6666666666666666666666666666666666666666';

/// The refund route's intent: `nft_refund`, `claimRefund` on the instance's
/// NftEscrow (`contracts.escrow`, loop-api S179), no approval, paying back
/// 87.5 USD1 (hand-made, 待后端真实回包核对).
Map<String, Object?> _refundIntentJson({String contract = _escrow}) {
  final body = l2IntentJson(
    kind: 'nft_refund',
    approval: false,
    contract: contract,
  );
  final intent = body['launch2Intent']! as Map<String, Object?>;
  intent['amountIn'] = '0';
  intent['expectedOut'] = '87.5';
  intent['minOut'] = '87.5';
  intent['taxUsd1'] = '0';
  return body;
}

final class _Fake implements Launch2Gateway {
  _Fake(this.detail, {this.positions});

  Launch2InstanceDetail detail;
  final Launch2Positions? positions;
  int loads = 0;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    loads += 1;
    return Future<Launch2InstanceDetail>.value(detail);
  }

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) => Future<Launch2Quote>.value(l2Quote());

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) => _unavailable();

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) =>
      Future<Launch2BuybackPage>.value(l2Buybacks());

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) => _unavailable();

  @override
  Future<Launch2Positions> loadPositions() => positions == null
      ? _unavailable()
      : Future<Launch2Positions>.value(positions);

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _unavailable();
}

final class _FakeRefund implements Launch2NftRefundGateway {
  _FakeRefund({this.refusal, this.onReport, this.contract = _escrow});

  final String? refusal;
  final String contract;
  final void Function()? onReport;
  final List<String> prepared = <String>[];
  final List<String> reports = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Intent> prepareRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
  }) async {
    prepared.add('$instanceId:$walletId:$tokenId');
    if (refusal != null) {
      throw LoopChainException(
        LoopChainFailureKind.validationFailed,
        reasonCode: refusal,
      );
    }
    return LoopV2Launch2Codec.intent(
      _refundIntentJson(contract: contract),
      venue: Launch2Venue.nftEscrow,
    );
  }

  @override
  Future<Launch2NftRefundReport> reportRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
    required String intentId,
    required String transactionHash,
  }) async {
    reports.add('$tokenId:$intentId:$transactionHash');
    onReport?.call();
    return LoopV2Launch2Codec.nftRefundReport(<String, Object?>{
      'nftRefundReport': <String, Object?>{
        'intentId': intentId,
        'status': 'submitted',
      },
      'contractVersion': '2.0',
    }, intentId: intentId);
  }
}

final class _RecordingWallet implements WalletSigningGateway {
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
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value: _txHash,
    );
  }
}

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  _Fake gateway, {
  _FakeRefund? refund,
  _RecordingWallet? wallet,
}) => pumpS7Page(
  tester,
  page,
  meta: _meta(),
  wallet: FakeWalletDirectory(
    activeWalletId: l2WalletId,
    wallets: <LoopWalletAccount>[
      LoopWalletAccount(
        walletId: l2WalletId,
        address: l2WalletAddress,
        kind: LoopWalletKind.embedded,
        status: LoopWalletStatus.active,
        isActive: true,
        firstSeenAt: DateTime.utc(2026, 9),
        lastSeenAt: DateTime.utc(2026, 10, 8),
      ),
    ],
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(gateway),
    if (refund != null)
      launch2NftRefundGatewayProvider.overrideWithValue(refund),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
      ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
  ],
);

Future<void> _open(
  WidgetTester tester,
  _Fake gateway, {
  _FakeRefund? refund,
  _RecordingWallet? wallet,
}) => _pump(
  tester,
  const Launch2InstanceScreen(instanceId: l2InstanceA),
  gateway,
  refund: refund,
  wallet: wallet,
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    (tester.widget<Widget>(_key(key)) as dynamic).onPressed as VoidCallback?;

String _textOf(WidgetTester tester, String key) {
  final widget = tester.widget<Widget>(
    find
        .descendant(of: _key(key), matching: find.byType(Text), matchRoot: true)
        .first,
  );
  return (widget as Text).data!;
}

void main() {
  loopWatchGround();

  group('codec · exitPaths / viewerNftRefunds', () {
    test('absent and null both read as unsupported', () {
      final absent = _detail(omit: true);
      expect(absent.exitPaths, isNull);
      expect(absent.viewerNftRefunds, isNull);
      final nulls = _detail();
      expect(nulls.exitPaths, isNull);
      expect(nulls.viewerNftRefunds, isNull);
    });

    test('every field decodes', () {
      final detail = _detail(
        exit: _exit(
          timeout: 'opened_by_timeout',
          refund: 'open',
          refunded: 1,
          minted: 3,
        ),
        refunds: <Object?>[
          _refund('1'),
          _refund('2', refunded: true, claimable: false),
        ],
      );
      final exit = detail.exitPaths!;
      expect(exit.snapshotTimeoutAt, DateTime.utc(2027, 1, 21, 7));
      expect(exit.timeoutOpenState, Launch2TimeoutOpenState.openedByTimeout);
      expect(exit.refundOpensAt, DateTime.utc(2027, 1, 28, 7));
      expect(exit.refundState, Launch2RefundState.open);
      expect(exit.refundedCount, 1);
      expect(exit.totalMinted, 3);
      final refunds = detail.viewerNftRefunds!;
      expect(refunds, hasLength(2));
      expect(refunds.first.tokenId, '1');
      expect(refunds.first.claimable, isTrue);
      expect(refunds.first.refunded, isFalse);
      expect(refunds.first.amount, Decimal.parse('87.5'));
      expect(refunds.first.opensAt, DateTime.utc(2027, 1, 28, 7));
      expect(refunds.last.refunded, isTrue);
      for (final (wire, state) in <(String, Launch2TimeoutOpenState)>[
        ('not_applicable', Launch2TimeoutOpenState.notApplicable),
        ('waiting', Launch2TimeoutOpenState.waiting),
        ('available', Launch2TimeoutOpenState.available),
      ]) {
        expect(
          _detail(exit: _exit(timeout: wire)).exitPaths!.timeoutOpenState,
          state,
        );
      }
      for (final (wire, state) in <(String, Launch2RefundState)>[
        ('waiting', Launch2RefundState.waiting),
        ('closed_graduated', Launch2RefundState.closedGraduated),
      ]) {
        expect(
          _detail(exit: _exit(refund: wire)).exitPaths!.refundState,
          state,
        );
      }
    });

    test('an unknown state reads as not_applicable for that path; an '
        'unreadable block reads as unsupported; the page never fails', () {
      final unknown = _detail(
        exit: _exit(timeout: 'opened_by_keeper', refund: 'partial'),
      ).exitPaths!;
      expect(unknown.timeoutOpenState, Launch2TimeoutOpenState.notApplicable);
      expect(unknown.refundState, Launch2RefundState.notApplicable);
      expect(
        _detail(exit: <String, Object?>{..._exit(), 'refundOpensAt': 'soon'})
            .exitPaths,
        isNull,
      );
      expect(_detail(exit: 'open').exitPaths, isNull);
      expect(_detail(refunds: 'none').viewerNftRefunds, isNull);
      final partial = _detail(
        refunds: <Object?>[
          _refund('1'),
          _refund('x'),
          <String, Object?>{'tokenId': '3'},
          7,
        ],
      ).viewerNftRefunds!;
      expect(partial.map((r) => r.tokenId), <String>['1']);
    });

    test('the refund intent: nft_refund only from the refund route', () {
      final intent = LoopV2Launch2Codec.intent(
        _refundIntentJson(),
        venue: Launch2Venue.nftEscrow,
      );
      expect(intent.kind, Launch2IntentKind.nftRefund);
      expect(intent.expectedOut, Decimal.parse('87.5'));
      expect(
        () => LoopV2Launch2Codec.intent(_refundIntentJson()),
        throwsA(anything),
      );
      expect(
        () => LoopV2Launch2Codec.intent(
          l2IntentJson(approval: false),
          venue: Launch2Venue.nftEscrow,
        ),
        throwsA(anything),
      );
    });

    // loop-api S179: `me/positions` carries no refunds, so the wallet row's
    // 可退款 tag does not appear today; the optional decode stays.
    test('a positions row without viewerNftRefunds is not refundable', () {
      expect(l2Positions().items.single.nftRefundClaimable, isFalse);
    });
  });

  group('copy', () {
    test('the refund refusal codes each say what did not happen', () {
      const expected = <String, String>{
        'LAUNCH2_REFUND_NOT_OPEN': '退款还没有开放，没有发起退款',
        'LAUNCH2_REFUND_ALREADY_CLAIMED': '这枚 NFT 的款已经退过，没有重复退款',
        'LAUNCH2_REFUND_NOT_OWNER': '这枚 NFT 不在当前钱包里，没有发起退款',
        'LAUNCH2_REFUND_GRADUATED': '项目已毕业，NFT 款已转入回购，没有发起退款',
        'LAUNCH2_EXIT_PATHS_UNSUPPORTED': '这个项目的合约不支持退款，没有发起退款',
        'LAUNCH2_REFUND_NOTHING_TO_REFUND': '托管里已经没有可退的款，没有发起退款',
        'LAUNCH2_REFUND_INTENT_NOT_FOUND': '找不到这笔退款记录，上报没有成功，链上结果不受影响',
        'LAUNCH2_REFUND_TRANSACTION_CONFLICT':
            '这笔退款已用另一笔交易上报过，这次上报没有记录，链上结果不受影响',
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(launch2ReasonText(key), value, reason: key);
      }
      // The hold codes still read as decision 0161 says.
      expect(launch2ReasonText('LAUNCH2_USD1_PAUSED'), launch2Usd1PausedText);
    });

    test('the sheet title and noun', () {
      expect(launch2IntentNoun(Launch2IntentKind.nftRefund), '退回 NFT 款');
      expect(
        launch2IntentTitle(
          Launch2IntentKind.nftRefund,
          venue: Launch2Venue.nftEscrow,
        ),
        '退回 NFT 款',
      );
    });
  });

  group('project page · timeoutOpenState', () {
    testWidgets('snapshot_pending · not_applicable: no line', (tester) async {
      await _open(
        tester,
        _Fake(_detail(stage: 'snapshot_pending', exit: _exit())),
      );
      expect(_key('launch2-stage-bar'), findsOneWidget);
      expect(_key('launch2-exit-timeout'), findsNothing);
      expect(_key('launch2-exit-opened-by-timeout'), findsNothing);
      await _drain(tester);
    });

    testWidgets('snapshot_pending · waiting: the time anyone may open', (
      tester,
    ) async {
      await _open(
        tester,
        _Fake(
          _detail(
            stage: 'snapshot_pending',
            exit: _exit(timeout: 'waiting'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: _key('launch2-stage-bar'),
          matching: find.text(
            launch2TimeoutWaitingText(DateTime.parse(_timeoutAt)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        launch2TimeoutWaitingText(DateTime.parse(_timeoutAt)),
        startsWith('快照未发布 · '),
      );
      expect(
        launch2TimeoutWaitingText(DateTime.parse(_timeoutAt)),
        endsWith(' 后任何人可直接开盘'),
      );
      await _drain(tester);
    });

    testWidgets('snapshot_pending · available: waiting to be opened', (
      tester,
    ) async {
      await _open(
        tester,
        _Fake(
          _detail(
            stage: 'snapshot_pending',
            exit: _exit(timeout: 'available'),
          ),
        ),
      );
      expect(_textOf(tester, 'launch2-exit-timeout'), '已到可开盘时间，等待开盘');
      await _drain(tester);
    });

    testWidgets('public · opened_by_timeout: the title\'s note', (
      tester,
    ) async {
      await _open(
        tester,
        _Fake(_detail(exit: _exit(timeout: 'opened_by_timeout'))),
      );
      expect(find.text('超时开盘，无提前购'), findsOneWidget);
      expect(_key('launch2-exit-opened-by-timeout'), findsOneWidget);
      expect(_key('launch2-exit-timeout'), findsNothing);
      await _drain(tester);
    });

    testWidgets('no exitPaths: the page is as before', (tester) async {
      await _open(tester, _Fake(_detail(stage: 'snapshot_pending')));
      expect(_key('launch2-exit-timeout'), findsNothing);
      expect(_key('launch2-refund'), findsNothing);
      expect(_key('launch2-refund-waiting'), findsNothing);
      await _drain(tester);
    });
  });

  group('project page · refundState', () {
    testWidgets('waiting with an NFT: the line under the NFT', (tester) async {
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'waiting'),
            refunds: <Object?>[_refund('1', claimable: false)],
          ),
        ),
      );
      expect(
        _textOf(tester, 'launch2-refund-waiting'),
        launch2RefundWaitingText(DateTime.parse(_opensAt)),
      );
      expect(
        launch2RefundWaitingText(DateTime.parse(_opensAt)),
        endsWith(' 前未毕业，可按比例退回 NFT 款'),
      );
      expect(_key('launch2-refund'), findsNothing);
      await _drain(tester);
    });

    testWidgets('waiting without an NFT: nothing', (tester) async {
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'waiting'),
            refunds: <Object?>[],
            held: 0,
          ),
        ),
      );
      expect(_key('launch2-refund-waiting'), findsNothing);
      await _drain(tester);
    });

    testWidgets('open: one row per NFT, 可退 / 已退 / 不可退, 退款 only on '
        'a refundable one', (tester) async {
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'open', refunded: 1),
            refunds: <Object?>[
              _refund('1'),
              _refund('2', refunded: true, claimable: false),
              _refund('3', claimable: false),
            ],
          ),
        ),
        refund: _FakeRefund(),
      );
      await _scrollTo(tester, _key('launch2-refund-row-3'));
      expect(find.text('退回 NFT 款'), findsOneWidget);
      expect(find.text('已退 1 / 3 枚'), findsOneWidget);
      expect(_textOf(tester, 'launch2-refund-status-1'), '可退');
      expect(_textOf(tester, 'launch2-refund-status-2'), '已退');
      expect(_textOf(tester, 'launch2-refund-status-3'), '不可退');
      expect(_textOf(tester, 'launch2-refund-amount-1'), '87.5 USD1');
      expect(_onPressed(tester, 'launch2-refund-1'), isNotNull);
      expect(_key('launch2-refund-2'), findsNothing);
      expect(_key('launch2-refund-3'), findsNothing);
      await _drain(tester);
    });

    testWidgets('open without an NFT: nothing', (tester) async {
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'open'),
            refunds: <Object?>[],
            held: 0,
          ),
        ),
      );
      expect(_key('launch2-refund'), findsNothing);
      await _drain(tester);
    });

    testWidgets('closed_graduated with an unrefunded NFT: no more refunds', (
      tester,
    ) async {
      await _open(
        tester,
        _Fake(
          _detail(
            stage: 'graduated',
            exit: _exit(refund: 'closed_graduated'),
            refunds: <Object?>[_refund('1', claimable: false)],
          ),
        ),
      );
      await _scrollTo(tester, _key('launch2-refund-closed'));
      expect(_textOf(tester, 'launch2-refund-closed'), '项目已毕业，NFT 款转入回购，不再退款');
      expect(_key('launch2-refund'), findsNothing);
      await _drain(tester);
    });

    testWidgets('closed_graduated with every NFT refunded, or none: nothing', (
      tester,
    ) async {
      await _open(
        tester,
        _Fake(
          _detail(
            stage: 'graduated',
            exit: _exit(refund: 'closed_graduated'),
            refunds: <Object?>[_refund('1', refunded: true, claimable: false)],
          ),
        ),
      );
      expect(_key('launch2-refund-closed'), findsNothing);
      await _drain(tester);
      await _open(
        tester,
        _Fake(
          _detail(
            stage: 'graduated',
            exit: _exit(refund: 'closed_graduated'),
            refunds: <Object?>[],
            held: 0,
          ),
        ),
      );
      expect(_key('launch2-refund-closed'), findsNothing);
      await _drain(tester);
    });

    testWidgets('退款: confirm, prepare, the signing exit, the report, then '
        'a fresh read turns the row 已退', (tester) async {
      final gateway = _Fake(
        _detail(
          exit: _exit(refund: 'open'),
          refunds: <Object?>[_refund('1')],
        ),
      );
      final wallet = _RecordingWallet();
      final refund = _FakeRefund(
        onReport: () => gateway.detail = _detail(
          exit: _exit(refund: 'open', refunded: 1),
          refunds: <Object?>[_refund('1', refunded: true, claimable: false)],
        ),
      );
      await _open(tester, gateway, refund: refund, wallet: wallet);
      await _scrollTo(tester, _key('launch2-refund-1'));
      await tester.tap(_key('launch2-refund-1'));
      await tester.pumpAndSettle();
      expect(_key('launch2-refund-confirm'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-refund-confirm'),
          matching: find.text('87.5 USD1'),
        ),
        findsOneWidget,
      );
      expect(refund.prepared, isEmpty);
      await tester.tap(_key('launch2-refund-confirm-button'));
      await tester.pumpAndSettle();
      expect(refund.prepared.single, '$l2InstanceA:$l2WalletId:1');
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-sign-sheet'),
          matching: find.text('退回 NFT 款'),
        ),
        findsWidgets,
      );
      final loadsBefore = gateway.loads;
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.single.kind, IntentKind.launchPurchase);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(refund.reports.single, '1:$l2IntentId:$_txHash');
      expect(gateway.loads, greaterThan(loadsBefore));
      await _scrollTo(tester, _key('launch2-refund-status-1'));
      expect(_textOf(tester, 'launch2-refund-status-1'), '已退');
      expect(_key('launch2-refund-1'), findsNothing);
      expect(find.text('退回 NFT 款已在链上确认。'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a refusal stays under the NFT\'s row, nothing is signed', (
      tester,
    ) async {
      final wallet = _RecordingWallet();
      final refund = _FakeRefund(refusal: 'LAUNCH2_REFUND_NOT_OWNER');
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'open'),
            refunds: <Object?>[_refund('1')],
          ),
        ),
        refund: refund,
        wallet: wallet,
      );
      await _scrollTo(tester, _key('launch2-refund-1'));
      await tester.tap(_key('launch2-refund-1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-refund-confirm-button'));
      await tester.pumpAndSettle();
      expect(refund.prepared, hasLength(1));
      expect(_key('launch2-sign-sheet'), findsNothing);
      expect(wallet.handed, isEmpty);
      expect(
        find.descendant(
          of: _key('launch2-refund-failed-1'),
          matching: find.text('这枚 NFT 不在当前钱包里，没有发起退款'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });
  });

  group('project page · refund target', () {
    testWidgets('an intent to any contract but contracts.escrow (here the '
        'NFT) is refused before the wallet', (tester) async {
      final wallet = _RecordingWallet();
      final refund = _FakeRefund(contract: l2Nft);
      await _open(
        tester,
        _Fake(
          _detail(
            exit: _exit(refund: 'open'),
            refunds: <Object?>[_refund('1')],
          ),
        ),
        refund: refund,
        wallet: wallet,
      );
      await _scrollTo(tester, _key('launch2-refund-1'));
      await tester.tap(_key('launch2-refund-1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-refund-confirm-button'));
      await tester.pumpAndSettle();
      expect(refund.prepared, hasLength(1));
      expect(_key('launch2-sign-sheet'), findsNothing);
      expect(wallet.handed, isEmpty);
      expect(
        find.descendant(
          of: _key('launch2-refund-failed-1'),
          matching: find.textContaining('交易内容与确认内容不一致'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });
  });

  group('钱包 · 资产', () {
    testWidgets('without refunds the NFT row is as before', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[
              Launch2WalletRows(onOpen: (_) {}, hidden: false),
            ],
          ),
        ),
        _Fake(_detail(), positions: l2Positions()),
      );
      expect(find.text('项目 NFT #1'), findsOneWidget);
      expect(find.textContaining('可退款'), findsNothing);
      await _drain(tester);
    });
  });
}
