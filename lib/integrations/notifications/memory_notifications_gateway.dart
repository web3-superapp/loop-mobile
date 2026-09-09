import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';

/// Explicit Development Preview notification preferences and feed, written
/// against the V2 contract.
///
/// Three contract rules are reproduced exactly, because a Preview that broke
/// them would teach the wrong shape:
///
/// * all ten categories are always present, and a write carries all ten;
/// * `security.event` is locked on — a write that tries to turn it off is
///   refused rather than ignored, which is what the server does;
/// * delivery is unavailable whatever is saved: there is no push channel in
///   either composition, so [LoopNotificationPreferences.push] stays
///   `PUSH_RUNTIME_DEFERRED`.
///
/// Only `lib/main_preview.dart` may construct it.
final class MemoryNotificationsGateway implements NotificationsGateway {
  MemoryNotificationsGateway({Map<LoopNotificationCategory, bool>? enabled})
    : _enabled = <LoopNotificationCategory, bool>{
        for (final category in LoopNotificationCategory.values)
          category:
              category == LoopNotificationCategory.securityEvent ||
              (enabled?[category] ?? _defaultEnabled(category)),
      };

  static const push = LoopUnavailable('PUSH_RUNTIME_DEFERRED');

  static bool _defaultEnabled(LoopNotificationCategory category) =>
      category != LoopNotificationCategory.communityAll;

  final Map<LoopNotificationCategory, bool> _enabled;
  int _version = 1;
  DateTime? _updatedAt = DateTime.utc(2026, 9, 1, 8, 30);

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;

  LoopNotificationPreferences get _preferences => LoopNotificationPreferences(
    version: _version,
    updatedAt: _updatedAt,
    categories: <LoopNotificationCategory, LoopNotificationCategoryState>{
      for (final category in LoopNotificationCategory.values)
        category: LoopNotificationCategoryState(
          enabled: _enabled[category]!,
          locked: category == LoopNotificationCategory.securityEvent,
        ),
    },
    push: push,
  );

  @override
  Future<LoopNotificationPreferences> loadPreferences() async => _preferences;

  @override
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  }) async {
    if (expectedVersion != _version) {
      throw const LoopChainException(LoopChainFailureKind.versionConflict);
    }
    // The exact ten keys, and `security.event` true. The server answers
    // `422 VALIDATION_FAILED` rather than quietly correcting either one.
    if (categories.length != LoopNotificationCategory.values.length ||
        !LoopNotificationCategory.values.every(categories.containsKey) ||
        categories[LoopNotificationCategory.securityEvent] != true) {
      throw const LoopChainException(LoopChainFailureKind.validationFailed);
    }
    _enabled
      ..clear()
      ..addAll(categories);
    _version += 1;
    _updatedAt = DateTime.now().toUtc();
    return _preferences;
  }

  /// The context feed has no producer in Preview either: only the price-alert
  /// evaluator writes notifications, and it runs server-side.
  @override
  Future<LoopNotificationFeed> loadFeed({String? cursor}) async =>
      LoopNotificationFeed(
        items: const <LoopNotificationEntry>[],
        nextCursor: null,
        unreadCount: 0,
        push: push,
      );

  @override
  Future<LoopNotificationEntry> markRead(String notificationId) =>
      Future<LoopNotificationEntry>.error(
        const LoopChainException(LoopChainFailureKind.notFound),
      );
}
