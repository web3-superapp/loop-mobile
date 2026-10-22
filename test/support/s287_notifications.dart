// S287 · decision 0241: shared fixtures of the notification centre tests
// and its self-review shots.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_inbox_screen.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';

import 's5_fixtures.dart';
import 's5_page_harness.dart';

const s287InstanceId = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const s287ProfileId = '5c6d7e8f-9a0b-4c1d-8e2f-3a4b5c6d7e8f';
const s287RequestId = '0f1e2d3c-4b5a-4968-8776-655443322110';

/// The page's fixed "now": 2026-10-22 15:00 on the device's own clock.
final DateTime s287Now = DateTime(2026, 10, 22, 15);

String s287Id(int n) =>
    '${n.toRadixString(16).padLeft(8, '0')}-1111-4111-8111-111111111111';

LoopNotificationEntry s287Entry({
  required String id,
  LoopNotificationCategory? type,
  String? rawType,
  String contextRoute = 'launch2-instance',
  Map<String, String> contextParams = const <String, String>{
    'instanceId': s287InstanceId,
  },
  Map<String, String?> payload = const <String, String?>{},
  DateTime? readAt,
  DateTime? createdAt,
}) => LoopNotificationEntry(
  notificationId: id,
  type: type,
  rawType: rawType,
  entityRef: 'launch2Instance:$s287InstanceId',
  contextRoute: contextRoute,
  contextParams: contextParams,
  payload: payload,
  source: null,
  observedAt: null,
  readAt: readAt,
  createdAt: (createdAt ?? s287Now.subtract(const Duration(hours: 1))).toUtc(),
);

/// A notifications port whose every answer a test sets.
final class S287NotificationsGateway implements NotificationsGateway {
  S287NotificationsGateway({
    List<LoopNotificationEntry>? items,
    this.nextCursor,
    this.feedFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : items = items ?? <LoopNotificationEntry>[];

  List<LoopNotificationEntry> items;
  String? nextCursor;
  LoopChainFailureKind? feedFailure;
  Map<String, LoopNotificationFeed> pages = <String, LoopNotificationFeed>{};
  final List<String?> cursors = <String?>[];

  @override
  final LoopChainGatewayMode mode;

  final List<String> read = <String>[];
  LoopNotificationUnreadCount? unread;
  int unreadReads = 0;
  int? readAllAnswer;
  int readAllCalls = 0;

  @override
  Future<LoopNotificationFeed> loadFeed({String? cursor}) async {
    cursors.add(cursor);
    final failure = feedFailure;
    if (failure != null) throw LoopChainException(failure);
    if (cursor != null) {
      final page = pages[cursor];
      if (page == null) {
        throw const LoopChainException(LoopChainFailureKind.readFailed);
      }
      return page;
    }
    return LoopNotificationFeed(
      items: items,
      nextCursor: nextCursor,
      unreadCount: items.where((entry) => entry.isUnread).length,
      push: null,
    );
  }

  @override
  Future<LoopNotificationEntry> markRead(String notificationId) async {
    read.add(notificationId);
    final held = <LoopNotificationEntry>[
      ...items,
      for (final page in pages.values) ...page.items,
    ].firstWhere((entry) => entry.notificationId == notificationId);
    return held.markedRead(DateTime.utc(2026, 10, 22, 7));
  }

  @override
  Future<LoopNotificationUnreadCount?> loadUnreadCount() async {
    unreadReads += 1;
    return unread;
  }

  @override
  Future<int?> markAllRead() async {
    readAllCalls += 1;
    return readAllAnswer;
  }

  @override
  Future<LoopNotificationPreferences> loadPreferences() async =>
      s5Preferences();

  @override
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  }) async => s5Preferences();
}

List<LoopNotificationEntry> s287MixedRows() => <LoopNotificationEntry>[
  s287Entry(
    id: s287Id(1),
    rawType: 'launch.graduated',
    payload: const <String, String?>{'symbol': 'FROG'},
  ),
  s287Entry(
    id: s287Id(2),
    rawType: 'social.friend_request',
    contextRoute: 'dm-requests',
    contextParams: const <String, String>{},
    payload: const <String, String?>{'displayName': 'Nightowl'},
    readAt: DateTime.utc(2026, 10, 22, 6, 30),
  ),
  s287Entry(
    id: s287Id(3),
    rawType: 'launch.badge_minted',
    payload: const <String, String?>{'symbol': 'FROG', 'tokenId': '12'},
    createdAt: DateTime(2026, 10, 20, 9),
  ),
  s287Entry(
    id: s287Id(4),
    rawType: 'social.friend_accepted',
    contextRoute: 'user-profile',
    contextParams: const <String, String>{'publicProfileId': s287ProfileId},
    payload: const <String, String?>{'displayName': 'Pepe Maxi'},
    createdAt: DateTime(2026, 10, 19, 20),
    readAt: DateTime.utc(2026, 10, 20),
  ),
  s287Entry(
    id: s287Id(5),
    rawType: 'mystery.kind',
    contextRoute: 'somewhere-new',
    contextParams: const <String, String>{},
    payload: const <String, String?>{'title': '一条新通知', 'body': '这一类还没有专门的样式'},
    createdAt: DateTime(2026, 10, 18, 9),
  ),
];

/// The router's own record resolution, as `lib/app.dart` composes it.
String? s287Resolve(LoopNotificationEntry entry) =>
    LoopNotificationRouter.resolveRecord(
      LoopNotificationContext(
        contextRoute: entry.contextRoute,
        assetId: entry.contextParams['assetId'],
        communityId: entry.contextParams['communityId'],
        instanceId: entry.contextParams['instanceId'],
        publicProfileId: entry.contextParams['publicProfileId'],
      ),
    )?.location;

Future<List<String>> pumpS287Inbox(
  WidgetTester tester,
  S287NotificationsGateway gateway, {
  List<String>? settingsOpened,
  Size size = const Size(390, 1400),
}) async {
  final opened = <String>[];
  await pumpS5Page(
    tester,
    NotificationInboxScreen(
      onBack: () {},
      onOpenSettings: () => settingsOpened?.add('notif-settings'),
      resolveLocation: s287Resolve,
      onOpenLocation: opened.add,
    ),
    notifications: gateway,
    size: size,
    overrides: <Override>[
      loopReadClockProvider.overrideWithValue(() => s287Now),
    ],
  );
  return opened;
}
