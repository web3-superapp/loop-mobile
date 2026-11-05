// S370c · decision 0295: 钱包 / 情报 / 挖矿 / 设置 second-level pages swept
// against the Figma's general rules (docs/58 §9): the 20 page margin, the
// 48 CTA, the row heights (chat 67, holdings 51), the 36 holdings face, the
// 8 button corner and the 12 card corner.
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_inbox_screen.dart';
import 'package:loop_mobile/features/profile/sign_out_button.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/loop_ground_probe.dart';
import 'support/s287_notifications.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _host(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The files this batch swept (decision 0295 §范围).
const List<String> _swept = <String>[
  'lib/features/wallet/send_screens.dart',
  'lib/features/wallet/swap_screens.dart',
  'lib/features/wallet/approval_screens.dart',
  'lib/features/wallet/tx_result_screen.dart',
  'lib/features/wallet/money_asset_picker.dart',
  'lib/features/wallet/money_actions_widgets.dart',
  'lib/features/wallet/wallet_read_screens.dart',
  'lib/features/wallet/wallet_read_widgets.dart',
  'lib/features/wallet/deferred_screens.dart',
  'lib/features/wallet/testnet_faucet/testnet_faucet_sheet.dart',
  'lib/features/market/alerts/alerts_screen.dart',
  'lib/features/market/watchlist/watchlist_editor_screen.dart',
  'lib/features/mining/mining_secondary_screens.dart',
  'lib/features/mining/referral_screen.dart',
  'lib/features/mining_rewards/mining_rewards_screen.dart',
  'lib/features/account/account_screens.dart',
  'lib/features/account/privy_login_screen.dart',
  'lib/features/account/loop_id_setup_screen.dart',
  'lib/features/account/onboarding_communities.dart',
  'lib/features/security/mfa/passkey_sheet.dart',
  'lib/features/security/mfa/mfa_sheet.dart',
  'lib/features/security/app_lock/app_lock_prompt.dart',
  'lib/features/security/step_up/step_up_widgets.dart',
  'lib/features/system/system_surfaces.dart',
  'lib/features/profile/settings/settings_screen.dart',
  'lib/features/profile/security/security_screens.dart',
  'lib/features/profile/sign_out_button.dart',
  'lib/features/profile/support/support_screen.dart',
  'lib/features/profile/presentation/avatar_editor.dart',
  'lib/features/profile/profile_v2_screens.dart',
  'lib/features/scan/scan_screen.dart',
  'lib/features/chain/chain_widgets.dart',
  'lib/features/beta_feedback/beta_feedback_screen.dart',
  'lib/features/beta_feedback/beta_feedback_mine_screen.dart',
];

void main() {
  loopWatchGround();

  group('页边距 20', () {
    test('no swept page puts its content on a 16 page edge', () {
      final edge16 = RegExp(r'fromLTRB\(\s*16,[^)]*,\s*16,|horizontal:\s*16\)');
      final offenders = <String>[
        for (final path in _swept)
          for (final (index, line) in File(path).readAsLinesSync().indexed)
            if (edge16.hasMatch(line)) '$path:${index + 1}',
      ];
      expect(offenders, isEmpty);
    });

    test('the chain blocks and the sign-out button default to 20', () {
      const footnote = LoopFootnote(text: 'x');
      const footer = LoopProvenanceFooter(text: 'x');
      const testnet = LoopTestnetNotice(visible: true);
      final signOut = LoopSignOutButton(onSignOut: () async {});
      expect(footnote.margin.left, LoopSpacing.page);
      expect(footnote.margin.right, LoopSpacing.page);
      expect(footer.margin.left, LoopSpacing.page);
      expect(testnet.margin.left, LoopSpacing.page);
      expect(testnet.margin.right, LoopSpacing.page);
      expect(signOut.padding.left, LoopSpacing.page);
      expect(signOut.padding.right, LoopSpacing.page);
    });
  });

  group('圆角', () {
    test('a picture tile on 意见反馈 is a 12 card, not a 10 tile', () {
      for (final path in <String>[
        'lib/features/beta_feedback/beta_feedback_screen.dart',
        'lib/features/beta_feedback/beta_feedback_mine_screen.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('LoopRadius.tile')),
        );
      }
    });

    testWidgets('兑换 · the asset key is a button at 8', (tester) async {
      await _host(tester, SwapAssetPickButton(label: 'BNB', onPressed: () {}));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SwapAssetPickButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, LoopRadius.button);
      expect(LoopRadius.button, BorderRadius.circular(8));
    });
  });

  group('按钮', () {
    testWidgets('登录 · a method is the 48 CTA at 16 / 600', (tester) async {
      await _host(
        tester,
        AuthMethodButton(
          key: const ValueKey<String>('auth-method'),
          label: 'Email',
          leading: const SizedBox.square(dimension: 16),
          busy: false,
          onPressed: () {},
          primary: true,
        ),
      );
      expect(AuthMethodButton.height, 48);
      final ink = tester.getSize(
        find.descendant(
          of: _key('auth-method'),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.height, 48);
      final word = tester.widget<Text>(find.text('Email'));
      expect(word.style?.fontSize, 16);
      expect(word.style?.fontWeight, FontWeight.w600);
    });
  });

  group('行高', () {
    testWidgets('通知 · a row is the chat row\'s 67 with a 1 px line', (
      tester,
    ) async {
      await pumpS287Inbox(
        tester,
        S287NotificationsGateway(items: s287MixedRows()),
      );
      expect(notificationRowHeight, LoopRowHeight.chat);
      final row = tester.getSize(_key('notification-row-${s287Id(2)}'));
      expect(row.height, closeTo(67, 0.5));
      final line = find.byKey(notificationRowDividerKey).first;
      expect(tester.getSize(line).height, 1);
      expect(tester.getTopLeft(line).dx, LoopSpacing.page);
      expect(tester.getTopRight(line).dx, 390 - LoopSpacing.page);
    });

    testWidgets('资产详情 · a trade row is 51', (tester) async {
      await _host(
        tester,
        TokenTradeRow(
          trade: MarketTrade(
            transactionHash: s5TxHash,
            logIndex: 12,
            blockNumber: BigInt.from(120640705),
            blockHash: s5BlockHash,
            blockTimestamp: DateTime.utc(2026, 9, 8, 7, 30),
            confirmations: 101,
            status: LoopConfirmationStatus.confirmed,
            direction: MarketTradeDirection.buy,
            amountAsset: Decimal.parse('1.25'),
            amountQuote: Decimal.parse('934.35'),
            quoteAssetId: s5UsdtAssetId,
            quoteSymbol: 'USDT',
            priceAfter: Decimal.parse('747.48'),
            poolAddress: s5PoolAddress,
            isOwn: true,
          ),
        ),
      );
      expect(TokenTradeRow.height, 51);
      expect(tester.getSize(find.byType(TokenTradeRow)).height, 51);
    });

    testWidgets('我的 · the Launch USD1 row is a 51 holdings row, face 36', (
      tester,
    ) async {
      final launch = LoopLaunchChainBalance(
        chainId: 'eip155:97',
        available: true,
        reasonCode: null,
        nativeBalance: null,
        usd1: const LoopLaunchUsd1Reading(
          balance: '25000000000000000000',
          allowance: '0',
        ),
      );
      await _host(
        tester,
        SizedBox(width: 390, child: walletLaunchUsd1Row(launch, hidden: false)),
      );
      final row = _key('wallet-launch-chain-usd1-row');
      expect(tester.getSize(row).height, LoopRowHeight.holdings);
      final logo = tester.widget<LoopTokenLogo>(
        find.descendant(of: row, matching: find.byType(LoopTokenLogo)),
      );
      expect(logo.size, LoopRowHeight.holdingsAvatar);
    });

    testWidgets('自选管理 · an editor row is 51 with a 36 mark', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 3,
              updatedAt: DateTime.utc(2026, 9, 8),
              groups: <WatchlistGroup>[
                WatchlistGroup(
                  key: 'default',
                  name: 'Default',
                  items: <WatchlistItem>[
                    WatchlistItem(
                      assetId: s5UsdtAssetId,
                      asset: s5Summary(symbol: 'USDT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      final logo = _key('watchlist-logo-$s5UsdtAssetId');
      await scrollToS5Section(tester, logo);
      expect(tester.getSize(logo), const Size.square(36));
      final row = _key('watchlist-item-$s5UsdtAssetId');
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(LoopRowHeight.holdings),
      );
    });
  });
}
