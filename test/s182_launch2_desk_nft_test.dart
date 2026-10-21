// S182 · 发射台 as the prototype's Launch Desk, and 共识勋章 in the same
// parts (client decision 0164; data since 0163, docs/32).
//
// The desk picks its main event from the list rows already read; the NFT
// page reads the project page's own instance read and mints through the
// project page's own trip (`launch2MintNft`). The samples are the S136
// fixtures; `summary` and `links` (loop-api S180) are added by hand.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

/// Distinct instance ids for the hero rows (UUIDv4 shape).
String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

String _iso(DateTime value) => value.toUtc().toIso8601String();

/// One list row; [startIn] moves the NFT sale's start (and end) relative to
/// the test clock.
Map<String, Object?> _rowJson(
  int n,
  String stage, {
  int soldBps = 0,
  Duration? startIn,
  Duration? nextIn,
  String ticker = 'FROG',
  String name = 'Frog Launch',
}) {
  final row = l2RowJson(
    instanceId: _id(n),
    stage: stage,
    soldBps: soldBps,
    ticker: ticker,
    name: name,
    nextChangeAt: nextIn == null ? null : l2Now.add(nextIn),
    noNextChange: stage == 'public' || stage == 'graduated',
  );
  if (startIn != null) {
    final start = l2Now.add(startIn);
    row['nftSale'] = <String, Object?>{
      ...(row['nftSale']! as Map<String, Object?>),
      'startAt': _iso(start),
      'endAt': _iso(start.add(const Duration(days: 7))),
    };
    if (stage == 'upcoming') row['nextChangeAt'] = _iso(start);
  }
  return row;
}

List<Launch2InstanceRow> _rows(List<Map<String, Object?>> rows) =>
    l2Page(rows).items;

/// A detail body with [mutate] applied to its `instance`.
Launch2InstanceDetail _detail({
  String stage = 'nft_sale',
  Map<String, Object?>? viewer,
  bool noViewer = false,
  bool openedWithoutHolders = false,
  Object? tradingHold,
  String? summary,
  String? tokenId,
  String ticker = 'FROG',
  String name = 'Frog Launch',
}) {
  final body = l2DetailJson(
    stage: stage,
    viewer: viewer,
    noViewer: noViewer,
    openedWithoutHolders: openedWithoutHolders,
    noNextChange: stage == 'public' || stage == 'graduated',
  );
  final instance = body['instance']! as Map<String, Object?>;
  instance['ticker'] = ticker;
  instance['name'] = name;
  if (tradingHold != null) instance['tradingHold'] = tradingHold;
  if (summary != null) {
    instance['summary'] = summary;
    instance['links'] = <String>['https://x.com/frog'];
  }
  if (tokenId != null) {
    final view = instance['viewer']! as Map<String, Object?>;
    view['nft'] = <String, Object?>{'mintedTokenId': tokenId, 'held': 1};
  }
  return LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null);
}

final class _Fake implements Launch2Gateway {
  // S267 (decision 0227): no K line in these fixtures; the card hides.
  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) => Future<Launch2CandleSeries>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  _Fake({
    this.page,
    List<Launch2InstanceDetail>? details,
    this.intent,
    this.nftError,
  }) : details = details ?? <Launch2InstanceDetail>[];

  final Launch2InstancePage? page;

  /// The detail reads, in order; the last one repeats.
  final List<Launch2InstanceDetail> details;
  final Launch2Intent? intent;

  /// Decision 0201: what prepareNftMint refuses with, when set.
  final LoopChainException? nftError;
  int detailReads = 0;
  int listReads = 0;
  int nftCalls = 0;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) {
    listReads += 1;
    return page == null
        ? _unavailable()
        : Future<Launch2InstancePage>.value(page);
  }

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    if (details.isEmpty) return _unavailable();
    final index = detailReads < details.length
        ? detailReads
        : details.length - 1;
    detailReads += 1;
    return Future<Launch2InstanceDetail>.value(details[index]);
  }

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) {
    nftCalls += 1;
    final error = nftError;
    if (error != null) return Future<Launch2Intent>.error(error);
    final value = intent;
    return value == null ? _unavailable() : Future<Launch2Intent>.value(value);
  }

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
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
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) =>
      Future<Launch2BuybackPage>.value(l2Buybacks());

  @override
  Future<Launch2Positions> loadPositions() => _unavailable();

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
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
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

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: l2WalletId,
  address: l2WalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  _Fake gateway, {
  WalletSigningGateway? wallet,
  bool noWallet = false,
  Size size = const Size(390, 2600),
  Launch2OverviewGateway? overview,
  bool settle = true,
  bool reduceMotion = false,
  DateTime Function()? clock,
  Launch2Polling? polling,
  List<Override> extra = const <Override>[],
  bool ambientMotion = false,
}) => pumpS7Page(
  tester,
  ambientMotion: ambientMotion,
  reduceMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: page,
          ),
        )
      : page,
  meta: _meta(),
  size: size,
  settle: settle,
  wallet: noWallet
      ? FakeWalletDirectory()
      : FakeWalletDirectory(
          activeWalletId: l2WalletId,
          wallets: <LoopWalletAccount>[_wallet()],
        ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(gateway),
    launch2ClockProvider.overrideWithValue(clock ?? () => l2Now),
    launch2PollingProvider.overrideWithValue(
      polling ??
          const Launch2Polling(
            detailInterval: Duration(hours: 1),
            tradingInterval: Duration(hours: 1),
            listInterval: Duration(hours: 1),
            snapshotInterval: Duration(hours: 1),
          ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
    if (overview != null)
      launch2OverviewGatewayProvider.overrideWithValue(overview),
    ...extra,
  ],
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Widget _list(
  List<String> opened, {
  Launch2ListScope scope = Launch2ListScope.all,
  VoidCallback? onOpenGraduated,
}) => Scaffold(
  body: Launch2ListSegment(
    scope: scope,
    onNavigate: opened.add,
    onOpenGraduated: onOpenGraduated,
  ),
);

_Fake _listGateway(List<Map<String, Object?>> rows) =>
    _Fake(page: l2Page(rows));

LoopButton _button(WidgetTester tester) =>
    tester.widget<LoopButton>(_key('launch2-nft-mint'));

Launch2NftMedal _medal(WidgetTester tester) =>
    tester.widget<Launch2NftMedal>(_key('launch2-nft-medal'));

/// The ledger card under [key].
/// The words of the desk page under [key] (decision 0223: every page stands
/// on the banner art, so the event's words are no longer a folio).
Launch2DeskEventFace _desk(WidgetTester tester, String key) =>
    tester.widget<Launch2DeskEventFace>(
      find.descendant(
        of: _key(key),
        matching: find.byType(Launch2DeskEventFace),
      ),
    );

LoopFolioPrimary _folio(WidgetTester tester, String key) =>
    tester.widget<LoopFolioPrimary>(
      find.descendant(of: _key(key), matching: find.byType(LoopFolioPrimary)),
    );

/// The 共识勋章 card's caption and stamp, as one line.
String _statusText(WidgetTester tester) {
  final folio = _folio(tester, 'launch2-nft-status');
  return <String>[?folio.caption, ?folio.stamp].join(' | ');
}

/// Whether the desk's stage chip [id] says it is on (S264).
bool _chipSelected(WidgetTester tester, String id) =>
    tester
        .widget<Semantics>(
          find
              .ancestor(
                of: _key('launch2-desk-seg-$id'),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .selected ??
    false;

void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  loopWatchGround();

  group('desk · the main event and its order', () {
    test('activities first (NFT sale, early round, curve ≥ 70 %), previews '
        'after them nearest first; everything else stays out', () {
      final rows = _rows(<Map<String, Object?>>[
        _rowJson(1, 'upcoming', startIn: const Duration(days: 3)),
        _rowJson(2, 'public', soldBps: 8200),
        _rowJson(3, 'graduated'),
        _rowJson(4, 'priority', nextIn: const Duration(minutes: 40)),
        _rowJson(5, 'public', soldBps: 6999),
        _rowJson(6, 'nft_sale'),
        _rowJson(7, 'upcoming', startIn: const Duration(hours: 5)),
        _rowJson(8, 'snapshot_pending', nextIn: const Duration(hours: 1)),
        _rowJson(9, 'public', soldBps: 7000),
      ]);
      final hero = launch2HeroRows(rows);
      expect(hero.map((row) => row.instanceId), <String>[
        _id(6),
        _id(4),
        _id(2),
        _id(9),
        _id(7),
      ]);
      // The record cards: the main event and the next one open now.
      expect(launch2DeskRecordRows(hero).map((row) => row.instanceId), <String>[
        _id(6),
        _id(4),
      ]);
    });

    test('at most five; NFT sales ending soonest lead', () {
      final rows = _rows(<Map<String, Object?>>[
        for (var i = 1; i <= 7; i++)
          _rowJson(i, 'nft_sale', nextIn: Duration(hours: 10 - i)),
      ]);
      final hero = launch2HeroRows(rows);
      expect(hero, hasLength(launch2HeroLimit));
      expect(hero.first.instanceId, _id(7));
      expect(hero.last.instanceId, _id(3));
    });

    test('previews alone still make a main event, nearest sale first; a '
        'second preview earns no record card', () {
      final rows = _rows(<Map<String, Object?>>[
        _rowJson(1, 'upcoming', startIn: const Duration(days: 2)),
        _rowJson(2, 'upcoming', startIn: const Duration(hours: 2)),
      ]);
      final hero = launch2HeroRows(rows);
      expect(hero.map((row) => row.instanceId), <String>[_id(2), _id(1)]);
      expect(launch2DeskRecordRows(hero).map((row) => row.instanceId), <String>[
        _id(2),
      ]);
    });

    testWidgets('no qualifying row: the empty desk, no stamp, no record card', (
      tester,
    ) async {
      final opened = <String>[];
      final rows = <Map<String, Object?>>[
        _rowJson(1, 'graduated'),
        _rowJson(2, 'public', soldBps: 5000),
        _rowJson(3, 'snapshot_pending', nextIn: const Duration(hours: 1)),
      ];
      await _pump(tester, _list(opened), _listGateway(rows));
      final folio = _desk(tester, 'launch2-desk');
      expect(folio.heading, '暂无进行中的发射');
      expect(folio.caption, 'NFT 预售开始后会出现在这里');
      expect(folio.stamp, isNull);
      // Decision 0223: the empty desk stands on the banner art too.
      expect(
        find.descendant(
          of: _key('launch2-desk'),
          matching: find.byType(Launch2BannerBackdrop),
        ),
        findsOneWidget,
      );
      expect(find.byType(Launch2DeskRecordCard), findsNothing);
      expect(_key('launch2-tile-${_id(1)}'), findsOneWidget);
      expect(_key('launch2-tile-${_id(2)}'), findsOneWidget);
      await tester.tap(_key('launch2-desk'));
      await tester.pump();
      expect(opened, isEmpty);
      await _drain(tester);
    });

    testWidgets('the 已毕业 list draws no desk whatever it holds', (tester) async {
      final rows = <Map<String, Object?>>[_rowJson(1, 'nft_sale')];
      await _pump(
        tester,
        _list(<String>[], scope: Launch2ListScope.graduated),
        _listGateway(rows),
        overview: _FakeOverview(<Map<String, Object?>>[_overviewJson()]),
      );
      expect(_key('launch2-desk'), findsNothing);
      expect(_key('launch2-desk-segs'), findsNothing);
      expect(find.byType(Launch2DeskRecordCard), findsNothing);
      expect(_key('launch2-tape'), findsNothing);
      expect(_key('launch2-stats'), findsNothing);
      expect(_key('launch2-curation-notice'), findsNothing);
      expect(_key('launch2-group-minting'), findsNothing);
      expect(_key('launch2-tile-${_id(1)}'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('desk · the ledger card per stage', () {
    final rows = _rows(<Map<String, Object?>>[
      _rowJson(1, 'upcoming', startIn: const Duration(days: 2, hours: 3)),
      _rowJson(2, 'nft_sale'),
      _rowJson(4, 'priority', soldBps: 3500),
      _rowJson(5, 'public', soldBps: 8000),
    ]);
    Launch2InstanceRow at(int n) =>
        rows.firstWhere((row) => row.instanceId == _id(n));

    test('nft_sale: 共识勋章铸造中, minted, price and the list rule', () {
      final row = at(2);
      expect(launch2DeskStatus(row), '共识勋章铸造中');
      expect(
        launch2DeskCaption(row),
        '已铸 2 枚 · 100 USD1 / 枚。持有即进快照名单，名单发布后 1 小时提前购。',
      );
      expect(launch2DeskStampPrefix(row.stage), '剩 ');
      expect(launch2HeroLocation(row), Launch2Route.nft(_id(2)));
    });

    test('priority: 提前购进行中, minted, sold share and price', () {
      final row = at(4);
      expect(launch2DeskStatus(row), '提前购进行中');
      expect(launch2DeskCaption(row), '已铸 2 枚 · 内盘已售 35% · 0.0₄4167 USD1');
      expect(launch2DeskStampPrefix(row.stage), '剩 ');
      expect(launch2HeroLocation(row), Launch2Route.instance(_id(4)));
    });

    test('public ≥ 70 %: 内盘冲刺 80%, price and 卖满 8 亿自动毕业', () {
      final row = at(5);
      expect(launch2DeskStatus(row), '内盘冲刺 80%');
      expect(launch2DeskCaption(row), '0.0₄4167 USD1 · 卖满 8 亿自动毕业');
      expect(launch2HeroLocation(row), Launch2Route.instance(_id(5)));
    });

    test('upcoming: 开售倒计时, the start, price and duration', () {
      final row = at(1);
      expect(launch2DeskStatus(row), '铸造倒计时');
      expect(
        launch2DeskCaption(row),
        '${launch2ShortDateTime(row.nftSale.startAt)} 开始铸造 · '
        '100 USD1 / 枚 · 铸造期 7 天',
      );
      expect(launch2DeskStampPrefix(row.stage), '距铸造 ');
      expect(launch2HeroLocation(row), Launch2Route.nft(_id(1)));
    });

    test('the kicker names the chain; the spoken sentence the event', () {
      expect(launch2DeskKicker('eip155:97'), '发射台 · BSC TESTNET');
      expect(launch2DeskKicker('eip155:56'), '发射台 · BSC');
      expect(
        launch2HeroSpokenLabel(at(2), l2Now),
        'FROG，共识勋章铸造中，剩 2 天 3 小时，已铸 2 枚',
      );
      expect(launch2HeroTicker('ABCDEFGHIJ'), 'ABCDEFGH…');
      expect(
        launch2ShortDateTime(DateTime(2026, 10, 18, 17, 32)),
        '10-18 17:32',
      );
    });

    testWidgets('drawn: full Lime, the ticker over the sentence, the stamp '
        'counts down and re-reads the list at zero; a tap opens the medal', (
      tester,
    ) async {
      final opened = <String>[];
      var now = l2Now;
      final gateway = _listGateway(<Map<String, Object?>>[
        _rowJson(2, 'nft_sale', nextIn: const Duration(seconds: 3)),
      ]);
      await _pump(
        tester,
        _list(opened),
        gateway,
        clock: () => now,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      final folio = _desk(tester, 'launch2-desk');
      // Decision 0223: the banner art, the ticker in Chalk over the brush,
      // the stage line in light Purple, the countdown on the Ink capsule.
      expect(folio.kicker, '发射台 · BSC TESTNET');
      expect(folio.heading, 'FROG\n共识勋章铸造中');
      expect(folio.stamp, '剩 00:03');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is LoopFolioPrimary &&
              widget.variant == LoopFolioVariant.lime,
        ),
        findsNothing,
      );
      final title = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-desk'),
          matching: _key('launch2-desk-event-title'),
        ),
      );
      expect(title.data, 'FROG');
      expect(title.style?.color, LoopColors.chalk);
      final status = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-desk'),
          matching: _key('launch2-desk-event-status'),
        ),
      );
      expect(status.data, '共识勋章铸造中');
      expect(status.style?.color, LoopColors.purpleInk);
      now = l2Now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_desk(tester, 'launch2-desk').stamp, '剩 00:02');
      final reads = gateway.listReads;
      now = l2Now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(gateway.listReads, greaterThan(reads));

      await tester.tap(_key('launch2-desk'));
      await tester.pump();
      expect(opened.last, '/launch2/nft?id=${_id(2)}');
      await _drain(tester);
    });

    testWidgets('a sprint has no countdown: no stamp; a tap opens the '
        'project', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        _list(opened),
        _listGateway(<Map<String, Object?>>[
          _rowJson(5, 'public', soldBps: 9100),
        ]),
      );
      final folio = _desk(tester, 'launch2-desk');
      expect(folio.heading, 'FROG\n内盘冲刺 91%');
      expect(folio.stamp, isNull);
      await tester.tap(_key('launch2-desk'));
      await tester.pump();
      expect(opened.last, '/launch2/instance?id=${_id(5)}');
      await _drain(tester);
    });
  });

  group('desk · the pager', () {
    testWidgets('one page: no dots, the card as it is alone', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[_rowJson(1, 'nft_sale')]),
      );
      expect(_key('launch2-desk-pages'), findsOneWidget);
      expect(_key('launch2-desk-dots'), findsNothing);
      // The page is the screen less the two 20 gutters (decision 0229).
      expect(tester.getSize(_key('launch2-desk-page-${_id(1)}')).width, 350);
      await _drain(tester);
    });

    testWidgets('one page per event, previews too; dots from two pages; a '
        'swipe moves the dot and each page opens its own place; nothing '
        'moves by itself', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        _list(opened),
        _listGateway(<Map<String, Object?>>[
          _rowJson(1, 'nft_sale'),
          _rowJson(2, 'priority', nextIn: const Duration(minutes: 30)),
          _rowJson(3, 'upcoming', startIn: const Duration(days: 1)),
        ]),
      );
      expect(_key('launch2-desk-dots'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(_key('launch2-desk-dot-$i'), findsOneWidget);
      }
      Color dot(int i) =>
          (tester.widget<Container>(_key('launch2-desk-dot-$i')).decoration!
                  as BoxDecoration)
              .color!;
      final active = dot(0);
      expect(dot(1), isNot(active));
      await tester.pump(const Duration(seconds: 30));
      expect(dot(0), active);
      await tester.tap(_key('launch2-desk-page-${_id(1)}'));
      await tester.pump();
      expect(opened.last, '/launch2/nft?id=${_id(1)}');

      await tester.drag(_key('launch2-desk-pages'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(dot(1), active);
      expect(
        _desk(tester, 'launch2-desk-page-${_id(2)}').heading,
        'FROG\n提前购进行中',
      );
      await tester.tap(_key('launch2-desk-page-${_id(2)}'));
      await tester.pump();
      expect(opened.last, '/launch2/instance?id=${_id(2)}');

      await tester.drag(_key('launch2-desk-pages'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(dot(2), active);
      expect(
        _desk(tester, 'launch2-desk-page-${_id(3)}').stamp,
        startsWith('距铸造 '),
      );
      await _drain(tester);
    });

    test('pages: live events, then previews; campaigns join them '
        '(decision 0165, covered in s184)', () {
      final hero = launch2HeroRows(
        _rows(<Map<String, Object?>>[
          _rowJson(1, 'upcoming', startIn: const Duration(days: 1)),
          _rowJson(2, 'nft_sale'),
        ]),
      );
      final running = Launch2DeskCampaign(
        campaignId: 'c1',
        title: '十月共识周',
        subtitle: '铸造勋章抽 USD1',
        startsAt: l2Now.subtract(const Duration(days: 1)),
        endsAt: l2Now.add(const Duration(days: 1)),
        link: Launch2CampaignLink.route('/launch2/nft?id=${_id(2)}'),
      );
      final over = Launch2DeskCampaign(
        campaignId: 'c2',
        title: '已结束',
        startsAt: l2Now.subtract(const Duration(days: 2)),
        endsAt: l2Now.subtract(const Duration(minutes: 1)),
        link: const Launch2CampaignLink.route('/launch2'),
      );
      final pages = launch2DeskPages(
        hero,
        campaigns: <Launch2DeskCampaign>[running, over],
        now: l2Now,
      );
      expect(pages.map((page) => page.id), <String>[
        'event-${_id(2)}',
        'event-${_id(1)}',
        'campaign-c1',
      ]);
      expect(launch2DeskPages(const <Launch2InstanceRow>[]), isEmpty);
    });

    testWidgets('a campaign page draws as the quiet ledger and opens its '
        'route', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            launch2AmbientMotionProvider.overrideWithValue(false),
            launch2ClockProvider.overrideWithValue(() => l2Now),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: Launch2DeskPager(
                pages: <Launch2DeskPage>[
                  Launch2DeskCampaignPage(
                    Launch2DeskCampaign(
                      campaignId: 'c1',
                      title: '十月共识周',
                      subtitle: '铸造勋章抽 USD1',
                      startsAt: l2Now.subtract(const Duration(days: 1)),
                      endsAt: l2Now.add(const Duration(days: 3)),
                      link: const Launch2CampaignLink.route('/launch2/nft'),
                    ),
                  ),
                ],
                chainId: 'eip155:97',
                onNavigate: opened.add,
              ),
            ),
          ),
        ),
      );
      // Decision 0211: a full-bleed picture card, title and subtitle on it.
      expect(find.text('十月共识周'), findsOneWidget);
      expect(find.text('铸造勋章抽 USD1'), findsOneWidget);
      expect(_key('launch2-campaign-card-c1'), findsOneWidget);
      await tester.tap(_key('launch2-desk-page-campaign-c1'));
      expect(opened, <String>['/launch2/nft']);
    });
  });

  group('desk · segment counts', () {
    testWidgets('from the rows when no figures were read; zero is kept and '
        'dimmed; the main event\'s segment is on', (tester) async {
      final json = <Map<String, Object?>>[
        _rowJson(1, 'nft_sale'),
        _rowJson(2, 'priority', nextIn: const Duration(hours: 1)),
        _rowJson(3, 'public', soldBps: 2500),
        _rowJson(4, 'graduated'),
        _rowJson(5, 'graduated'),
      ];
      await _pump(tester, _list(<String>[]), _listGateway(json));
      expect(_key('launch2-desk-segs'), findsOneWidget);
      for (final label in <String>['铸造中 1', '内盘 2', '预告 0', '已毕业 2']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // S264: the chosen chip is Purple with the Yellow splat on it.
      expect(_key('launch2-desk-seg-splat-minting'), findsOneWidget);
      expect(_key('launch2-desk-seg-splat-curve'), findsNothing);
      expect(_chipSelected(tester, 'minting'), isTrue);
      expect(_chipSelected(tester, 'curve'), isFalse);
      await _drain(tester);
    });

    testWidgets('the overview\'s figures when read', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[_rowJson(1, 'nft_sale')]),
        overview: _FakeOverview(<Map<String, Object?>>[_overviewJson()]),
      );
      for (final label in <String>['铸造中 2', '内盘 6', '预告 3', '已毕业 12']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await _drain(tester);
    });

    testWidgets('已毕业 switches to the 已毕业 segment', (tester) async {
      var switched = 0;
      await _pump(
        tester,
        _list(<String>[], onOpenGraduated: () => switched += 1),
        _listGateway(<Map<String, Object?>>[
          _rowJson(1, 'nft_sale'),
          _rowJson(2, 'graduated'),
        ]),
      );
      await tester.tap(find.text('已毕业 1'));
      await tester.pump();
      expect(switched, 1);
      await _drain(tester);
    });

    testWidgets('a count scrolls its far group heading into view', (
      tester,
    ) async {
      final json = <Map<String, Object?>>[
        for (var i = 1; i <= 14; i++) _rowJson(i, 'nft_sale'),
        _rowJson(20, 'upcoming', startIn: const Duration(days: 1)),
        for (var i = 30; i <= 44; i++) _rowJson(i, 'graduated'),
      ];
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(json),
        size: const Size(390, 800),
      );
      expect(_key('launch2-group-upcoming'), findsNothing);
      await tester.tap(find.text('预告 1'));
      await tester.pumpAndSettle();
      expect(_key('launch2-group-upcoming'), findsOneWidget);
      final y = tester.getTopLeft(_key('launch2-group-upcoming')).dy;
      expect(y, inInclusiveRange(0, 400));
      await _drain(tester);
    });
  });

  group('desk · record cards', () {
    testWidgets('the NFT sale: Lime row icon, the countdown over 铸造剩余, '
        'the bar at the time past and the foot line', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        _list(opened),
        _listGateway(<Map<String, Object?>>[_rowJson(1, 'nft_sale')]),
      );
      final id = _id(1);
      final card = _key('launch2-desk-record-$id');
      expect(card, findsOneWidget);
      expect(
        tester
            .widget<LoopMonoTile>(
              find.descendant(of: card, matching: find.byType(LoopMonoTile)),
            )
            .accent,
        isTrue,
      );
      final row = _rows(<Map<String, Object?>>[_rowJson(1, 'nft_sale')]).single;
      expect(
        tester.widget<Text>(_key('launch2-desk-record-sub-$id')).data,
        'Frog Launch · 铸造期 7 天 · '
        '截止 ${launch2ShortDateTime(row.nftSale.endAt)}',
      );
      expect(
        find.descendant(
          of: _key('launch2-desk-record-figure-$id'),
          matching: find.text('2天 03:00:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('铸造剩余')),
        findsOneWidget,
      );
      // The sale runs 01-16 → 01-23; the clock is 01-20: 4 of 7 days.
      expect(
        tester.widget<LoopProgressBar>(_key('launch2-desk-bar-$id')).value,
        closeTo(4 / 7, 1e-9),
      );
      expect(
        tester.widget<Text>(_key('launch2-desk-record-foot-$id')).data,
        '铸造期已过 57% · 已铸 2 枚 · 100 USD1 / 枚',
      );
      // Not drawn twice: no minting group, no row.
      expect(_key('launch2-group-minting'), findsNothing);
      expect(_key('launch2-tile-$id'), findsNothing);
      await tester.tap(card);
      await tester.pump();
      expect(opened.last, '/launch2/nft?id=$id');
      await _drain(tester);
    });

    testWidgets('a second live event gets the same card (the bar = sold / '
        '8 亿); a preview after it stays a row', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[
          _rowJson(1, 'nft_sale'),
          _rowJson(2, 'public', soldBps: 8000),
          _rowJson(3, 'upcoming', startIn: const Duration(days: 1)),
        ]),
      );
      expect(find.byType(Launch2DeskRecordCard), findsNWidgets(2));
      expect(
        tester
            .widget<LoopProgressBar>(_key('launch2-desk-bar-${_id(2)}'))
            .value,
        0.8,
      );
      expect(
        find.descendant(
          of: _key('launch2-desk-record-figure-${_id(2)}'),
          matching: find.text('80%'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(_key('launch2-desk-record-foot-${_id(2)}')).data,
        '0.0₄4167 USD1 · 卖满自动毕业',
      );
      expect(_key('launch2-tile-${_id(2)}'), findsNothing);
      expect(_key('launch2-tile-${_id(3)}'), findsOneWidget);
      expect(_key('launch2-desk-record-${_id(3)}'), findsNothing);
      // The first card sits above the second.
      expect(
        tester.getTopLeft(_key('launch2-desk-record-${_id(1)}')).dy,
        lessThan(tester.getTopLeft(_key('launch2-desk-record-${_id(2)}')).dy),
      );
      await _drain(tester);
    });

    testWidgets('a preview main event: no bar, the price line', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[
          _rowJson(1, 'upcoming', startIn: const Duration(days: 1)),
        ]),
      );
      expect(_key('launch2-desk-record-${_id(1)}'), findsOneWidget);
      expect(_key('launch2-desk-bar-${_id(1)}'), findsNothing);
      expect(
        tester.widget<Text>(_key('launch2-desk-record-foot-${_id(1)}')).data,
        '100 USD1 / 枚 · 铸造期 7 天',
      );
      await _drain(tester);
    });
  });

  group('desk · the live tape', () {
    final rows = <Map<String, Object?>>[_rowJson(1, 'nft_sale')];

    List<Map<String, Object?>> many(int count) => <Map<String, Object?>>[
      for (var i = 0; i < count; i++)
        _activityJson(
          'curve_buy',
          hash: '${i % 10}',
          ago: Duration(minutes: 2 * i),
        ),
    ];

    testWidgets('S264: the Purple band runs the newest trades in one line; '
        '「全部」 opens up to ten in a sheet; a line there opens the project', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        _list(opened),
        _listGateway(rows),
        overview: _FakeOverview(<Map<String, Object?>>[
          <String, Object?>{'activity': many(12), 'contractVersion': '2.0'},
        ]),
      );
      expect(_key('launch2-ticker'), findsOneWidget);
      expect(_key('launch2-ticker-live'), findsOneWidget);
      expect(find.text('实时'), findsOneWidget);
      // The three still lines are gone.
      expect(_key('launch2-tape'), findsNothing);
      final band = tester.widget<ColoredBox>(_key('launch2-ticker-band'));
      expect(band.color, LoopColors.purple);
      expect(tester.getSize(_key('launch2-ticker-band')).height, 36);
      // 买入 sits on its own Ink ground, in rise.
      final verb = tester.widget<Text>(find.text('买入').first);
      expect(verb.style?.color, LoopColors.rise);
      final verbGround = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('买入').first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect((verbGround.decoration! as BoxDecoration).color, LoopColors.ink);

      await tester.tap(_key('launch2-ticker-all'));
      await tester.pumpAndSettle();
      expect(_key('launch2-tape'), findsOneWidget);
      expect(_key('launch2-tape-line-9'), findsOneWidget);
      expect(_key('launch2-tape-line-10'), findsNothing);
      final time = tester.widget<Text>(
        find
            .descendant(
              of: _key('launch2-tape-line-0'),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(time.data, '刚刚');
      expect(time.style?.color, LoopColors.text3);
      await tester.tap(_key('launch2-tape-line-1'));
      await tester.pumpAndSettle();
      expect(opened.last, '/launch2/instance?id=${_id(1)}');
      expect(_key('launch2-tape'), findsNothing);
      await _drain(tester);
    });

    testWidgets('S264: the line moves while motion is allowed and stands '
        'still under reduced motion', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(rows),
        overview: _FakeOverview(<Map<String, Object?>>[_overviewJson()]),
        settle: false,
        ambientMotion: true,
      );
      await tester.pump();
      await tester.pump();
      double offset() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: _key('launch2-ticker-rail'),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .x;
      final before = offset();
      await tester.pump(const Duration(seconds: 2));
      expect(offset(), lessThan(before));
      await _drain(tester);

      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(rows),
        overview: _FakeOverview(<Map<String, Object?>>[_overviewJson()]),
        reduceMotion: true,
        ambientMotion: true,
      );
      final still = offset();
      await tester.pump(const Duration(seconds: 2));
      expect(offset(), still);
      await _drain(tester);
    });

    testWidgets('a later read is shown as read, newest first', (tester) async {
      final overview = _FakeOverview(<Map<String, Object?>>[
        _overviewJson(),
        _overviewJson(
          lead: <Map<String, Object?>>[
            _activityJson('graduated', hash: 'e', ticker: 'NEWT'),
          ],
        ),
      ]);
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(rows),
        overview: overview,
      );
      expect(find.textContaining('NEWT 毕业了'), findsNothing);
      // The list's own poll (1 h in this harness) refreshes the overview.
      await tester.pump(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(overview.reads, 2);
      expect(
        find.descendant(
          of: _key('launch2-ticker'),
          matching: find.text('NEWT 毕业了'),
        ),
        findsWidgets,
      );
      await _drain(tester);
    });

    testWidgets('no activity, or no overview at all: the band says 暂无成交 '
        'and stands still; no 全部, no stats', (tester) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(rows),
        overview: _FakeOverview(<Map<String, Object?>>[
          <String, Object?>{'activity': <Object?>[], 'contractVersion': '2.0'},
        ]),
      );
      expect(_key('launch2-ticker-empty'), findsOneWidget);
      expect(_key('launch2-ticker-all'), findsNothing);
      expect(_key('launch2-ticker-rail'), findsNothing);
      expect(_key('launch2-stats'), findsNothing);
      expect(find.text('战绩'), findsNothing);
      expect(_key('launch2-desk'), findsOneWidget);
      await _drain(tester);

      await _pump(tester, _list(<String>[]), _listGateway(rows));
      expect(_key('launch2-ticker-empty'), findsOneWidget);
      expect(_key('launch2-stats'), findsNothing);
      await _drain(tester);
    });
  });

  group('desk · groups', () {
    testWidgets('`.label` groups in order, members in the server\'s order; '
        'the record cards\' rows are not repeated; empty groups have no '
        'label; rows carry no fuse and no ring', (tester) async {
      final json = <Map<String, Object?>>[
        _rowJson(1, 'upcoming', startIn: const Duration(days: 1)),
        _rowJson(2, 'closed_no_holders'),
        _rowJson(3, 'public', soldBps: 2500),
        _rowJson(4, 'nft_sale'),
        _rowJson(5, 'snapshot_pending', nextIn: const Duration(hours: 1)),
        _rowJson(6, 'public', soldBps: 1000),
        _rowJson(7, 'graduated'),
      ];
      await _pump(tester, _list(<String>[]), _listGateway(json));
      final order = <String>[
        'curve',
        'snapshot',
        'upcoming',
        'graduated',
        'closed',
      ];
      final ys = <double>[
        for (final name in order)
          tester.getTopLeft(_key('launch2-group-$name')).dy,
      ];
      expect(ys, orderedEquals(<double>[...ys]..sort()));
      // S264: numbered headings over boards.
      expect(
        find.descendant(
          of: _key('launch2-group-curve'),
          matching: find.byType(Launch2SectionHeading),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-group-curve'),
          matching: find.text('01'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-board-curve'),
          matching: _key('launch2-tile-${_id(3)}'),
        ),
        findsOneWidget,
      );
      // The minting group held only the main event, now its record card.
      expect(_key('launch2-group-minting'), findsNothing);
      expect(_key('launch2-group-priority'), findsNothing);
      expect(_key('launch2-tile-${_id(4)}'), findsNothing);
      expect(_key('launch2-desk-record-${_id(4)}'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-tile-${_id(3)}')).dy,
        lessThan(tester.getTopLeft(_key('launch2-tile-${_id(6)}')).dy),
      );
      // The record card and the tape come before the first group.
      expect(
        tester.getTopLeft(_key('launch2-desk-record-${_id(4)}')).dy,
        lessThan(ys.first),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'launch2-row-ring',
              ),
        ),
        findsNothing,
      );
      await _drain(tester);
    });
  });

  group('desk · 战绩 and the notice', () {
    testWidgets('a 2×2 stat grid, then the notice, then the source line', (
      tester,
    ) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[_rowJson(1, 'graduated')]),
        overview: _FakeOverview(<Map<String, Object?>>[
          <String, Object?>{'stats': _statsJson(), 'contractVersion': '2.0'},
        ]),
      );
      expect(find.text('战绩'), findsOneWidget);
      final grid = tester.widget<MemeStatFigures>(
        find.descendant(
          of: _key('launch2-stats'),
          matching: find.byType(MemeStatFigures),
        ),
      );
      expect(grid.stats.map((stat) => '${stat.value}|${stat.label}'), <String>[
        '3|本周毕业 · 累计 12',
        '4,200.5 USD1|累计回购',
        '318 枚|勋章已铸',
        '9|进行中',
      ]);
      expect(_key('launch2-stats-buyback'), findsOneWidget);
      final notice = tester.widget<LoopNotice>(_key('launch2-curation-notice'));
      expect(notice.title, '精品发射，不是每天几万个');
      final stats = tester.getTopLeft(_key('launch2-stats')).dy;
      final noticeY = tester.getTopLeft(_key('launch2-curation-notice')).dy;
      expect(stats, lessThan(noticeY));
      expect(
        noticeY,
        lessThan(tester.getTopLeft(_key('launch2-list-all-provenance')).dy),
      );
      await _drain(tester);
    });

    testWidgets('no figures read: no 战绩 at all, the notice stays', (
      tester,
    ) async {
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(<Map<String, Object?>>[_rowJson(1, 'graduated')]),
        overview: _FakeOverview(<Map<String, Object?>>[
          _overviewJson(noStats: true),
        ]),
      );
      expect(_key('launch2-ticker-rail'), findsOneWidget);
      expect(_key('launch2-stats'), findsNothing);
      expect(find.text('战绩'), findsNothing);
      expect(_key('launch2-curation-notice'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('共识勋章 · the seven states', () {
    testWidgets('upcoming: grey ring, 开售倒计时, 开售后可铸造 disabled', (tester) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail(stage: 'upcoming')]),
      );
      expect(_key('launch2-nft-screen'), findsOneWidget);
      expect(
        _statusText(tester),
        '铸造倒计时 · 100 USD1 / 枚 · 铸造期 7 天 | 距铸造 2天 03:00:00',
      );
      expect(_button(tester).label, '开始后可铸造');
      expect(_button(tester).onPressed, isNull);
      expect(_medal(tester).lit, isFalse);
      expect(_medal(tester).bottomLabel, '共识勋章');
      await _drain(tester);
    });

    testWidgets('nft_sale, not held: Purple ring, the countdown, minted, the '
        'yellow mint button; summary above 这枚勋章能做什么', (tester) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail(summary: '一只青蛙的共识实验')]),
      );
      expect(_statusText(tester), '铸造中 · 已铸 2 枚 | 剩 2天 03:00:00');
      final folio = _folio(tester, 'launch2-nft-status');
      expect(folio.kicker, '共识勋章');
      expect(folio.heading, 'FROG');
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(folio.headingTone, LoopFolioHeadingTone.accent);
      // The medal sits under the ledger card.
      expect(
        tester.getTopLeft(_key('launch2-nft-medal')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(_key('launch2-nft-status')).dy,
        ),
      );
      expect(_key('launch2-nft-benefits'), findsOneWidget);
      expect(_key('launch2-nft-rules'), findsOneWidget);
      expect(_button(tester).label, '铸造 1 枚 · 100 USD1');
      expect(_button(tester).onPressed, isNotNull);
      // S257 (decision 0212): the ordinary yellow primary, a Purple ring,
      // no Brass anywhere on the page.
      expect(_button(tester).tone, LoopButtonTone.lime);
      expect(_medal(tester).lit, isTrue);
      expect(_medal(tester).ringColour, LoopColors.purple);
      expect(_medal(tester).inkColour, LoopColors.chalk);
      expect(find.text('一只青蛙的共识实验'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-nft-summary')).dy,
        lessThan(tester.getTopLeft(find.text('这枚勋章能做什么')).dy),
      );
      expect(
        tester.widget<LoopKeyValue>(_key('launch2-nft-held')).value,
        '0 / 1',
      );
      await _drain(tester);
    });

    testWidgets('nft_sale, held: #tokenId on the medal, 已持有 disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail(tokenId: '128')]),
      );
      expect(_medal(tester).bottomLabel, '#128');
      expect(_button(tester).label, '已持有 · 每地址 1 枚');
      expect(_button(tester).onPressed, isNull);
      expect(
        tester.widget<LoopKeyValue>(_key('launch2-nft-held')).value,
        '#128 · 已在候选名单',
      );
      await _drain(tester);
    });

    testWidgets('snapshot_pending: holder waits for the list, others see '
        '铸造已结束', (tester) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[
            _detail(stage: 'snapshot_pending', tokenId: '5'),
          ],
        ),
      );
      expect(_statusText(tester), '铸造已结束 · 名单生成中 · 已铸 2 枚');
      expect(_button(tester).label, '等待名单发布');
      expect(_button(tester).onPressed, isNull);
      expect(_medal(tester).lit, isTrue);
      await _drain(tester);

      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[_detail(stage: 'snapshot_pending')],
        ),
      );
      expect(_button(tester).label, '铸造已结束');
      expect(_button(tester).onPressed, isNull);
      await _drain(tester);
    });

    testWidgets('priority / public / graduated: 去项目页交易 opens the project', (
      tester,
    ) async {
      for (final (stage, status, opened) in <(String, String, bool)>[
        ('priority', '提前购进行中 · 已铸 2 枚 | 剩 2天 03:00:00', false),
        ('public', '内盘已开放 · 已铸 2 枚', false),
        ('graduated', '已毕业 · 已铸 2 枚', false),
      ]) {
        final navigated = <String>[];
        await _pump(
          tester,
          Launch2NftScreen(instanceId: l2InstanceA, onNavigate: navigated.add),
          _Fake(details: <Launch2InstanceDetail>[_detail(stage: stage)]),
        );
        expect(_statusText(tester), status, reason: stage);
        expect(_button(tester).label, '去项目页交易', reason: stage);
        expect(_medal(tester).lit, opened, reason: '$stage, not held');
        await tester.tap(_key('launch2-nft-mint'));
        await tester.pump();
        expect(navigated, <String>[Launch2Route.instance(l2InstanceA)]);
        await _drain(tester);
      }
    });

    testWidgets('a public round opened without holders says so', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[
            _detail(stage: 'public', openedWithoutHolders: true),
          ],
        ),
      );
      expect(_statusText(tester), '铸造期内无人铸造，已直接进入公开轮 · 已铸 2 枚');
      await _drain(tester);
    });

    testWidgets('closed_no_holders: grey ring, closed for good, 去项目页', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[_detail(stage: 'closed_no_holders')],
        ),
      );
      expect(_statusText(tester), '铸造期内无人铸造，项目已关闭');
      expect(
        _folio(tester, 'launch2-nft-status').headingTone,
        LoopFolioHeadingTone.neutral,
      );
      expect(_button(tester).label, '去项目页');
      expect(_button(tester).onPressed, isNotNull);
      expect(_medal(tester).lit, isFalse);
      await _drain(tester);
    });

    testWidgets('no wallet: 激活钱包后可铸造, disabled', (tester) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail(noViewer: true)]),
        noWallet: true,
      );
      expect(_button(tester).label, '激活钱包后可铸造');
      expect(_button(tester).onPressed, isNull);
      expect(
        tester.widget<LoopKeyValue>(_key('launch2-nft-held')).value,
        '未激活钱包',
      );
      await _drain(tester);
    });

    testWidgets('tradingHold: the 0161 banner, the line above the button, '
        'the mint disabled', (tester) async {
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[
          _detail(
            tradingHold: <String, Object?>{
              'kind': 'usd1_paused',
              'since': '2027-01-20T06:30:00.000Z',
            },
          ),
        ],
        intent: l2Intent(),
      );
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        gateway,
      );
      expect(_key('launch2-trading-hold'), findsOneWidget);
      expect(_key('launch2-nft-bar-hold'), findsOneWidget);
      expect(_button(tester).label, '铸造 1 枚 · 100 USD1');
      expect(_button(tester).onPressed, isNull);
      await tester.tap(_key('launch2-nft-mint'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(gateway.nftCalls, 0);
      await _drain(tester);
    });

    testWidgets('a malformed id fails closed without a read', (tester) async {
      final gateway = _Fake();
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: 'not-an-id'),
        gateway,
      );
      expect(_key('launch2-nft-invalid-identity'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-nft-invalid-identity'),
          matching: find.byType(LoopEmptyState),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(gateway.detailReads, 0);
      await _drain(tester);
    });
  });

  group('共识勋章 · one mint', () {
    testWidgets('confirm → prepare → sign; the re-read shows the mint: '
        '#tokenId on the medal, 已持有, one toast', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[
          _detail(),
          _detail(tokenId: '7'),
        ],
        intent: l2Intent(),
      );
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        gateway,
        wallet: wallet,
      );
      expect(_medal(tester).bottomLabel, '共识勋章');
      await tester.tap(_key('launch2-nft-mint'));
      await tester.pumpAndSettle();
      expect(_key('launch2-nft-confirm'), findsOneWidget);
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      expect(gateway.nftCalls, 1);
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.map((intent) => intent.kind), <IntentKind>[
        IntentKind.launchApproval,
        IntentKind.launchPurchase,
      ]);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(gateway.detailReads, greaterThanOrEqualTo(2));
      expect(_medal(tester).bottomLabel, '#7');
      expect(_button(tester).label, '已持有 · 每地址 1 枚');
      expect(_button(tester).onPressed, isNull);
      expect(find.text(launch2NftMintedToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await _drain(tester);
    });

    testWidgets('a refused prepare is said above the button, nothing signed', (
      tester,
    ) async {
      final wallet = _RecordingWallet();
      final gateway = _Fake(details: <Launch2InstanceDetail>[_detail()]);
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        gateway,
        wallet: wallet,
      );
      await tester.tap(_key('launch2-nft-mint'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      expect(gateway.nftCalls, 1);
      expect(_key('launch2-nft-bar-failure'), findsOneWidget);
      expect(_key('launch2-nft-action-failed'), findsOneWidget);
      expect(wallet.handed, isEmpty);
      await _drain(tester);
    });
  });

  group('S230 · decision 0201', () {
    testWidgets('USD1 short on the 勋章 page: the figure above the button and '
        '去充值 opens receive (docs/22 §3)', (tester) async {
      final wallet = _RecordingWallet();
      final navigated = <String>[];
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[_detail()],
        // loop-api `POST …/nft/mint/prepare`: 409 INSUFFICIENT_BALANCE /
        // LAUNCH2_USD1_BALANCE_INSUFFICIENT, detailsSafe.requiredUsd1 and
        // balanceUsd1.
        nftError: const LoopChainException(
          LoopChainFailureKind.insufficientBalance,
          reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          requiredUsd1: '100',
          balanceUsd1: '0',
        ),
      );
      await _pump(
        tester,
        Launch2NftScreen(instanceId: l2InstanceA, onNavigate: navigated.add),
        gateway,
        wallet: wallet,
      );
      await tester.tap(_key('launch2-nft-mint'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      final bar = _key('launch2-nft-bar-failure');
      expect(
        find.descendant(
          of: bar,
          matching: find.text('USD1 余额不足：需要 100 USD1，当前 0 USD1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: _key('launch2-nft-bar-topup')),
        findsOneWidget,
      );
      expect(wallet.handed, isEmpty);
      await tester.tap(_key('launch2-nft-bar-topup'));
      await tester.pumpAndSettle();
      expect(navigated, <String>['/wallet/receive?walletId=$l2WalletId']);
      await _drain(tester);
    });

    testWidgets('a refusal that is not about balance offers no 去充值', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail()]),
      );
      await tester.tap(_key('launch2-nft-mint'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      expect(_key('launch2-nft-bar-failure'), findsOneWidget);
      expect(_key('launch2-nft-bar-topup'), findsNothing);
      await _drain(tester);
    });
  });

  group('entries', () {
    testWidgets('the project page keeps 购买 NFT and adds 铸造页', (tester) async {
      final navigated = <String>[];
      await _pump(
        tester,
        Launch2InstanceScreen(
          instanceId: l2InstanceA,
          onNavigate: navigated.add,
        ),
        _Fake(details: <Launch2InstanceDetail>[_detail()]),
      );
      expect(_key('launch2-buy-nft'), findsOneWidget);
      expect(_key('launch2-nft-open'), findsOneWidget);
      await tester.tap(_key('launch2-nft-open'));
      await tester.pump();
      expect(navigated, <String>['/launch2/nft?id=$l2InstanceA']);
      await _drain(tester);
    });

    test('the route carries the instance id like the project page', () {
      expect(Launch2Route.nftPath, '/launch2/nft');
      expect(Launch2Route.nft(l2InstanceA), '/launch2/nft?id=$l2InstanceA');
      expect(
        Launch2Route.idOf(Uri.parse(Launch2Route.nft(l2InstanceA))),
        l2InstanceA,
      );
    });

    test('summary and links are optional on a row; junk reads as none', () {
      final row = l2RowJson();
      expect(l2Page(<Map<String, Object?>>[row]).items.single.summary, isNull);
      final page = l2Page(<Map<String, Object?>>[
        <String, Object?>{
          ...row,
          'summary': '  一只青蛙  ',
          'links': <Object?>['https://x.com/frog', 'javascript:alert(1)', 7],
        },
      ]);
      expect(page.items.single.summary, '一只青蛙');
      expect(page.items.single.links, <String>['https://x.com/frog']);
      final junk = l2Page(<Map<String, Object?>>[
        <String, Object?>{...row, 'summary': 42, 'links': 'nope'},
      ]);
      expect(junk.items.single.summary, isNull);
      expect(junk.items.single.links, isEmpty);
    });
  });

  group('360 dp', () {
    testWidgets('the desk, counts, record cards, tape, groups and 战绩 with '
        'long tickers and names do not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      final json = <Map<String, Object?>>[
        _rowJson(
          1,
          'nft_sale',
          ticker: 'ABCDEFGHIJKL',
          name: '一个名字很长很长很长的项目用来测试三百六十宽度',
        ),
        _rowJson(2, 'priority', nextIn: const Duration(minutes: 30)),
        _rowJson(3, 'public', soldBps: 9100, ticker: 'WXYZWXYZWXYZ'),
        _rowJson(
          4,
          'upcoming',
          startIn: const Duration(days: 12),
          name: '一个名字很长很长很长的项目用来测试三百六十宽度',
        ),
        _rowJson(5, 'graduated', ticker: 'GRADUATEDLON'),
      ];
      await _pump(
        tester,
        _list(<String>[]),
        _listGateway(json),
        overview: _FakeOverview(<Map<String, Object?>>[
          <String, Object?>{
            ..._overviewJson(
              lead: <Map<String, Object?>>[
                _activityJson('reward_claimed', hash: 'c', amount: '123456.78'),
                _activityJson('buyback', hash: 'd', ticker: 'ABCDEFGHIJKL'),
              ],
            ),
            'stats': <String, Object?>{
              ..._statsJson(),
              'buybackUsd1Total': '123456789.99',
            },
          },
        ]),
        size: const Size(360, 800),
      );
      expect(tester.view.physicalSize, const Size(360, 800));
      expect(_desk(tester, 'launch2-desk').heading, 'ABCDEFGH…\n共识勋章铸造中');
      expect(find.byType(Launch2DeskRecordCard), findsNWidgets(2));
      expect(_key('launch2-ticker'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2400));
      await tester.pumpAndSettle();
      expect(_key('launch2-stats'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });

    testWidgets('共识勋章 with a long ticker and name does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[
            _detail(
              ticker: 'ABCDEFGHIJKL',
              name: '一个名字很长很长很长的项目用来测试三百六十宽度',
              summary: '简介' * 30,
              tokenId: '123456',
            ),
          ],
        ),
        size: const Size(360, 800),
      );
      expect(tester.view.physicalSize, const Size(360, 800));
      expect(_key('launch2-nft-medal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        _key('launch2-nft-provenance'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  });

  group('one action name per entry', () {
    Future<void> walk(
      WidgetTester tester, {
      required Widget page,
      required String startKey,
      required String heading,
      required String confirm,
      required String noun,
      required String absent,
    }) async {
      final wallet = _RecordingWallet();
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[_detail()],
        intent: l2Intent(),
      );
      await _pump(tester, page, gateway, wallet: wallet);
      await tester.tap(_key(startKey));
      await tester.pumpAndSettle();
      expect(find.text(heading), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('launch2-nft-confirm-button')).label,
        confirm,
      );
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      final sheet = _key('launch2-sign-sheet');
      expect(sheet, findsOneWidget);
      expect(find.text('确认$noun'), findsWidgets);
      // The two-step strip names the main step the same way.
      expect(find.textContaining(noun), findsWidgets);
      // Nothing on the sheet or its step strip names the other action.
      final onSheet = find.descendant(
        of: find.ancestor(of: sheet, matching: find.byType(Column)).last,
        matching: find.textContaining(absent),
      );
      expect(onSheet, findsNothing);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.last.title, '确认$noun');
      await _drain(tester);
    }

    testWidgets('from 共识勋章: 铸造 all the way to the wallet', (tester) async {
      await walk(
        tester,
        page: const Launch2NftScreen(instanceId: l2InstanceA),
        startKey: 'launch2-nft-mint',
        heading: '铸造 FROG 共识勋章',
        confirm: '继续铸造',
        noun: '铸造',
        absent: '购买',
      );
    });

    testWidgets('from the project page: 铸造 too (decision 0200)', (
      tester,
    ) async {
      await walk(
        tester,
        page: const Launch2InstanceScreen(instanceId: l2InstanceA),
        startKey: 'launch2-buy-nft',
        heading: '铸造 FROG 共识勋章',
        confirm: '继续铸造',
        noun: '铸造',
        absent: '购买',
      );
    });
  });

  group('§7.1 tape · sentences and time', () {
    Launch2Activity item(
      Launch2ActivityKind kind, {
      String? actor = '0x1d2f000000000000000000000000000000009b9b',
      String? amount = '20',
      Duration ago = const Duration(seconds: 10),
    }) => Launch2Activity(
      kind: kind,
      instanceId: _id(1),
      ticker: 'DOGE',
      name: 'Doge on LOOP',
      actor: actor,
      amountUsd1: amount == null ? null : Decimal.parse(amount),
      at: l2Now.subtract(ago),
    );

    test('the seven kinds', () {
      expect(
        launch2ActivityLine(item(Launch2ActivityKind.curveBuy), l2Now),
        '刚刚 0x1d2f…9b 买入 DOGE 20 USD1',
      );
      expect(
        launch2ActivityText(item(Launch2ActivityKind.curveSell, actor: null)),
        '有人卖出 DOGE 20 USD1',
      );
      expect(
        launch2ActivityText(
          item(Launch2ActivityKind.nftMint, actor: null, amount: null),
        ),
        '有人铸造 DOGE 勋章',
      );
      expect(
        launch2ActivityText(item(Launch2ActivityKind.graduated, amount: null)),
        'DOGE 毕业了',
      );
      expect(
        launch2ActivityText(
          item(Launch2ActivityKind.buyback, actor: null, amount: '100'),
        ),
        '平台回购 DOGE 100 USD1',
      );
      expect(
        launch2ActivityText(item(Launch2ActivityKind.roundActivated)),
        'DOGE 外盘新一轮激活',
      );
      expect(
        launch2ActivityText(
          item(Launch2ActivityKind.rewardClaimed, amount: '10.94'),
        ),
        '0x1d2f…9b 领取 DOGE 奖励 10.94 USD1',
      );
    });

    test('relative time: 刚刚, N 分钟前, then HH:mm', () {
      expect(
        launch2RelativeTime(l2Now.subtract(const Duration(seconds: 59)), l2Now),
        '刚刚',
      );
      expect(
        launch2RelativeTime(l2Now.subtract(const Duration(minutes: 5)), l2Now),
        '5 分钟前',
      );
      final earlier = l2Now.subtract(const Duration(hours: 2));
      expect(launch2RelativeTime(earlier, l2Now), loopLocalClockLabel(earlier));
    });

    test('the overview codec drops what it cannot read and never fails on '
        'a field', () {
      final overview = LoopV2Launch2OverviewCodec.overview(
        _overviewJson(
          extra: <Object?>[
            <String, Object?>{'kind': 'teleport', 'instanceId': _id(1)},
            'not an object',
            <String, Object?>{..._activityJson('curve_buy'), 'at': 'yesterday'},
          ],
          stats: <String, Object?>{..._statsJson(), 'nftMintedTotal': -1},
        ),
        mediaUrl: (_) => null,
      );
      expect(overview.activity, hasLength(2));
      expect(overview.stats, isNull);
      expect(
        () => LoopV2Launch2OverviewCodec.overview('x', mediaUrl: (_) => null),
        throwsA(anything),
      );
      final full = LoopV2Launch2OverviewCodec.overview(
        _overviewJson(),
        mediaUrl: (_) => null,
      );
      expect(full.stats!.graduatedThisWeek, 3);
      expect(full.activity.first.actor, isNull);
    });
  });

  // Decision 0166 (S186-1): the project page in the 共识勋章 page's parts.
  group('project page folio (0166)', () {
    Launch2InstanceDetail detailOf(
      String stage, {
      String? holdReason,
      String name = 'Frog Launch',
    }) {
      final body = l2DetailJson(
        stage: stage,
        holdReason: holdReason,
        noNextChange:
            stage == 'public' || stage == 'graduated' || stage == 'paused',
        includePool: stage == 'graduated',
      );
      (body['instance']! as Map<String, Object?>)['name'] = name;
      return LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null);
    }

    /// Every colour the page paints in text and glyphs.
    Set<Color> paintedColours(WidgetTester tester) => <Color>{
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        ?text.style?.color,
      for (final icon in tester.widgetList<LoopIcon>(find.byType(LoopIcon)))
        ?icon.color,
    };

    testWidgets('nft_sale: one quiet record folio on top, the stage as its '
        'kicker and the countdown in its stamp; labels, stat grid, '
        'record card + bar; 铸造页 in Text2', (tester) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[_detail()]),
      );
      final folios = tester.widgetList<LoopFolioPrimary>(
        find.byType(LoopFolioPrimary),
      );
      expect(folios, hasLength(1));
      final folio = folios.single;
      expect(folio.key, const ValueKey<String>('launch2-instance-folio'));
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(folio.archetype, LoopFolioArchetype.record);
      expect(folio.ring, isFalse);
      expect(folio.kicker, '铸造中');
      expect(folio.heading, 'FROG');
      expect(folio.headingTone, LoopFolioHeadingTone.accent);
      expect(folio.caption, startsWith('Frog Launch · '));
      expect(folio.stamp, startsWith('剩 '));
      expect(_key('launch2-copy-address'), findsOneWidget);
      // The folio is above every stage block.
      expect(
        tester.getTopLeft(_key('launch2-instance-folio')).dy,
        lessThan(tester.getTopLeft(_key('launch2-nft-sale')).dy),
      );
      expect(
        find.descendant(
          of: _key('launch2-nft-sale'),
          matching: find.byWidgetPredicate(
            (w) => w is LoopLabel && w.text == '项目 NFT',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-nft-sale'),
          matching: find.byType(MemeStatFigures),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-nft-progress'),
          matching: find.byType(LoopProgressBar),
        ),
        findsOneWidget,
      );
      final link = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-nft-open'),
          matching: find.text('铸造页'),
        ),
      );
      expect(link.style?.color, LoopColors.text2);
      await _drain(tester);
    });

    testWidgets('public: the curve is a label, a stat grid and a record card '
        'with its bar; the panel opens with a label', (tester) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[detailOf('public')]),
      );
      final folio = tester.widget<LoopFolioPrimary>(
        find.byType(LoopFolioPrimary),
      );
      expect(folio.kicker, '公开内盘');
      expect(folio.stamp, isNull);
      expect(_key('launch2-countdown'), findsNothing);
      for (final label in <String>['内盘', '公开内盘']) {
        expect(
          find.byWidgetPredicate((w) => w is LoopLabel && w.text == label),
          findsOneWidget,
          reason: label,
        );
      }
      expect(_key('launch2-curve-price'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-curve'),
          matching: find.byType(LoopProgressBar),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('upcoming and paused state the heading in Chalk', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(details: <Launch2InstanceDetail>[detailOf('upcoming')]),
      );
      var folio = tester.widget<LoopFolioPrimary>(
        find.byType(LoopFolioPrimary),
      );
      expect(folio.headingTone, LoopFolioHeadingTone.neutral);
      expect(folio.stamp, startsWith('距铸造 '));
      await _drain(tester);
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[
            detailOf('paused', holdReason: 'LAUNCH2_ACTIVATION_MISSING'),
          ],
        ),
      );
      folio = tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary));
      expect(folio.kicker, '已暂停');
      expect(folio.headingTone, LoopFolioHeadingTone.neutral);
      await _drain(tester);
    });

    for (final stage in <String>[
      'upcoming',
      'nft_sale',
      'public',
      'graduated',
      'paused',
    ]) {
      testWidgets('$stage: no v1 warning, no Brass, no 20 / 700 heading', (
        tester,
      ) async {
        await _pump(
          tester,
          const Launch2InstanceScreen(instanceId: l2InstanceA),
          _Fake(
            details: <Launch2InstanceDetail>[
              stage == 'nft_sale'
                  ? _detail()
                  : detailOf(
                      stage,
                      holdReason: stage == 'paused'
                          ? 'LAUNCH2_ACTIVATION_MISSING'
                          : null,
                    ),
            ],
          ),
        );
        final colours = paintedColours(tester);
        expect(colours, isNot(contains(LoopColors.warning)));
        expect(colours, isNot(contains(LoopColors.brass)));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.style?.fontSize == 20 &&
                w.style?.fontWeight == FontWeight.w700,
          ),
          findsNothing,
        );
        await _drain(tester);
      });
    }

    testWidgets('the paused stage pill is grey, not warning yellow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: LoopColors.ink,
            body: Center(child: Launch2StagePill(stage: Launch2Stage.paused)),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('已暂停'));
      expect(text.style?.color, LoopColors.text2);
    });

    testWidgets('360 dp: a long name in the folio and the curve do not '
        'overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(
          details: <Launch2InstanceDetail>[
            detailOf('public', name: '一个名字很长很长很长的项目用来测试三百六十宽度'),
          ],
        ),
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        _key('launch2-trade-panel'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  });

  // S233 · client decision 0202 (S227-2, S227-3). test/fixtures/s233/ holds
  // the S171 BSC testnet instance with only its stage and snapshot moved.
  group('S233 · decision 0202', () {
    const instance = '8cf88c44-adf8-4c3f-9de2-46a895af3d1d';
    const tx =
        '0x3e83a226db47ebd5807162fd4e2b1ed855b40e0f3f63cc1f2f37a7d49caa2e92';
    const signer = '0x3e8739bf1b2fda26c008fdef26e7554777c19316';
    final publishedAt = DateTime.utc(2026, 10, 13, 19, 36, 13);
    DateTime clock() => DateTime.utc(2026, 10, 13, 19, 40);

    Launch2InstanceDetail s233(String name) => LoopV2Launch2Codec.detail(
      (jsonDecode(File('test/fixtures/s233/$name.json').readAsStringSync())
          as Map<String, Object?>)['body'],
      mediaUrl: (_) => null,
    );

    final generating = s233('instance_snapshot_pending_generating');
    final broadcast = s233('instance_snapshot_pending_broadcast');
    final confirmed = s233('instance_snapshot_pending_confirmed');
    final priority = s233('instance_priority_published');

    testWidgets('共识勋章 · snapshot_pending follows the publication: 名单生成中, '
        '名单发布中, 名单已上链，同步中', (tester) async {
      for (final (detail, title) in <(Launch2InstanceDetail, String)>[
        (generating, '名单生成中'),
        (broadcast, '名单发布中'),
        (confirmed, '名单已上链，同步中'),
      ]) {
        await _pump(
          tester,
          const Launch2NftScreen(instanceId: instance),
          _Fake(details: <Launch2InstanceDetail>[detail]),
          clock: clock,
        );
        expect(_statusText(tester), '铸造已结束 · $title · 已铸 3 枚');
        expect(launch2SnapshotPendingTitle(detail.snapshot), title);
        expect(_key('launch2-snapshot-published'), findsNothing);
        await _drain(tester);
      }
    });

    testWidgets('共识勋章 · snapshot_pending is read every 3 s, so 名单发布中 is '
        'seen; 提前购 goes back to the page\'s own interval', (tester) async {
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[generating, broadcast, priority],
      );
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: instance),
        gateway,
        clock: clock,
        polling: const Launch2Polling(),
        settle: false,
      );
      await tester.pump();
      expect(gateway.detailReads, 1);
      expect(_statusText(tester), '铸造已结束 · 名单生成中 · 已铸 3 枚');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(gateway.detailReads, 2);
      expect(_statusText(tester), '铸造已结束 · 名单发布中 · 已铸 3 枚');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(gateway.detailReads, 3);
      expect(_statusText(tester), startsWith('提前购进行中 · 已铸 3 枚'));
      // 提前购 on this page waits the detail interval (15 s) again.
      await tester.pump(const Duration(seconds: 14));
      await tester.pump();
      expect(gateway.detailReads, 3);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(gateway.detailReads, 4);
      await _drain(tester);
    });

    testWidgets('project page · snapshot_pending is read every 3 s; 提前购 '
        'returns to the trading interval', (tester) async {
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[generating, broadcast, priority],
      );
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: instance),
        gateway,
        clock: clock,
        polling: const Launch2Polling(),
        settle: false,
      );
      await tester.pump();
      expect(gateway.detailReads, 1);
      Finder pendingTitle(String text) => find.descendant(
        of: _key('launch2-snapshot-pending'),
        matching: find.text(text),
      );
      expect(pendingTitle('名单生成中'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(gateway.detailReads, 2);
      expect(pendingTitle('名单发布中'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(gateway.detailReads, 3);
      expect(_key('launch2-snapshot-pending'), findsNothing);
      // 提前购 trades: the trading interval (5 s), not 3 s.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(gateway.detailReads, 3);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(gateway.detailReads, 4);
      await _drain(tester);
    });

    test('the snapshot interval applies to snapshot_pending alone', () {
      const polling = Launch2Polling();
      expect(
        polling.intervalFor(Launch2Stage.snapshotPending, fast: false),
        const Duration(seconds: 3),
      );
      expect(
        polling.intervalFor(Launch2Stage.nftSale, fast: false),
        const Duration(seconds: 15),
      );
      expect(
        polling.intervalFor(Launch2Stage.priority, fast: true),
        const Duration(seconds: 5),
      );
    });

    Future<void> expectPublishedBlock(
      WidgetTester tester,
      List<Uri> opened,
    ) async {
      final block = _key('launch2-snapshot-published');
      await tester.scrollUntilVisible(
        _key('launch2-snapshot-explorer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(block, findsOneWidget);
      String value(String key) => tester.widget<LoopKeyValue>(_key(key)).value;
      expect(value('launch2-snapshot-members'), '3 人');
      expect(
        value('launch2-snapshot-published-at'),
        loopDateTimeLabel(publishedAt),
      );
      expect(value('launch2-snapshot-verification'), '已核验');
      expect(value('launch2-snapshot-tx'), launch2ShortAddress(tx));
      // Decision 0118: the list's addresses are never on the page.
      expect(find.textContaining(signer), findsNothing);
      expect(find.textContaining(tx), findsNothing);
      await tester.tap(_key('launch2-snapshot-explorer'));
      await tester.pump();
      expect(opened, <Uri>[Uri.parse('https://testnet.bscscan.com/tx/$tx')]);
    }

    testWidgets('project page · 提前购: the 名单已发布 block with count, time, '
        '已核验 and the BscScan link', (tester) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: instance),
        _Fake(details: <Launch2InstanceDetail>[priority]),
        clock: clock,
        extra: <Override>[
          launch2ExternalLinkOpenerProvider.overrideWithValue(
            (context, uri) async => opened.add(uri),
          ),
        ],
      );
      await expectPublishedBlock(tester, opened);
      await _drain(tester);
    });

    testWidgets('共识勋章 · 提前购: the same block', (tester) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: instance),
        _Fake(details: <Launch2InstanceDetail>[priority]),
        clock: clock,
        extra: <Override>[
          launch2ExternalLinkOpenerProvider.overrideWithValue(
            (context, uri) async => opened.add(uri),
          ),
        ],
      );
      expect(_statusText(tester), startsWith('提前购进行中 · 已铸 3 枚'));
      await expectPublishedBlock(tester, opened);
      await _drain(tester);
    });

    test('the block: from 提前购 on, never for a public round opened without '
        'holders; BscScan by chain', () {
      expect(launch2SnapshotPublishedShown(priority), isTrue);
      expect(launch2SnapshotPublishedShown(broadcast), isFalse);
      expect(launch2SnapshotPublishedShown(_detail(stage: 'public')), isTrue);
      expect(
        launch2SnapshotPublishedShown(
          _detail(stage: 'public', openedWithoutHolders: true),
        ),
        isFalse,
      );
      expect(
        launch2SnapshotPublishedShown(_detail(stage: 'graduated')),
        isTrue,
      );
      expect(
        launch2ExplorerTxUri('eip155:56', tx).toString(),
        'https://bscscan.com/tx/$tx',
      );
      expect(
        launch2ExplorerTxUri('eip155:97', tx).toString(),
        'https://testnet.bscscan.com/tx/$tx',
      );
      expect(launch2ExplorerTxUri('eip155:97', null), isNull);
      expect(launch2SnapshotVerificationText(null), isNull);
    });

    test('提前购 is 提前购进行中 on the list rows too', () {
      final row = _rows(<Map<String, Object?>>[
        _rowJson(1, 'priority', nextIn: const Duration(minutes: 30)),
      ]).single;
      expect(launch2HeroHeadline(row.stage, sprint: false), '提前购进行中');
      expect(
        launch2RecordSubtitle(row),
        startsWith('Frog Launch · 提前购进行中 · 截止 '),
      );
    });
  });

  group('S236 · decision 0203', () {
    const instance = '8cf88c44-adf8-4c3f-9de2-46a895af3d1d';
    const viewerWallet = '7dd2bf27-5c36-428d-95cb-54298d0fa974';
    final at = DateTime.utc(2026, 10, 19, 4, 33, 40);
    DateTime clock() => at;

    Launch2InstanceDetail s236(String name) => LoopV2Launch2Codec.detail(
      (jsonDecode(File('test/fixtures/s236/$name.json').readAsStringSync())
          as Map<String, Object?>)['body'],
      mediaUrl: (_) => null,
    );

    final broadcast = s236('instance_snapshot_pending_broadcast');
    final before = s236('instance_nft_sale_before_mint');
    final after = s236('instance_nft_sale_after_mint');

    /// [detail] as read again after another wallet minted: only
    /// `nftSale.soldCount` moves, the viewer holds what it held.
    Launch2InstanceDetail withSoldCount(Launch2InstanceDetail detail, int n) {
      final body = jsonDecode(
        File('test/fixtures/s236/instance_nft_sale_before_mint.json')
            .readAsStringSync(),
      ) as Map<String, Object?>;
      final instance =
          (body['body']! as Map<String, Object?>)['instance']!
              as Map<String, Object?>;
      (instance['nftSale']! as Map<String, Object?>)['soldCount'] = '$n';
      return LoopV2Launch2Codec.detail(body['body'], mediaUrl: (_) => null);
    }

    /// The NFT mint intent for this instance and this viewer, live at [at].
    Launch2Intent mintIntent() {
      final body = l2IntentJson();
      final intent = body['launch2Intent']! as Map<String, Object?>;
      intent['instanceId'] = instance;
      intent['walletId'] = viewerWallet;
      intent['createdAt'] = _iso(at);
      intent['deadline'] = _iso(at.add(const Duration(minutes: 5)));
      intent['expiresAt'] = _iso(at.add(const Duration(minutes: 5)));
      return LoopV2Launch2Codec.intent(body);
    }

    LoopFolioPrimary folio(WidgetTester tester) =>
        tester.widget<LoopFolioPrimary>(_key('launch2-instance-folio'));

    testWidgets('S234-3 · 名单发布中: the card label and the body say the same '
        'state', (tester) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: instance),
        _Fake(details: <Launch2InstanceDetail>[broadcast]),
        clock: clock,
      );
      expect(folio(tester).kicker, '名单发布中');
      expect(
        find.descendant(
          of: _key('launch2-snapshot-pending'),
          matching: find.text('名单发布中'),
        ),
        findsOneWidget,
      );
      expect(find.text('名单生成中'), findsNothing);
      expect(launch2InstanceStageLabel(broadcast), '名单发布中');
      // Every other stage keeps its own label.
      expect(launch2InstanceStageLabel(before), '铸造中');
      await _drain(tester);
    });

    testWidgets('S234-2 · 铸造中: the card and the figure say 已铸, not 已售', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: instance),
        _Fake(details: <Launch2InstanceDetail>[after]),
        clock: clock,
      );
      expect(folio(tester).caption, 'S234 Walk · 每地址 1 枚 · 已铸 2 枚');
      expect(launch2InstanceFolioCaption(after), contains('已铸 2 枚'));
      final stats = tester
          .widgetList<MemeStatFigures>(find.byType(MemeStatFigures))
          .expand((grid) => grid.stats);
      expect(stats.map((stat) => stat.label), contains('已铸'));
      expect(stats.map((stat) => stat.label), isNot(contains('已售')));
      expect(find.text('已售'), findsNothing);
      await _drain(tester);
    });

    Future<_Fake> mintUntilBroadcast(
      WidgetTester tester,
      Widget page,
      String startKey,
      List<Launch2InstanceDetail> details,
    ) async {
      final gateway = _Fake(details: details, intent: mintIntent());
      await _pump(
        tester,
        page,
        gateway,
        wallet: _RecordingWallet(),
        clock: clock,
        polling: const Launch2Polling(
          detailInterval: Duration(hours: 1),
          tradingInterval: Duration(seconds: 1),
          listInterval: Duration(hours: 1),
          snapshotInterval: Duration(hours: 1),
        ),
      );
      await tester.tap(_key(startKey));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pump();
      await tester.pump();
      // The wallet broadcast: 已广播, nothing confirmed yet.
      expect(_key('loop-sign-sheet-complete'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('loop-sign-sheet-complete'),
          matching: find.text('已广播'),
        ),
        findsOneWidget,
      );
      return gateway;
    }

    Future<void> expectConfirmedThenClosed(WidgetTester tester) async {
      // The watch re-reads after `tradingInterval`; the read shows the mint.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      final sheet = _key('loop-sign-sheet-complete');
      expect(
        find.descendant(of: sheet, matching: find.text('已确认')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('铸造已在链上确认。')),
        findsOneWidget,
      );
      // The step strip says it too.
      expect(find.text('已确认'), findsWidgets);
      // It closes itself without a tap.
      await tester.pump(launch2SignConfirmedCloseDelay);
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsNothing);
    }

    testWidgets('S234-4 · 共识勋章: the sheet turns 已确认 when the read shows '
        'the mint and closes itself; the page holds the NFT', (tester) async {
      final gateway = await mintUntilBroadcast(
        tester,
        const Launch2NftScreen(instanceId: instance),
        'launch2-nft-mint',
        <Launch2InstanceDetail>[before, after],
      );
      await expectConfirmedThenClosed(tester);
      expect(gateway.detailReads, greaterThanOrEqualTo(2));
      expect(_medal(tester).bottomLabel, '#2');
      expect(_button(tester).label, '已持有 · 每地址 1 枚');
      expect(find.text(launch2NftMintedToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await _drain(tester);
    });

    testWidgets('S234-4 · project page: the same sheet, the same signal', (
      tester,
    ) async {
      await mintUntilBroadcast(
        tester,
        const Launch2InstanceScreen(instanceId: instance),
        'launch2-buy-nft',
        <Launch2InstanceDetail>[before, after],
      );
      await expectConfirmedThenClosed(tester);
      expect(find.textContaining('铸造已在链上确认'), findsWidgets);
      await _drain(tester);
    });

    testWidgets('S234-4 · no change in the read: 已广播 stays, the reads stop '
        'at the limit, and 关闭 still closes it', (tester) async {
      final gateway = await mintUntilBroadcast(
        tester,
        const Launch2NftScreen(instanceId: instance),
        'launch2-nft-mint',
        <Launch2InstanceDetail>[before],
      );
      for (var i = 0; i < launch2ConfirmationReads + 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      final sheet = _key('loop-sign-sheet-complete');
      expect(
        find.descendant(of: sheet, matching: find.text('已广播')),
        findsOneWidget,
      );
      expect(find.text('已确认'), findsNothing);
      // One initial read plus at most the watch's own limit.
      expect(
        gateway.detailReads,
        lessThanOrEqualTo(1 + launch2ConfirmationReads),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsNothing);
      await _drain(tester);
    });

    test('the figure is the viewer\'s own and the check has a direction: '
        'mint 0 → >0, buy bought up, sell sold up', () {
      final intent = mintIntent();
      Decimal figure(Launch2InstanceDetail detail, Launch2Intent of) =>
          launch2OwnConfirmationFigure(detail, of)!;
      expect(figure(before, intent), Decimal.zero);
      expect(figure(after, intent), Decimal.one);
      // Another wallet's mint (soldCount 1 → 2) never moves it.
      final othersMint = withSoldCount(before, 2);
      expect(figure(othersMint, intent), Decimal.zero);
      bool advanced(Launch2IntentKind kind, String from, String to) =>
          launch2OwnConfirmationAdvanced(
            kind,
            baseline: Decimal.parse(from),
            now: Decimal.parse(to),
          );
      expect(advanced(Launch2IntentKind.nftMint, '0', '1'), isTrue);
      expect(advanced(Launch2IntentKind.nftMint, '0', '0'), isFalse);
      // Already held at the broadcast: a mint never confirms from it.
      expect(advanced(Launch2IntentKind.nftMint, '1', '1'), isFalse);
      expect(advanced(Launch2IntentKind.buy, '100', '150'), isTrue);
      expect(advanced(Launch2IntentKind.buy, '100', '100'), isFalse);
      expect(advanced(Launch2IntentKind.buy, '100', '90'), isFalse);
      expect(advanced(Launch2IntentKind.sell, '5', '8'), isTrue);
      expect(advanced(Launch2IntentKind.sell, '5', '5'), isFalse);
      expect(advanced(Launch2IntentKind.rewardClaim, '0', '9'), isFalse);
      final buy = LoopV2Launch2Codec.intent(
        l2IntentJson(kind: 'buy', approval: false),
      );
      final sell = LoopV2Launch2Codec.intent(
        l2IntentJson(kind: 'sell', approval: false),
      );
      final curveDetail = _detail(stage: 'priority');
      // A buy reads bought, a sell reads sold.
      expect(
        launch2OwnConfirmationFigure(curveDetail, buy),
        curveDetail.viewer!.curve.bought,
      );
      expect(
        launch2OwnConfirmationFigure(curveDetail, sell),
        curveDetail.viewer!.curve.sold,
      );
      expect(
        launch2OwnConfirmationFigure(before, buy),
        isNull,
        reason: 'the intent is for another wallet than the viewer',
      );
      expect(
        launch2OwnConfirmationFigure(_detail(noViewer: true), buy),
        isNull,
      );
    });

    testWidgets('S234-4 · someone else mints meanwhile (before → before with '
        'soldCount + 1): the sheet stays 已广播', (tester) async {
      final gateway = await mintUntilBroadcast(
        tester,
        const Launch2NftScreen(instanceId: instance),
        'launch2-nft-mint',
        <Launch2InstanceDetail>[before, withSoldCount(before, 2)],
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      final sheet = _key('loop-sign-sheet-complete');
      expect(
        find.descendant(of: sheet, matching: find.text('已广播')),
        findsOneWidget,
      );
      // The watch did read the second answer (soldCount 2).
      expect(gateway.detailReads, greaterThanOrEqualTo(2));
      expect(find.text('已确认'), findsNothing);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await _drain(tester);
    });

    testWidgets('S234-4 · a locked outcome (wallet answer unknown) stays '
        '已广播 and asks for nothing more', (tester) async {
      final gateway = _Fake(
        details: <Launch2InstanceDetail>[before, after],
        intent: mintIntent(),
      );
      await _pump(
        tester,
        const Launch2NftScreen(instanceId: instance),
        gateway,
        wallet: _UnknownMainWallet(),
        clock: clock,
        polling: const Launch2Polling(
          detailInterval: Duration(hours: 1),
          tradingInterval: Duration(seconds: 1),
          listInterval: Duration(hours: 1),
          snapshotInterval: Duration(hours: 1),
        ),
      );
      await tester.tap(_key('launch2-nft-mint'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-risk-tick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-nft-confirm-button'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pump();
      await tester.pump();
      final sheet = _key('loop-sign-sheet-complete');
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('已广播')),
        findsOneWidget,
      );
      final reads = gateway.detailReads;
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(gateway.detailReads, reads);
      expect(find.text('已确认'), findsNothing);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await _drain(tester);
    });
  });
}

Map<String, Object?> _activityJson(
  String kind, {
  String hash = 'a',
  String ticker = 'DOGE',
  String? actor = '0x1d2f000000000000000000000000000000009b9b',
  String? amount = '20',
  Duration ago = const Duration(seconds: 10),
}) => <String, Object?>{
  'kind': kind,
  'instanceId': _id(1),
  'ticker': ticker,
  'name': 'Doge on LOOP',
  'logoUrl': null,
  'actor': actor,
  'amountUsd1': amount,
  'at': _iso(l2Now.subtract(ago)),
  'transactionHash': '0x${hash * 64}',
};

Map<String, Object?> _statsJson() => <String, Object?>{
  'liveCount': 9,
  'mintingCount': 2,
  'priorityCount': 1,
  'curveCount': 5,
  'upcomingCount': 3,
  'graduatedTotal': 12,
  'graduatedThisWeek': 3,
  'buybackUsd1Total': '4200.5',
  'nftMintedTotal': 318,
};

Map<String, Object?> _overviewJson({
  List<Map<String, Object?>> lead = const <Map<String, Object?>>[],
  List<Object?> extra = const <Object?>[],
  Map<String, Object?>? stats,
  bool noStats = false,
}) => <String, Object?>{
  'activity': <Object?>[
    ...lead,
    _activityJson('nft_mint', actor: null, amount: null),
    _activityJson('curve_buy', hash: 'b', ago: const Duration(minutes: 5)),
    ...extra,
  ],
  if (!noStats) 'stats': stats ?? _statsJson(),
  'observedAt': _iso(l2Now),
  'contractVersion': '2.0',
};

final class _FakeOverview implements Launch2OverviewGateway {
  _FakeOverview(this.answers);

  /// The reads, in order; the last one repeats.
  final List<Map<String, Object?>> answers;
  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Overview> loadOverview() {
    final index = reads < answers.length ? reads : answers.length - 1;
    reads += 1;
    return Future<Launch2Overview>.value(
      LoopV2Launch2OverviewCodec.overview(
        answers[index],
        mediaUrl: (_) => null,
      ),
    );
  }
}

/// Accepts the approval; the main transaction's wallet answer is unknown
/// (a locked outcome, decision 0203).
final class _UnknownMainWallet implements WalletSigningGateway {
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
    if (intent.kind == IntentKind.launchApproval) {
      return const WalletHandoffResult(
        accepted: true,
        code: 'wallet_accepted',
        value: _txHash,
      );
    }
    return const WalletHandoffResult(
      accepted: false,
      code: 'wallet_outcome_unknown',
    );
  }
}
