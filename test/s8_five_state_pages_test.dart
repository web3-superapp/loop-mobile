import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The five reviewed states for the nine business pages that reached the 93-page
/// acceptance matrix with **no** state pinned by a test of their own
/// (`LOOP/docs/acceptance/93-pages.md` §3, the 0/5 row).
///
/// Each page gets one case per state. Where a state cannot be reached — an
/// `empty` phase a controller can never publish, or a permission a page never
/// asks the device for — the case still exists: it names the reason and asserts
/// that the page renders its honest projection instead of a zero, a fixture or
/// the wrong state block.
///
/// The shared state blocks (`LaunchStateBlock`, `LoopChainStateBlock`) are not
/// evidence on their own: every expectation below names one page's own key
/// prefix, so a block that stopped being reachable from that page fails here.

// ---------------------------------------------------------------------------
// launch-detail / launch-tier / launch-holders / launch-graduation /
// loop-economy / mining-rules — one table, five states each.
// ---------------------------------------------------------------------------

typedef _S7Ports = ({LaunchGateway? launch, MiningGateway? mining});

final class _S7StateCase {
  const _S7StateCase({
    required this.slug,
    required this.page,
    required this.ports,
    required this.readyKey,
    required this.emptyReason,
  });

  /// The manifest slug, which is also the page's state-block key prefix.
  final String slug;
  final Widget page;

  /// Builds the ports for one state. Exactly one of the two answers is the
  /// resource this page reads; the rest keep their defaults.
  final _S7Ports Function({LaunchFailureKind? failure, bool pending}) ports;

  /// A key that only exists once the page rendered its loaded projection. It
  /// proves the successful read did not fall through to an empty block.
  final String readyKey;

  /// Why `empty` is not a state this page can reach.
  final String emptyReason;
}

_S7Ports _launchPorts(FakeLaunchGateway gateway) =>
    (launch: gateway, mining: null);

final List<_S7StateCase> _s7Cases = <_S7StateCase>[
  _S7StateCase(
    slug: 'launch-detail',
    page: const LaunchDetailScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: failure == null && !pending ? s7Detail() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-detail-slots',
    emptyReason:
        'GET /v2/launches/{launchId} 要么返回一个项目，要么失败；契约里没有'
        '「读到了但没有内容」这一档，所以 launch-detail 永远到不了 empty 相。',
  ),
  _S7StateCase(
    slug: 'launch-tier',
    page: const LaunchTierScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        eligibility: S7Answer<LaunchEligibility>(
          value: failure == null && !pending ? s7Eligibility() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-tier-result',
    emptyReason:
        '资格结果永远是一条记录：没有配置模式时 `mode: unavailable` + `tier: null`，'
        '仍然是一条读到的资格，不是空列表。',
  ),
  _S7StateCase(
    slug: 'launch-holders',
    page: const LaunchHoldersScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        holders: S7Answer<LaunchHolders>(
          value: failure == null && !pending ? s7Holders() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-holders-notice',
    emptyReason:
        '持有人分布本身就是 `{status: unavailable}`：读成功时页面渲染三个不可用块，'
        '「没有来源」与「分布为零」是两回事，所以这里不能出现空状态。',
  ),
  _S7StateCase(
    slug: 'launch-graduation',
    page: const LaunchGraduationScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: failure == null && !pending ? s7Detail() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-graduation-notice',
    emptyReason: '毕业四步由契约固定给出，读成功时一定有四行 pending；没有「零步骤」这种响应。',
  ),
  _S7StateCase(
    slug: 'loop-economy',
    page: const LoopEconomyScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        economy: S7Answer<LaunchEconomy>(
          value: failure == null && !pending ? s7Economy() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'loop-economy-projects',
    emptyReason: '账本是一组计数，读成功时计数可以为 0 但对象一定存在，因此没有空状态。',
  ),
  _S7StateCase(
    slug: 'mining-rules',
    page: const MiningRulesScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => (
      launch: null,
      mining: FakeMiningGateway(
        rules: S7Answer<MiningRules>(
          value: failure == null && !pending ? s7MiningRules() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'mining-rules-notice',
    emptyReason:
        '规则响应永远带 `baseline`：没有已批准版本时页面渲染 baseline 的不可用原因，'
        '这是「未批准」不是「没有规则」。',
  ),
];

void main() {
  for (final testCase in _s7Cases) {
    group('${testCase.slug} · five states', () {
      testWidgets('${testCase.slug} loading shows a skeleton and no fact', (
        tester,
      ) async {
        final ports = testCase.ports(pending: true);
        await pumpS7Page(
          tester,
          testCase.page,
          launch: ports.launch,
          mining: ports.mining,
          settle: false,
        );

        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-loading')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>(testCase.readyKey)),
          findsNothing,
          reason: 'a skeleton must not be accompanied by the loaded body',
        );
      });

      testWidgets(
        '${testCase.slug} empty is unreachable, so the page states the reason',
        (tester) async {
          final ports = testCase.ports();
          await pumpS7Page(
            tester,
            testCase.page,
            launch: ports.launch,
            mining: ports.mining,
          );

          // The reason lives in the case so the matrix can quote it verbatim.
          expect(testCase.emptyReason, isNotEmpty);
          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
            findsNothing,
            reason: testCase.emptyReason,
          );
          await scrollToS7Section(
            tester,
            find.byKey(ValueKey<String>(testCase.readyKey)),
          );
          expect(
            find.byKey(ValueKey<String>(testCase.readyKey)),
            findsOneWidget,
          );
        },
      );

      testWidgets('${testCase.slug} offline pauses instead of erroring', (
        tester,
      ) async {
        final ports = testCase.ports(failure: LaunchFailureKind.offline);
        await pumpS7Page(
          tester,
          testCase.page,
          launch: ports.launch,
          mining: ports.mining,
        );

        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-error')),
          findsNothing,
        );
        expect(find.text('离线 · 显示缓存'), findsOneWidget);
        expect(find.textContaining('已暂停：'), findsOneWidget);
      });

      testWidgets('${testCase.slug} an unexpected failure is an error state', (
        tester,
      ) async {
        final ports = testCase.ports(failure: LaunchFailureKind.unexpected);
        await pumpS7Page(
          tester,
          testCase.page,
          launch: ports.launch,
          mining: ports.mining,
        );

        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-error')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
          findsNothing,
          reason: 'a failed read is never presented as "there is nothing"',
        );
        expect(find.byKey(ValueKey<String>(testCase.readyKey)), findsNothing);
      });

      testWidgets(
        '${testCase.slug} a refused read renders the permission state',
        (tester) async {
          final ports = testCase.ports(
            failure: LaunchFailureKind.permissionDenied,
          );
          await pumpS7Page(
            tester,
            testCase.page,
            launch: ports.launch,
            mining: ports.mining,
          );

          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-permission')),
            findsOneWidget,
          );
          expect(find.textContaining('当前账号无权执行此操作'), findsWidgets);
          expect(find.byKey(ValueKey<String>(testCase.readyKey)), findsNothing);
        },
      );
    });
  }

  // -------------------------------------------------------------------------
  // chart-full
  // -------------------------------------------------------------------------

  group('chart-full · five states', () {
    testWidgets('chart-full loading shows a chart skeleton and no candle', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(pending: true),
        ),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('candles-state-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('USDT per WBNB'), findsNothing);
    });

    testWidgets('chart-full an interval with no trade is empty, not zero', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            value: s5Series(items: const <LoopCandle>[]),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('candles-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('空桶不会补 0'), findsOneWidget);
      expect(find.text('O 0'), findsNothing);
    });

    testWidgets(
      'chart-full an unreadable series is an error, not a flat line',
      (tester) async {
        await pumpS5Page(
          tester,
          const FullChartScreen(assetId: s5WbnbAssetId),
          market: FakeMarketReadGateway(
            candles: S5Answer<MarketCandleSeries>(
              failure: LoopChainFailureKind.invalidData,
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('candles-state-error')),
          findsOneWidget,
        );
        expect(find.textContaining('O '), findsNothing);
      },
    );

    testWidgets('chart-full offline pauses the chart and keeps the intervals', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('candles-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('candles-state-error')),
        findsNothing,
      );
      // The interval bar is local state and stays usable while offline.
      expect(
        find.byKey(const ValueKey<String>('candle-interval-1h')),
        findsOneWidget,
      );
    });

    testWidgets('chart-full a refused series renders the permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('candles-state-permission')),
        findsOneWidget,
      );
      // The page asks the device for nothing: no camera, microphone or
      // notification permission is involved in reading a candle series.
      expect(find.textContaining('去系统设置'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // token-holders
  // -------------------------------------------------------------------------

  group('token-holders · five states', () {
    testWidgets('token-holders loading shows a skeleton and no count', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          holders: S5Answer<MarketHolders>(pending: true),
        ),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('token-holders-state-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('持有人'), findsWidgets);
      expect(find.textContaining('8,019,338'), findsNothing);
    });

    testWidgets('token-holders an unavailable count is stated, never a zero', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          holders: S5Answer<MarketHolders>(
            value: const MarketHolders(
              assetId: s5WbnbAssetId,
              holderCount: LoopFact.unavailable('HOLDER_COUNT_NOT_SUPPORTED'),
              distribution: LoopUnavailable(
                'HOLDER_DISTRIBUTION_NOT_SUPPORTED',
              ),
            ),
          ),
        ),
      );

      // `empty` is unreachable here: the read either returns a holders object
      // whose facts are unavailable, or it fails. A missing count is a stated
      // reason, not an empty page and never a 0.
      expect(
        find.byKey(const ValueKey<String>('token-holders-state-empty')),
        findsNothing,
      );
      expect(find.text('持有人总数不可用'), findsOneWidget);
      expect(find.text('0 持有人'), findsNothing);
    });

    testWidgets('token-holders an unreadable payload is an error state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          holders: S5Answer<MarketHolders>(
            failure: LoopChainFailureKind.invalidData,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('token-holders-state-error')),
        findsOneWidget,
      );
      expect(find.textContaining('持有人总数不可用'), findsOneWidget);
    });

    testWidgets('token-holders offline pauses without claiming zero holders', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          holders: S5Answer<MarketHolders>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('token-holders-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('token-holders-state-error')),
        findsNothing,
      );
      expect(find.text('0 持有人'), findsNothing);
    });

    testWidgets('token-holders a refused read renders the permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          holders: S5Answer<MarketHolders>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('token-holders-state-permission')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('token-holders-distribution')),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // group-info
  // -------------------------------------------------------------------------

  group('group-info · five states', () {
    testWidgets('group-info loading shows the resolve skeleton and no exit', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        groupAliasResolver: FakeGroupAliasResolverGateway(pending: true),
        settle: false,
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('group-info-state-loading')),
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-leave')),
        findsNothing,
      );
    });

    testWidgets(
      'group-info an unconfirmed membership is empty, not a failure',
      (tester) async {
        await pumpCommunityPage(
          tester,
          GroupInfoScreen(channelCid: testGroupCid),
          chat: FakeChatV2Gateway(),
          groupAliasResolver: FakeGroupAliasResolverGateway(
            failure: GroupAliasGatewayFailureKind.notFound,
          ),
        );

        await scrollToCommunitySection(
          tester,
          find.byKey(const ValueKey<String>('group-info-state-empty')),
        );
        expect(
          find.byKey(const ValueKey<String>('group-info-state-empty')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('group-info-resolve-failed')),
          findsNothing,
        );
        expect(find.textContaining('这不代表退出失败'), findsOneWidget);
      },
    );

    testWidgets('group-info a broken resolve is an error with a retry', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        groupAliasResolver: FakeGroupAliasResolverGateway(
          failure: GroupAliasGatewayFailureKind.invalidData,
        ),
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('group-info-resolve-failed')),
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-resolve-failed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-leave')),
        findsNothing,
      );
    });

    testWidgets('group-info offline is its own state, not a broken resolve', (
      tester,
    ) async {
      final resolver = FakeGroupAliasResolverGateway(
        failure: GroupAliasGatewayFailureKind.offline,
      );
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        groupAliasResolver: resolver,
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('group-info-state-offline')),
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-info-resolve-failed')),
        findsNothing,
      );
      expect(resolver.calls, hasLength(1));
    });

    testWidgets('group-info a refused exit never claims the group was left', (
      tester,
    ) async {
      final chat = FakeChatV2Gateway(
        failure: CommunityFailureKind.permissionDenied,
      );
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: chat,
        groupAliasResolver: FakeGroupAliasResolverGateway(),
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('group-info-leave')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('group-info-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出').last);
      await tester.pumpAndSettle();

      expect(chat.commands, contains('leave-group:$testResolvedGroupId'));
      expect(find.text('已退出群聊'), findsNothing);
      expect(find.textContaining('当前账号无权执行此操作'), findsOneWidget);
      // The page never asks the device for a permission of its own.
      expect(find.textContaining('去系统设置'), findsNothing);
    });
  });
}
