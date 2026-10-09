// S123g · IA cleanup (decision 0133; audit 2026-10-09 M14, m8–m16).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/notifications/loop_notification_navigation.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/profile/sign_out_button.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s8_harness.dart';

void main() {
  loopWatchGround();

  group('退出登录 (M14, m15)', () {
    testWidgets(
      '我: the tap asks first; cancel leaves, confirm signs out once',
      (tester) async {
        var signedOut = 0;
        final release = Completer<void>();
        await _pumpProfile(
          tester,
          onSignOut: () async {
            signedOut += 1;
            await release.future;
          },
        );
        final button = find.byKey(const ValueKey<String>('profile-sign-out'));
        await tester.scrollUntilVisible(
          button,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('sign-out-confirm-sheet')),
          findsOneWidget,
        );
        expect(find.text(loopSignOutConfirmTitle), findsOneWidget);
        expect(find.text(loopSignOutConfirmBody), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey<String>('community-confirm-cancel')),
        );
        await tester.pumpAndSettle();
        expect(signedOut, 0);

        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('community-confirm-accept')),
        );
        await tester.pump();
        expect(signedOut, 1);
        // While it runs the control says so and takes no second tap.
        expect(find.text('正在退出…'), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('sign-out-confirm-sheet')),
          findsNothing,
        );
        expect(signedOut, 1);
        release.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('我 and 设置 draw the same control', (tester) async {
      await _pumpProfile(tester, onSignOut: () async {});
      final profile = find.byKey(const ValueKey<String>('profile-sign-out'));
      await tester.scrollUntilVisible(
        profile,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget(profile), isA<LoopSignOutButton>());
      final profileButton = tester.widget<LoopButton>(
        find.descendant(of: profile, matching: find.byType(LoopButton)),
      );

      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}, onSignOut: () async {}),
        settings: FakeAccountSettingsGateway(),
      );
      final settings = find.byKey(const ValueKey<String>('settings-sign-out'));
      expect(tester.widget(settings), isA<LoopSignOutButton>());
      final settingsButton = tester.widget<LoopButton>(
        find.descendant(of: settings, matching: find.byType(LoopButton)),
      );
      expect(settingsButton.block, profileButton.block);
      expect(settingsButton.primary, profileButton.primary);
      expect(settingsButton.label, profileButton.label);
    });
  });

  group('设置 · stated values (m8)', () {
    testWidgets('语言 / 货币单位 / 主题 are read-only, not dead buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final opened = <String>[];
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: opened.add),
        settings: FakeAccountSettingsGateway(),
      );

      for (final key in <String>[
        'settings-language',
        'settings-display-currency',
        'settings-theme',
      ]) {
        final row = find.byKey(ValueKey<String>(key));
        final widget = tester.widget<LoopRecordRow>(row);
        expect(widget.onTap, isNull, reason: key);
        expect(widget.readOnly, isTrue, reason: key);
        // No ink to press, no chevron promising a page.
        expect(
          find.descendant(of: row, matching: find.byType(InkWell)),
          findsNothing,
          reason: key,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byWidgetPredicate(
              (widget) => widget is LoopIcon && widget.name == 'chevron',
            ),
          ),
          findsNothing,
          reason: key,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
      }
      expect(opened, isEmpty);
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('settings-theme')),
        ),
        matchesSemantics(label: '主题，深色，不可更改', isReadOnly: true),
      );
      expect(
        find.byKey(const ValueKey<String>('settings-fixed-values-note')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('我 · one entry per destination (m9)', () {
    testWidgets('no 好友 key; the request row is named after its page', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpProfile(tester, onNavigate: opened.add);

      expect(
        find.byKey(const ValueKey<String>('profile-open-friends')),
        findsNothing,
      );
      final requests = find.byKey(
        const ValueKey<String>('profile-open-friend-requests'),
      );
      await tester.scrollUntilVisible(
        requests,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<LoopRecordRow>(requests).title, '陌生人请求');
      expect(find.text('好友请求'), findsNothing);
      await tester.tap(requests);
      expect(opened, <String>['friend-requests']);
    });
  });

  group('钱包 · IA (m9, m14)', () {
    testWidgets('the total opens nothing; 交易历史 is named once', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      // 净值明细 was folded into this tab.
      expect(
        find.byKey(const ValueKey<String>('wallet-networth-entry')),
        findsNothing,
      );
      expect(
        tester
            .widget<LoopIconButton>(
              find.byKey(const ValueKey<String>('wallet-history-action')),
            )
            .label,
        '交易历史',
      );
      expect(find.text('授权与网络'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wallet-security-entry')),
        findsNothing,
      );
    });
  });

  group('兑换 · explanations behind (i)', () {
    testWidgets('the page is the form; the two notes open from the bar', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );

      expect(find.text('路由由供应商选择'), findsNothing);
      expect(find.text('算力影响不可用'), findsNothing);
      // The real limit stays, as one small line.
      expect(
        tester.widget(
          find.byKey(const ValueKey<String>('swap-evidence-pending')),
        ),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.byType(LoopNotice), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('swap-info-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('swap-info-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-routing-notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-power-notice')),
        findsOneWidget,
      );
      expect(find.textContaining('LOOP 不自建路由'), findsOneWidget);
      expect(find.textContaining('买入后的算力变化暂时读不到'), findsOneWidget);
    });
  });

  group('交易历史 · by day (m13)', () {
    final now = DateTime(2026, 10, 9, 15);

    test('a day reads as 今天, 昨天, a date, or a dated year', () {
      expect(
        walletActivityDayLabel(DateTime(2026, 10, 9, 0, 5), now: now),
        '今天',
      );
      expect(walletActivityDayLabel(DateTime(2026, 10, 8, 23), now: now), '昨天');
      expect(
        walletActivityDayLabel(DateTime(2026, 9, 16, 8), now: now),
        '9月16日',
      );
      expect(
        walletActivityDayLabel(DateTime(2025, 12, 31, 8), now: now),
        '2025年12月31日',
      );
    });

    test('runs of one day keep the tape order', () {
      final days = walletActivityDays(<LoopWalletActivityEntry>[
        _entry('a', DateTime(2026, 10, 9, 14)),
        _entry('b', DateTime(2026, 10, 9, 9)),
        _entry('c', DateTime(2026, 10, 8, 20)),
        _entry('d', DateTime(2026, 9, 1, 20)),
      ], now: now);
      expect(days.map((day) => day.label), <String>['今天', '昨天', '9月1日']);
      expect(days.first.entries.map((entry) => entry.logIndex), <int>[1, 2]);
    });

    testWidgets('the tape carries a header per day, rows unchanged', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: s5Activity(
              items: <LoopWalletActivityEntry>[
                _entry('a', DateTime(2026, 9, 8, 12)),
                _entry('b', DateTime(2026, 9, 8, 9)),
                _entry('c', DateTime(2026, 9, 1, 9)),
              ],
            ),
          ),
        ),
      );

      final first = find.byKey(
        const ValueKey<String>('tx-history-day-2026-09-08'),
      );
      final second = find.byKey(
        const ValueKey<String>('tx-history-day-2026-09-01'),
      );
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(find.byType(WalletActivityDayHeader), findsNWidgets(2));
      final rows = find.byType(LoopRecordRow);
      expect(rows, findsNWidgets(3));
      // Header, its two rows, the next header, its row.
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(rows.at(0)).dy),
      );
      expect(
        tester.getTopLeft(rows.at(1)).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(rows.at(2)).dy),
      );
    });
  });

  group('聊天 · 发起 steps aside (m10)', () {
    testWidgets('scrolling on hides it, scrolling back brings it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byKey(const ValueKey<String>('chat-tab-screen'))),
      ).go('/chat');
      await tester.pumpAndSettle();

      final slot = find.byKey(const ValueKey<String>('chat-create-slot'));
      expect(tester.widget<AnimatedSlide>(slot).offset, Offset.zero);

      void scroll(ScrollDirection direction, double pixels) {
        final context = tester.element(
          find.byKey(const ValueKey<String>('chat-tab-screen')),
        );
        UserScrollNotification(
          metrics: FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 2000,
            pixels: pixels,
            viewportDimension: 600,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
          context: context,
          direction: direction,
        ).dispatch(context);
      }

      scroll(ScrollDirection.reverse, 300);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedSlide>(slot).offset, isNot(Offset.zero));
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: slot, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );

      scroll(ScrollDirection.forward, 200);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedSlide>(slot).offset, Offset.zero);
    });
  });

  group('通知 · opens over the page (decision 0133)', () {
    test('a child page is pushed over the product', () {
      expect(
        loopNotificationOpenMode(target: '/market/alerts', current: '/wallet'),
        LoopNotificationOpenMode.push,
      );
      expect(
        loopNotificationOpenMode(
          target: '/community?id=x',
          current: '/chat/dm?peer=1',
        ),
        LoopNotificationOpenMode.push,
      );
    });

    test('a tab, a cold stack or an account gate is replaced', () {
      expect(
        loopNotificationOpenMode(target: '/chat', current: '/wallet/send'),
        LoopNotificationOpenMode.go,
      );
      expect(
        loopNotificationOpenMode(target: '/market/alerts', current: null),
        LoopNotificationOpenMode.go,
      );
      expect(
        loopNotificationOpenMode(target: '/market/alerts', current: '/'),
        LoopNotificationOpenMode.go,
      );
      for (final gate in <String>['/splash', '/auth', '/auth/loop-id']) {
        expect(
          loopNotificationOpenMode(target: '/market/alerts', current: gate),
          LoopNotificationOpenMode.go,
          reason: gate,
        );
      }
    });
  });
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  Future<void> Function()? onSignOut,
  ValueChanged<String>? onNavigate,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: ProviderScope(
        child: ProfileSurfaceScreen.fromId(
          'profile',
          onNavigate: onNavigate ?? (_) {},
          onSignOut: onSignOut,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LoopWalletActivityEntry _entry(String id, DateTime at) {
  final index = id.codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
  return LoopWalletActivityEntry(
    assetId: s5WbnbAssetId,
    symbol: 'WBNB',
    decimals: 18,
    direction: LoopTransferDirection.incoming,
    counterpartyAddress: s5Address,
    rawValue: '1000000000000000000',
    displayValue: s5Decimal('1'),
    transactionHash: s5TxHash,
    logIndex: index,
    blockNumber: BigInt.from(120628064 + index),
    blockHash: s5BlockHash,
    confirmations: 101,
    status: LoopConfirmationStatus.confirmed,
    observedAt: at.toUtc(),
  );
}
