// S327 · decision 0257: UX-012 / 013 / 015 / 016 / 017.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_segmented_control.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _iconOf(WidgetTester tester, String glyphKey) => tester
    .widget<LoopIconButton>(
      find.descendant(
        of: _key(glyphKey),
        matching: find.byType(LoopIconButton),
      ),
    )
    .icon;

CommunitySummary _community(String id, String name, int members) {
  final base = testCommunity(
    communityId: id,
    name: name,
    memberCount: members,
    label: '算力社区',
  );
  return CommunitySummary(
    communityId: base.communityId,
    name: base.name,
    slug: base.slug,
    description: '$name 的一句简介',
    logoRef: base.logoRef,
    verificationStatus: base.verificationStatus,
    boundAssetKey: null,
    memberCount: base.memberCount,
    createdAt: base.createdAt,
    configVersion: base.configVersion,
    viewerMembership: CommunityDirectoryViewer.none,
    label: base.label,
  );
}

/// A history port that answers every window with the same short line.
final class S327FlatHistory implements WalletNetWorthHistoryGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async => LoopNetWorthHistory(
    range: range,
    points: <LoopNetWorthPoint>[
      LoopNetWorthPoint(
        at: DateTime.utc(2026, 10, 8),
        netWorthUsd: Decimal.parse('10'),
      ),
      LoopNetWorthPoint(
        at: DateTime.utc(2026, 10, 9),
        netWorthUsd: Decimal.parse('12'),
      ),
    ],
    change24h: null,
    fiat: null,
    source: 'loop_networth_snapshots',
    observedAt: DateTime.utc(2026, 10, 9),
  );
}

void main() {
  loopWatchGround();

  group('UX-012 · 邀请卡', () {
    testWidgets('a copy glyph turns into a tick and back after 3 seconds', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );
      // One card: the code and the link with their glyphs, share and poster;
      // no 复制邀请码 button.
      expect(_key('referral-invite-card'), findsOneWidget);
      expect(_key('referral-poster'), findsOneWidget);
      expect(find.widgetWithText(LoopButton, '复制邀请码'), findsNothing);
      expect(_iconOf(tester, 'referral-copy-code'), 'copy');

      await tester.tap(_key('referral-copy-code'));
      await tester.pump();
      expect(copied, 'LOOP-7HJKM');
      expect(_iconOf(tester, 'referral-copy-code'), 'check');

      await tester.pump(const Duration(seconds: 2));
      expect(_iconOf(tester, 'referral-copy-code'), 'check');
      await tester.pump(referralCopiedHold - const Duration(seconds: 2));
      await tester.pump();
      expect(_iconOf(tester, 'referral-copy-code'), 'copy');
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('leaving the page while ticked cancels the timer', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );
      await tester.tap(_key('referral-copy-code'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      // No pending timer is left behind (the test framework fails if so).
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('UX-013 · 发现社区', () {
    testWidgets('「热门社区」 and 「全部社区」 headings, no category chips', (
      tester,
    ) async {
      final page = CommunityDirectoryPage(
        items: <CommunitySummary>[
          _community('10000000-0000-4000-8000-000000000001', 'DeFi 早读会', 22),
          _community('10000000-0000-4000-8000-000000000002', 'Meme 观察室', 27),
          _community('10000000-0000-4000-8000-000000000003', '新手问答角', 19),
        ],
        nextCursor: null,
        recommendation: const CommunityRecommendation(
          recommendationId: '22222222-2222-4222-8222-222222222222',
          ruleVersion: 'rule:verified-members-v1',
        ),
        ordering: const CommunityOrderingApplied(
          sort: CommunityDirectorySort.members,
          basis: CommunityStoredBasis(),
        ),
      );
      await pumpCommunityPage(
        tester,
        SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
        community: FakeCommunityGateway(directoryPage: page),
      );
      expect(find.text('发现社区'), findsOneWidget);
      expect(find.text('规则与入驻'), findsOneWidget);
      expect(find.text('热门社区'), findsOneWidget);
      expect(find.text('全部社区'), findsOneWidget);
      expect(find.text('查看更多'), findsOneWidget);
      // The banner is the community with the most members.
      expect(
        _key('square-hot-10000000-0000-4000-8000-000000000002'),
        findsOneWidget,
      );
      // The order is a dropdown, not a chip row.
      expect(_key('square-community-sort'), findsOneWidget);
      expect(_key('square-sort-power'), findsNothing);
      // No category chips: the directory carries no category.
      for (final word in <String>['算力', 'Meme', 'DeFi', '新手']) {
        expect(
          find.byWidgetPredicate((w) => w is LoopSeg && w.label == word),
          findsNothing,
          reason: word,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 30));
    });
  });

  group('UX-015 · 钱包资产卡', () {
    // Decision 0259 (S329) overrides 0257's always-open chart: folded by
    // default, and the windows are quiet word tabs.
    testWidgets('the chart folds behind 今日盈亏 and its windows are quiet '
        'tabs', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(
            S327FlatHistory(),
          ),
        ],
      );
      expect(_key('wallet-networth-panel'), findsNothing);
      expect(_key('wallet-networth-expand'), findsOneWidget);
      await tester.tap(_key('wallet-pnl'));
      await tester.pumpAndSettle();
      expect(_key('wallet-networth-panel'), findsOneWidget);
      final ranges = tester.widget<WalletQuietTabs<LoopNetWorthRange>>(
        _key('wallet-networth-ranges'),
      );
      expect(ranges.options, LoopNetWorthRange.values);
      expect(
        find.descendant(
          of: _key('wallet-networth-ranges'),
          matching: find.byType(LoopSeg),
        ),
        findsNothing,
      );
    });
  });

  group('UX-016 · 兑换', () {
    testWidgets('slippage is a small segmented control; ⇅ sits centred on '
        'the card between 支付 and 获得', (tester) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        quotes: FakeSwapQuoteGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      final slippage = tester.widget<WalletSegmentedControl<int>>(
        _key('swap-slippage'),
      );
      expect(slippage.options, <int>[50, 100, 300]);
      expect(slippage.selected, 50);
      expect(
        find.descendant(
          of: _key('swap-slippage'),
          matching: find.byType(LoopSeg),
        ),
        findsNothing,
      );
      final panel = tester.getRect(_key('swap-panel'));
      final flip = tester.getCenter(_key('swap-flip'));
      expect((flip.dx - panel.center.dx).abs(), lessThan(1));
      final divider = tester.getCenter(_key('swap-divider'));
      expect((flip.dy - divider.dy).abs(), lessThan(1));
      expect(tester.getTopLeft(_key('swap-source-pick')).dy, lessThan(flip.dy));
      expect(
        tester.getTopLeft(_key('swap-destination-pick')).dy,
        greaterThan(flip.dy),
      );
      expect(tester.widget(_key('swap-evidence-pending')), isA<LoopNotice>());
    });
  });

  group('UX-017 · 我', () {
    testWidgets('设置 is the gear in the top bar; no 隐藏余额 capsule', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        ProfileSurfaceScreen.fromId('profile', onNavigate: (_) {}),
        wallet: FakeWalletReadGateway(),
      );
      final topbar = find.byType(LoopTopbar);
      expect(topbar, findsOneWidget);
      expect(
        find.descendant(of: topbar, matching: _key('profile-open-settings')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(_key('profile-open-settings')).dx,
        greaterThan(tester.getSize(find.byType(LoopDashboardPage)).width / 2),
      );
      expect(_key('profile-top-row'), findsNothing);
      // The eye is a small glyph inside the net worth card.
      expect(
        find.descendant(
          of: _key('profile-networth-panel'),
          matching: _key('profile-hide-balance'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(_key('profile-hide-balance')).width,
        LoopTouch.minimum,
      );
    });
  });
}
