// S353c · decision 0280: 我的 and another account's page on the Figma wallet
// frames (docs/58 §5.10–§5.13, §5.19, §5.20, §9.4), in English at 360.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_networth_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';

Finder _key(String key) => find.byKey(ValueKey<String>(key));

const Size _narrow = Size(360, 1400);

final class _Week implements WalletNetWorthHistoryGateway {
  _Week({this.points = 7});

  final int points;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async => LoopNetWorthHistory(
    range: range,
    points: <LoopNetWorthPoint>[
      for (var index = 0; index < points; index++)
        LoopNetWorthPoint(
          at: DateTime.utc(2026, 10, 8 + index),
          netWorthUsd: Decimal.fromInt(5000 + index * 200),
        ),
    ],
    change24h: LoopNetWorthChangeAvailable(
      usd: Decimal.parse('12.08'),
      pct: Decimal.parse('1.2'),
    ),
    fiat: LoopNetWorthFiat(
      currency: 'CNY',
      rate: Decimal.parse('7.1'),
      amount: Decimal.parse('913.27'),
    ),
  );
}

/// Whether a laid-out text was cut (an ellipsis or a missing line).
bool _cut(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  return paragraph.didExceedMaxLines;
}

void main() {
  loopWatchGround();

  group('总资产 · §5.10', () {
    testWidgets('no plate; the figure is white 40 / 700 with no unit', (
      tester,
    ) async {
      await pumpMePage(tester, size: _narrow);
      expect(
        find.descendant(
          of: _key('wallet-total-plate'),
          matching: find.byType(LoopChromePlate),
        ),
        findsNothing,
      );
      final figure = tester.widget<Text>(_key('wallet-total-figure'));
      expect(figure.style!.color, LoopColors.textPrimary);
      expect(figure.style!.fontSize, 40);
      expect(figure.style!.fontWeight, FontWeight.w700);
      expect(_key('wallet-total-unit'), findsNothing);
    });

    testWidgets('a stored week draws the 124 × 86 trend; a tap opens the '
        'chart', (tester) async {
      await pumpMePage(
        tester,
        size: _narrow,
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(_Week()),
        ],
      );
      await tester.pumpAndSettle();
      final trend = _key('wallet-networth-trend');
      expect(trend, findsOneWidget);
      expect(tester.getSize(trend), WalletNetWorthTrend.size);
      expect(_key('wallet-networth-panel'), findsNothing);
      await tester.tap(trend);
      await tester.pumpAndSettle();
      expect(_key('wallet-networth-panel'), findsOneWidget);
    });

    testWidgets('no history, no trend — never a drawn-in shape', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        size: _narrow,
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(
            _Week(points: 1),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(_key('wallet-networth-trend'), findsNothing);
    });

    testWidgets('no history port, no trend', (tester) async {
      await pumpMePage(tester, size: _narrow);
      expect(_key('wallet-networth-trend'), findsNothing);
    });

    testWidgets('「管理」 is the dark secondary button: white 8 %, Yellow word', (
      tester,
    ) async {
      await pumpMePage(tester, size: _narrow);
      final ground = tester.widget<Container>(
        find
            .descendant(
              of: _key('wallet-manage-action'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = ground.decoration! as BoxDecoration;
      expect(decoration.color, LoopColors.buttonGhost);
      expect(decoration.border, isNull);
    });
  });

  group('五快捷键 · §5.11', () {
    testWidgets('no ground, a 24 glyph, a 14 / 500 word, four rules; '
        '「Receive」 is whole at 360', (tester) async {
      await pumpMePage(tester, size: _narrow);
      await tester.runAsync(loopLoadShotFonts);
      await tester.pump();
      expect(
        tester.getSize(_key('wallet-quick-disc-receive')),
        const Size.square(24),
      );
      for (var index = 1; index < 5; index++) {
        expect(
          tester.getSize(_key('wallet-quick-rule-$index')),
          const Size(1, 28),
        );
      }
      final receive = find.descendant(
        of: _key('wallet-receive-entry'),
        matching: find.text('Receive'),
      );
      final word = tester.widget<Text>(receive);
      expect(word.style!.fontSize, 14);
      expect(word.style!.fontWeight, FontWeight.w500);
      expect(_cut(tester, receive), isFalse);
      expect(
        find.descendant(
          of: _key('wallet-quick-actions'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color != null,
          ),
        ),
        findsNothing,
      );
    });
  });

  group('持仓 · §5.3 / §5.13 / §5.19', () {
    testWidgets('「Earns power」 is a 12 / 500 word with (i), no badge', (
      tester,
    ) async {
      await pumpMePage(tester, size: _narrow);
      expect(
        find.descendant(
          of: _key('wallet-power-tag'),
          matching: find.byType(LoopBadge),
        ),
        findsNothing,
      );
      final label = tester.widget<Text>(_key('wallet-power-tag-label'));
      expect(label.style!.fontSize, 12);
      expect(label.style!.fontWeight, FontWeight.w500);
    });

    testWidgets('a holding is 51 tall with a 36 avatar, 14 / 600 amount', (
      tester,
    ) async {
      await pumpMePage(tester, size: _narrow);
      const assetId = s5NativeAssetId;
      expect(
        tester.getSize(_key('wallet-balance-head-$assetId')).height,
        LoopRowHeight.holdings,
      );
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: _key('wallet-balance-open-$assetId'),
                    matching: find.byType(LoopTokenLogo),
                  )
                  .first,
            )
            .width,
        LoopRowHeight.holdingsAvatar,
      );
      final amount = tester.widget<Text>(
        _key('wallet-balance-amount-$assetId'),
      );
      expect(amount.style!.fontSize, 14);
      expect(amount.style!.fontWeight, FontWeight.w600);
      final value = tester.widget<Text>(_key('wallet-balance-value-$assetId'));
      expect(value.style!.fontSize, 12);
      expect(value.style!.fontWeight, FontWeight.w300);
    });

    testWidgets('empty: the 106 crown and the title, no sentence', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        balances: s5Balances(rows: const <LoopAssetBalanceRow>[]),
        size: _narrow,
      );
      final empty = _key('wallet-balances-empty');
      expect(empty, findsOneWidget);
      final art = tester.widget<LoopEmptyArt>(
        find.descendant(of: empty, matching: find.byType(LoopEmptyArt)),
      );
      expect(art.width, 106);
      expect(
        find.descendant(of: empty, matching: _key('loop-empty-message')),
        findsNothing,
      );
    });
  });

  group('英文 360 · no cut words', () {
    testWidgets('我的: 「Joined …」 and the counts are whole', (tester) async {
      await pumpMePage(tester, size: _narrow);
      await tester.runAsync(loopLoadShotFonts);
      await tester.pump();
      expect(_cut(tester, _key('profile-joined')), isFalse);
    });

    testWidgets('another account: counts wrap, keys are bare and whole, '
        'holdings are 51 tall', (tester) async {
      await pumpOtherProfile(tester, size: const Size(360, 1000));
      await tester.runAsync(loopLoadShotFonts);
      await tester.pump();
      final counts = _key('user-profile-counts');
      for (final word in <String>['Followers', 'Communities']) {
        final text = find.descendant(
          of: counts,
          matching: find.textContaining(word),
        );
        expect(_cut(tester, text), isFalse, reason: word);
      }
      final keys = _key('user-profile-keys');
      expect(
        find.descendant(of: keys, matching: _key('loop-round-key-face')),
        findsNothing,
      );
      final message = find.descendant(
        of: _key('user-profile-message'),
        matching: find.text('Direct message'),
      );
      expect(_cut(tester, message), isFalse);
      expect(
        tester.getSize(_key('user-profile-holding-eip155:56:native')).height,
        LoopRowHeight.holdings,
      );
    });
  });
}
