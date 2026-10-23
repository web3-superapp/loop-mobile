// S292 · decision 0242: the notification centre carries a launched project's
// review and deployment progress (loop-api S291) — codec, rows, taps, push
// routing, settings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/notifications/notification_inbox_screen.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s287_notifications.dart';

const _projectId = '3e4f5a6b-7c8d-4e9f-8a0b-1c2d3e4f5a6b';
const _taskId = '9d8c7b6a-5f4e-4d3c-9b2a-1f0e9d8c7b6a';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

LoopNotificationEntry _entry({
  required int n,
  required String rawType,
  required String contextRoute,
  String entityRef = 'launchProject:$_projectId',
  Map<String, String> contextParams = const <String, String>{},
  Map<String, String?> payload = const <String, String?>{},
}) => LoopNotificationEntry(
  notificationId: s287Id(n),
  type: null,
  rawType: rawType,
  entityRef: entityRef,
  contextRoute: contextRoute,
  contextParams: contextParams,
  payload: payload,
  source: null,
  observedAt: null,
  readAt: null,
  createdAt: s287Now.subtract(Duration(minutes: n)).toUtc(),
);

/// The record resolution `lib/app.dart` composes (`_notificationContextOf`),
/// including decision 0242's project id.
String? _resolve(LoopNotificationEntry entry) =>
    LoopNotificationRouter.resolveRecord(
      LoopNotificationContext(
        contextRoute: entry.contextRoute,
        assetId: entry.contextParams['assetId'],
        communityId: entry.contextParams['communityId'],
        instanceId: entry.contextParams['instanceId'],
        publicProfileId: entry.contextParams['publicProfileId'],
        projectId:
            entry.contextParams['projectId'] ??
            LoopNotificationRouter.launchProjectIdOf(entry.entityRef),
      ),
    )?.location;

/// Rows exactly as the contract writes them: the server's own title / body.
List<LoopNotificationEntry> _serverRows() => <LoopNotificationEntry>[
  _entry(
    n: 1,
    rawType: 'launch.review_approved',
    contextRoute: 'launch2-project-sign',
    payload: const <String, String?>{
      'title': 'FROG 审核已通过',
      'body': '请完成签名，发射才会部署',
      'projectName': 'FROG',
    },
  ),
  _entry(
    n: 2,
    rawType: 'launch.review_rejected',
    contextRoute: 'launch2-projects-mine',
    payload: const <String, String?>{
      'title': 'FROG 审核未通过',
      'body': '项目简介与白皮书不一致',
    },
  ),
  _entry(
    n: 3,
    rawType: 'launch.activated',
    contextRoute: 'launch2-instance',
    entityRef: 'launch2Instance:$s287InstanceId',
    contextParams: const <String, String>{'instanceId': s287InstanceId},
    payload: const <String, String?>{
      'title': 'FROG 已上链',
      'body': '开售时间 2026-10-25 20:00（北京时间）',
    },
  ),
  _entry(
    n: 4,
    rawType: 'launch.deploy_failed',
    contextRoute: 'launch2-projects-mine',
    entityRef: 'launchTask:$_taskId',
    payload: const <String, String?>{
      'title': 'FROG 部署失败',
      'body': 'Gas 不足，请重新签名',
    },
  ),
  // A type this build does not know sits among them and changes nothing.
  _entry(
    n: 5,
    rawType: 'launch.something_later',
    contextRoute: 'launch2-somewhere',
    payload: const <String, String?>{'title': '以后的新事件'},
  ),
];

void main() {
  loopWatchGround();

  group('kinds', () {
    test('the four feed types are kinds filed under 资格快照与开始提醒', () {
      final kinds = <String, LoopNotificationKind>{
        'launch.review_approved': LoopNotificationKind.launchReviewApproved,
        'launch.review_rejected': LoopNotificationKind.launchReviewRejected,
        'launch.activated': LoopNotificationKind.launchActivated,
        'launch.deploy_failed': LoopNotificationKind.launchDeployFailed,
      };
      for (final MapEntry(key: wire, value: kind) in kinds.entries) {
        expect(LoopNotificationKind.tryParse(wire), kind);
        expect(kind.category, LoopNotificationCategory.launchRound);
      }
    });

    test('the codec decodes them, and an unknown type beside them', () async {
      Map<String, Object?> row(String id, String type, String route) =>
          <String, Object?>{
            'notificationId': id,
            'type': type,
            'entityRef': 'launchProject:$_projectId',
            'contextRoute': route,
            'contextParams': const <String, Object?>{},
            'payload': const <String, Object?>{
              'projectName': 'FROG',
              'reasonText': null,
            },
            'source': null,
            'observedAt': null,
            'readAt': null,
            'createdAt': '2026-10-22T06:00:00.000Z',
          };
      final api = DioLoopV2NotificationsApi(
        s5Dio((options, handler) {
          handler.resolve(
            s5Response(options, <String, Object?>{
              'items': <Map<String, Object?>>[
                row(
                  s287Id(1),
                  'launch.review_approved',
                  'launch2-project-sign',
                ),
                row(
                  s287Id(2),
                  'launch.review_rejected',
                  'launch2-projects-mine',
                ),
                row(s287Id(3), 'launch.activated', 'launch2-instance'),
                row(s287Id(4), 'launch.deploy_failed', 'launch2-projects-mine'),
                row(s287Id(5), 'launch.unheard_of', 'launch2-projects-mine'),
              ],
              'nextCursor': null,
              'unreadCount': 5,
              'push': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
              'contractVersion': '2.0',
            }),
          );
        }),
      );
      final feed = await api.getFeed(
        accessToken: 'privy-access-token',
        clientVersion: s5ClientVersion,
      );
      expect(feed.items.map((entry) => entry.kind), <LoopNotificationKind?>[
        LoopNotificationKind.launchReviewApproved,
        LoopNotificationKind.launchReviewRejected,
        LoopNotificationKind.launchActivated,
        LoopNotificationKind.launchDeployFailed,
        null,
      ]);
      expect(feed.items.every((entry) => entry.type == null), isTrue);
      expect(feed.items.last.rawType, 'launch.unheard_of');
      expect(feed.priceAlerts, isEmpty);
    });
  });

  group('presentation', () {
    test('the server title / body win', () {
      final views = _serverRows().map(loopNotificationPresentation).toList();
      expect(views.map((view) => view.icon), <String>[
        'key',
        'blocked',
        'launch',
        'warn',
        'bell',
      ]);
      expect(views[0].title, 'FROG 审核已通过');
      expect(views[0].body, '请完成签名，发射才会部署');
      expect(views[1].body, '项目简介与白皮书不一致');
      expect(views[2].body, '开售时间 2026-10-25 20:00（北京时间）');
      expect(views[3].title, 'FROG 部署失败');
      expect(views[4].title, '以后的新事件');
    });

    test('without them, the contract sentences from the row facts', () {
      LoopNotificationPresentation view(
        String type, [
        Map<String, String?> payload = const <String, String?>{},
      ]) => loopNotificationPresentation(
        _entry(
          n: 1,
          rawType: type,
          contextRoute: 'launch2-projects-mine',
          payload: payload,
        ),
      );

      final approved = view('launch.review_approved', <String, String?>{
        'projectName': 'FROG',
      });
      expect(approved.title, 'FROG 审核已通过');
      expect(approved.body, '请完成签名，发射才会部署');

      final rejected = view('launch.review_rejected', <String, String?>{
        'projectName': 'FROG',
        'reasonText': '图片含水印',
      });
      expect(rejected.title, 'FROG 审核未通过');
      expect(rejected.body, '图片含水印');

      final saleStartAt = DateTime.utc(2026, 10, 25, 12);
      final local = saleStartAt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      final activated = view('launch.activated', <String, String?>{
        'projectName': 'FROG',
        'saleStartAt': saleStartAt.toIso8601String(),
      });
      expect(activated.title, 'FROG 已上链');
      expect(
        activated.body,
        '开售时间 ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}',
      );

      final failed = view('launch.deploy_failed', <String, String?>{
        'projectName': 'FROG',
        'reasonText': '链上回滚',
      });
      expect(failed.title, 'FROG 部署失败');
      expect(failed.body, '链上回滚');

      // A row that names no project says so plainly and invents no reason
      // or sale time.
      expect(view('launch.review_approved').title, '发射审核已通过');
      expect(view('launch.review_rejected').title, '发射审核未通过');
      expect(view('launch.review_rejected').body, isNull);
      expect(view('launch.activated').title, '你的发射已上链');
      expect(
        view('launch.activated', <String, String?>{'saleStartAt': 'soon'}).body,
        isNull,
      );
      expect(view('launch.deploy_failed').title, '发射部署失败');
      expect(view('launch.deploy_failed').body, isNull);
    });

    testWidgets('the four rows draw among an unknown one', (tester) async {
      await pumpS287Inbox(
        tester,
        S287NotificationsGateway(items: _serverRows()),
      );

      expect(_key('notification-icon-${s287Id(1)}-key'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(2)}-blocked'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(3)}-launch'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(4)}-warn'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(5)}-bell'), findsOneWidget);
      expect(find.text('FROG 审核已通过'), findsOneWidget);
      expect(find.text('FROG 审核未通过'), findsOneWidget);
      expect(find.text('FROG 已上链'), findsOneWidget);
      expect(find.text('FROG 部署失败'), findsOneWidget);
      expect(find.text('以后的新事件'), findsOneWidget);
      expect(find.text('未读 5 条'), findsOneWidget);
    });
  });

  group('taps', () {
    testWidgets('each row opens its destination; the unknown one only reads', (
      tester,
    ) async {
      final gateway = S287NotificationsGateway(items: _serverRows());
      final opened = <String>[];
      await pumpS5Page(
        tester,
        NotificationInboxScreen(
          onBack: () {},
          resolveLocation: _resolve,
          onOpenLocation: opened.add,
        ),
        notifications: gateway,
        size: const Size(390, 1400),
      );

      for (var n = 1; n <= 5; n += 1) {
        await tester.tap(_key('notification-row-${s287Id(n)}'));
        await tester.pumpAndSettle();
      }

      expect(gateway.read, <String>[for (var n = 1; n <= 5; n += 1) s287Id(n)]);
      expect(opened, <String>[
        '/launch2/project/sign?id=$_projectId',
        '/launch2/projects/mine',
        '/launch2/instance?id=$s287InstanceId',
        '/launch2/projects/mine',
      ]);
    });

    test('the signing page takes the project from contextParams first', () {
      const other = '11111111-2222-4333-8444-555555555555';
      expect(
        _resolve(
          _entry(
            n: 1,
            rawType: 'launch.review_approved',
            contextRoute: 'launch2-project-sign',
            contextParams: const <String, String>{'projectId': other},
          ),
        ),
        '/launch2/project/sign?id=$other',
      );
      // A task reference names no project: the project list, naming nothing.
      expect(
        _resolve(
          _entry(
            n: 1,
            rawType: 'launch.review_approved',
            contextRoute: 'launch2-project-sign',
            entityRef: 'launchTask:$_taskId',
          ),
        ),
        '/launch2/projects/mine',
      );
      // A malformed id is not a project.
      expect(
        _resolve(
          _entry(
            n: 1,
            rawType: 'launch.review_approved',
            contextRoute: 'launch2-project-sign',
            contextParams: const <String, String>{'projectId': '../x'},
            entityRef: 'launchTask:$_taskId',
          ),
        ),
        '/launch2/projects/mine',
      );
      expect(
        LoopNotificationRouter.launchProjectIdOf('launchProject:$_projectId'),
        _projectId,
      );
      expect(
        LoopNotificationRouter.launchProjectIdOf('launchProject:nope'),
        isNull,
      );
      expect(
        LoopNotificationRouter.launchProjectIdOf('launchTask:$_taskId'),
        isNull,
      );
    });
  });

  group('push', () {
    final router = LoopNotificationRouter(
      clock: () => DateTime.utc(2026, 10, 22, 12),
    );
    const authenticated = LoopNotificationSessionContext.authenticated();

    LoopNotificationDecision route(
      String type,
      String entityRef,
      String contextRoute,
    ) => router.route(
      data: <String, Object?>{
        'type': type,
        'entityRef': entityRef,
        'contextRoute': contextRoute,
        'eventVersion': '1',
      },
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    String uuid(int n) =>
        '3e4f5a6b-7c8d-4e9f-8a0b-${n.toRadixString(16).padLeft(12, '0')}';

    final cases =
        <
          (
            LoopPushNotificationType,
            String,
            String,
            String,
            LoopNotificationContext,
            String,
            String,
          )
        >[
          (
            LoopPushNotificationType.launchReviewApproved,
            'launch_review_approved',
            'launchProject',
            'launch2-project-sign',
            const LoopNotificationContext(
              contextRoute: 'launch2-project-sign',
              projectId: _projectId,
            ),
            '/launch2/project/sign?id=$_projectId',
            '/launch2/projects/mine',
          ),
          (
            LoopPushNotificationType.launchReviewRejected,
            'launch_review_rejected',
            'launchProject',
            'launch2-projects-mine',
            const LoopNotificationContext(
              contextRoute: 'launch2-projects-mine',
            ),
            '/launch2/projects/mine',
            '/launch2/projects/mine',
          ),
          (
            LoopPushNotificationType.launchActivated,
            'launch_activated',
            'launch2Instance',
            'launch2-instance',
            const LoopNotificationContext(
              contextRoute: 'launch2-instance',
              instanceId: s287InstanceId,
            ),
            '/launch2/instance?id=$s287InstanceId',
            '/launch2/projects/mine',
          ),
          (
            LoopPushNotificationType.launchDeployFailed,
            'launch_deploy_failed',
            'launchProject',
            'launch2-projects-mine',
            const LoopNotificationContext(
              contextRoute: 'launch2-projects-mine',
            ),
            '/launch2/projects/mine',
            '/launch2/projects/mine',
          ),
        ];

    var serial = 0;
    for (final (
          type,
          wire,
          prefix,
          contextRoute,
          context,
          confirmed,
          unconfirmed,
        )
        in cases) {
      test('$wire with $contextRoute opens what the feed confirmed', () {
        expect(type.wireName, wire);
        expect(type.contextRoute.wireName, contextRoute);
        final decision = route(
          wire,
          '$prefix:${uuid(serial += 1)}',
          contextRoute,
        );
        expect(decision.disposition, LoopNotificationDisposition.pointerReady);
        expect(decision.pointer?.type, type);
        expect(
          LoopNotificationRouter.resolve(
            decision.pointer!,
            context: context,
          ).location,
          confirmed,
        );
        // No record, or a record of another family: nothing from the
        // payload is used.
        expect(
          LoopNotificationRouter.resolve(decision.pointer!).location,
          unconfirmed,
        );
        expect(
          LoopNotificationRouter.resolve(
            decision.pointer!,
            context: const LoopNotificationContext(
              contextRoute: 'token',
              projectId: _projectId,
              instanceId: s287InstanceId,
            ),
          ).location,
          unconfirmed,
        );
      });

      for (final wrong in <String>[
        'launch2-project-sign',
        'launch2-projects-mine',
        'launch2-instance',
        'token',
        'launch2-projects',
      ]) {
        if (wrong == contextRoute) continue;
        test('$wire paired with $wrong fails closed', () {
          final decision = route(wire, '$prefix:${uuid(serial += 1)}', wrong);
          expect(decision.disposition, LoopNotificationDisposition.malformed);
          expect(decision.pointer, isNull);
        });
      }
    }

    test('the push names map to the feed types', () {
      expect(
        <String, String?>{
          for (final type in <LoopPushNotificationType>[
            LoopPushNotificationType.launchReviewApproved,
            LoopPushNotificationType.launchReviewRejected,
            LoopPushNotificationType.launchActivated,
            LoopPushNotificationType.launchDeployFailed,
          ])
            type.wireName: type.feedType,
        },
        <String, String?>{
          'launch_review_approved': 'launch.review_approved',
          'launch_review_rejected': 'launch.review_rejected',
          'launch_activated': 'launch.activated',
          'launch_deploy_failed': 'launch.deploy_failed',
        },
      );
    });

    test('a project event may name its deployment task instead', () {
      for (final (type, contextRoute) in <(String, String)>[
        ('launch_review_approved', 'launch2-project-sign'),
        ('launch_review_rejected', 'launch2-projects-mine'),
        ('launch_deploy_failed', 'launch2-projects-mine'),
      ]) {
        expect(
          route(
            type,
            'launchTask:${uuid(serial += 1)}',
            contextRoute,
          ).disposition,
          LoopNotificationDisposition.pointerReady,
          reason: type,
        );
      }
      // The activation is about the instance, not the task.
      expect(
        route(
          'launch_activated',
          'launchTask:${uuid(serial += 1)}',
          'launch2-instance',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
    });

    test('a wrong entity kind, the dotted name or an unknown type fails', () {
      expect(
        route(
          'launch_review_approved',
          'launch2Instance:${uuid(serial += 1)}',
          'launch2-project-sign',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
      expect(
        route(
          'launch_review_approved',
          'launchProject:not-a-uuid',
          'launch2-project-sign',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
      expect(
        route(
          'launch.review_approved',
          'launchProject:${uuid(serial += 1)}',
          'launch2-project-sign',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
      expect(
        route(
          'launch_review_pending',
          'launchProject:${uuid(serial += 1)}',
          'launch2-projects-mine',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
    });

    test('a fifth key still fails closed', () {
      final decision = router.route(
        data: <String, Object?>{
          'type': 'launch_review_approved',
          'entityRef': 'launchProject:$_projectId',
          'contextRoute': 'launch2-project-sign',
          'eventVersion': '1',
          'projectId': _projectId,
        },
        ingress: LoopNotificationIngress.interaction,
        session: authenticated,
      );
      expect(decision.disposition, LoopNotificationDisposition.malformed);
    });

    test('the older pairs are unchanged', () {
      expect(
        LoopPushNotificationType.launchGraduated.contextRoute.wireName,
        'launch2-instance',
      );
      expect(
        LoopNotificationRouter.resolve(
          route(
            'launch_graduated',
            'launch2Instance:${uuid(serial += 1)}',
            'launch2-instance',
          ).pointer!,
        ).location,
        '/meme',
      );
    });
  });

  group('settings', () {
    testWidgets('资格快照与开始提醒 names the new rows and still says 暂不生效', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );
      final row = _key('notification-category-launch.round');
      await scrollToS5Section(tester, row);
      expect(
        find.descendant(
          of: row,
          matching: find.text('含共识勋章、发射审核结果与上链进度 · 暂不生效'),
        ),
        findsOneWidget,
      );
      expect(LoopNotificationCategory.launchRound.deliversToday, isFalse);
    });
  });
}
