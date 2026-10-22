import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/notifications/community_application_notifications.dart';
import 'package:loop_mobile/features/notifications/notification_inbox.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `notifications` · index / stream (decision 0241, 需求方 2026-10-22 第 10 条).
///
/// The account's notifications in one list: 今天 and 更早, newest first as the
/// feed returns them, with an unread dot and a bold title on what has not been
/// read. A tap marks the row read and opens what the server's record names —
/// the page asks [resolveLocation], which is the notification router's own
/// record resolution, and never builds a location itself. A row whose
/// destination this build does not know is marked read and stays.
///
/// States: loading, empty (「还没有通知」), error with retry, offline,
/// unavailable (no adapter) and permission, all through
/// [LoopChainStateBlock]; a Development Preview says 演示数据.
class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({
    super.key,
    this.onBack,
    this.onOpenSettings,
    this.resolveLocation,
    this.onOpenLocation,
  });

  final VoidCallback? onBack;

  /// Opens `notif-settings`.
  final VoidCallback? onOpenSettings;

  /// Where a row leads, or `null` when nowhere this build knows.
  final String? Function(LoopNotificationEntry entry)? resolveLocation;

  /// Opens a location [resolveLocation] produced.
  final ValueChanged<String>? onOpenLocation;

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(notificationsGatewayProvider).mode;
    final state = ref.watch(notificationInboxControllerProvider);
    final controller = ref.read(notificationInboxControllerProvider.notifier);
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final feed = state.value;
    final now = ref.watch(loopReadClockProvider)();
    final hasUnread =
        feed != null &&
        (feed.unreadCount > 0 || feed.items.any((entry) => entry.isUnread));
    final empty =
        state.phase == LoopChainViewPhase.ready &&
        feed != null &&
        feed.items.isEmpty &&
        feed.nextCursor == null;

    Future<void> refresh() async {
      await controller.reload();
      unawaited(
        ref.read(notificationUnreadCountProvider.notifier).refresh(force: true),
      );
    }

    return LoopFlat(
      child: LoopStreamPage(
        key: const ValueKey<String>('notification-inbox-screen'),
        archetype: LoopPageArchetype.listing,
        title: '通知',
        kicker: loopChainPreviewKicker(mode),
        onBack: widget.onBack,
        subtitle: feed == null
            ? null
            : feed.unreadCount > 0
            ? '未读 ${feed.unreadCount} 条'
            : null,
        actions: <Widget>[
          if (hasUnread)
            LoopIconButton(
              key: const ValueKey<String>('notification-inbox-read-all'),
              icon: 'check',
              label: '全部已读',
              onPressed: controller.markingAll
                  ? null
                  : () => unawaited(_markAllRead(controller)),
            ),
        ],
        onRefresh: refresh,
        updating: state.refreshing,
        collection: ListView(
          key: const ValueKey<String>('notification-inbox-list'),
          physics: loopRefreshablePhysics(refresh),
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            LoopChainPreviewNotice(mode: mode, resource: '通知'),
            LoopPersonRow(
              key: const ValueKey<String>('notification-inbox-settings'),
              height: 56,
              leading: const LoopEntryIcon('settings', size: 36),
              title: '通知设置',
              subtitle: '选择想收到哪些通知',
              chevron: true,
              onTap: widget.onOpenSettings,
            ),
            if (empty)
              const LoopEmptyState(
                key: ValueKey<String>('notification-inbox-empty'),
                illustration: LoopIllustration.history,
                title: '还没有通知',
                message: '代币毕业、勋章铸造、好友申请和安全提醒会出现在这里。',
              )
            else if (state.phase != LoopChainViewPhase.ready || feed == null)
              LoopChainStateBlock(
                keyPrefix: 'notification-inbox',
                phase: state.phase,
                failureKind: state.failureKind,
                rows: 6,
                onRetry: () => unawaited(controller.reload()),
              )
            else ...<Widget>[
              for (final (day, rows) in loopNotificationGroups(
                feed.items,
                now: now,
              )) ...<Widget>[
                LoopLabel(
                  day.label,
                  key: ValueKey<String>('notification-inbox-day-${day.name}'),
                  tight: true,
                ),
                for (final entry in rows)
                  _NotificationRow(
                    key: ValueKey<String>(
                      'notification-row-${entry.notificationId}',
                    ),
                    entry: entry,
                    now: now,
                    onTap: () => unawaited(_open(entry, controller)),
                  ),
              ],
              LoopLoadMoreFooter(
                key: const ValueKey<String>('notification-inbox-footer'),
                keyPrefix: 'notification-inbox',
                cursor: feed.nextCursor,
                canLoadMore: !controller.loadingMore && !state.refreshing,
                loading: controller.loadingMore,
                onLoadMore: controller.loadMore,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    LoopNotificationEntry entry,
    NotificationInboxController controller,
  ) async {
    final location = widget.resolveLocation?.call(entry);
    final wasUnread = entry.isUnread;
    await controller.markRead(entry.notificationId);
    if (wasUnread) {
      unawaited(
        ref.read(notificationUnreadCountProvider.notifier).refresh(force: true),
      );
    }
    if (!mounted || location == null) return;
    widget.onOpenLocation?.call(location);
  }

  Future<void> _markAllRead(NotificationInboxController controller) async {
    final marked = await controller.markAllRead();
    unawaited(
      ref.read(notificationUnreadCountProvider.notifier).refresh(force: true),
    );
    if (!mounted) return;
    LoopToast.show(
      context,
      message: marked == null ? '没有标记成功，请稍后再试' : '已全部标为已读',
      kind: marked == null ? LoopToastKind.err : LoopToastKind.ok,
    );
  }
}

/// What one row says: its glyph, its title and its one line of body.
///
/// Every word comes from the row. A kind or category this build knows gets
/// its own sentence; anything else is drawn plainly from the payload's own
/// `title` and `body`, so an unknown type never takes the list down.
@immutable
final class LoopNotificationPresentation {
  const LoopNotificationPresentation({
    required this.icon,
    required this.title,
    this.body,
  });

  final String icon;
  final String title;
  final String? body;
}

String? _text(LoopNotificationEntry entry, String key) {
  final value = entry.payload[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

LoopNotificationPresentation loopNotificationPresentation(
  LoopNotificationEntry entry,
) {
  final title = _text(entry, 'title');
  final body = _text(entry, 'body');
  final symbol = _text(entry, 'symbol') ?? _text(entry, 'ticker');
  final name =
      _text(entry, 'alias') ??
      _text(entry, 'displayName') ??
      _text(entry, 'nickname') ??
      _text(entry, 'loopId');
  switch (entry.kind) {
    case LoopNotificationKind.launchGraduated:
      return LoopNotificationPresentation(
        icon: 'graduate',
        title:
            title ??
            switch (symbol ?? _text(entry, 'projectName')) {
              final String subject => '$subject 已毕业',
              null => '你参与的项目已毕业',
            },
        body: body ?? _text(entry, 'projectName'),
      );
    case LoopNotificationKind.launchBadgeMinted:
      final tokenId = _text(entry, 'tokenId');
      return LoopNotificationPresentation(
        icon: 'crown',
        title: title ?? '共识勋章铸造完成',
        body:
            body ??
            switch ((symbol, tokenId)) {
              (final String s, final String t) => '$s · #$t',
              (final String s, null) => s,
              (null, final String t) => '#$t',
              (null, null) => null,
            },
      );
    case LoopNotificationKind.friendRequest:
      return LoopNotificationPresentation(
        icon: 'user',
        title: title ?? '新的好友申请',
        body: body ?? (name == null ? null : '$name 想加你为好友'),
      );
    case LoopNotificationKind.friendAccepted:
      return LoopNotificationPresentation(
        icon: 'users',
        title: title ?? '好友申请已通过',
        body: body ?? (name == null ? null : '你和 $name 已成为好友'),
      );
    case null:
      break;
  }
  final application = CommunityApplicationNotification.read(entry);
  if (application != null) {
    return LoopNotificationPresentation(
      icon: 'community',
      title: application.title,
      body: application.body,
    );
  }
  switch (entry.type) {
    case LoopNotificationCategory.tradePriceAlert:
      final threshold = _text(entry, 'threshold');
      final observed = _text(entry, 'observedValue');
      return LoopNotificationPresentation(
        icon: 'chart',
        title: title ?? (symbol == null ? '价格提醒已触发' : '$symbol 价格提醒已触发'),
        body:
            body ??
            (threshold == null || observed == null
                ? null
                : '目标 $threshold · 观察值 $observed'),
      );
    case LoopNotificationCategory.securityEvent:
      return LoopNotificationPresentation(
        icon: 'shield',
        title:
            title ??
            (entry.payload['event'] == 'session_revoked'
                ? '撤销了一个设备会话'
                : '安全事件'),
        body: body ?? _text(entry, 'platform'),
      );
    case LoopNotificationCategory.communityMention:
    case LoopNotificationCategory.communityAnnouncement:
    case LoopNotificationCategory.communityAll:
      return LoopNotificationPresentation(
        icon: 'community',
        title: title ?? entry.type!.label,
        body: body,
      );
    case LoopNotificationCategory.launchRound:
    case LoopNotificationCategory.launchGraduation:
      return LoopNotificationPresentation(
        icon: 'launch',
        title: title ?? entry.type!.label,
        body: body,
      );
    case LoopNotificationCategory.miningSettlement:
    case LoopNotificationCategory.miningWeight:
      return LoopNotificationPresentation(
        icon: 'mine',
        title: title ?? entry.type!.label,
        body: body,
      );
    case LoopNotificationCategory.tradeResult:
      return LoopNotificationPresentation(
        icon: 'swap-vert',
        title: title ?? entry.type!.label,
        body: body,
      );
    case null:
      return LoopNotificationPresentation(
        icon: 'bell',
        title: title ?? '通知',
        body: body,
      );
  }
}

/// One row: an 8 dp unread dot in its own column (kept empty once read so the
/// glyphs line up), the kind's glyph, the title over one line of body, and
/// the time on the right.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.entry,
    required this.now,
    required this.onTap,
    super.key,
  });

  final LoopNotificationEntry entry;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final view = loopNotificationPresentation(entry);
    final unread = entry.isUnread;
    final id = entry.notificationId;
    final time = loopRelativeTime(entry.createdAt, now: now);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, LoopSpacing.page, 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 12,
              child: unread
                  ? Center(
                      child: Container(
                        key: ValueKey<String>('notification-unread-$id'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: LoopColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            LoopEntryIcon(
              view.icon,
              key: ValueKey<String>('notification-icon-$id-${view.icon}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    view.title,
                    key: ValueKey<String>('notification-title-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style:
                        LoopTypography.withWeight(
                          LoopType.title,
                          unread ? FontWeight.w700 : FontWeight.w400,
                        ).copyWith(
                          color: unread ? LoopColors.chalk : LoopColors.text2,
                        ),
                  ),
                  if (view.body case final String body) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      key: ValueKey<String>('notification-body-$id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              time,
              style: LoopType.caption.copyWith(color: LoopColors.text3),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label:
          '${unread ? '未读，' : ''}${view.title}'
          '${view.body == null ? '' : '，${view.body}'}，$time',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          highlightColor: LoopColors.card2,
          child: row,
        ),
      ),
    );
  }
}
