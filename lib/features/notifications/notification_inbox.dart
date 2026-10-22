import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';

/// `notifications` · the notification centre's list (decision 0241).
///
/// The same `GET /v2/notifications/feed` the `alerts` page and the token page
/// read, held by its own controller so the two context readers keep exactly
/// the behaviour they had. Paging follows the feed's cursor; a read is one
/// `POST …/read`; 「全部已读」 is `POST /v2/notifications/read-all` and, on a
/// server that does not have it yet, the rows on screen one by one.
final class NotificationInboxController
    extends LoopChainReadController<LoopNotificationFeed> {
  /// Whether the server answered `read-all` with `404` in this session. Once
  /// it has, 「全部已读」 goes straight to the row-by-row fallback.
  bool _readAllAbsent = false;

  bool _loadingMore = false;
  bool _markingAll = false;

  /// Whether the next page is being read.
  bool get loadingMore => _loadingMore;

  /// Whether 「全部已读」 is running.
  bool get markingAll => _markingAll;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(notificationsGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopNotificationFeed> fetch() =>
      ref.read(notificationsGatewayProvider).loadFeed();

  /// Reads the page after the one on screen and appends it. A row already
  /// held is not added twice.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || _loadingMore || inFlight) return;
    _loadingMore = true;
    state = state.working(true);
    try {
      final page = await ref
          .read(notificationsGatewayProvider)
          .loadFeed(cursor: cursor);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final held = <String>{
        for (final entry in latest.items) entry.notificationId,
      };
      state = state.ready(
        LoopNotificationFeed(
          items: <LoopNotificationEntry>[
            ...latest.items,
            for (final entry in page.items)
              if (held.add(entry.notificationId)) entry,
          ],
          nextCursor: page.nextCursor,
          unreadCount: page.unreadCount,
          push: page.push,
        ),
      );
    } catch (_) {
      // The page stays as it was; the footer offers the retry.
      if (ref.mounted) state = state.working(false);
    } finally {
      _loadingMore = false;
    }
  }

  /// Marks one row read. A row that is already read is not written again.
  ///
  /// A failure leaves the row unread and the page as it was: the tap that
  /// asked for it still opens its destination.
  Future<bool> markRead(String notificationId) async {
    final current = state.value;
    if (current == null) return false;
    final held = current.items
        .where((entry) => entry.notificationId == notificationId)
        .firstOrNull;
    if (held == null || !held.isUnread) return held != null;
    try {
      final updated = await ref
          .read(notificationsGatewayProvider)
          .markRead(notificationId);
      if (!ref.mounted) return true;
      _replace(<String, LoopNotificationEntry>{
        updated.notificationId: updated,
      }, read: 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 「全部已读」. Answers how many rows changed, or `null` when nothing
  /// could be confirmed.
  Future<int?> markAllRead() async {
    final current = state.value;
    if (current == null || _markingAll) return null;
    _markingAll = true;
    try {
      final gateway = ref.read(notificationsGatewayProvider);
      if (!_readAllAbsent) {
        final marked = await gateway.markAllRead();
        if (!ref.mounted) return marked;
        if (marked != null) {
          final now = ref.read(loopReadClockProvider)().toUtc();
          final latest = state.value ?? current;
          state = state.ready(
            LoopNotificationFeed(
              items: <LoopNotificationEntry>[
                for (final entry in latest.items)
                  entry.isUnread ? entry.markedRead(now) : entry,
              ],
              nextCursor: latest.nextCursor,
              unreadCount: 0,
              push: latest.push,
            ),
          );
          return marked;
        }
        _readAllAbsent = true;
      }
      // An older server: the rows this page holds, one `…/read` each.
      var marked = 0;
      final unread = (state.value ?? current).items
          .where((entry) => entry.isUnread)
          .map((entry) => entry.notificationId)
          .toList(growable: false);
      for (final id in unread) {
        try {
          final updated = await gateway.markRead(id);
          if (!ref.mounted) return marked + 1;
          marked += 1;
          _replace(<String, LoopNotificationEntry>{
            updated.notificationId: updated,
          }, read: 1);
        } catch (_) {
          // The rest still get their chance; this row stays unread.
        }
      }
      return marked;
    } catch (_) {
      return null;
    } finally {
      _markingAll = false;
    }
  }

  void _replace(Map<String, LoopNotificationEntry> rows, {required int read}) {
    final latest = state.value;
    if (latest == null) return;
    final remaining = latest.unreadCount - read;
    state = state.ready(
      LoopNotificationFeed(
        items: <LoopNotificationEntry>[
          for (final entry in latest.items) rows[entry.notificationId] ?? entry,
        ],
        nextCursor: latest.nextCursor,
        unreadCount: remaining < 0 ? 0 : remaining,
        push: latest.push,
      ),
    );
  }
}

final notificationInboxControllerProvider =
    NotifierProvider.autoDispose<
      NotificationInboxController,
      LoopChainResourceState<LoopNotificationFeed>
    >(NotificationInboxController.new);

/// The unread total under the 聊天 bell (decision 0241).
///
/// `null` draws nothing: no adapter, a Preview build, a server without
/// `GET /v2/notifications/unread-count`, or a first read that has not
/// answered. It is read when the bell first appears, when the App comes back
/// to the foreground, when a LOOP notification arrives and after the
/// notification centre marks anything read — never on a timer, and a
/// foreground return reads at most once per [minimumInterval].
final class NotificationUnreadCountController extends Notifier<int?> {
  static const Duration minimumInterval = Duration(seconds: 60);

  DateTime? _readAt;
  Future<void>? _inFlight;
  int _generation = 0;

  @override
  int? build() {
    ref.watch(notificationsGatewayProvider.select((gateway) => gateway.mode));
    // Another account's count is not this one's.
    ref.watch(loopAccountScopeProvider);
    _generation += 1;
    _readAt = null;
    _inFlight = null;
    return null;
  }

  /// Re-reads the count. Without [force] a read younger than
  /// [minimumInterval] is kept.
  Future<void> refresh({bool force = false}) {
    final gateway = ref.read(notificationsGatewayProvider);
    if (gateway.mode != LoopChainGatewayMode.production) {
      state = null;
      return Future<void>.value();
    }
    final now = ref.read(loopReadClockProvider)();
    final last = _readAt;
    if (!force && last != null && now.difference(last) < minimumInterval) {
      return Future<void>.value();
    }
    final active = _inFlight;
    if (active != null) return active;
    final generation = _generation;
    late final Future<void> operation;
    operation =
        () async {
          try {
            final answer = await gateway.loadUnreadCount();
            if (!ref.mounted || generation != _generation) return;
            _readAt = ref.read(loopReadClockProvider)();
            state = answer?.unread;
          } catch (_) {
            // A failed read keeps the last answer; it is asked again on the next
            // trigger.
          }
        }().whenComplete(() {
          if (identical(_inFlight, operation)) _inFlight = null;
        });
    _inFlight = operation;
    return operation;
  }
}

final notificationUnreadCountProvider =
    NotifierProvider<NotificationUnreadCountController, int?>(
      NotificationUnreadCountController.new,
    );

/// The two sections of the notification centre.
enum LoopNotificationDay {
  today('今天'),
  earlier('更早');

  const LoopNotificationDay(this.label);

  final String label;
}

/// Which section [createdAt] falls in, by the device's own calendar day.
@visibleForTesting
LoopNotificationDay loopNotificationDayOf(
  DateTime createdAt, {
  required DateTime now,
}) {
  final local = createdAt.toLocal();
  final today = now.toLocal();
  return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day
      ? LoopNotificationDay.today
      : LoopNotificationDay.earlier;
}

/// The rows of [items] grouped under 今天 / 更早, each group in feed order.
/// An empty group is not returned.
List<(LoopNotificationDay, List<LoopNotificationEntry>)> loopNotificationGroups(
  List<LoopNotificationEntry> items, {
  required DateTime now,
}) {
  final today = <LoopNotificationEntry>[];
  final earlier = <LoopNotificationEntry>[];
  for (final entry in items) {
    (loopNotificationDayOf(entry.createdAt, now: now) ==
                LoopNotificationDay.today
            ? today
            : earlier)
        .add(entry);
  }
  return <(LoopNotificationDay, List<LoopNotificationEntry>)>[
    if (today.isNotEmpty) (LoopNotificationDay.today, today),
    if (earlier.isNotEmpty) (LoopNotificationDay.earlier, earlier),
  ];
}
