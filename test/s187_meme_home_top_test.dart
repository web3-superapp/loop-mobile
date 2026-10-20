import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/features/meme/meme_best_trades.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_home_top.dart';
import 'package:loop_mobile/features/meme/meme_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_best_trades_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/meme_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S187-3 · MEME Tab 「首页」 top (decision 0176)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final class _Meme implements MemeGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _no() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<MemeTokenPage> listTokens(MemeListTab tab, {String? cursor}) =>
      Future<MemeTokenPage>.value(
        memePage(
          tab: tab.wireName,
          items: <Map<String, Object?>>[memeRowJson()],
        ),
      );

  @override
  Future<MemeTokenDetail> loadToken(String memeTokenId) => _no();
  @override
  Future<MemeTradePage> loadTrades(String memeTokenId, {String? cursor}) =>
      _no();
  @override
  Future<MemeHolderPage> loadHolders(String memeTokenId, {String? cursor}) =>
      _no();
  @override
  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  ) => _no();
  @override
  Future<MemeQuote> quote({
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  }) => _no();
  @override
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) => _no();
  @override
  Future<MemeTokenDetail> createToken(MemeCreateDraft draft) => _no();
  @override
  Future<MemeIntent> prepareIntent({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  }) => _no();
  @override
  Future<MemeIntent> reportBroadcast({
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
  }) => _no();
  @override
  Future<MemeIntent> loadIntent(String memeIntentId) => _no();
}

final class _Board implements MemeBestTradesGateway {
  _Board({this.board, this.failure});

  final MemeBestTradesBoard? board;
  final LoopChainFailureKind? failure;
  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MemeBestTradesBoard> loadWeekly() {
    reads += 1;
    final kind = failure;
    if (kind != null) {
      return Future<MemeBestTradesBoard>.error(LoopChainException(kind));
    }
    return Future<MemeBestTradesBoard>.value(board!);
  }
}

final class _Hidden implements LoopBalanceVisibilityStore {
  const _Hidden(this.value);

  final bool? value;

  @override
  Future<bool?> readHideBalance() => Future<bool?>.value(value);

  @override
  Future<void> writeHideBalance(bool value) => Future<void>.value();
}

const String _profileId = 'pp_0123456789';

MemeBestTrade _trade(int rank) => MemeBestTrade(
  rank: rank,
  publicProfileId: '$_profileId$rank',
  loopId: 'LOOP-ABCD000$rank',
  alias: rank == 1 ? 'Oura456' : null,
  avatarRef: null,
  memeTokenId: memeTokenIdA,
  symbol: 'FROG',
  logoUrl: null,
  realizedUsd1: Decimal.parse(rank == 1 ? '116807.57' : '${100 - rank}.5'),
);

MemeBestTradesBoard _boardOf(int count) => MemeBestTradesBoard(
  items: <MemeBestTrade>[for (var i = 1; i <= count; i += 1) _trade(i)],
  observedAt: DateTime.utc(2026, 10, 15, 12),
);

LoopV2MetaSnapshot _meta({bool wallet = true}) {
  final base = s7MetaSnapshot();
  const open = <LoopV2CapabilityId>{
    LoopV2CapabilityId.meme,
    LoopV2CapabilityId.walletRead,
    LoopV2CapabilityId.bscRead,
  };
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (open.contains(capability.id) &&
              (wallet || capability.id == LoopV2CapabilityId.meme))
            LoopV2Capability(
              id: capability.id,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.confirmed,
                reasonCode: 'OBSERVED',
              ),
            )
          else
            capability,
      ],
    ),
  );
}

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: memeWalletId,
  address: memeWalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

Future<List<String>> _pump(
  WidgetTester tester, {
  List<LoopWalletBalances> balances = const <LoopWalletBalances>[],
  _Board? board,
  bool? hidden,
  bool wallet = true,
  VoidCallback? onOpenGraduated,
}) async {
  final opened = <String>[];
  await pumpS7Page(
    tester,
    MemeLaunchpadSegment(
      onNavigate: opened.add,
      onOpenGraduated: onOpenGraduated,
    ),
    meta: _meta(wallet: wallet),
    wallet: FakeWalletDirectory(
      activeWalletId: memeWalletId,
      wallets: <LoopWalletAccount>[_wallet()],
      balances: balances,
    ),
    overrides: <Override>[
      memeGatewayProvider.overrideWithValue(_Meme()),
      memeBestTradesGatewayProvider.overrideWithValue(
        board ?? _Board(failure: LoopChainFailureKind.notFound),
      ),
      if (hidden != null)
        loopBalanceVisibilityStoreProvider.overrideWithValue(_Hidden(hidden)),
    ],
  );
  return opened;
}

String _text(WidgetTester tester, String key) {
  final widget = tester.widget(_key(key));
  if (widget is Text) return widget.data ?? widget.textSpan!.toPlainText();
  throw StateError('not a Text: $key');
}

void main() {
  group('balance block', () {
    testWidgets('no verified source draws -- with the reason, never 0', (
      tester,
    ) async {
      // FakeWalletDirectory with no balances answers `unavailable`.
      await _pump(tester);
      expect(_text(tester, 'meme-balance-figure'), memeBalanceUnread);
      expect(_key('meme-balance-reason'), findsOneWidget);
      expect(_text(tester, 'meme-balance-reason'), isNotEmpty);
      expect(find.text(r'$0'), findsNothing);
      expect(_key('meme-balance-change'), findsNothing);
    });

    testWidgets('a closed wallet module is -- with its reason', (tester) async {
      await _pump(
        tester,
        wallet: false,
        balances: <LoopWalletBalances>[s5Balances()],
      );
      expect(_text(tester, 'meme-balance-figure'), memeBalanceUnread);
      expect(_text(tester, 'meme-balance-reason'), contains('钱包余额暂时读不到'));
    });

    testWidgets('a partial net worth is not a total', (tester) async {
      await _pump(
        tester,
        balances: <LoopWalletBalances>[
          s5Balances(
            netWorth: LoopNetWorthValued(
              partial: true,
              valuationCurrency: 'USD',
              valueUsd: Decimal.parse('12'),
              unavailableCount: 2,
              quality: LoopFactQuality.fresh,
              priceSource: LoopFactSource.dexscreener,
              asOf: DateTime.utc(2026, 9, 8),
              isSpendable: false,
              change24h: const LoopNetWorthChangeUnavailable(
                'PRICE_CHANGE_PARTIAL',
              ),
            ),
          ),
        ],
      );
      expect(_text(tester, 'meme-balance-figure'), memeBalanceUnread);
      expect(_text(tester, 'meme-balance-reason'), contains('2 项资产暂无价格'));
    });

    testWidgets('a valued total draws the figure and the 24h change', (
      tester,
    ) async {
      await _pump(tester, balances: <LoopWalletBalances>[s5Balances()]);
      expect(_text(tester, 'meme-balance-figure'), r'$6,352.82');
      final figure = tester.widget<Text>(_key('meme-balance-figure'));
      expect(figure.style!.fontSize, LoopType.figureXl.fontSize);
      expect(figure.style!.fontWeight, LoopType.figureXl.fontWeight);
      expect(
        _text(tester, 'meme-balance-change'),
        startsWith(r'+$302.52 · 24 小时'),
      );
      final change = tester.widget<Text>(_key('meme-balance-change'));
      final span = change.textSpan! as TextSpan;
      expect(span.children!.first.style!.color, LoopColors.rise);
    });

    testWidgets('the hide-balance preference masks the figures', (
      tester,
    ) async {
      await _pump(
        tester,
        balances: <LoopWalletBalances>[s5Balances()],
        hidden: true,
      );
      expect(_text(tester, 'meme-balance-figure'), memeMaskedFigure);
      expect(_text(tester, 'meme-balance-change'), startsWith('****'));
      expect(find.textContaining('6,352'), findsNothing);
    });

    testWidgets('充值 is the one full Lime and opens the receive page '
        'without a faucet', (tester) async {
      final opened = await _pump(tester, board: _Board(board: _boardOf(3)));
      final primaries = tester
          .widgetList<LoopButton>(find.byType(LoopButton))
          .where((button) => button.primary)
          .toList();
      expect(primaries, hasLength(1));
      expect(primaries.single.label, '充值');
      await tester.tap(_key('meme-top-up'));
      await tester.pumpAndSettle();
      expect(opened.last, '/wallet/receive?walletId=$memeWalletId');
    });
  });

  group('每周最佳交易', () {
    for (final kind in <LoopChainFailureKind>[
      LoopChainFailureKind.notFound,
      LoopChainFailureKind.unavailable,
      LoopChainFailureKind.invalidData,
    ]) {
      testWidgets('a ${kind.name} board draws nothing', (tester) async {
        await _pump(tester, board: _Board(failure: kind));
        expect(_key('meme-best-trades'), findsNothing);
        expect(find.text('每周最佳交易'), findsNothing);
        // The list below is untouched.
        expect(_key('meme-row-$memeTokenIdA'), findsOneWidget);
      });
    }

    testWidgets('an empty board draws nothing', (tester) async {
      await _pump(tester, board: _Board(board: _boardOf(0)));
      expect(_key('meme-best-trades'), findsNothing);
    });

    testWidgets('a board draws at most ten 170-wide cards that open the '
        'token and the profile', (tester) async {
      final board = _Board(
        board: MemeBestTradesBoard(
          items: <MemeBestTrade>[for (var i = 1; i <= 12; i += 1) _trade(i)],
          observedAt: DateTime.utc(2026, 10, 15),
        ),
      );
      final opened = await _pump(tester, board: board);
      expect(find.text('每周最佳交易'), findsOneWidget);
      for (var rank = 1; rank <= 10; rank += 1) {
        expect(_key('meme-best-trade-$rank'), findsOneWidget);
      }
      expect(_key('meme-best-trade-11'), findsNothing);
      expect(tester.getSize(_key('meme-best-trade-1')).width, 170);
      expect(find.text('Oura456'), findsOneWidget);
      expect(find.text('LOOP-ABCD0002'), findsOneWidget);
      final gain = tester.widget<Text>(_key('meme-best-trade-1-gain'));
      expect(gain.data, r'+$116,807.57');
      expect(gain.style!.color, LoopColors.lime);

      await tester.tap(_key('meme-best-trade-1-gain'));
      await tester.pumpAndSettle();
      expect(opened.last, '/meme/token?id=$memeTokenIdA');
      await tester.tap(_key('meme-best-trade-1-user'));
      await tester.pumpAndSettle();
      expect(opened.last, contains('${_profileId}1'));
    });
  });

  group('tabs and chips', () {
    testWidgets('balance, best trades, tabs, chips and rows in that order', (
      tester,
    ) async {
      await _pump(
        tester,
        balances: <LoopWalletBalances>[s5Balances()],
        board: _Board(board: _boardOf(2)),
      );
      final bar = tester.widget<MarketTabBar>(_key('meme-home-tabs'));
      expect(bar.labels, <String>['自选', '代币', '已毕业']);
      expect(bar.selectedIndex, 1);
      final chips = tester.widget<LoopSegBar>(_key('meme-list-chips'));
      expect(chips.labels, <String>['新发', '热门', '快打满', '已毕业']);
      double top(String key) => tester.getTopLeft(_key(key)).dy;
      expect(top('meme-balance'), lessThan(top('meme-best-trades')));
      expect(top('meme-best-trades'), lessThan(top('meme-home-tabs')));
      expect(top('meme-home-tabs'), lessThan(top('meme-list-chips')));
      expect(top('meme-list-chips'), lessThan(top('meme-row-$memeTokenIdA')));
    });

    testWidgets('自选 opens 行情 and 已毕业 opens the graduated segment', (
      tester,
    ) async {
      var graduated = 0;
      final opened = await _pump(tester, onOpenGraduated: () => graduated++);
      await tester.tap(_key('meme-home-tab-自选'));
      await tester.pumpAndSettle();
      expect(opened.last, '/market');
      await tester.tap(_key('meme-home-tab-已毕业'));
      await tester.pumpAndSettle();
      expect(graduated, 1);
    });

    testWidgets('without a graduated segment 已毕业 picks the classic chip', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_key('meme-home-tab-已毕业'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarketTabBar>(_key('meme-home-tabs')).selectedIndex,
        2,
      );
      expect(
        tester.widget<LoopSegBar>(_key('meme-list-chips')).selectedIndex,
        3,
      );
    });
  });

  group('codec', () {
    Map<String, Object?> row({
      int rank = 1,
      Object? memeTokenId = memeTokenIdA,
      Object? realized = '12.5',
      Object? avatar = 'avatar:media/$memeMediaId',
    }) => <String, Object?>{
      'rank': rank,
      'user': <String, Object?>{
        'userId': 'pp_$rank',
        'loopId': 'LOOP-ABCDEFG$rank',
        'alias': rank == 1 ? 'frogmaker' : null,
        'avatar': avatar,
      },
      'token': <String, Object?>{
        'memeTokenId': memeTokenId,
        'symbol': 'FROG',
        'logoUrl': 'https://elsewhere.example/v2/media/$memeMediaId.webp',
      },
      'realizedUsd1': realized,
      'observedAt': '2026-10-15T12:00:00.000Z',
    };

    test('reads the board and drops rows it cannot read', () {
      final board = LoopV2MemeBestTradesCodec.board(<String, Object?>{
        'window': '7d',
        'items': <Object?>[
          row(),
          row(rank: 2, memeTokenId: 'not-a-uuid'),
          row(rank: 3, realized: '-1'),
          row(rank: 4, realized: 12),
          row(rank: 5, avatar: 'https://evil.example/a.png'),
          'garbage',
        ],
        'observedAt': '2026-10-15T12:00:00.000Z',
        'contractVersion': '2.0',
        'futureKey': true,
      }, mediaUrl: memeTestMediaUrl);
      expect(board.items.map((item) => item.rank), <int>[1, 5]);
      final first = board.items.first;
      expect(first.displayName, 'frogmaker');
      expect(first.avatarRef, 'avatar:media/$memeMediaId');
      expect(first.realizedUsd1, Decimal.parse('12.5'));
      // The picture is loaded from this build's origin, not the payload's.
      expect(first.logoUrl, memeTestMediaUrl(memeMediaId));
      expect(board.items.last.avatarRef, isNull);
      expect(board.items.last.displayName, 'LOOP-ABCDEFG5');
    });

    test('keeps at most ten rows', () {
      final board = LoopV2MemeBestTradesCodec.board(<String, Object?>{
        'items': <Object?>[for (var i = 1; i <= 10; i += 1) row(rank: i)],
        'observedAt': '2026-10-15T12:00:00.000Z',
      }, mediaUrl: memeTestMediaUrl);
      expect(board.items, hasLength(10));
    });

    test('a payload that is not a board is invalid', () {
      for (final raw in <Object?>[
        null,
        <Object?>[],
        <String, Object?>{'items': 'x', 'observedAt': '2026-10-15T12:00:00Z'},
        <String, Object?>{'items': <Object?>[]},
        <String, Object?>{
          'window': '30d',
          'items': <Object?>[],
          'observedAt': '2026-10-15T12:00:00Z',
        },
      ]) {
        expect(
          () =>
              LoopV2MemeBestTradesCodec.board(raw, mediaUrl: memeTestMediaUrl),
          throwsA(isA<LoopBackendFailure>()),
        );
      }
    });
  });
}
