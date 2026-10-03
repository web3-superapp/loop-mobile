import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/launch/meme_screen.dart';
import 'package:loop_mobile/features/market/intelligence_screen.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/scoped_assets_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/community_test_harness.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('MEME keeps both views reachable at $width', (tester) async {
      await pumpS7Page(
        tester,
        const MemeScreen(),
        size: Size(width, 844),
        launch: FakeLaunchGateway(mode: LaunchGatewayMode.preview),
        overrides: [
          marketReadGatewayProvider.overrideWithValue(FakeMarketReadGateway()),
        ],
      );
      expect(find.text('MEME'), findsOneWidget);
      expect(find.byType(LaunchScreen), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('meme-destinations'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('loop-page-primary'))).dy,
        ),
      );
      final assetsTab = find.byKey(const ValueKey('meme-destination-平台 MEME'));
      expect(tester.getSize(assetsTab).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(assetsTab).width, greaterThanOrEqualTo(44));
      await tester.tap(assetsTab);
      await tester.pumpAndSettle();
      expect(find.byType(ScopedAssetsScreen), findsOneWidget);
      expect(find.text('上一页'), findsNothing);
      expect(find.text('下一页'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meme-destination-发射台')));
      await tester.pumpAndSettle();
      expect(find.byType(LaunchScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('intelligence switches scope and ranking at $width', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const IntelligenceScreen(),
        size: Size(width, 844),
        market: FakeMarketReadGateway(),
        mining: FakeMiningGateway(),
        overrides: [
          communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          launchGatewayProvider.overrideWithValue(FakeLaunchGateway()),
        ],
      );
      expect(find.text('情报'), findsOneWidget);
      expect(find.byType(MarketScreen), findsOneWidget);
      final marketMode = find.byKey(
        const ValueKey('intelligence-destination-行情'),
      );
      expect(tester.getSize(marketMode).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(marketMode).height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('社区资产'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScopedAssetsScreen>(find.byType(ScopedAssetsScreen))
            .scope,
        ScopedAssetsScope.community,
      );
      expect(find.text('全部资产'), findsOneWidget);
      await tester.tap(find.text('全部资产'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketScreen), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('intelligence-destination-算力榜')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiningRankScreen), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('intelligence-destinations')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey('mining-rank-capability-unavailable'),
                ),
              )
              .dy,
        ),
      );
      final page = tester.widget<LoopDashboardPage>(
        find.byKey(const ValueKey('mining-rank-screen')),
      );
      expect(page.titleWidget, isNull);
      await tester.tap(
        find.byKey(const ValueKey('intelligence-destination-行情')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarketScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ranking prefix precedes the confirmed snapshot card', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const MiningRankScreen(
        sectionsPrefix: [Text('Navigation', key: ValueKey('rank-nav'))],
      ),
      mining: FakeMiningGateway(),
      size: const Size(320, 844),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('rank-nav'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('loop-page-primary'))).dy,
      ),
    );
    expect(find.byKey(const ValueKey('mining-rank-reading')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked market leaves intelligence navigation reachable', (
    tester,
  ) async {
    await pumpS5Page(
      tester,
      const IntelligenceScreen(),
      market: FakeMarketReadGateway(),
      meta: s5MetaSnapshot(
        marketRead: LoopV2CapabilityAvailability.unavailable,
      ),
      size: const Size(320, 844),
    );
    expect(
      find.byKey(const ValueKey('market-capability-block')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('market-tabs')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('intelligence-destination-算力榜')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MiningRankScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('intelligence-destination-行情')));
    await tester.pumpAndSettle();
    expect(find.byType(MarketScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch project cards keep separate identities and callbacks', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpS7Page(
      tester,
      LaunchScreen(onOpenLaunch: opened.add),
      launch: FakeLaunchGateway(
        overview: S7Answer(
          value: s7Overview(
            live: [
              s7LaunchSummary(launchId: 'first', name: 'MoonCat'),
              s7LaunchSummary(launchId: 'second', name: 'Long project name'),
            ],
          ),
        ),
      ),
      size: const Size(320, 844),
    );
    final first = find.byKey(const ValueKey('launch-row-first'));
    final second = find.byKey(const ValueKey('launch-row-second'));
    expect(
      tester.widget<LoopRecordRow>(first).position,
      LoopRowPosition.single,
    );
    expect(
      tester.widget<LoopRecordRow>(second).position,
      LoopRowPosition.single,
    );
    expect(
      tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
      greaterThanOrEqualTo(10),
    );
    await tester.tap(second);
    expect(opened, ['second']);
    expect(tester.takeException(), isNull);
  });
}
