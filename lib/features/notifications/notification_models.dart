import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The ten reviewed notification categories.
///
/// `security.event` is forced on and locked: the server rejects `false` for it
/// rather than ignoring it, so the UI must always submit `true`.
enum LoopNotificationCategory {
  miningSettlement('mining.settlement', '挖矿', '每日结算完成', null),
  miningWeight('mining.weight', '挖矿', '权重变化', '持有币的 Mining Weight 调整时'),
  launchRound('launch.round', 'Launch', '资格快照与开始提醒', null),
  launchGraduation('launch.graduation', 'Launch', '毕业通知', null),
  tradeResult('trade.result', '交易', '成交结果', null),
  tradePriceAlert('trade.priceAlert', '交易', '价格提醒', '关闭后价格提醒仍会记录事件，但不会生成通知'),
  communityMention('community.mention', '社区', '@我的消息', null),
  communityAnnouncement('community.announcement', '社区', '公告', null),
  communityAll('community.all', '社区', '全部消息', '大群建议关闭'),
  securityEvent('security.event', '安全', '安全事件', '无法关闭');

  const LoopNotificationCategory(
    this.wireName,
    this.section,
    this.label,
    this.detail,
  );

  final String wireName;
  final String section;
  final String label;
  final String? detail;

  static LoopNotificationCategory? tryParse(String value) {
    for (final category in values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

@immutable
final class LoopNotificationCategoryState {
  const LoopNotificationCategoryState({
    required this.enabled,
    required this.locked,
  });

  final bool enabled;
  final bool locked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopNotificationCategoryState &&
          other.enabled == enabled &&
          other.locked == locked;

  @override
  int get hashCode => Object.hash(enabled, locked);
}

/// `GET/PUT /v2/notification-preferences`.
@immutable
final class LoopNotificationPreferences {
  LoopNotificationPreferences({
    required this.version,
    required this.updatedAt,
    required Map<LoopNotificationCategory, LoopNotificationCategoryState>
    categories,
    required this.push,
  }) : categories =
           Map<
             LoopNotificationCategory,
             LoopNotificationCategoryState
           >.unmodifiable(categories);

  final int version;
  final DateTime? updatedAt;
  final Map<LoopNotificationCategory, LoopNotificationCategoryState> categories;

  /// Always unavailable: there is no FCM/APNs project.
  final LoopUnavailable push;

  bool enabledFor(LoopNotificationCategory category) =>
      categories[category]?.enabled ?? false;

  bool lockedFor(LoopNotificationCategory category) =>
      categories[category]?.locked ?? false;

  int get enabledCount =>
      categories.values.where((state) => state.enabled).length;

  /// The exact ten-key map a write must carry, with the requested edit applied
  /// and `security.event` pinned to `true`.
  Map<LoopNotificationCategory, bool> draftWith(
    LoopNotificationCategory category,
    bool enabled,
  ) {
    final draft = <LoopNotificationCategory, bool>{
      for (final entry in categories.entries) entry.key: entry.value.enabled,
    };
    if (category != LoopNotificationCategory.securityEvent) {
      draft[category] = enabled;
    }
    draft[LoopNotificationCategory.securityEvent] = true;
    return draft;
  }
}

/// One context notification. There is no standalone notification centre: the
/// feed is reachable from the `alerts` page and the token page.
@immutable
final class LoopNotificationEntry {
  LoopNotificationEntry({
    required this.notificationId,
    required this.type,
    required this.entityRef,
    required this.contextRoute,
    required Map<String, String> contextParams,
    required Map<String, String?> payload,
    required this.source,
    required this.observedAt,
    required this.readAt,
    required this.createdAt,
  }) : contextParams = Map<String, String>.unmodifiable(contextParams),
       payload = Map<String, String?>.unmodifiable(payload);

  final String notificationId;
  final LoopNotificationCategory type;

  /// `priceAlert:<alertId>` — used to highlight the alert row it belongs to.
  final String entityRef;

  /// The server-decided destination slug plus its parameters. The client never
  /// builds a route from display text.
  final String contextRoute;
  final Map<String, String> contextParams;

  /// Display facts only; every value is a string with provenance in the same
  /// object.
  final Map<String, String?> payload;
  final String? source;
  final DateTime? observedAt;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  /// The alert id this notification refers to, when it is a price alert.
  String? get priceAlertId {
    const prefix = 'priceAlert:';
    if (!entityRef.startsWith(prefix)) return null;
    final id = entityRef.substring(prefix.length);
    return id.isEmpty ? null : id;
  }
}

@immutable
final class LoopNotificationFeed {
  LoopNotificationFeed({
    required List<LoopNotificationEntry> items,
    required this.nextCursor,
    required this.unreadCount,
    required this.push,
  }) : items = List<LoopNotificationEntry>.unmodifiable(items);

  final List<LoopNotificationEntry> items;
  final String? nextCursor;
  final int unreadCount;
  final LoopUnavailable push;

  List<LoopNotificationEntry> get priceAlerts => items
      .where((entry) => entry.type == LoopNotificationCategory.tradePriceAlert)
      .toList(growable: false);
}
