import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Loading / Empty / Error / Offline for the ten Launch and Mining pages that
/// render their read states through `LaunchStateBlock`.
///
/// Two rules decide what every case below asserts.
///
/// **1. A shared block is never the evidence.** `LaunchStateBlock` keys itself
/// `<prefix>-state-*`, and the prefix is passed in by the page. Every
/// expectation here names one page's own prefix, so a page that stopped
/// routing its observation into the block — or that routed it with someone
/// else's prefix — fails here rather than riding on a sibling's test.
///
/// **2. `<prefix>-state-empty` is unreachable through the shared block.**
/// `LaunchViewPhase.empty` is only produced by `launchPhaseForFailure(null)`
/// (`launch_contract.dart:165`), and the single caller that can reach a page is
/// `LaunchResourceState.failed(kind)` (`launch_contract.dart:219`), whose
/// parameter is non-nullable — the controllers only ever call it with a real
/// kind (`launch_controllers.dart:62`, `mining_controllers.dart:42`). So the
/// Empty column is written as a **negative**: a successful read must render the
/// page's loaded projection and must not render the empty block. Each case
/// carries the model that proves "read succeeded but there is nothing" is not
/// in that resource's contract.
///
/// Three pages do own a real, page-local empty — `launch`, `launch-rounds` and
/// `launch-trade` — and those are pinned positively in bespoke cases at the
/// bottom of the file.
///
/// Offline is only written for `launch-trade`, `loop-stake` and `mining-rank`:
/// the other seven are already pinned in `s8_offline_permission_states_test`
/// and are not duplicated here.

typedef _S7Ports = ({LaunchGateway? launch, MiningGateway? mining});

/// One page, one resource, and the four states that resource can put it in.
final class _StateCase {
  const _StateCase({
    required this.slug,
    required this.page,
    required this.ports,
    required this.readyKey,
    required this.emptyContract,
    this.alsoUnreadKeys = const <String>[],
    this.unreadText,
    this.showsMissingFigure = true,
    this.pinsOffline = false,
  });

  /// The manifest slug, which is also this page's state-block key prefix.
  final String slug;
  final Widget page;

  /// Builds the ports for one state. Only the resource this page reads is
  /// driven; every other answer keeps its successful default, so a state that
  /// appears can only have come from this page's own read.
  final _S7Ports Function({LaunchFailureKind? failure, bool pending}) ports;

  /// A key that exists only after the page rendered its loaded projection.
  final String readyKey;

  /// Other keys that must stay absent until the read lands. These are the
  /// page's own conclusions — an empty card, a form, a list — and a read that
  /// did not land is not evidence for any of them.
  final List<String> alsoUnreadKeys;

  /// A text fragment only a landed read can print.
  final String? unreadText;

  /// Whether the folio prints [launchMissingFigure] instead of a number while
  /// the read has not landed.
  final bool showsMissingFigure;

  /// Why "the read succeeded and there is nothing" is not in this resource's
  /// contract, quoted from the model that defines it.
  final String emptyContract;

  /// Offline is written here only where no other file already pins it.
  final bool pinsOffline;

  List<String> get unreadKeys => <String>[readyKey, ...alsoUnreadKeys];
}

_S7Ports _launchPorts(FakeLaunchGateway gateway) =>
    (launch: gateway, mining: null);

_S7Ports _miningPorts(FakeMiningGateway gateway) =>
    (launch: null, mining: gateway);

final List<_StateCase> _cases = <_StateCase>[
  // launch — the catalogue. Its Empty is page-local (see the bespoke case),
  // so only Loading and Error come from the table.
  _StateCase(
    slug: 'launch',
    page: const LaunchScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        overview: S7Answer<LaunchOverview>(
          value: failure == null && !pending ? s7Overview() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-segments',
    // The segment bar prints four counts; none of them may be guessed, and
    // neither may the total in the folio heading.
    unreadText: '个已登记项目',
    emptyContract:
        'launch 的空态是分段级的（launch-segment-empty-<segment>），不是整页的：'
        '目录读成功时一定有一个 LaunchOverview 对象。',
  ),
  // launch-trade — the change under test. A detail read that has not landed
  // used to collapse into `launch-trade-no-round`; it now has its own block.
  _StateCase(
    slug: 'launch-trade',
    page: const LaunchTradeScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: failure == null && !pending ? s7Detail() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-trade-amount',
    // "没有可参与的轮次" is a statement about the round configuration. A read
    // that did not land says nothing about it, so the card must stay away.
    alsoUnreadKeys: <String>['launch-trade-no-round', 'launch-trade-rounds'],
    unreadText: 'MCAT',
    emptyContract:
        '认购页的空态是「这个 Launch 没有配置轮次」，由 LaunchDetail.rounds 决定，'
        '写在 launch-trade-no-round 上；LaunchStateBlock 的 empty 相到不了。',
    pinsOffline: true,
  ),
  // launch-history
  _StateCase(
    slug: 'launch-history',
    page: const LaunchHistoryScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        history: S7Answer<LaunchHistory>(
          value: failure == null && !pending ? s7History() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-history-notice',
    alsoUnreadKeys: <String>['launch-unavailable-购买、权益与退款记录'],
    emptyContract:
        'LaunchHistory 是 `{launchId, source}` 两个必填字段'
        '（launch_models.dart:719-724），读成功时永远有一条 source 说明；'
        '「读到了但没有记录」不在契约里，空列表只由 source 解释。',
  ),
  // launch-rounds — its Empty is the page-local `launch-rounds-empty`.
  _StateCase(
    slug: 'launch-rounds',
    page: const LaunchRoundsScreen(launchId: s7LaunchId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: failure == null && !pending ? s7Detail() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-rounds-notice',
    // Same rule as launch-trade: "还没有配置任何轮次" is a read conclusion.
    alsoUnreadKeys: <String>['launch-rounds-empty', 'launch-rounds-list'],
    unreadText: '个轮次',
    emptyContract:
        '轮次页的空态是「配置里没有轮次」，由 LaunchDetail.rounds 决定，'
        '写在 launch-rounds-empty 上，不经过 LaunchStateBlock。',
  ),
  // launch-apply
  _StateCase(
    slug: 'launch-apply',
    page: const LaunchApplyScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: failure == null && !pending
              ? const LaunchProjectPage(
                  items: <LaunchProject>[],
                  nextCursor: null,
                )
              : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'launch-apply-name',
    alsoUnreadKeys: <String>['launch-apply-projects', 'launch-apply-save'],
    // The folio prints 新建申请, not a figure, so there is no em dash to pin.
    showsMissingFigure: false,
    emptyContract:
        'LaunchProjectPage 可以带 items: []（launch_models.dart:313-318），'
        '但那是 ready：控制器把空列表当成读成功，页面渲染空白表单让人建第一份草稿'
        '（launch_controllers.dart:392-398），只有失败才会进 LaunchStateBlock。',
  ),
  // loop-stake
  _StateCase(
    slug: 'loop-stake',
    page: const LoopStakeScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _launchPorts(
      FakeLaunchGateway(
        stake: S7Answer<LaunchStake>(
          value: failure == null && !pending ? s7Stake() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'loop-stake-executable',
    alsoUnreadKeys: <String>['loop-stake-notice'],
    emptyContract:
        'LaunchStake 是 `{stake, executable}` 两个必填字段'
        '（launch_models.dart:691-698）：读成功时一定有一条质押口径和一个'
        '可执行性布尔值，没有「读到了但没有质押对象」这一档。',
    pinsOffline: true,
  ),
  // mining-assets
  _StateCase(
    slug: 'mining-assets',
    page: const MiningAssetsScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _miningPorts(
      FakeMiningGateway(
        assets: S7Answer<MiningAssets>(
          value: failure == null && !pending ? s7MiningAssets() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'mining-assets-total',
    alsoUnreadKeys: <String>['mining-assets-empty-notice'],
    emptyContract:
        'MiningAssets 是三个必填的 LaunchUnavailable'
        '（mining_models.dart:83-93），根本没有列表字段：'
        '「计入/排除为空」按契约成立且由 source 解释，不是页面的空态。',
  ),
  // mining-rewards
  _StateCase(
    slug: 'mining-rewards',
    page: const MiningRewardsScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _miningPorts(
      FakeMiningGateway(
        rewards: S7Answer<MiningRewards>(
          value: failure == null && !pending ? s7MiningRewards() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'mining-rewards-metrics',
    alsoUnreadKeys: <String>['mining-rewards-claim'],
    emptyContract:
        'MiningRewards 是四个必填的 LaunchUnavailable 加一个 claimExecutable'
        '（mining_models.dart:96-113）：读成功时四条口径都在，'
        '「账本为空」由 source 说明，不会让页面变成空态。',
  ),
  // mining-rank
  _StateCase(
    slug: 'mining-rank',
    page: const MiningRankScreen(),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _miningPorts(
      FakeMiningGateway(
        rank: S7Answer<MiningRank>(
          value: failure == null && !pending ? s7MiningRank() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'mining-rank-anonymity',
    alsoUnreadKeys: <String>['mining-rank-notice'],
    emptyContract:
        'MiningRank 的 ranking / myPosition 都是必填的 LaunchUnavailable，'
        'display 是必填的匿名规则（mining_models.dart:151-165）：'
        '读成功时一定有一条榜单口径和一条显示规则，没有「空榜单」这个响应。',
    pinsOffline: true,
  ),
  // mining-community
  _StateCase(
    slug: 'mining-community',
    page: const MiningCommunityScreen(communityId: s7CommunityId),
    ports: ({LaunchFailureKind? failure, bool pending = false}) => _miningPorts(
      FakeMiningGateway(
        community: S7Answer<MiningCommunity>(
          value: failure == null && !pending ? s7MiningCommunity() : null,
          failure: failure,
          pending: pending,
        ),
      ),
    ),
    readyKey: 'mining-community-metrics',
    alsoUnreadKeys: <String>['mining-community-asset'],
    unreadText: 'Frog Holders',
    emptyContract:
        'MiningCommunity 是一个必填的社区引用 + 一个 sealed 权重 + 四条必填口径'
        '（mining_models.dart:211-227）：读成功时社区一定存在，'
        '未授予权重是 MiningCommunityWeightPending，不是空态。',
  ),
];

/// Pages whose Empty column is a page-local card rather than the table's
/// negative assertion. They are pinned positively below.
const Set<String> _pageLocalEmpty = <String>{
  'launch',
  'launch-rounds',
  'launch-trade',
};

Future<void> _pump(
  WidgetTester tester,
  _StateCase testCase, {
  LaunchFailureKind? failure,
  bool pending = false,
}) {
  final ports = testCase.ports(failure: failure, pending: pending);
  return pumpS7Page(
    tester,
    testCase.page,
    launch: ports.launch,
    mining: ports.mining,
    // A pending answer never completes, so the frame is pumped rather than
    // settled: settling a live skeleton would time out.
    settle: !pending,
  );
}

/// Asserts that none of the page's own read conclusions are on screen.
void _expectNothingRead(_StateCase testCase) {
  for (final key in testCase.unreadKeys) {
    expect(
      find.byKey(ValueKey<String>(key)),
      findsNothing,
      reason: '${testCase.slug} 没读到数据时不得渲染 $key',
    );
  }
  final text = testCase.unreadText;
  if (text != null) {
    expect(
      find.textContaining(text),
      findsNothing,
      reason: '${testCase.slug} 不得显示一个它没有读到的事实',
    );
  }
}

void main() {
  for (final testCase in _cases) {
    group('${testCase.slug} · read states', () {
      testWidgets(
        '${testCase.slug} shows its own skeleton and no unread figure',
        (tester) async {
          await _pump(tester, testCase, pending: true);

          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-loading')),
            findsOneWidget,
          );
          _expectNothingRead(testCase);
          if (testCase.showsMissingFigure) {
            // The folio keeps the em dash: a page that has not read a number
            // prints the missing-figure mark, never a 0 and never a fixture.
            expect(find.text(launchMissingFigure), findsWidgets);
          }
        },
      );

      if (!_pageLocalEmpty.contains(testCase.slug)) {
        testWidgets(
          '${testCase.slug} a successful read is ready, never the empty block',
          (tester) async {
            await _pump(tester, testCase);

            // The reason is carried in the case so the acceptance matrix can
            // quote the contract verbatim.
            expect(testCase.emptyContract, isNotEmpty);
            expect(
              find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
              findsNothing,
              reason: testCase.emptyContract,
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
      }

      testWidgets('${testCase.slug} an unexpected failure is an error state', (
        tester,
      ) async {
        await _pump(tester, testCase, failure: LaunchFailureKind.unexpected);

        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-error')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-offline')),
          findsNothing,
          reason: '服务端答复了一个错误，这不是断网',
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
          findsNothing,
          reason: '读失败永远不能被写成「这里没有内容」',
        );
        _expectNothingRead(testCase);
      });

      if (testCase.pinsOffline) {
        testWidgets('${testCase.slug} pauses offline instead of erroring', (
          tester,
        ) async {
          await _pump(tester, testCase, failure: LaunchFailureKind.offline);

          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-offline')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-error')),
            findsNothing,
            reason: '断网不是服务端的错误答复',
          );
          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
            findsNothing,
            reason: '暂停的页面不能声称「这里没有内容」',
          );
          expect(find.text('离线 · 显示缓存'), findsOneWidget);
          _expectNothingRead(testCase);
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // The three page-local empties. Each is a conclusion the page may only draw
  // from a read that landed, so each is asserted on a successful read.
  // -------------------------------------------------------------------------

  group('page-local empty cards', () {
    testWidgets(
      'launch says which segment is empty, not that Launch is empty',
      (tester) async {
        await pumpS7Page(
          tester,
          const LaunchScreen(),
          // A catalogue that read fine and holds no live launch. The default
          // segment is `live` (launch_controllers.dart:102).
          launch: FakeLaunchGateway(
            overview: S7Answer<LaunchOverview>(
              value: s7Overview(
                live: const <LaunchSummary>[],
                awaitingSchedule: const <LaunchSummary>[],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('launch-segment-empty-live')),
          findsOneWidget,
        );
        expect(find.text('发射中：暂无项目'), findsOneWidget);
        // The read landed, so the page-wide block is out of the question: the
        // segment bar and the rest of the catalogue are still on screen.
        expect(
          find.byKey(const ValueKey<String>('launch-state-empty')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('launch-segments')),
          findsOneWidget,
        );
      },
    );

    testWidgets('launch-rounds says the configuration holds no round', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchRoundsScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s7Detail(rounds: const <LaunchRound>[]),
          ),
        ),
      );

      // 「还没有配置任何轮次」is a fact about the configuration that was read,
      // which is why it is a page card and not the shared empty block.
      expect(
        find.byKey(const ValueKey<String>('launch-rounds-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-rounds-state-empty')),
        findsNothing,
      );
      expect(find.text('0 个轮次'), findsOneWidget);
    });

    testWidgets('launch-trade says there is no round only after it read one', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchTradeScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s7Detail(rounds: const <LaunchRound>[]),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-trade-no-round')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-trade-state-empty')),
        findsNothing,
      );
      // The rest of the action stays rendered: the read landed, the round
      // configuration is simply empty.
      expect(
        find.byKey(const ValueKey<String>('launch-trade-amount')),
        findsOneWidget,
      );
    });
  });
}
