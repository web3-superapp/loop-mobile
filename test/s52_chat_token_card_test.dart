// S52 · a contract address pasted into a conversation opens a Token Card.
//
// The message is never rewritten: the address stays in the bubble, and the
// card under it is LOOP reading that address through the market port. This
// file pins what the card may say in each of its states, which of its four
// actions can be taken, and that one address is read once for the whole
// conversation however many bubbles name it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card_cache.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_detection.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _address = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';

MarketSecurityBlock _security() => MarketSecurityAvailable(
  source: LoopFactSource.goplus,
  fetchedAt: DateTime.utc(2026, 9, 8, 7, 20),
  ttlSeconds: 600,
  quality: LoopFactQuality.fresh,
  reasonCode: null,
  facts: <MarketSecurityFact>[
    MarketSecurityFact(
      fact: 'openSource',
      value: 'true',
      source: LoopFactSource.goplus,
      observedAt: DateTime.utc(2026, 9, 8, 7, 20),
    ),
    MarketSecurityFact(
      fact: 'mintable',
      value: 'true',
      source: LoopFactSource.goplus,
      observedAt: DateTime.utc(2026, 9, 8, 7, 20),
    ),
  ],
);

/// The shape the backend answers a pasted, unregistered address with
/// (`frontend-v2-market-api.md` §4a): identity from a provider lookup, no
/// ticker and no precision on the DexScreener path, and no holder count.
MarketAssetDetail _unregisteredDetail() => MarketAssetDetail(
  asset: MarketAssetIdentitySettled(
    LoopChainAsset(
      assetId: 'eip155:56:$_address',
      chainId: 'eip155:56',
      address: _address,
      symbol: null,
      name: null,
      decimals: null,
      status: LoopAssetStatus.unregistered,
      source: LoopAssetSource(
        kind: LoopAssetSourceKind.providerLookup,
        provider: LoopFactSource.geckoterminal,
        fetchedAt: DateTime.utc(2026, 9, 20, 14, 52),
        ttlSeconds: 3600,
        quality: LoopFactQuality.fresh,
        blockNumber: null,
        verifiedAt: null,
      ),
      updatedAt: DateTime.utc(2026, 9, 20, 14, 52),
    ),
  ),
  capability: const LoopAssetCapability(
    viewable: true,
    swappable: false,
    value: LoopAssetCapabilityValue.viewable,
    reasonCode: 'ASSET_NOT_REGISTERED',
  ),
  price: s5FreshFact('2575.14'),
  priceChange24h: s5FreshFact('-2.52'),
  liquidityUsd: s5FreshFact('16714230.21'),
  volume24h: s5FreshFact('25016115.55'),
  marketCap: s5FreshFact('1300514252.30'),
  fdv: s5FreshFact('1300404347.01'),
  primaryPair: null,
  community: const MarketCommunityUnavailable('COMMUNITY_NOT_BOUND'),
  security: const MarketSecurityUnavailable(
    'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
  ),
  holderCount: const LoopFact.unavailable(
    'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
  ),
);

MarketCommunityBlock _community() => const MarketCommunityBound(
  communityId: 'c0ffee00-0000-4000-8000-000000000001',
  name: 'PEPE 社区',
  slug: 'pepe',
  memberCount: 128000,
);

Future<List<String>> _pumpCard(
  WidgetTester tester, {
  required FakeMarketReadGateway market,
  LoopV2MetaSnapshot? meta,
  bool settle = true,
  int cards = 1,
  bool? transport,
  List<Override> overrides = const <Override>[],
}) async {
  final navigated = <String>[];
  await pumpS5Page(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF050604),
      body: ListView(
        children: <Widget>[
          for (var index = 0; index < cards; index++)
            ChatTokenCard(
              key: ValueKey<int>(index),
              address: _address,
              onNavigate: navigated.add,
            ),
        ],
      ),
    ),
    market: market,
    meta: meta,
    settle: settle,
    overrides: <Override>[
      loopDeviceTransportProvider.overrideWithValue(_Transport(transport)),
      ...overrides,
    ],
  );
  return navigated;
}

/// What the device reports about its network, held still for one test.
final class _Transport implements LoopDeviceTransport {
  const _Transport(this.value);

  final bool? value;

  @override
  Future<bool?> hasTransport() async => value;
}

void main() {
  group('an address is recognised, a ticker is not', () {
    test(
      'one address, however it was capitalised, is one lower-cased read',
      () {
        expect(loopDetectChatTokenAddresses('看看 $_address'), <String>[
          _address,
        ]);
        expect(
          loopDetectChatTokenAddresses(
            _address.toUpperCase().replaceFirst('0X', '0x'),
          ),
          <String>[_address],
        );
        expect(loopDetectChatTokenAddresses('$_address 和 $_address'), <String>[
          _address,
        ]);
      },
    );

    test('a ticker is never an identity', () {
      expect(loopDetectChatTokenAddresses(r'$MCAT 内盘 61%'), isEmpty);
      expect(loopDetectChatTokenAddresses(r'$PEPE $LOOP'), isEmpty);
    });

    test('a hash, a truncation and a glued word are not addresses', () {
      // 32 bytes: the first 40 hex characters of a transaction hash would
      // otherwise read as somebody else's contract.
      expect(loopDetectChatTokenAddresses(s5TxHash), isEmpty);
      expect(loopDetectChatTokenAddresses(s5PoolId), isEmpty);
      expect(loopDetectChatTokenAddresses(_address.substring(0, 41)), isEmpty);
      expect(loopDetectChatTokenAddresses('${_address}ab'), isEmpty);
      expect(loopDetectChatTokenAddresses('word$_address'), isEmpty);
      expect(loopDetectChatTokenAddresses('0xZZ'), isEmpty);
    });

    test('a message opens at most three cards, in writing order', () {
      final second = '0x${'1' * 40}';
      final third = '0x${'2' * 40}';
      final fourth = '0x${'3' * 40}';
      expect(
        loopDetectChatTokenAddresses('$_address $second $third $fourth'),
        <String>[_address, second, third],
      );
      expect(loopChatTokenCardsPerMessage, 3);
    });

    test('the read identity is the canonical asset id', () {
      final assetId = loopChatTokenAssetId(
        _address.toUpperCase().replaceFirst('0X', '0x'),
      );
      expect(assetId, 'eip155:56:$_address');
      expect(MarketAssetRoute.isCanonical(assetId), isTrue);
    });
  });

  group('the card states what it read', () {
    testWidgets('while the read is in flight nothing is claimed', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(pending: true),
        ),
        settle: false,
      );

      expect(find.text(loopChatTokenCardKicker), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('chat-token-card-loading-$_address')),
        findsOneWidget,
      );
      expect(find.text('识别中…'), findsOneWidget);
      expect(find.text('等待数据'), findsNWidgets(3));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('图表')),
        matchesSemantics(
          label: '图表',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a read asset carries identity, quote, metrics and facts', (
      tester,
    ) async {
      final navigated = await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            value: s5Detail(security: _security(), community: _community()),
          ),
        ),
      );

      expect(
        find.byKey(ValueKey<String>('chat-token-card-$_address')),
        findsOneWidget,
      );
      expect(find.text('WBNB'), findsOneWidget);
      expect(find.text(loopChatTokenShortAddress(_address)), findsOneWidget);
      expect(find.text(r'$747.39'), findsOneWidget);
      // 市值 was not reported; the cell says so instead of printing 0.
      expect(find.text('未报告'), findsOneWidget);
      expect(find.textContaining('LOOP 社区 PEPE 社区'), findsOneWidget);
      expect(find.textContaining('检测到 mint 函数'), findsOneWidget);
      // A fact the provider answered "false" for is not a card line.
      expect(find.textContaining('合约已验证开源'), findsNothing);
      expect(find.textContaining('报价 来源 DexScreener'), findsOneWidget);
      // The opaque identity never reaches the screen; the address does.
      expect(find.textContaining('eip155'), findsNothing);

      await tester.tap(find.text('图表'));
      await tester.pump();
      expect(navigated, <String>[
        MarketAssetRoute.token('eip155:56:$_address'),
      ]);

      await tester.tap(find.text('社区'));
      await tester.pump();
      expect(navigated.last, contains('c0ffee00-0000-4000-8000-000000000001'));
    });

    testWidgets('buy and sell stay on the card and state why they are shut', (
      tester,
    ) async {
      final navigated = await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(value: s5Detail()),
        ),
      );

      expect(find.text('买入'), findsOneWidget);
      expect(find.text('卖出'), findsOneWidget);
      expect(find.textContaining('买入与卖出现在不可用'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      for (final label in const <String>['买入', '卖出']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
      }
      semantics.dispose();
      await tester.tap(find.text('买入'), warnIfMissed: false);
      await tester.tap(find.text('卖出'), warnIfMissed: false);
      await tester.pump();
      expect(navigated, isEmpty);
    });

    testWidgets('no bound community closes the community action', (
      tester,
    ) async {
      final navigated = await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(value: s5Detail()),
        ),
      );

      expect(find.text('暂无 LOOP 社区'), findsOneWidget);
      await tester.tap(find.text('社区'), warnIfMissed: false);
      await tester.pump();
      expect(navigated, isEmpty);
    });

    testWidgets('an unregistered address is answered, and says so', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(value: _unregisteredDetail()),
        ),
      );

      // No ticker was reported, so the address is what the card prints, and
      // the line under it names the chain rather than the same address again.
      expect(
        find.text(loopTruncatedAssetId('eip155:56:$_address')),
        findsOneWidget,
      );
      expect(find.text('BNB Smart Chain'), findsOneWidget);
      expect(find.text(r'$2,575.14'), findsOneWidget);
      expect(
        find.textContaining('资产目录状态 · 未登记 · 身份来自 GeckoTerminal'),
        findsOneWidget,
      );
      // There is no holder page for an address outside the registry, and the
      // cell says which gap it is.
      expect(find.text('未收录'), findsOneWidget);
      expect(find.text('暂无 LOOP 社区'), findsOneWidget);
    });

    // S57: the server answered 200 and said it has no identity for this
    // address. The card states that, shows the address it asked about, and
    // holds the retry shut while the provider's quota is spent.
    testWidgets('an address nothing could describe says so, not a ticker', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5UnreadableDetail(assetId: 'eip155:56:$_address'),
        ),
      );
      await _pumpCard(tester, market: market);

      expect(
        find.byKey(ValueKey<String>('chat-token-card-unavailable-$_address')),
        findsOneWidget,
      );
      expect(
        find.text(
          '这个地址暂时读不到 · '
          '${loopReasonCodeText('MARKET_PROVIDER_RATE_LIMITED')}',
        ),
        findsOneWidget,
      );
      // The address it asked about, and nothing invented to head the card.
      expect(find.text(loopChatTokenShortAddress(_address)), findsNWidgets(2));
      expect(find.textContaining('MARKET_PROVIDER'), findsNothing);
      // Every figure beside it is unavailable for the same reason.
      expect(find.text('数据不可得'), findsNWidgets(3));
      expect(find.text('没有读到报价'), findsOneWidget);

      // The retry is on the card and cannot be spent while the quota is out.
      final reads = market.assetReads.length;
      await tester.tap(find.text('重试'), warnIfMissed: false);
      await tester.pump();
      expect(market.assetReads.length, reads);
    });

    testWidgets('an unreadable address that is not rate limited may retry', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5UnreadableDetail(
            assetId: 'eip155:56:$_address',
            reasonCode: 'MARKET_PROVIDER_UNREACHABLE',
          ),
        ),
      );
      await _pumpCard(tester, market: market);

      final reads = market.assetReads.length;
      await tester.tap(find.text('重试'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(market.assetReads.length, greaterThan(reads));
    });

    testWidgets('an address the registry does not carry says exactly that', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.notFound,
          ),
        ),
      );

      expect(
        find.byKey(ValueKey<String>('chat-token-card-unlisted-$_address')),
        findsOneWidget,
      );
      // Decision 0183: an unlisted contract is one weak line, not a strip.
      expect(
        tester.widget(
          find.byKey(ValueKey<String>('chat-token-card-unlisted-$_address')),
        ),
        isA<LoopInlineUnavailable>(),
      );
      expect(
        find.text('未收录的代币 · ${loopChatTokenShortAddress(_address)}'),
        findsOneWidget,
      );
      expect(find.byType(LoopTokenCard), findsNothing);
    });

    testWidgets('a closed provider renders the reason, not a figure', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.unavailable,
          ),
        ),
      );

      expect(
        find.byKey(ValueKey<String>('chat-token-card-unavailable-$_address')),
        findsOneWidget,
      );
      expect(find.text('数据不可得'), findsNWidgets(3));
      expect(
        find.text(loopChainFailureReason(LoopChainFailureKind.unavailable)),
        findsOneWidget,
      );
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('a closed capability renders the server own reason', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(value: s5Detail()),
        ),
        meta: s5MetaSnapshot(
          marketRead: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(ValueKey<String>('chat-token-card-unavailable-$_address')),
        findsOneWidget,
      );
      expect(
        find.text(loopReasonCodeText('MARKET_RUNTIME_UNAVAILABLE')),
        findsOneWidget,
      );
    });

    testWidgets('an offline device says so and keeps the retry', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
        transport: false,
      );

      expect(
        find.byKey(ValueKey<String>('chat-token-card-offline-$_address')),
        findsOneWidget,
      );
      expect(
        tester.widget(
          find.byKey(ValueKey<String>('chat-token-card-offline-$_address')),
        ),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('重试'), findsOneWidget);
    });
  });

  // S253 (S237 / S240 device reports): a card read that failed while the
  // network was up said 「设备离线」 and its retry seemed to do nothing.
  group('S253 · a failed read is not an offline device', () {
    void bumpRecovery(WidgetTester tester) {
      ProviderScope.containerOf(
        tester.element(find.byType(ChatTokenCard).first),
      ).read(loopNetworkRecoveryTickProvider.notifier).bump();
    }

    testWidgets('a connection failure with a network up says 加载失败', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5Detail(),
          failure: LoopChainFailureKind.offline,
          failingResolves: 1,
        ),
      );
      await _pumpCard(tester, market: market, transport: true);

      expect(
        find.byKey(ValueKey<String>('chat-token-card-offline-$_address')),
        findsNothing,
      );
      expect(find.textContaining('设备离线'), findsNothing);
      expect(
        find.byKey(ValueKey<String>('chat-token-card-failed-$_address')),
        findsOneWidget,
      );
      expect(find.text(loopChatTokenCardFailedMessage), findsOneWidget);

      // The whole line is the retry, and the retry is a new read.
      await tester.tap(find.text(loopChatTokenCardFailedMessage));
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(2));
      expect(
        find.byKey(ValueKey<String>('chat-token-card-$_address')),
        findsOneWidget,
      );
    });

    testWidgets('a platform that cannot say is not offline either', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );
      expect(find.text(loopChatTokenCardFailedMessage), findsOneWidget);
      expect(find.textContaining('设备离线'), findsNothing);
    });

    testWidgets('a timed-out read is a failed load with a retry', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.timedOut,
          ),
        ),
        transport: true,
      );
      expect(find.text(loopChatTokenCardFailedMessage), findsOneWidget);
    });

    testWidgets('the connection coming back retries once, by itself', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5Detail(),
          failure: LoopChainFailureKind.readFailed,
          failingResolves: 1,
        ),
      );
      await _pumpCard(tester, market: market, transport: true);
      expect(find.text(loopChatTokenCardFailedMessage), findsOneWidget);
      expect(market.assetReads, hasLength(1));

      bumpRecovery(tester);
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(2));
      expect(
        find.byKey(ValueKey<String>('chat-token-card-$_address')),
        findsOneWidget,
      );
    });

    testWidgets('one failure buys one automatic retry, not one per tick', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          failure: LoopChainFailureKind.readFailed,
        ),
      );
      await _pumpCard(tester, market: market, transport: true);
      expect(market.assetReads, hasLength(1));

      bumpRecovery(tester);
      await tester.pumpAndSettle();
      bumpRecovery(tester);
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(2));
      expect(find.text(loopChatTokenCardFailedMessage), findsOneWidget);
    });

    testWidgets('a card shown again after a failure asks once more', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5Detail(),
          failure: LoopChainFailureKind.readFailed,
          failingResolves: 1,
        ),
      );
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      await pumpS5Page(
        tester,
        Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (context, visible, _) => ListView(
              children: <Widget>[
                const ChatTokenCard(key: ValueKey<int>(0), address: _address),
                if (visible)
                  const ChatTokenCard(key: ValueKey<int>(1), address: _address),
              ],
            ),
          ),
        ),
        market: market,
        overrides: <Override>[
          loopDeviceTransportProvider.overrideWithValue(const _Transport(true)),
        ],
      );
      expect(market.assetReads, hasLength(1));
      expect(find.text(loopChatTokenCardFailedMessage), findsNWidgets(2));

      // The second bubble scrolls out and back: a new card element mounts.
      shown.value = false;
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(1));
      shown.value = true;
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(2));
      expect(
        find.byKey(ValueKey<String>('chat-token-card-$_address')),
        findsNWidgets(2),
      );
    });

    testWidgets('an unlisted contract is an answer and is never retried', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          failure: LoopChainFailureKind.notFound,
        ),
      );
      await _pumpCard(tester, market: market, transport: true);
      bumpRecovery(tester);
      await tester.pumpAndSettle();
      expect(market.assetReads, hasLength(1));
    });
  });

  group('the conversation reads one address once', () {
    testWidgets('three bubbles naming the same contract are one read', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(value: s5Detail()),
      );
      await _pumpCard(tester, market: market, cards: 3);

      expect(market.assetReads, <String>['eip155:56:$_address']);
      expect(market.intervals, <LoopCandleInterval>[
        LoopCandleInterval.oneHour,
      ]);
      expect(find.byType(LoopTokenCard), findsNWidgets(3));
    });

    test('an answer is held for a minute and no longer', () {
      final read = DateTime.utc(2026, 9, 20, 12);
      final entry = ChatTokenCardEntry(
        address: _address,
        assetId: 'eip155:56:$_address',
        asset: const LoopChainResourceState<MarketAssetDetail>(
          mode: LoopChainGatewayMode.production,
          phase: LoopChainViewPhase.ready,
        ),
        candles: const LoopChainResourceState<MarketCandleSeries>(
          mode: LoopChainGatewayMode.production,
          phase: LoopChainViewPhase.ready,
        ),
        readAt: read,
      );
      expect(loopChatTokenCardFreshness, const Duration(seconds: 60));
      expect(entry.isStale(read.add(const Duration(seconds: 59))), isFalse);
      expect(entry.isStale(read.add(const Duration(seconds: 60))), isTrue);
    });
  });

  test('the composer promises the recognition and nothing more', () {
    expect(loopChatComposerHint, contains('贴合约地址'));
    expect(loopChatComposerHint, contains('发消息'));
    expect(loopChatComposerHint.contains('AI'), isFalse);
    // It has to stay on one line beside the attachment and send controls.
    expect(loopChatComposerHint.runes.length, lessThanOrEqualTo(16));
  });
}
