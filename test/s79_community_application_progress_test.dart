import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/notifications/community_application_notifications.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _ownedId = '3fa85f64-5717-4562-b3fc-2c963f66af11';
const _secondOwnedId = '3fa85f64-5717-4562-b3fc-2c963f66af22';
const _notificationId = 'cbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';

CommunityHome _home({
  List<JoinedCommunity> joined = const <JoinedCommunity>[],
  List<OwnedCommunity> owned = const <OwnedCommunity>[],
  bool ownedTruncated = false,
}) => CommunityHome(
  joined: joined,
  joinedTruncated: false,
  owned: owned,
  ownedTruncated: ownedTruncated,
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 9, 10, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

OwnedCommunity _owned({
  String communityId = _ownedId,
  String name = 'Builders Guild',
  CommunityVerification status = CommunityVerification.pending,
  DateTime? submittedAt,
  DateTime? reviewedAt,
  String? rejectedReason,
  bool withReview = true,
}) => OwnedCommunity(
  community: testCommunity(
    communityId: communityId,
    name: name,
    verification: status,
  ),
  membership: CommunityMembership(
    role: CommunityRole.owner,
    status: CommunityMemberStatus.active,
    joinedAt: DateTime.utc(2026, 7),
  ),
  application: withReview
      ? CommunityApplicationReview(
          status: status,
          submittedAt: submittedAt ?? DateTime.utc(2026, 9, 10, 3, 5),
          reviewedAt:
              reviewedAt ??
              (status == CommunityVerification.pending
                  ? null
                  : DateTime.utc(2026, 9, 11, 4)),
          rejectedReason: rejectedReason,
        )
      : null,
);

JoinedCommunity _joined({
  String communityId = '3fa85f64-5717-4562-b3fc-2c963f66af33',
  String name = 'Frog Holders',
}) => JoinedCommunity(
  community: testCommunity(communityId: communityId, name: name),
  membership: CommunityMembership(
    role: CommunityRole.member,
    status: CommunityMemberStatus.active,
    joinedAt: DateTime.utc(2026, 7),
  ),
);

LoopNotificationEntry _reviewNotification({
  required String event,
  String notificationId = _notificationId,
  String communityId = _ownedId,
  String? communityName = 'Builders Guild',
  String? reason,
  DateTime? readAt,
}) => LoopNotificationEntry(
  notificationId: notificationId,
  type: LoopNotificationCategory.communityAnnouncement,
  entityRef: 'community:$communityId',
  contextRoute: 'community-profile',
  contextParams: <String, String>{'communityId': communityId},
  payload: <String, String?>{
    'event': event,
    'communityId': communityId,
    'communityName': communityName,
    'reviewedAt': '2026-09-11T04:00:00.000Z',
    'reason': reason,
  },
  source: null,
  observedAt: null,
  readAt: readAt,
  createdAt: DateTime.utc(2026, 9, 11, 4),
);

Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeCommunityGateway community,
  ValueChanged<String>? onNavigate,
  FakeNotificationsGateway? notifications,
  LoopV2MetaSnapshot? meta,
}) => pumpCommunityPage(
  tester,
  ProfileSurfaceScreen.fromId('profile', onNavigate: onNavigate ?? (_) {}),
  community: community,
  notifications: notifications,
  meta: meta,
);

LoopRecordRow _row(WidgetTester tester, String key) =>
    tester.widget<LoopRecordRow>(find.byKey(ValueKey<String>(key)));

void main() {
  group('profile · 我的社区 splits into joined and created', () {
    testWidgets('an account that created nothing draws no 我创建的 group', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(joined: <JoinedCommunity>[_joined()]),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-open-communities')),
      );

      expect(find.text('我加入的'), findsOneWidget);
      // An empty group would teach every account about a review queue none of
      // them is in.
      expect(find.text('我创建的'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('profile-owned-communities')),
        findsNothing,
      );
    });

    testWidgets('the created group lists one row per owned community', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(
            joined: <JoinedCommunity>[_joined()],
            owned: <OwnedCommunity>[
              _owned(),
              _owned(
                communityId: _secondOwnedId,
                name: 'Writers Room',
                status: CommunityVerification.verified,
              ),
            ],
          ),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-owned-communities')),
      );

      // The joined row keeps its own count and never counts what was created.
      expect(_row(tester, 'profile-open-communities').trailing, '1 个已加入');
      expect(find.text('我创建的'), findsOneWidget);
      expect(_row(tester, 'profile-owned-$_ownedId').title, 'Builders Guild');
      expect(
        _row(tester, 'profile-owned-$_secondOwnedId').title,
        'Writers Room',
      );
    });

    testWidgets('each created row carries its own review state', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(
            owned: <OwnedCommunity>[
              _owned(),
              _owned(
                communityId: _secondOwnedId,
                name: 'Writers Room',
                status: CommunityVerification.verified,
              ),
              _owned(
                communityId: '3fa85f64-5717-4562-b3fc-2c963f66af44',
                name: 'Muted Hall',
                status: CommunityVerification.rejected,
                rejectedReason: '社区名称与已经上线的官方社区重复，请换一个更具体的名称后再提交申请。',
              ),
            ],
          ),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-owned-communities')),
      );

      expect(find.text('审核中'), findsOneWidget);
      expect(find.text('已通过'), findsOneWidget);
      expect(find.text('已驳回'), findsOneWidget);
      // A pending or accepted row dates the version under review; a refused
      // one states the reason instead, because that is what its owner can act
      // on. The reason is elided at 30 code points.
      expect(
        _row(tester, 'profile-owned-$_ownedId').subtitle,
        '提交于 ${_local(DateTime.utc(2026, 9, 10, 3, 5))}',
      );
      expect(
        _row(
          tester,
          'profile-owned-3fa85f64-5717-4562-b3fc-2c963f66af44',
        ).subtitle,
        '驳回：社区名称与已经上线的官方社区重复，请换一个更具体的名称后再提…',
      );
    });

    testWidgets('a created row opens that community record', (tester) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(owned: <OwnedCommunity>[_owned()]),
        ),
        onNavigate: destinations.add,
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-owned-$_ownedId')),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('profile-owned-$_ownedId')),
      );
      await tester.pumpAndSettle();
      expect(destinations, <String>['community-profile:$_ownedId']);
    });

    testWidgets('a row with no review block dates the community itself', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(owned: <OwnedCommunity>[_owned(withReview: false)]),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-owned-$_ownedId')),
      );

      expect(
        _row(tester, 'profile-owned-$_ownedId').subtitle,
        startsWith('创建于 '),
      );
      expect(find.text('审核中'), findsOneWidget);
    });
  });

  group('profile · 审核通知', () {
    testWidgets('both review outcomes get a Chinese title and body', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(owned: <OwnedCommunity>[_owned()]),
        ),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            value: s5Feed(
              unreadCount: 2,
              items: <LoopNotificationEntry>[
                _reviewNotification(event: 'community.application.verified'),
                _reviewNotification(
                  event: 'community.application.rejected',
                  notificationId: 'cbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
                  communityId: _secondOwnedId,
                  communityName: 'Writers Room',
                  reason: '名称与官方社区重复',
                ),
              ],
            ),
          ),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-application-notifications')),
      );

      expect(find.text('你的社区「Builders Guild」已通过审核'), findsOneWidget);
      expect(find.text('已显示验证标记，挖矿权重与官方群已开放。'), findsOneWidget);
      expect(find.text('你的社区「Writers Room」未通过审核'), findsOneWidget);
      expect(find.text('原因：名称与官方社区重复'), findsOneWidget);
    });

    testWidgets('tapping one reads it and opens the community record', (
      tester,
    ) async {
      final destinations = <String>[];
      final notifications = FakeNotificationsGateway(
        feed: S5Answer<LoopNotificationFeed>(
          value: s5Feed(
            items: <LoopNotificationEntry>[
              _reviewNotification(event: 'community.application.verified'),
            ],
          ),
        ),
      );
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(owned: <OwnedCommunity>[_owned()]),
        ),
        notifications: notifications,
        onNavigate: destinations.add,
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(
          const ValueKey<String>(
            'profile-application-notification-$_notificationId',
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'profile-application-notification-$_notificationId',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(notifications.read, <String>[_notificationId]);
      expect(destinations, <String>['community-profile:$_ownedId']);
    });

    testWidgets('a feed that answered nothing draws no block at all', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(owned: <OwnedCommunity>[_owned()]),
        ),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            failure: LoopChainFailureKind.unavailable,
          ),
        ),
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('profile-owned-communities')),
      );

      expect(find.text('审核通知'), findsNothing);
      // The group above already carries the authoritative state.
      expect(find.text('审核中'), findsOneWidget);
    });
  });

  group('community-profile · the owner is shown the review', () {
    testWidgets('a pending application says when it was submitted', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              verification: CommunityVerification.pending,
            ),
            viewer: testViewer(),
            application: CommunityApplicationReview(
              status: CommunityVerification.pending,
              submittedAt: DateTime.utc(2026, 9, 10, 3, 5),
              reviewedAt: null,
              rejectedReason: null,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-application-pending')),
        findsOneWidget,
      );
      expect(
        find.text('审核中 · 提交于 ${_local(DateTime.utc(2026, 9, 10, 3, 5))}'),
        findsOneWidget,
      );
      expect(find.textContaining('通过后开放挖矿权重与官方群'), findsOneWidget);
    });

    testWidgets('a refused application prints the reason in full', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              verification: CommunityVerification.rejected,
            ),
            application: CommunityApplicationReview(
              status: CommunityVerification.rejected,
              submittedAt: DateTime.utc(2026, 9, 10, 3, 5),
              reviewedAt: DateTime.utc(2026, 9, 11, 4),
              rejectedReason: '社区名称与已经上线的官方社区重复，请换一个更具体的名称后再提交申请。',
            ),
          ),
        ),
      );

      expect(find.text('已驳回'), findsOneWidget);
      expect(
        find.text('原因：社区名称与已经上线的官方社区重复，请换一个更具体的名称后再提交申请。'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-application-resubmit')),
        findsOneWidget,
      );
    });

    testWidgets('a member sees neither card on the same community', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              verification: CommunityVerification.pending,
            ),
            viewer: testViewer(role: CommunityRole.member),
            // The server sends a non-owner nothing; this asserts the client
            // would still refuse to draw it if one ever arrived.
            application: CommunityApplicationReview(
              status: CommunityVerification.pending,
              submittedAt: DateTime.utc(2026, 9, 10, 3, 5),
              reviewedAt: null,
              rejectedReason: null,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-application-pending')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-application-rejected')),
        findsNothing,
      );
    });

    testWidgets('a verified application draws no card', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            application: CommunityApplicationReview(
              status: CommunityVerification.verified,
              submittedAt: DateTime.utc(2026, 9, 10, 3, 5),
              reviewedAt: DateTime.utc(2026, 9, 11, 4),
              rejectedReason: null,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-application-pending')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-application-rejected')),
        findsNothing,
      );
    });

    testWidgets('resubmission saves the edit first, then asks for a review', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(
          community: testCommunity(
            verification: CommunityVerification.rejected,
          ),
          application: CommunityApplicationReview(
            status: CommunityVerification.rejected,
            submittedAt: DateTime.utc(2026, 9, 10, 3, 5),
            reviewedAt: DateTime.utc(2026, 9, 11, 4),
            rejectedReason: '名称与官方社区重复',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: gateway,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-application-resubmit')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('community-edit-name')),
        'Frog Holders DAO',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('community-edit-submit')),
      );
      await tester.pumpAndSettle();

      // Nothing is written before the confirmation.
      expect(gateway.commands, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, <String>[
        'edit:$testCommunityId:Frog Holders DAO',
        'resubmit:$testCommunityId',
      ]);
      expect(find.text('已重新提交，状态回到审核中'), findsOneWidget);
    });
  });

  group('push · the two review events', () {
    test('a verified review opens the community the feed confirmed', () {
      final router = LoopNotificationRouter();
      final decision = router.route(
        data: <String, Object?>{
          'type': 'community_application_verified',
          'entityRef': 'community:$_ownedId',
          'contextRoute': 'community-profile',
          'eventVersion': '1',
        },
        ingress: LoopNotificationIngress.interaction,
        session: const LoopNotificationSessionContext.authenticated(),
      );
      expect(decision.disposition, LoopNotificationDisposition.pointerReady);

      final intent = LoopNotificationRouter.resolve(
        decision.pointer!,
        context: const LoopNotificationContext(
          contextRoute: 'community-profile',
          communityId: _ownedId,
        ),
      );
      expect(intent, isA<LoopCommunityApplicationNotificationIntent>());
      expect(intent.location, '/community/profile?id=$_ownedId');
    });

    test('an unconfirmed refusal names no community', () {
      final router = LoopNotificationRouter();
      final decision = router.route(
        data: <String, Object?>{
          'type': 'community_application_rejected',
          'entityRef': 'community:$_ownedId',
          'contextRoute': 'community-profile',
          'eventVersion': '1',
        },
        ingress: LoopNotificationIngress.interaction,
        session: const LoopNotificationSessionContext.authenticated(),
      );

      final intent = LoopNotificationRouter.resolve(decision.pointer!);
      expect(intent, isA<LoopCommunityIndexNotificationIntent>());
      expect(intent.location, '/community');
    });

    test('a review event paired with another destination is refused', () {
      final router = LoopNotificationRouter();
      final decision = router.route(
        data: <String, Object?>{
          'type': 'community_application_verified',
          'entityRef': 'community:$_ownedId',
          'contextRoute': 'token',
          'eventVersion': '1',
        },
        ingress: LoopNotificationIngress.interaction,
        session: const LoopNotificationSessionContext.authenticated(),
      );
      expect(decision.disposition, LoopNotificationDisposition.malformed);
    });
  });

  group('feed copy', () {
    test('a row with no community id is not a review result', () {
      final entry = LoopNotificationEntry(
        notificationId: _notificationId,
        type: LoopNotificationCategory.communityAnnouncement,
        entityRef: 'community:$_ownedId',
        contextRoute: 'community-profile',
        contextParams: const <String, String>{},
        payload: const <String, String?>{
          'event': 'community.application.verified',
        },
        source: null,
        observedAt: null,
        readAt: null,
        createdAt: DateTime.utc(2026, 9, 11, 4),
      );
      expect(CommunityApplicationNotification.read(entry), isNull);
    });

    test('an announcement that is not a review is left alone', () {
      final entry = _reviewNotification(event: 'community.announcement.posted');
      expect(CommunityApplicationNotification.read(entry), isNull);
    });

    test('a refusal with no reason still says it was refused', () {
      final result = CommunityApplicationNotification.read(
        _reviewNotification(event: 'community.application.rejected'),
      )!;
      expect(result.title, '你的社区「Builders Guild」未通过审核');
      expect(result.body, '运维没有给出原因。修改社区资料后可以重新提交。');
    });

    test('a row with no name names no community', () {
      final result = CommunityApplicationNotification.read(
        _reviewNotification(
          event: 'community.application.verified',
          communityName: null,
        ),
      )!;
      expect(result.title, '你的社区已通过审核');
    });
  });

  group('the feed carries an operator reason whole', () {
    Future<LoopNotificationFeed> readFeed(Object? reason) {
      final api = DioLoopV2NotificationsApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, <String, Object?>{
              'items': <Object?>[
                s5NotificationBody()
                  ..['type'] = 'community.announcement'
                  ..['entityRef'] = 'community:$_ownedId'
                  ..['contextRoute'] = 'community-profile'
                  ..['contextParams'] = <String, Object?>{
                    'communityId': _ownedId,
                  }
                  ..['payload'] = <String, Object?>{
                    'event': 'community.application.rejected',
                    'communityId': _ownedId,
                    'communityName': 'Builders Guild',
                    'reviewedAt': '2026-09-11T04:00:00.000Z',
                    'reason': reason,
                  },
              ],
              'nextCursor': null,
              'unreadCount': 1,
              'push': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
              'contractVersion': '2.0',
            }),
          ),
        ),
      );
      return api.getFeed(accessToken: 'token', clientVersion: s5ClientVersion);
    }

    test('a 280 code point reason of astral text survives the page', () async {
      // The bound the server raised is counted in code points; counted in
      // UTF-16 units this reason is 560 long and used to take the whole page
      // down with it.
      final reason = '🐸' * 280;
      final feed = await readFeed(reason);
      final result = CommunityApplicationNotification.read(feed.items.single)!;
      expect(result.reason, reason);
      expect(result.body, '原因：$reason');
    });

    test('a value past the raised bound is still an invalid payload', () async {
      await expectLater(readFeed('x' * 513), throwsA(isA<Object>()));
    });
  });

  group('row copy', () {
    test('a reason at the bound is not elided', () {
      final exact = 'x' * communityRejectedReasonPreviewRunes;
      expect(communityRejectedReasonPreview(exact), '驳回：$exact');
      expect(communityRejectedReasonPreview('${exact}y'), '驳回：$exact…');
    });

    test('a blank reason is a refusal without one', () {
      expect(communityRejectedReasonPreview('   '), '驳回：运维没有给出原因');
      expect(communityRejectedReasonPreview(null), '驳回：运维没有给出原因');
    });
  });
}

String _local(DateTime instant) {
  final local = instant.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
