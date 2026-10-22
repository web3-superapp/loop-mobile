import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';

/// Feature-facing port for the context notification feed and the ten
/// notification preference categories.
abstract interface class NotificationsGateway {
  LoopChainGatewayMode get mode;

  Future<LoopNotificationFeed> loadFeed({String? cursor});

  /// Marking read carries an `Idempotency-Key`; the operation is naturally
  /// idempotent and a repeat returns the same `readAt`.
  Future<LoopNotificationEntry> markRead(String notificationId);

  /// The account's unread total, or `null` when the server has no such
  /// endpoint yet (`404`, decision 0241): the badge is then not drawn.
  Future<LoopNotificationUnreadCount?> loadUnreadCount();

  /// Marks every notification read and answers how many changed, or `null`
  /// when the server has no such endpoint yet (`404`). The notification
  /// centre then marks the rows it holds one by one.
  Future<int?> markAllRead();

  Future<LoopNotificationPreferences> loadPreferences();

  /// Whole-resource replacement under a version CAS. All ten keys are always
  /// sent, and `security.event` is always `true`.
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  });
}

final class UnavailableNotificationsGateway implements NotificationsGateway {
  const UnavailableNotificationsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopNotificationFeed> loadFeed({String? cursor}) => _unavailable();

  @override
  Future<LoopNotificationEntry> markRead(String notificationId) =>
      _unavailable();

  @override
  Future<LoopNotificationUnreadCount?> loadUnreadCount() => _unavailable();

  @override
  Future<int?> markAllRead() => _unavailable();

  @override
  Future<LoopNotificationPreferences> loadPreferences() => _unavailable();

  @override
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  }) => _unavailable();
}

final notificationsGatewayProvider = Provider<NotificationsGateway>(
  (ref) => const UnavailableNotificationsGateway(),
);
