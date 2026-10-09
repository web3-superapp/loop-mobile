import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

import 'support/loop_ground_probe.dart';
import 'support/meme_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Decision 0123 (S121c): the visual follow-ups to S121b.
void main() {
  loopWatchGround();
  Finder key(String value) => find.byKey(ValueKey<String>(value));

  group('1 · wallet asset rows are OKX rows', () {
    testWidgets('logo 36, symbol 18, amount 18, ≈\$ grey, the 96 × 44 pill', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );
      final row = key('wallet-balance-$s5NativeAssetId');
      await scrollToS5Section(tester, row);

      expect(
        find.descendant(of: row, matching: find.byType(LoopQuoteRow)),
        findsNothing,
        reason: 'the row itself is the quote row',
      );
      expect(tester.widget(row), isA<LoopQuoteRow>());
      final logo = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'LoopTokenLogo',
        ),
      );
      expect(tester.getSize(logo), const Size(36, 36));
      final symbol = tester.widget<Text>(
        find.descendant(of: row, matching: find.text('BNB')).first,
      );
      expect(symbol.style!.fontSize, 18);
      final amount = tester.widget<Text>(
        key('wallet-balance-amount-$s5NativeAssetId'),
      );
      expect(amount.style!.fontSize, 18);
      final pill = find.descendant(
        of: key('wallet-balance-change-$s5NativeAssetId'),
        matching: key('loop-change-pill'),
      );
      expect(tester.getSize(pill), loopChangePillSize);
      // The derived-price note is small type at the end of the grey line.
      final mark = tester.widget<Text>(
        key('wallet-balance-mark-$s5NativeAssetId'),
      );
      expect(mark.data, contains('以 WBNB 计价'));
      expect(mark.style!.fontSize, 11);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the zero switch is one line of text', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(),
                s5Row(
                  assetId: s5WbnbAssetId,
                  balance: LoopBalanceAvailable(
                    rawValue: '0',
                    displayBalance: Decimal.zero,
                    availableBalance: Decimal.zero,
                    spendableBalance: Decimal.zero,
                    gasReserve: Decimal.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await scrollToS5Section(tester, key('wallet-zero-toggle'));
      expect(find.text('显示 1 项零余额资产'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(key('wallet-zero-toggle'));
      await tester.pumpAndSettle();
      expect(find.text('隐藏零余额资产'), findsOneWidget);
      expect(key('wallet-balance-$s5WbnbAssetId'), findsOneWidget);
    });

    testWidgets('the Launch chain row has the same shape', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(launchChain: _launchChain()),
          ),
        ),
      );
      final row = key('wallet-launch-chain-row');
      await scrollToS5Section(tester, row);
      expect(tester.widget(row), isA<LoopQuoteRow>());
      expect(find.text('tBNB'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('可动用 2.495'), findsOneWidget);
      expect(find.text('手续费保留 0.005'), findsOneWidget);
    });
  });

  group('2 · launchpad trading pill', () {
    testWidgets('a 4px Lime bar under the percentage; graduated unchanged', (
      tester,
    ) async {
      await _pump(tester, MemeTokenCard(row: _meme()));
      final label = tester.getRect(key('meme-progress-label'));
      final bar = tester.getRect(key('meme-progress-fill'));
      expect(bar.height, 4);
      expect(bar.top, greaterThan(label.bottom));
      final fill = tester.widget<FractionallySizedBox>(
        key('meme-progress-fill'),
      );
      expect((fill.child! as ColoredBox).color, LoopColors.lime);
      expect(find.text('33%'), findsOneWidget);

      await _pump(
        tester,
        MemeTokenCard(row: _meme(status: 'graduated', progressBps: 10000)),
      );
      expect(key('meme-graduated-tag'), findsOneWidget);
      expect(key('meme-progress-fill'), findsNothing);
      expect(find.text('已毕业'), findsOneWidget);
    });

    testWidgets('the 快打满 hero card draws its ring and name', (tester) async {
      final row = _meme(progressBps: 9100);
      await _pump(tester, MemeHeroCard(row: row));
      expect(key('meme-hero-${row.memeTokenId}'), findsOneWidget);
      expect(key('meme-progress-ring'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(tester.getSize(find.byType(MemeHeroCard)), const Size(220, 120));
      expect(tester.takeException(), isNull);
    });
  });

  group('3 · rank podium', () {
    IntelRankEntry entry(int position, String name) => IntelRankEntry(
      id: 'user-$position',
      position: position,
      leading: (size) => SizedBox.square(dimension: size),
      name: name,
      figure: '${1000 - position}',
      weight: '1.$position',
    );

    testWidgets('two-line names, equal cards, faces 56 / 48 / 48', (
      tester,
    ) async {
      await _pump(
        tester,
        IntelRankPodium(
          entries: <IntelRankEntry>[
            entry(1, '冠军'),
            entry(2, '一个名字非常非常长的社区会被截成两行而不是一行显示'),
            entry(3, '季军'),
          ],
        ),
      );
      expect(tester.getSize(key('intel-rank-face-1')), const Size(56, 56));
      expect(tester.getSize(key('intel-rank-face-2')), const Size(48, 48));
      expect(tester.getSize(key('intel-rank-face-3')), const Size(48, 48));
      final heights = <double>[
        for (final place in <int>[1, 2, 3])
          tester.getSize(key('intel-rank-user-$place')).height,
      ];
      expect(heights.toSet(), hasLength(1));
      final name = tester.renderObject<RenderParagraph>(
        key('intel-rank-name-2'),
      );
      expect(tester.widget<Text>(key('intel-rank-name-2')).maxLines, 2);
      expect(name.didExceedMaxLines, isTrue);
      // The figures share one line across the three cards.
      expect(
        tester.getRect(find.text('998')).bottom,
        tester.getRect(find.text('997')).bottom,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('4 · chat list', () {
    test('no hairline between rows; the last row clears 「发起」', () {
      final source = File('lib/features/chat/stream_chat_inbox_page.dart')
          .readAsStringSync();
      expect(source, isNot(contains('defaultChannelListViewSeparatorBuilder')));
      expect(source, isNot(contains('StreamChannelListSeparator')));
      expect(source, contains('chatInboxListBottomPadding,'));
      // The button stands the tab bar's reserve above the list's end; the
      // last row clears it by its 56 and a 32 margin.
      expect(chatInboxFabClearance, 88);
      expect(chatInboxListBottomPadding, LoopLayout.tabPageBottomReserve + 88);
    });
  });

  group('5 · token 关于 link rows have marks', () {
    test('MEME links and the token community entry carry an icon', () {
      final meme = File('lib/features/meme/meme_token_screen.dart')
          .readAsStringSync();
      expect(meme, contains("('X', links.twitter, 'link')"));
      expect(meme, contains("('官网', links.website, 'globe')"));
      expect(meme, contains('leading: LoopRowIcon(icon: icon)'));
      final token = File('lib/features/market/token_screen.dart')
          .readAsStringSync();
      expect(token, contains("LoopRowIcon(icon: 'community')"));
    });
  });

  group('7 · lists that really ended draw nothing', () {
    test('launchpad, market, square and chat never print 没有更多', () {
      for (final path in <String>[
        'lib/features/meme/meme_launchpad.dart',
        'lib/features/market/market_screen.dart',
        'lib/features/square/square_screen.dart',
        'lib/features/square/square_community_list.dart',
        'lib/features/community/community_discover_screen.dart',
        'lib/features/chat/stream_chat_inbox_page.dart',
      ]) {
        final code = File(path)
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        expect(code, isNot(contains("'没有更多")), reason: path);
      }
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

MemeTokenRow _meme({String status = 'trading', int progressBps = 3327}) =>
    memePage(
      items: <Map<String, Object?>>[
        memeRowJson(
          status: status,
          progressBps: progressBps,
          pool: status == 'graduated'
              ? '0x7777777777777777777777777777777777777777'
              : null,
          graduatedAt: status == 'graduated'
              ? '2026-10-08T05:00:00.000Z'
              : null,
        ),
      ],
    ).items.single;

LoopLaunchChainBalance _launchChain() => LoopLaunchChainBalance(
  chainId: 'eip155:97',
  available: true,
  reasonCode: null,
  nativeBalance: LoopLaunchChainNativeBalance(
    assetId: 'eip155:97:native',
    symbol: 'tBNB',
    decimals: 18,
    rawValue: '2500000000000000000',
    displayBalance: Decimal.parse('2.5'),
    availableBalance: Decimal.parse('2.5'),
    spendableBalance: Decimal.parse('2.495'),
    gasReserve: Decimal.parse('0.005'),
    snapshot: LoopBalanceSnapshot(
      blockNumber: BigInt.from(52000000),
      blockHash: s5BlockHash,
      observedAt: DateTime.utc(2026, 9, 9, 10, 45, 5),
      confirmations: 5,
    ),
  ),
);
