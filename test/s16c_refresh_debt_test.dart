import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// S16-C · the refresh debt the S16-B pass left open, and the review sentence
/// the server now owns.
///
/// Three things are pinned here:
///
/// * the three social lists — connections, stranger requests and the blocklist
///   — re-read in place: a pull keeps the rows it already has and marks them
///   更新中 instead of trading them for a skeleton;
/// * `alerts` and `referral` already kept their values through a reload but
///   said nothing about it, so a pull now raises the same 更新中 mark;
/// * a returned Launch application shows the server's own sentence verbatim.
///   The client holds no code-to-copy table any more, so an unfamiliar reason
///   code still reads as a sentence rather than as a fallback.
const _serverSentence = '官方链接无法访问或核对，换成可访问的链接后可以重新提交。';

ConnectionPage _connections({String? nextCursor}) => ConnectionPage(
  direction: ConnectionDirection.following,
  items: <ConnectionEntry>[
    ConnectionEntry(
      profile: testProfile(
        publicProfileId: testMemberId,
        loopId: 'LOOP-3HJKMNPQ',
        alias: 'frog_member',
      ),
      createdAt: DateTime.utc(2026, 8),
      viewerFollows: true,
      miningPower: testMiningPower,
    ),
  ],
  counts: const ConnectionCounts(following: 24, followers: 108),
  nextCursor: nextCursor,
);

BlockPage _blocks() => BlockPage(
  kind: BlockKind.user,
  items: <BlockEntry>[
    BlockEntry(
      kind: BlockKind.user,
      stableId: testMemberId,
      profile: testProfile(publicProfileId: testMemberId, alias: 'spam_bot'),
      reasonCode: 'message_request_report',
      createdAt: DateTime.utc(2026, 8, 20),
    ),
  ],
  userCount: 1,
  nextCursor: null,
);

MessageRequestPage _requests() => MessageRequestPage(
  items: <MessageRequestEntry>[
    MessageRequestEntry(
      messageRequestId: testRequestId,
      profile: testProfile(alias: 'fox_trader'),
      createdAt: DateTime.utc(2026, 9, 7),
      expiresAt: DateTime.utc(2026, 9, 14),
      preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
      aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
    ),
  ],
  nextCursor: null,
);

/// Drags the page's own scroll region past the refresh threshold.
///
/// `RefreshIndicator` arms at a quarter of the viewport height, so the
/// distance is stated per harness rather than assumed.
Future<void> _pull(WidgetTester tester, {double distance = 600}) async {
  await tester.fling(find.byType(Scrollable).last, Offset(0, distance), 1000);
  // The drag is released and the indicator settles into its running state;
  // the read itself is still held open, so the frame is pumped rather than
  // settled.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Finder get _updatingBadge =>
    find.byKey(const ValueKey<String>('loop-updating-badge'));

/// An alerts port whose list read can be held open.
final class _HeldAlertsGateway implements AlertsGateway {
  _HeldAlertsGateway();

  Completer<void>? hold;
  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopAlertPage> listAlerts({String? cursor}) {
    reads += 1;
    final page = LoopAlertPage(
      items: <LoopPriceAlert>[s5Alert()],
      nextCursor: null,
    );
    final held = hold;
    if (held == null) return Future<LoopAlertPage>.value(page);
    hold = null;
    return held.future.then((_) => page);
  }

  @override
  Future<LoopPriceAlert> createAlert(LoopAlertDraft draft) =>
      Future<LoopPriceAlert>.value(s5Alert());

  @override
  Future<LoopPriceAlert> updateAlert({
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
  }) => Future<LoopPriceAlert>.value(s5Alert());

  @override
  Future<void> deleteAlert({
    required String alertId,
    required int expectedVersion,
  }) => Future<void>.value();
}

/// A referral port whose overview read can be held open.
final class _HeldReferralGateway implements ReferralGateway {
  _HeldReferralGateway();

  Completer<void>? hold;
  int reads = 0;

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<ReferralOverview> loadOverview() {
    reads += 1;
    final overview = s7Referral();
    final held = hold;
    if (held == null) return Future<ReferralOverview>.value(overview);
    hold = null;
    return held.future.then((_) => overview);
  }

  @override
  Future<ReferralBinding> claim(String inviteCode) =>
      Future<ReferralBinding>.value(s7BoundBinding());
}

void main() {
  group('the social lists re-read in place', () {
    testWidgets('connections keeps its rows and wears 更新中', (tester) async {
      final gateway = FakeSocialGateway(connections: _connections());
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
      );
      expect(find.text('frog_member'), findsOneWidget);
      final before = gateway.commands.length;

      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester);

      // The read is in flight: the rows the user already had are still on
      // screen, and the topbar says so instead of the page going grey.
      expect(gateway.commands.length, before + 1);
      expect(find.text('frog_member'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_updatingBadge, findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();

      expect(find.text('frog_member'), findsOneWidget);
      expect(_updatingBadge, findsNothing);
    });

    testWidgets('stranger requests keep their rows and wear 更新中', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(requests: _requests());
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: gateway,
      );
      expect(find.text('fox_trader'), findsOneWidget);

      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester);

      expect(find.text('fox_trader'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_updatingBadge, findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(_updatingBadge, findsNothing);
    });

    testWidgets('the blocklist keeps its rows and wears 更新中', (tester) async {
      final gateway = FakeSocialGateway(blocks: _blocks());
      await pumpCommunityPage(tester, const BlocklistScreen(), social: gateway);
      expect(find.text('spam_bot'), findsOneWidget);

      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester);

      expect(find.text('spam_bot'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_updatingBadge, findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(_updatingBadge, findsNothing);
    });

    testWidgets('a pull with nothing to keep still loads as a skeleton', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(
        failure: CommunityFailureKind.offline,
        connections: _connections(),
      );
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );

      gateway.failure = null;
      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester);

      // Nothing was on screen to preserve, so this is a load, not a re-read.
      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(_updatingBadge, findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('frog_member'), findsOneWidget);
    });

    testWidgets('a failed pull keeps the rows it could not replace', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(connections: _connections());
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
      );
      expect(find.text('frog_member'), findsOneWidget);

      final hold = Completer<void>();
      gateway
        ..hold = hold
        ..failure = CommunityFailureKind.offline;
      await _pull(tester);
      hold.complete();
      await tester.pumpAndSettle();

      // The last successful read is still the best thing the page has, so it
      // stays; the failure is reported next to it instead of replacing it.
      expect(find.text('frog_member'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('connections-action-failure')),
        findsOneWidget,
      );
      expect(_updatingBadge, findsNothing);
    });

    test('a segment with no backend has nothing to re-read', () async {
      final gateway = FakeSocialGateway(blocks: _blocks());
      final container = ProviderContainer(
        overrides: [socialGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      container.listen(blocklistControllerProvider, (previous, next) {});
      final controller = container.read(blocklistControllerProvider.notifier);
      await controller.load();
      expect(gateway.commands, <String>['blocks:user']);

      controller.selectKind(BlockKind.contract);
      await controller.refresh();

      // Contract blocking has no backend at all, so a pull issues no request
      // rather than asking for a list that cannot exist.
      expect(gateway.commands, <String>['blocks:user']);
    });
  });

  group('the two pages that kept their values now say so', () {
    testWidgets('price alerts wear 更新中 while a pull is in flight', (
      tester,
    ) async {
      final gateway = _HeldAlertsGateway();
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: gateway,
        notifications: FakeNotificationsGateway(),
      );
      expect(find.text('1 个提醒正在监听'), findsOneWidget);
      expect(gateway.reads, 1);

      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester, distance: 900);

      expect(gateway.reads, 2);
      // The list the page already read stays exactly where it was.
      expect(find.text('1 个提醒正在监听'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_updatingBadge, findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(_updatingBadge, findsNothing);
    });

    testWidgets('referral wears 更新中 while a pull is in flight', (tester) async {
      final gateway = _HeldReferralGateway();
      await pumpS7Page(tester, const ReferralScreen(), referral: gateway);
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      expect(gateway.reads, 1);

      final hold = Completer<void>();
      gateway.hold = hold;
      await _pull(tester, distance: 900);

      expect(gateway.reads, 2);
      // The invite code that was issued stays readable through the re-read.
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_updatingBadge, findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(_updatingBadge, findsNothing);
    });
  });

  group('the review reason is the server sentence', () {
    testWidgets('an unfamiliar reason code still reads as a sentence', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[
              s7Project(
                reviewStatus: LaunchReviewStatus.returned,
                // Nothing on the client knows this code. The page is still
                // readable, because the sentence came with it.
                reviewReasonCode: 'operator_manual_review',
                reviewReasonText: _serverSentence,
              ),
            ],
            nextCursor: null,
          ),
        ),
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      expect(find.text(_serverSentence), findsOneWidget);
      // The code is a contract identifier for analytics and branching; it has
      // no business on a screen, and no local table turns it into one.
      expect(find.textContaining('operator_manual_review'), findsNothing);
    });

    testWidgets('a projection with no reason shows no returned notice', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[
              s7Project(reviewStatus: LaunchReviewStatus.returned),
            ],
            nextCursor: null,
          ),
        ),
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('launch-apply-returned-reason')),
        findsNothing,
      );
    });
  });
}
