import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';

LoopChainGatewayMode _notificationsMode(Ref ref) =>
    ref.watch(notificationsGatewayProvider.select((gateway) => gateway.mode));

/// The context notification feed. There is no standalone notification centre:
/// this list is embedded in the `alerts` page and the token page.
final class NotificationFeedController
    extends LoopChainReadController<LoopNotificationFeed> {
  @override
  LoopChainGatewayMode watchMode() => _notificationsMode(ref);

  @override
  Future<LoopNotificationFeed> fetch() =>
      ref.read(notificationsGatewayProvider).loadFeed();

  /// Marks one notification read. The operation is naturally idempotent and a
  /// repeat returns the same `readAt`.
  Future<bool> markRead(String notificationId) async {
    final current = state.value;
    if (current == null || state.busy) return false;
    state = state.working(true);
    try {
      final updated = await ref
          .read(notificationsGatewayProvider)
          .markRead(notificationId);
      final items = <LoopNotificationEntry>[
        for (final entry in current.items)
          if (entry.notificationId == updated.notificationId)
            updated
          else
            entry,
      ];
      final wasUnread = current.items.any(
        (entry) => entry.notificationId == notificationId && entry.isUnread,
      );
      state = state.ready(
        LoopNotificationFeed(
          items: items,
          nextCursor: current.nextCursor,
          unreadCount: wasUnread && current.unreadCount > 0
              ? current.unreadCount - 1
              : current.unreadCount,
          push: current.push,
        ),
      );
      return true;
    } on LoopChainException catch (error) {
      state = state.working(false).failed(error.kind);
      return false;
    } catch (_) {
      state = state.working(false).failed(LoopChainFailureKind.unexpected);
      return false;
    }
  }
}

final notificationFeedControllerProvider =
    NotifierProvider.autoDispose<
      NotificationFeedController,
      LoopChainResourceState<LoopNotificationFeed>
    >(NotificationFeedController.new);

/// `notif-settings` · the ten categories with a version compare-and-set.
@immutable
final class NotificationPreferencesState {
  const NotificationPreferencesState({
    required this.mode,
    required this.phase,
    this.resource,
    this.failureKind,
    this.busy = false,
    this.requiresReload = false,
  });

  factory NotificationPreferencesState.initial(LoopChainGatewayMode mode) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return NotificationPreferencesState(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final LoopNotificationPreferences? resource;
  final LoopChainFailureKind? failureKind;
  final bool busy;
  final bool requiresReload;

  bool get isReady => phase == LoopChainViewPhase.ready && resource != null;

  NotificationPreferencesState copyWith({
    LoopChainViewPhase? phase,
    LoopNotificationPreferences? resource,
    LoopChainFailureKind? failureKind,
    bool clearFailure = false,
    bool? busy,
    bool? requiresReload,
  }) => NotificationPreferencesState(
    mode: mode,
    phase: phase ?? this.phase,
    resource: resource ?? this.resource,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
    requiresReload: requiresReload ?? this.requiresReload,
  );
}

final class NotificationPreferencesController
    extends Notifier<NotificationPreferencesState>
    with LoopChainSingleFlight {
  @override
  NotificationPreferencesState build() {
    nextGeneration();
    final mode = ref.watch(
      notificationsGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return NotificationPreferencesState.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.copyWith(
      phase: state.resource == null
          ? LoopChainViewPhase.loading
          : LoopChainViewPhase.ready,
      clearFailure: true,
      requiresReload: false,
    );
    try {
      final resource = await ref
          .read(notificationsGatewayProvider)
          .loadPreferences();
      if (!isCurrent(generation)) return;
      state = NotificationPreferencesState(
        mode: state.mode,
        phase: LoopChainViewPhase.ready,
        resource: resource,
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      _fail(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      _fail(LoopChainFailureKind.unexpected);
    }
  });

  /// Toggles one category and commits immediately under the CAS version.
  ///
  /// `security.event` is locked: the toggle is not interactive and the write
  /// always carries `true`, because the server rejects `false` outright.
  Future<bool> toggle(LoopNotificationCategory category, bool enabled) async {
    final resource = state.resource;
    if (resource == null || state.busy || state.requiresReload) return false;
    if (resource.lockedFor(category)) return false;
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final next = await ref
          .read(notificationsGatewayProvider)
          .replacePreferences(
            expectedVersion: resource.version,
            categories: resource.draftWith(category, enabled),
          );
      state = NotificationPreferencesState(
        mode: state.mode,
        phase: LoopChainViewPhase.ready,
        resource: next,
      );
      return true;
    } on LoopChainException catch (error) {
      state = state.copyWith(
        busy: false,
        failureKind: error.kind,
        requiresReload: error.kind == LoopChainFailureKind.versionConflict,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        failureKind: LoopChainFailureKind.unexpected,
      );
      return false;
    }
  }

  void _fail(LoopChainFailureKind kind) {
    state = state.copyWith(
      phase: state.resource == null
          ? loopChainPhaseForFailure(kind)
          : LoopChainViewPhase.ready,
      failureKind: kind,
      busy: false,
    );
  }
}

final notificationPreferencesControllerProvider =
    NotifierProvider.autoDispose<
      NotificationPreferencesController,
      NotificationPreferencesState
    >(NotificationPreferencesController.new);
