import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The ten reviewed notification categories.
///
/// `security.event` is forced on and locked: the server rejects `false` for it
/// rather than ignoring it, so the UI must always submit `true`.
enum LoopNotificationCategory {
  miningSettlement('mining.settlement', '挖矿', '每日结算完成', null),
  miningWeight('mining.weight', '挖矿', '权重变化', '持有币的 Mining Weight 调整时'),
  // Decision 0242: the category also files the badge (0241) and a launched
  // project's review and deployment progress. The detail names what it
  // covers; whether any of it is sent today is the separate 暂不生效 mark.
  launchRound('launch.round', 'Launch', '资格快照与开始提醒', '含共识勋章、发射审核结果与上链进度'),
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

  /// Whether turning this category on produces a notification today.
  ///
  /// Only price alerts are emitted; every other category stores an intent the
  /// backend does not act on yet. The page says so per row rather than
  /// counting ten switches as ten notifications.
  ///
  /// `launch.round` stays false under decision 0242: the review and
  /// deployment rows it now files are written only once the server's
  /// `LAUNCH_REVIEW_INBOX_EMIT` is on, and that switch is off by default, so
  /// claiming them here would promise what the account does not receive.
  bool get deliversToday => this == LoopNotificationCategory.tradePriceAlert;

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

  /// The push channel, or `null` once the server has one.
  ///
  /// It is not a promise about this device: the account may still have refused
  /// the system permission, and no notification has been seen arriving on a
  /// real device yet. It only says whether there is a channel at all.
  final LoopUnavailable? push;

  bool enabledFor(LoopNotificationCategory category) =>
      categories[category]?.enabled ?? false;

  bool lockedFor(LoopNotificationCategory category) =>
      categories[category]?.locked ?? false;

  int get enabledCount =>
      categories.values.where((state) => state.enabled).length;

  /// How many switches that are on actually produce a notification today.
  ///
  /// 「9 项开启」 was true of the stored intent and false of the account's
  /// experience: only `trade.priceAlert` is emitted, so the other switches
  /// change a value the server keeps and nothing else. The summary counts what
  /// arrives; the page still shows every switch, each marked with whether it
  /// is in effect.
  int get deliveringEnabledCount => categories.entries
      .where((entry) => entry.value.enabled && entry.key.deliversToday)
      .length;

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

/// The notification kinds that are finer than a preference category
/// (decision 0241, loop-api S286; four more by decision 0242, loop-api S291).
///
/// They arrive in a feed row's `type` where older rows carry the category
/// itself. The category the account's preference governs is still one of the
/// ten; [category] says which, so a kind never adds an eleventh switch.
enum LoopNotificationKind {
  launchGraduated(
    'launch.graduated',
    LoopNotificationCategory.launchGraduation,
  ),
  // loop-api decision 0177: the badge is the snapshot credential, so it is
  // filed under 资格快照与开始提醒.
  launchBadgeMinted(
    'launch.badge_minted',
    LoopNotificationCategory.launchRound,
  ),
  friendRequest(
    'social.friend_request',
    LoopNotificationCategory.communityMention,
  ),
  friendAccepted(
    'social.friend_accepted',
    LoopNotificationCategory.communityMention,
  ),
  // Decision 0242 (loop-api S291): the review and deployment progress of a
  // project the account launched, all filed under 资格快照与开始提醒.
  launchReviewApproved(
    'launch.review_approved',
    LoopNotificationCategory.launchRound,
  ),
  launchReviewRejected(
    'launch.review_rejected',
    LoopNotificationCategory.launchRound,
  ),
  launchActivated('launch.activated', LoopNotificationCategory.launchRound),
  launchDeployFailed(
    'launch.deploy_failed',
    LoopNotificationCategory.launchRound,
  );

  const LoopNotificationKind(this.wireName, this.category);

  final String wireName;

  /// The preference category this kind is filed under, for display only.
  final LoopNotificationCategory category;

  static LoopNotificationKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One context notification.
///
/// Decision 0241 put the rows in one list — the notification centre under
/// 聊天 — and kept the two context readers (the `alerts` page and the token
/// page) exactly as they were.
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
    String? rawType,
    this.readStateKnown = true,
  }) : rawType = rawType ?? type?.wireName ?? 'unknown',
       contextParams = Map<String, String>.unmodifiable(contextParams),
       payload = Map<String, String?>.unmodifiable(payload);

  final String notificationId;

  /// The preference category the row's `type` names, or `null` when the row
  /// carries a finer [kind] or a type this build does not know. Every reader
  /// that filters by category (price alerts, community verdicts, security
  /// events) therefore keeps seeing only its own rows.
  final LoopNotificationCategory? type;

  /// The row's `type` exactly as the server sent it. A type this build does
  /// not know is kept, never refused: the row is drawn in the plain style.
  final String rawType;

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

  /// Whether the row said anything about being read. A row without the
  /// `readAt` key is treated as read (decision 0241): an unread mark the
  /// server never stated would be a claim the client made up.
  final bool readStateKnown;

  bool get isUnread => readStateKnown && readAt == null;

  /// One of the finer kinds, or `null`.
  LoopNotificationKind? get kind => LoopNotificationKind.tryParse(rawType);

  /// The category this row is filed under, whichever way it was named.
  LoopNotificationCategory? get category => type ?? kind?.category;

  /// The alert id this notification refers to, when it is a price alert.
  String? get priceAlertId {
    const prefix = 'priceAlert:';
    if (!entityRef.startsWith(prefix)) return null;
    final id = entityRef.substring(prefix.length);
    return id.isEmpty ? null : id;
  }

  /// The same row, read at [at]. Used by the notification centre when a
  /// read-all is confirmed by its count rather than row by row.
  LoopNotificationEntry markedRead(DateTime at) => LoopNotificationEntry(
    notificationId: notificationId,
    type: type,
    rawType: rawType,
    entityRef: entityRef,
    contextRoute: contextRoute,
    contextParams: contextParams,
    payload: payload,
    source: source,
    observedAt: observedAt,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );
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
  final LoopUnavailable? push;

  List<LoopNotificationEntry> get priceAlerts => items
      .where((entry) => entry.type == LoopNotificationCategory.tradePriceAlert)
      .toList(growable: false);
}

/// 「来源 …」 for a notification, and only when the name is one LOOP already
/// shows elsewhere.
///
/// The notification contract leaves `source` an open `[a-z][a-z0-9_]*`
/// identifier, so it arrives as a pipeline name: every row on the review
/// device read 「来源 mock_seed」. A value that maps onto a provider prints as
/// that provider; anything else is an internal string, and a source a reader
/// cannot check is not provenance, so the segment is dropped.
String? loopNotificationSourceLabel(String? source) {
  if (source == null) return null;
  final provider = LoopFactSource.tryParse(source);
  return provider == null ? null : '来源 ${loopFactSourceLabel(provider)}';
}

/// `GET /v2/notifications/unread-count` (decision 0241, loop-api S286).
@immutable
final class LoopNotificationUnreadCount {
  const LoopNotificationUnreadCount({
    required this.unread,
    required this.observedAt,
  });

  final int unread;
  final DateTime observedAt;
}
