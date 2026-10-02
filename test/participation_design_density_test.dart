import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

void main() {
  loopWatchGround();
  final pages = <String, Widget>{
    'mining': const MiningScreen(),
    'mining-assets': const MiningAssetsScreen(),
    'mining-rewards': const MiningRewardsScreen(),
    'mining-rank': const MiningRankScreen(),
    'mining-community': const MiningCommunityScreen(communityId: s7CommunityId),
    'mining-rules': const MiningRulesScreen(),
    'referral': const ReferralScreen(),
    'launch': const LaunchScreen(),
    'launch-detail': const LaunchDetailScreen(launchId: s7LaunchId),
    'launch-tier': const LaunchTierScreen(launchId: s7LaunchId),
    'loop-stake': const LoopStakeScreen(),
    'launch-trade': const LaunchTradeScreen(launchId: s7LaunchId),
    'launch-holders': const LaunchHoldersScreen(launchId: s7LaunchId),
    'launch-graduation': const LaunchGraduationScreen(launchId: s7LaunchId),
    'launch-history': const LaunchHistoryScreen(launchId: s7LaunchId),
    'launch-rounds': const LaunchRoundsScreen(launchId: s7LaunchId),
    'loop-economy': const LoopEconomyScreen(),
    'launch-apply': const LaunchApplyScreen(),
  };
  for (final width in [360.0, 390.0]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} gives its content room at $width', (
        tester,
      ) async {
        await pumpS7Page(
          tester,
          RepaintBoundary(
            key: const ValueKey("participation-capture"),
            child: entry.value,
          ),
          launch: FakeLaunchGateway(),
          mining: FakeMiningGateway(),
          referral: FakeReferralGateway(),
          size: Size(width, 844),
        );
        expect(tester.takeException(), isNull);
        final folios = find.byType(LoopFolioPrimary);
        if (folios.evaluate().isNotEmpty) {
          final rect = tester.getRect(folios.first);
          // Leave the majority of the viewport to the route's records/form.
          expect(rect.height, lessThan(240));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        final summary = find.byKey(const ValueKey('mining-summary-hero'));
        if (summary.evaluate().isNotEmpty) {
          expect(tester.getSize(summary).height, lessThan(340));
          for (final action in ['claim', 'assets']) {
            final rect = tester.getRect(
              find.byKey(ValueKey('mining-summary-hero-$action')),
            );
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.bottom, lessThan(550));
          }
        }
        if (const ['mining', 'launch', 'referral'].contains(entry.key)) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('participation-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('.tooling/participation-design');
            await directory.create(recursive: true);
            await File('${directory.path}/${entry.key}-${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
