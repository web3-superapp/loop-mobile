import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S136 · MEME v2 user pages (client decision 0139)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

/// One scripted answer: a value, a failure, or a read that never answers.
final class _Answer<T> {
  const _Answer.value(T this.value) : failure = null, pending = false;
  const _Answer.fail(LoopChainFailureKind kind, {String? reasonCode})
    : value = null,
      failure = (kind, reasonCode),
      pending = false;
  const _Answer.pending() : value = null, failure = null, pending = true;

  final T? value;
  final (LoopChainFailureKind, String?)? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final f = failure;
    if (f != null) {
      return Future<T>.error(LoopChainException(f.$1, reasonCode: f.$2));
    }
    return Future<T>.value(value as T);
  }
}

final class _FakeLaunch2 implements Launch2Gateway {
  _FakeLaunch2({
    this.list,
    List<_Answer<Launch2InstanceDetail>>? details,
    List<_Answer<Launch2Quote>>? quotes,
    this.nftAnswer,
    List<_Answer<Launch2Intent>>? tradeAnswers,
    this.buybacks,
    this.positions,
  }) : details = details ?? <_Answer<Launch2InstanceDetail>>[],
       quotes = quotes ?? <_Answer<Launch2Quote>>[],
       tradeAnswers = tradeAnswers ?? <_Answer<Launch2Intent>>[];

  _Answer<Launch2InstancePage> Function(Launch2Stage? stage, String? cursor)?
  list;
  final List<_Answer<Launch2InstanceDetail>> details;
  final List<_Answer<Launch2Quote>> quotes;
  _Answer<Launch2Intent>? nftAnswer;
  final List<_Answer<Launch2Intent>> tradeAnswers;
  _Answer<Launch2BuybackPage>? buybacks;
  _Answer<Launch2Positions>? positions;

  final List<(Launch2Stage?, String?)> listCalls = <(Launch2Stage?, String?)>[];
  final List<(Launch2Side, Decimal)> quoteCalls = <(Launch2Side, Decimal)>[];
  final List<Map<String, Object?>> tradeCalls = <Map<String, Object?>>[];
  int detailReads = 0;
  int nftCalls = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  static T _pick<T>(List<T> answers, int index) =>
      answers[index < answers.length ? index : answers.length - 1];

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) {
    listCalls.add((stage, cursor));
    final answer = list;
    return answer == null ? _unavailable() : answer(stage, cursor).resolve();
  }

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    final index = detailReads;
    detailReads += 1;
    if (details.isEmpty) return _unavailable();
    return _pick(details, index).resolve();
  }

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) {
    final index = quoteCalls.length;
    quoteCalls.add((side, amount));
    if (quotes.isEmpty) return _unavailable();
    return _pick(quotes, index).resolve();
  }

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) {
    nftCalls += 1;
    return nftAnswer?.resolve() ?? _unavailable();
  }

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) {
    final index = tradeCalls.length;
    tradeCalls.add(<String, Object?>{
      'side': side,
      'amount': amount,
      'minOut': minOut,
      'deadline': deadline,
    });
    if (tradeAnswers.isEmpty) return _unavailable();
    return _pick(tradeAnswers, index).resolve();
  }

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) =>
      buybacks?.resolve() ?? _unavailable();

  @override
  Future<Launch2Positions> loadPositions() =>
      positions?.resolve() ?? _unavailable();

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

LoopV2MetaSnapshot _meta({
  LoopV2CapabilityAvailability launch2 = LoopV2CapabilityAvailability.available,
}) {
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
            LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: launch2,
              reasonCode: launch2 == LoopV2CapabilityAvailability.available
                  ? null
                  : 'LAUNCH2_FACTORY_NOT_CONFIGURED',
              evidence: const LoopV2CapabilityEvidence(
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

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: l2WalletId,
  address: l2WalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

/// A clock the test moves by hand.
final class _Clock {
  DateTime now = l2Now;
  DateTime call() => now;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _FakeLaunch2 launch2,
  _RecordingWallet? wallet,
  LoopV2MetaSnapshot? meta,
  bool switchOn = true,
  _Clock? clock,
  bool settle = true,
  List<Override> overrides = const <Override>[],
}) {
  final time = clock ?? _Clock();
  return pumpS7Page(
    tester,
    page,
    meta: meta ?? _meta(),
    settle: settle,
    wallet: FakeWalletDirectory(
      activeWalletId: l2WalletId,
      wallets: <LoopWalletAccount>[_wallet()],
    ),
    overrides: <Override>[
      launch2GatewayProvider.overrideWithValue(launch2),
      launch2ClockProvider.overrideWithValue(time.call),
      launch2PollingProvider.overrideWithValue(
        const Launch2Polling(
          detailInterval: Duration(hours: 1),
          tradingInterval: Duration(hours: 1),
        ),
      ),
      loopFeatureSwitchesProvider.overrideWithValue(
        LoopFeatureSwitchValues(launch2Visible: switchOn),
      ),
      if (wallet != null)
        walletSigningGatewayProvider.overrideWithValue(wallet),
      ...overrides,
    ],
  );
}

/// Lets the pending timers of the page run out before teardown.
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

void main() {
  loopWatchGround();

  group('codec (strict keys, contract 0114 / 0117 / 0118)', () {
    test('every route decodes its contract sample', () {
      final page = l2Page(<Map<String, Object?>>[
        l2RowJson(),
        l2RowJson(instanceId: l2InstanceB, stage: 'upcoming'),
      ]);
      expect(page.items, hasLength(2));
      expect(
        page.items.first.curve.priceUsd1,
        Decimal.parse('0.00004166666625'),
      );
      expect(page.items.first.nftSale.endAt, DateTime.utc(2027, 1, 23, 7));
      final detail = l2Detail(stage: 'graduated');
      expect(detail.graduation!.officialPoolId, l2PoolId);
      expect(detail.contracts['curve'], l2Curve);
      expect(detail.template.perAddressCap, Decimal.fromInt(5000000));
      expect(l2Quote(exceedsMax: true).maxAmountIn, Decimal.parse('185185.18'));
      final intent = l2Intent();
      expect(intent.payloadMatchesReview, isTrue);
      expect(intent.approval!.spender, l2Nft);
      expect(
        l2Buybacks().live!.nextOrderBlockedReason,
        'BUYBACK_PROTECTION_BLOCKED',
      );
      expect(l2Positions().items.single.nftHeld, 1);
    });

    test('an unknown or a missing key is an invalid payload', () {
      Object? decode(Map<String, Object?> json) =>
          LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null);
      final extra = l2DetailJson();
      (extra['instance']! as Map<String, Object?>)['surprise'] = 1;
      expect(() => decode(extra), throwsA(isA<LoopBackendFailure>()));
      final missing = l2DetailJson();
      (missing['instance']! as Map<String, Object?>).remove('viewer');
      expect(() => decode(missing), throwsA(isA<LoopBackendFailure>()));
      final row = l2RowJson()..['stage'] = 'launching';
      expect(
        () => LoopV2Launch2Codec.page(
          l2PageJson(<Map<String, Object?>>[row]),
          mediaUrl: (_) => null,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('snapshot.publication is optional (before 0118) and strict when '
        'present', () {
      final absent = LoopV2Launch2Codec.detail(
        l2DetailJson(stage: 'snapshot_pending'),
        mediaUrl: (_) => null,
      );
      expect(absent.snapshot.publication, isNull);
      final present = LoopV2Launch2Codec.detail(
        l2DetailJson(
          stage: 'snapshot_pending',
          omitPublication: false,
          publication: <String, Object?>{
            'status': 'broadcast',
            'txHash': l2Hash,
            'cutoffBlock': '1234',
            'memberCount': 160,
          },
        ),
        mediaUrl: (_) => null,
      );
      expect(
        present.snapshot.publication!.status,
        Launch2PublicationStatus.broadcast,
      );
      expect(
        () => LoopV2Launch2Codec.detail(
          l2DetailJson(
            stage: 'snapshot_pending',
            omitPublication: false,
            publication: <String, Object?>{'status': 'sent'},
          ),
          mediaUrl: (_) => null,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a quote for another wallet, a tampered intent and a buyback page '
        'with both live answers are refused', () {
      expect(
        () => LoopV2Launch2Codec.quote(
          l2QuoteJson(),
          instanceId: l2InstanceA,
          side: Launch2Side.sell,
          walletId: l2WalletId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      final tampered = l2IntentJson();
      ((tampered['launch2Intent']! as Map<String, Object?>)['approval']!
              as Map<String, Object?>)['spender'] =
          '0x9999999999999999999999999999999999999999';
      expect(LoopV2Launch2Codec.intent(tampered).payloadMatchesReview, isFalse);
      final both = l2BuybacksJson()
        ..['liveUnavailable'] = <String, Object?>{
          'reasonCode': 'LAUNCH2_CHAIN_READ_FAILED',
        };
      expect(
        () => LoopV2Launch2Codec.buybacks(both, instanceId: l2InstanceA),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('MEME Tab segments (feature switch + capability)', () {
    testWidgets('switch off: the Tab stays 发射台 / 行情', (tester) async {
      final launch2 = _FakeLaunch2();
      await _pump(
        tester,
        const MemeScreen(),
        launch2: launch2,
        switchOn: false,
      );
      expect(find.text('发射台'), findsWidgets);
      expect(find.text('v2 发射'), findsNothing);
      expect(launch2.listCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('capability not available: the Tab stays 发射台 / 行情', (
      tester,
    ) async {
      final launch2 = _FakeLaunch2();
      await _pump(
        tester,
        const MemeScreen(),
        launch2: launch2,
        meta: _meta(launch2: LoopV2CapabilityAvailability.deferred),
      );
      expect(find.text('v2 发射'), findsNothing);
      expect(launch2.listCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('switch on + available: v2 发射 / 经典 / 已毕业, each list '
        'reads its own scope', (tester) async {
      final launch2 = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          stage == Launch2Stage.graduated
              ? l2Page(<Map<String, Object?>>[
                  l2RowJson(stage: 'graduated', noNextChange: true),
                ])
              : l2Page(<Map<String, Object?>>[l2RowJson()]),
        ),
      );
      await _pump(
        tester,
        const MemeScreen(),
        launch2: launch2,
        overrides: <Override>[
          memeGatewayProvider.overrideWithValue(const UnavailableMemeGateway()),
        ],
      );
      expect(find.text('v2 发射'), findsWidgets);
      expect(find.text('经典'), findsOneWidget);
      expect(find.text('已毕业'), findsWidgets);
      expect(launch2.listCalls.first, (null, null));
      expect(_key('launch2-row-$l2InstanceA'), findsOneWidget);

      await tester.tap(_key('meme-segment-2'));
      await tester.pumpAndSettle();
      expect(launch2.listCalls, contains((Launch2Stage.graduated, null)));
      expect(_key('launch2-stage-pill-graduated'), findsOneWidget);

      await tester.tap(_key('meme-segment-1'));
      await tester.pumpAndSettle();
      // 经典 is the S117 launchpad, closed here without its transport.
      expect(_key('meme-launchpad-unavailable'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('v2 list rows', () {
    testWidgets('each stage says its own two lines; only the countdown ticks', (
      tester,
    ) async {
      final clock = _Clock();
      final launch2 = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          l2Page(<Map<String, Object?>>[
            l2RowJson(
              instanceId: l2InstanceA,
              stage: 'upcoming',
              nextChangeAt: l2Now.add(const Duration(hours: 1, seconds: 5)),
            ),
            l2RowJson(
              instanceId: l2InstanceB,
              stage: 'nft_sale',
              soldCount: '42',
            ),
            l2RowJson(
              instanceId: '1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d',
              stage: 'priority',
              soldBps: 3327,
            ),
            l2RowJson(
              instanceId: '2c3d4e5f-6071-4b8c-9d0e-1f2a3b4c5d6e',
              stage: 'graduated',
              noNextChange: true,
            ),
          ]),
        ),
      );
      final opened = <String>[];
      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: opened.add),
        launch2: launch2,
        clock: clock,
      );
      expect(find.text('01:00:05'), findsOneWidget);
      expect(find.text('后开售'), findsOneWidget);
      expect(find.text('NFT 已售 42'), findsOneWidget);
      expect(find.text('剩 2天 03:00:00'), findsOneWidget);
      expect(find.text('33.27%'), findsOneWidget);
      expect(find.text('\$0.0₄4167'), findsOneWidget);
      expect(find.text('已毕业'), findsWidgets);
      expect(find.textContaining('毕业价'), findsOneWidget);
      expect(_key('launch2-list-all-provenance'), findsOneWidget);

      clock.now = l2Now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:00:04'), findsOneWidget);
      expect(find.text('剩 2天 02:59:59'), findsOneWidget);

      await tester.tap(_key('launch2-row-$l2InstanceB'));
      expect(opened.single, '/launch2/instance?id=$l2InstanceB');
      await _drain(tester);
    });

    testWidgets('a countdown that reaches zero re-reads the list', (
      tester,
    ) async {
      final clock = _Clock();
      final launch2 = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          l2Page(<Map<String, Object?>>[
            l2RowJson(
              stage: 'upcoming',
              nextChangeAt: l2Now.add(const Duration(seconds: 2)),
            ),
          ]),
        ),
      );
      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: (_) {}),
        launch2: launch2,
        clock: clock,
      );
      expect(launch2.listCalls, hasLength(1));
      clock.now = l2Now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(launch2.listCalls.length, greaterThan(1));
      await _drain(tester);
    });

    testWidgets('scrolling to the end reads the next page; empty, failed and '
        'closed lists say so', (tester) async {
      final launch2 = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          cursor == null
              ? l2Page(<Map<String, Object?>>[l2RowJson()], next: 'abc.def')
              : l2Page(<Map<String, Object?>>[
                  l2RowJson(instanceId: l2InstanceB),
                ]),
        ),
      );
      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: (_) {}),
        launch2: launch2,
      );
      expect(launch2.listCalls, contains((null, 'abc.def')));
      expect(_key('launch2-row-$l2InstanceB'), findsOneWidget);
      expect(find.text('没有更多'), findsNothing);
      await _drain(tester);

      final empty = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          l2Page(const <Map<String, Object?>>[]),
        ),
      );
      var acted = false;
      await _pump(
        tester,
        Launch2ListSegment(
          scope: Launch2ListScope.all,
          onNavigate: (_) {},
          onEmptyAction: () => acted = true,
        ),
        launch2: empty,
      );
      expect(_key('launch2-list-all-empty'), findsOneWidget);
      expect(_key('loop-empty-illustration-launchpad'), findsOneWidget);
      await tester.tap(_key('launch2-list-all-empty-action'));
      expect(acted, isTrue);
      await _drain(tester);

      final offline = _FakeLaunch2(
        list: (stage, cursor) => const _Answer<Launch2InstancePage>.fail(
          LoopChainFailureKind.offline,
        ),
      );
      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: (_) {}),
        launch2: offline,
      );
      expect(_key('launch2-list-all-state-offline'), findsOneWidget);
      await _drain(tester);

      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: (_) {}),
        launch2: _FakeLaunch2(),
        meta: _meta(launch2: LoopV2CapabilityAvailability.unavailable),
      );
      expect(_key('launch2-list-all-unavailable'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('project page · six stages', () {
    Future<void> open(
      WidgetTester tester,
      Launch2InstanceDetail detail, {
      _FakeLaunch2? gateway,
      _RecordingWallet? wallet,
      _Clock? clock,
    }) => _pump(
      tester,
      const Launch2InstanceScreen(instanceId: l2InstanceA),
      launch2:
          gateway ??
          _FakeLaunch2(
            details: <_Answer<Launch2InstanceDetail>>[
              _Answer<Launch2InstanceDetail>.value(detail),
            ],
            buybacks: _Answer<Launch2BuybackPage>.value(l2Buybacks()),
          ),
      wallet: wallet,
      clock: clock,
    );

    testWidgets('upcoming: 开售时间, countdown and the template behind (i)', (
      tester,
    ) async {
      await open(tester, l2Detail(stage: 'upcoming'));
      expect(_key('launch2-stage-upcoming'), findsOneWidget);
      expect(_key('launch2-stage-label'), findsOneWidget);
      expect(find.text('即将开售'), findsOneWidget);
      expect(_key('launch2-countdown'), findsOneWidget);
      expect(find.text('开售时间'), findsOneWidget);
      expect(_key('launch2-template'), findsOneWidget);
      await tester.tap(_key('launch2-template-info'));
      await tester.pumpAndSettle();
      expect(find.text('由平台模板固定'), findsOneWidget);
      expect(find.textContaining(launch2NftRiskSentence), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('nft_sale: 100 USD1, 0/1, 已售 and 购买 NFT', (tester) async {
      await open(tester, l2Detail());
      expect(_key('launch2-stage-nft_sale'), findsOneWidget);
      expect(find.text('100 USD1'), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('2 枚'), findsOneWidget);
      expect(_key('launch2-buy-nft'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets(
      'snapshot_pending: the line illustration and the cutoff block',
      (tester) async {
        await open(
          tester,
          l2Detail(
            stage: 'snapshot_pending',
            noNextChange: true,
            cutoffBlock: '1234',
          ),
        );
        expect(_key('launch2-snapshot-pending'), findsOneWidget);
        expect(_key('loop-empty-illustration-holders'), findsOneWidget);
        expect(find.text('截止块 #1,234，名单发布后开始 1 小时提前购'), findsOneWidget);
        expect(_key('launch2-countdown'), findsNothing);
        await _drain(tester);
      },
    );

    testWidgets(
      'priority / public: curve, panel with MAX, quota bar, 10% tax',
      (tester) async {
        await open(
          tester,
          l2Detail(
            stage: 'public',
            noNextChange: true,
            viewer: l2ViewerJson(
              member: true,
              eligibleNow: true,
              bought: '1000',
            ),
            trades: <Map<String, Object?>>[l2TradeJson()],
          ),
        );
        expect(_key('launch2-stage-public'), findsOneWidget);
        expect(_key('launch2-curve'), findsOneWidget);
        expect(_key('launch2-trade-panel'), findsOneWidget);
        expect(_key('launch2-trade-max'), findsOneWidget);
        expect(find.text('1,000 / 5,000,000'), findsOneWidget);
        expect(find.text('税率 10%'), findsOneWidget);
        // Selling opens only in the public round.
        expect(_key('launch2-trade-side'), findsOneWidget);
        expect(_key('launch2-eligibility-badge'), findsNothing);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await _scrollTo(tester, _key('launch2-trade-t-1'));
        expect(_key('launch2-trade-t-1'), findsOneWidget);
        await _drain(tester);
      },
    );

    testWidgets('graduated: pool behind (i), 去外盘交易 pre-fills the swap, '
        'buyback panel', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        Launch2InstanceScreen(instanceId: l2InstanceA, onNavigate: opened.add),
        launch2: _FakeLaunch2(
          details: <_Answer<Launch2InstanceDetail>>[
            _Answer<Launch2InstanceDetail>.value(
              l2Detail(stage: 'graduated', noNextChange: true),
            ),
          ],
          buybacks: _Answer<Launch2BuybackPage>.value(l2Buybacks()),
        ),
      );
      expect(_key('launch2-stage-graduated'), findsOneWidget);
      await tester.tap(_key('launch2-go-swap'));
      expect(opened.single, '/wallet/swap?to=eip155%3A97%3A$l2Meme');
      await tester.tap(_key('launch2-pool-info'));
      await tester.pumpAndSettle();
      expect(find.text(l2PoolId), findsOneWidget);
      expect(_key('launch2-pool-tax'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch2-buyback-next'));
      expect(find.text('100 USD1'), findsWidgets);
      expect(find.text('价格保护生效，暂不执行'), findsOneWidget);
      expect(find.textContaining('100 USD1 · 1 笔'), findsOneWidget);
      await tester.tap(_key('launch2-buyback-info'));
      await tester.pumpAndSettle();
      expect(find.text('回购不等于销毁'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('paused: the whole page grey with the server reason, no bar', (
      tester,
    ) async {
      await open(
        tester,
        l2Detail(
          stage: 'paused',
          noNextChange: true,
          holdReason: 'LAUNCH2_ACTIVATION_MISSING',
        ),
      );
      expect(_key('launch2-paused-reason'), findsOneWidget);
      expect(find.text('链上还没有看到激活记录，平台正在核对'), findsOneWidget);
      expect(_key('launch2-paused-body'), findsOneWidget);
      expect(_key('launch2-buy-nft'), findsNothing);
      expect(_key('launch2-go-swap'), findsNothing);
      await _drain(tester);
    });

    testWidgets('the project owner sees one line', (tester) async {
      await open(tester, l2Detail(owner: true));
      expect(_key('launch2-owner-strip'), findsOneWidget);
      expect(find.text('你是项目方'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a stage change re-renders in place with a 150 ms fade', (
      tester,
    ) async {
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(l2Detail()),
          _Answer<Launch2InstanceDetail>.value(
            l2Detail(stage: 'snapshot_pending', noNextChange: true),
          ),
        ],
      );
      await open(tester, l2Detail(), gateway: gateway);
      expect(_key('launch2-stage-nft_sale'), findsOneWidget);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 900),
        1000,
      );
      await tester.pumpAndSettle();
      expect(gateway.detailReads, greaterThan(1));
      expect(_key('launch2-stage-snapshot_pending'), findsOneWidget);
      expect(_key('launch2-stage-nft_sale'), findsNothing);
      final fade = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(fade.duration, const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await _drain(tester);
    });
  });

  group('project page · five states', () {
    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.offline, 'launch2-instance-state-offline'),
      (LoopChainFailureKind.readFailed, 'launch2-instance-state-error'),
      (
        LoopChainFailureKind.permissionDenied,
        'launch2-instance-state-permission',
      ),
      (LoopChainFailureKind.unavailable, 'launch2-instance-state-unavailable'),
    ]) {
      testWidgets('${kind.name} is its own state', (tester) async {
        await _pump(
          tester,
          const Launch2InstanceScreen(instanceId: l2InstanceA),
          launch2: _FakeLaunch2(
            details: <_Answer<Launch2InstanceDetail>>[
              _Answer<Launch2InstanceDetail>.fail(kind),
            ],
          ),
        );
        expect(_key(key), findsOneWidget);
        await _drain(tester);
      });
    }

    testWidgets('loading draws the skeleton; a bad id and a closed capability '
        'request nothing', (tester) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: _FakeLaunch2(
          details: <_Answer<Launch2InstanceDetail>>[
            const _Answer<Launch2InstanceDetail>.pending(),
          ],
        ),
        settle: false,
      );
      expect(_key('launch2-instance-state-loading'), findsOneWidget);
      await _drain(tester);

      final idle = _FakeLaunch2();
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: 'nope'),
        launch2: idle,
      );
      expect(_key('launch2-invalid-identity'), findsOneWidget);
      await _drain(tester);

      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: idle,
        meta: _meta(launch2: LoopV2CapabilityAvailability.unavailable),
      );
      expect(_key('launch2-instance-blocked'), findsOneWidget);
      expect(idle.detailReads, 0);
      await _drain(tester);
    });
  });

  group('NFT purchase', () {
    testWidgets('the sheet states the full sentence and waits for the tick; '
        'approve then mint go through the signing exit', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(l2Detail()),
        ],
        nftAnswer: _Answer<Launch2Intent>.value(l2Intent()),
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: gateway,
        wallet: wallet,
      );
      await tester.tap(_key('launch2-buy-nft'));
      await tester.pumpAndSettle();
      expect(_key('launch2-nft-confirm'), findsOneWidget);
      expect(find.text('我已知晓：不保证成交、不保证配售，公开内盘可能不发生。'), findsOneWidget);
      final button = _key('launch2-nft-confirm-button');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(gateway.nftCalls, 0);
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(gateway.nftCalls, 1);
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed, hasLength(2));
      expect(wallet.handed.first.kind, IntentKind.launchApproval);
      expect(wallet.handed.last.kind, IntentKind.launchPurchase);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(_key('launch2-pending'), findsOneWidget);
      expect(find.textContaining('已广播'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('gas short: the server rule in one line, nothing signed', (
      tester,
    ) async {
      final wallet = _RecordingWallet();
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(l2Detail()),
        ],
        nftAnswer: const _Answer<Launch2Intent>.fail(
          LoopChainFailureKind.insufficientBalance,
          reasonCode: 'LAUNCH2_GAS_INSUFFICIENT',
        ),
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: gateway,
        wallet: wallet,
      );
      await tester.tap(_key('launch2-buy-nft'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      expect(_key('launch2-action-failed'), findsOneWidget);
      expect(find.textContaining('tBNB 手续费不足'), findsOneWidget);
      expect(wallet.handed, isEmpty);
      await _drain(tester);
    });

    testWidgets('a wallet that already holds one cannot buy again', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: _FakeLaunch2(
          details: <_Answer<Launch2InstanceDetail>>[
            _Answer<Launch2InstanceDetail>.value(
              l2Detail(viewer: l2ViewerJson(held: 1)),
            ),
          ],
        ),
      );
      expect(find.text('已持有 NFT'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('trade panel', () {
    Future<_FakeLaunch2> openPriority(
      WidgetTester tester, {
      required List<_Answer<Launch2Quote>> quotes,
      List<_Answer<Launch2Intent>> trades = const <_Answer<Launch2Intent>>[],
      bool member = true,
      _RecordingWallet? wallet,
    }) async {
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(
            l2Detail(
              stage: 'priority',
              viewer: l2ViewerJson(member: member, eligibleNow: member),
            ),
          ),
        ],
        quotes: quotes,
        tradeAnswers: trades,
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: gateway,
        wallet: wallet,
      );
      return gateway;
    }

    testWidgets('MAX asks the server and fills its executable maximum', (
      tester,
    ) async {
      final gateway = await openPriority(
        tester,
        quotes: <_Answer<Launch2Quote>>[
          _Answer<Launch2Quote>.value(l2Quote(requested: '1', amountIn: '1')),
          _Answer<Launch2Quote>.value(
            l2Quote(requested: '185185.18', amountIn: '185185.18'),
          ),
        ],
      );
      expect(find.text('名单内'), findsOneWidget);
      await tester.tap(_key('launch2-trade-max'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls.first.$2, Decimal.one);
      final field = tester.widget<TextField>(_key('launch2-trade-amount'));
      expect(field.controller!.text, '185185.18');
      expect(gateway.quoteCalls.last.$2, Decimal.parse('185185.18'));
      await _drain(tester);
    });

    testWidgets('an amount above MAX says so and fills MAX in one tap', (
      tester,
    ) async {
      final gateway = await openPriority(
        tester,
        quotes: <_Answer<Launch2Quote>>[
          _Answer<Launch2Quote>.value(
            l2Quote(
              exceedsMax: true,
              requested: '1000000',
              amountIn: '185185.18',
            ),
          ),
          _Answer<Launch2Quote>.value(
            l2Quote(requested: '185185.18', amountIn: '185185.18'),
          ),
        ],
      );
      await tester.enterText(_key('launch2-trade-amount'), '1000000');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_key('launch2-trade-exceeds'), findsOneWidget);
      expect(find.textContaining('超出可买上限'), findsOneWidget);
      final confirm = tester.widget<Widget>(_key('launch2-trade-confirm'));
      expect((confirm as dynamic).onPressed, isNull);
      await tester.tap(_key('launch2-trade-fill-max'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_key('launch2-trade-amount'));
      expect(field.controller!.text, '185185.18');
      expect(gateway.quoteCalls.last.$2, Decimal.parse('185185.18'));
      expect(_key('launch2-trade-exceeds'), findsNothing);
      await _drain(tester);
    });

    testWidgets('outside the holder list the priority panel is greyed with '
        'the reason', (tester) async {
      final gateway = await openPriority(
        tester,
        quotes: <_Answer<Launch2Quote>>[_Answer<Launch2Quote>.value(l2Quote())],
        member: false,
      );
      expect(find.text('不在名单'), findsOneWidget);
      expect(_key('launch2-trade-blocked'), findsOneWidget);
      expect(find.text('提前购仅限名单内持有人，公开内盘开始后可买入'), findsOneWidget);
      final controls = tester.widget<Launch2Greyed>(
        _key('launch2-trade-controls'),
      );
      expect(controls.greyed, isTrue);
      await tester.tap(_key('launch2-trade-max'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('a price moved under the quote: one line, a fresh quote, no '
        'toast', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = await openPriority(
        tester,
        wallet: wallet,
        quotes: <_Answer<Launch2Quote>>[
          _Answer<Launch2Quote>.value(l2Quote()),
          _Answer<Launch2Quote>.value(l2Quote()),
        ],
        trades: <_Answer<Launch2Intent>>[
          const _Answer<Launch2Intent>.fail(
            LoopChainFailureKind.versionConflict,
            reasonCode: 'LAUNCH2_PRICE_MOVED',
          ),
          _Answer<Launch2Intent>.value(l2Intent(kind: 'buy', approval: false)),
        ],
      );
      await tester.enterText(_key('launch2-trade-amount'), '50');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls, hasLength(1));
      await tester.tap(_key('launch2-trade-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.tradeCalls, hasLength(1));
      expect(gateway.tradeCalls.single['amount'], Decimal.fromInt(50));
      expect(gateway.tradeCalls.single['minOut'], Decimal.parse('1113750.495'));
      expect(_key('launch2-trade-notice'), findsOneWidget);
      expect(find.text('价格已变化，已刷新'), findsOneWidget);
      expect(gateway.quoteCalls, hasLength(2));
      expect(_key('launch2-sign-sheet'), findsNothing);

      // The fresh quote goes through to the signing exit.
      await tester.tap(_key('launch2-trade-confirm'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.single.kind, IntentKind.launchPurchase);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await _drain(tester);
    });

    testWidgets('an expired quote re-quotes silently', (tester) async {
      final gateway = await openPriority(
        tester,
        quotes: <_Answer<Launch2Quote>>[
          _Answer<Launch2Quote>.value(l2Quote()),
          _Answer<Launch2Quote>.value(l2Quote()),
        ],
        trades: <_Answer<Launch2Intent>>[
          const _Answer<Launch2Intent>.fail(
            LoopChainFailureKind.quoteExpired,
            reasonCode: 'LAUNCH2_QUOTE_EXPIRED',
          ),
        ],
      );
      await tester.enterText(_key('launch2-trade-amount'), '50');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-trade-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls, hasLength(2));
      expect(_key('launch2-trade-notice'), findsNothing);
      expect(_key('launch2-trade-prepare-failed'), findsNothing);
      await _drain(tester);
    });
  });

  group('wallet rows', () {
    testWidgets('one row for the curve holding and one for the NFT', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[
              Launch2WalletRows(onOpen: opened.add, hidden: false),
            ],
          ),
        ),
        launch2: _FakeLaunch2(
          positions: _Answer<Launch2Positions>.value(l2Positions()),
        ),
      );
      expect(_key('launch2-wallet-meme-$l2InstanceA'), findsOneWidget);
      expect(_key('launch2-wallet-nft-$l2InstanceA'), findsOneWidget);
      expect(find.text('1,125,000.5'), findsOneWidget);
      expect(find.text('项目 NFT #1'), findsOneWidget);
      await tester.tap(_key('launch2-wallet-nft-$l2InstanceA'));
      expect(opened.single, '/launch2/instance?id=$l2InstanceA');
      await _drain(tester);
    });

    testWidgets('the switch off draws nothing and reads nothing', (
      tester,
    ) async {
      final gateway = _FakeLaunch2(
        positions: _Answer<Launch2Positions>.value(l2Positions()),
      );
      await _pump(
        tester,
        Scaffold(body: Launch2WalletRows(onOpen: (_) {}, hidden: false)),
        launch2: gateway,
        switchOn: false,
      );
      expect(_key('launch2-wallet-rows'), findsNothing);
      await _drain(tester);
    });
  });

  test('the signing exit refuses a tampered or foreign intent before any '
      'wallet', () {
    final tampered = l2IntentJson();
    ((tampered['launch2Intent']! as Map<String, Object?>)['approval']!
            as Map<String, Object?>)['spender'] =
        '0x9999999999999999999999999999999999999999';
    expect(
      Launch2IntentSigner.refusalBeforeWallet(
        LoopV2Launch2Codec.intent(tampered),
        fromAddress: l2WalletAddress,
        now: l2Now,
      ),
      'REVIEW_PAYLOAD_MISMATCH',
    );
    expect(
      Launch2IntentSigner.refusalBeforeWallet(
        l2Intent(),
        fromAddress: '0x000000000000000000000000000000000000000b',
        now: l2Now,
      ),
      'LAUNCH2_WALLET_ADDRESS_MISMATCH',
    );
    expect(
      Launch2IntentSigner.refusalBeforeWallet(
        l2Intent(),
        fromAddress: l2WalletAddress,
        now: l2Now.add(const Duration(hours: 1)),
      ),
      'INTENT_EXPIRED',
    );
  });

  // -------------------------------------------------------------------------
  // S142 · decision 0142: the terminal stage `closed_no_holders`
  // (loop-api decision 0120, `snapshot.closure`).
  // -------------------------------------------------------------------------
  group('S142 · closed_no_holders', () {
    Object? decode(Map<String, Object?> json) =>
        LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null);
    Map<String, Object?> snapshotOf(Map<String, Object?> json) =>
        (json['instance']! as Map<String, Object?>)['snapshot']!
            as Map<String, Object?>;

    test('the closure is read; it and the stage arrive together', () {
      final detail = l2Detail(stage: 'closed_no_holders', cutoffBlock: '1234');
      expect(detail.stage, Launch2Stage.closedNoHolders);
      expect(detail.stage.terminal, isTrue);
      expect(detail.stage.tradable, isFalse);
      expect(detail.row.nextChangeAt, isNull);
      expect(detail.snapshot.closure?.cutoffBlock, BigInt.from(1234));
      expect(
        detail.snapshot.closure?.closedAt,
        DateTime.utc(2027, 1, 23, 7, 2),
      );
      expect(detail.snapshot.publication, isNull);

      // `closure` is a required key (null outside the closed stage).
      final missing = l2DetailJson();
      snapshotOf(missing).remove('closure');
      expect(() => decode(missing), throwsA(isA<LoopBackendFailure>()));
      // The closed stage without its closure.
      final bare = l2DetailJson(stage: 'closed_no_holders');
      snapshotOf(bare)['closure'] = null;
      expect(() => decode(bare), throwsA(isA<LoopBackendFailure>()));
      // A closure under a stage that is not closed (or held).
      final stray = l2DetailJson(stage: 'nft_sale');
      snapshotOf(stray)['closure'] = <String, Object?>{
        'reason': 'no_holders',
        'cutoffBlock': '1',
        'closedAt': '2027-01-23T07:02:00.000Z',
      };
      expect(() => decode(stray), throwsA(isA<LoopBackendFailure>()));
      // An unknown reason, and a terminal stage that still counts down.
      final reason = l2DetailJson(stage: 'closed_no_holders');
      (snapshotOf(reason)['closure']! as Map<String, Object?>)['reason'] =
          'refunded';
      expect(() => decode(reason), throwsA(isA<LoopBackendFailure>()));
      final ticking = l2DetailJson(stage: 'closed_no_holders');
      (ticking['instance']! as Map<String, Object?>)['nextChangeAt'] =
          '2027-01-24T07:00:00.000Z';
      expect(() => decode(ticking), throwsA(isA<LoopBackendFailure>()));
    });

    testWidgets('the page: 无人认购，已关闭, grey, the cutoff block and the '
        'closing time, no bar, no panel, no polling', (tester) async {
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(
            l2Detail(stage: 'closed_no_holders', cutoffBlock: '1234'),
          ),
        ],
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: gateway,
      );
      expect(_key('launch2-stage-closed_no_holders'), findsOneWidget);
      expect(find.text('已关闭'), findsOneWidget);
      expect(find.text('无人认购，已关闭'), findsWidgets);
      expect(_key('launch2-closed-no-holders'), findsOneWidget);
      expect(find.text('#1,234'), findsOneWidget);
      expect(find.text('关闭时间'), findsOneWidget);
      expect(_key('launch2-countdown'), findsNothing);
      expect(_key('launch2-buy-nft'), findsNothing);
      expect(_key('launch2-trade-amount'), findsNothing);
      expect(_key('launch2-go-swap'), findsNothing);
      // Terminal: the page does not keep re-reading it.
      final reads = gateway.detailReads;
      await tester.pump(const Duration(hours: 2));
      expect(gateway.detailReads, reads);
      await _drain(tester);
    });

    testWidgets('the v2 list sinks closed rows below every other row; the '
        'row is grey and says 无人认购，已关闭', (tester) async {
      const closedId = '1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d';
      final launch2 = _FakeLaunch2(
        list: (stage, cursor) => _Answer<Launch2InstancePage>.value(
          l2Page(<Map<String, Object?>>[
            l2RowJson(instanceId: closedId, stage: 'closed_no_holders'),
            l2RowJson(instanceId: l2InstanceA, stage: 'nft_sale'),
            l2RowJson(
              instanceId: l2InstanceB,
              stage: 'graduated',
              noNextChange: true,
            ),
          ]),
        ),
      );
      await _pump(
        tester,
        Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: (_) {}),
        launch2: launch2,
      );
      final closedTop = tester.getTopLeft(_key('launch2-row-$closedId')).dy;
      expect(
        tester.getTopLeft(_key('launch2-row-$l2InstanceA')).dy,
        lessThan(closedTop),
      );
      expect(
        tester.getTopLeft(_key('launch2-row-$l2InstanceB')).dy,
        lessThan(closedTop),
      );
      expect(_key('launch2-row-closed'), findsOneWidget);
      expect(_key('launch2-stage-pill-closed_no_holders'), findsOneWidget);
      expect(
        launch2ListOrder(
          l2Page(<Map<String, Object?>>[
            l2RowJson(instanceId: closedId, stage: 'closed_no_holders'),
            l2RowJson(instanceId: l2InstanceA, stage: 'public'),
          ]).items,
        ).map((row) => row.instanceId),
        <String>[l2InstanceA, closedId],
      );
      await _drain(tester);
    });

    testWidgets('a quote answering 409 LAUNCH2_STAGE_MISMATCH stays one line '
        'in the panel and re-reads the detail; no error page', (tester) async {
      final gateway = _FakeLaunch2(
        details: <_Answer<Launch2InstanceDetail>>[
          _Answer<Launch2InstanceDetail>.value(l2Detail(stage: 'public')),
        ],
        quotes: <_Answer<Launch2Quote>>[
          const _Answer<Launch2Quote>.fail(
            LoopChainFailureKind.versionConflict,
            reasonCode: 'LAUNCH2_STAGE_MISMATCH',
          ),
        ],
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        launch2: gateway,
      );
      final reads = gateway.detailReads;
      await tester.enterText(_key('launch2-trade-amount'), '50');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls, hasLength(1));
      expect(gateway.detailReads, greaterThan(reads));
      expect(_key('launch2-trade-quote-failed'), findsOneWidget);
      expect(find.textContaining('当前阶段不能交易，已重新读取项目状态'), findsOneWidget);
      expect(_key('launch2-instance-state-error'), findsNothing);
      expect(_key('launch2-stage-public'), findsOneWidget);
      await _drain(tester);
    });
  });
}
