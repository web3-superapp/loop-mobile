import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';

enum PerpPositionsPhase {
  initial,
  loading,
  ready,
  bindingRequired,
  stale,
  unavailable,
  failure,
}

@immutable
final class PerpPositionsState {
  PerpPositionsState._({
    required this.mode,
    required this.phase,
    Iterable<PerpPosition> items = const <PerpPosition>[],
    this.nextCursor,
    this.lastFetchedAt,
    this.expiresAt,
    this.pageCount = 0,
    this.isLoadingMore = false,
    this.failureKind,
    this.requestId,
    this.pageFailureKind,
    this.pageRequestId,
  }) : items = List<PerpPosition>.unmodifiable(items);

  factory PerpPositionsState.initial(PerpGatewayMode mode) {
    return PerpPositionsState._(
      mode: mode,
      phase: mode == PerpGatewayMode.unavailable
          ? PerpPositionsPhase.unavailable
          : PerpPositionsPhase.initial,
      failureKind: mode == PerpGatewayMode.unavailable
          ? PerpGatewayFailureKind.unavailable
          : null,
    );
  }

  final PerpGatewayMode mode;
  final PerpPositionsPhase phase;
  final List<PerpPosition> items;
  final String? nextCursor;
  final DateTime? lastFetchedAt;
  final DateTime? expiresAt;
  final int pageCount;
  final bool isLoadingMore;
  final PerpGatewayFailureKind? failureKind;
  final String? requestId;
  final PerpGatewayFailureKind? pageFailureKind;
  final String? pageRequestId;

  bool get isBusy => phase == PerpPositionsPhase.loading || isLoadingMore;

  bool get isEmpty => phase == PerpPositionsPhase.ready && items.isEmpty;

  bool get canLoadMore =>
      phase == PerpPositionsPhase.ready && !isLoadingMore && nextCursor != null;

  bool hasFreshFactsAt(DateTime now) {
    final deadline = expiresAt;
    return phase == PerpPositionsPhase.ready &&
        deadline != null &&
        deadline.isAfter(now.toUtc());
  }

  String? get failureCode => failureKind == null
      ? null
      : PerpGatewayException(failureKind!, requestId: requestId).code;

  String? get pageFailureCode => pageFailureKind == null
      ? null
      : PerpGatewayException(pageFailureKind!, requestId: pageRequestId).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerpPositionsState &&
          other.mode == mode &&
          other.phase == phase &&
          listEquals(other.items, items) &&
          other.nextCursor == nextCursor &&
          other.lastFetchedAt == lastFetchedAt &&
          other.expiresAt == expiresAt &&
          other.pageCount == pageCount &&
          other.isLoadingMore == isLoadingMore &&
          other.failureKind == failureKind &&
          other.requestId == requestId &&
          other.pageFailureKind == pageFailureKind &&
          other.pageRequestId == pageRequestId;

  @override
  int get hashCode => Object.hash(
    mode,
    phase,
    Object.hashAll(items),
    nextCursor,
    lastFetchedAt,
    expiresAt,
    pageCount,
    isLoadingMore,
    failureKind,
    requestId,
    pageFailureKind,
    pageRequestId,
  );
}

typedef PerpPositionsClock = DateTime Function();

abstract interface class PerpPositionsExpiryHandle {
  void cancel();
}

typedef PerpPositionsExpiryScheduler = PerpPositionsExpiryHandle Function(
  Duration delay,
  void Function() callback,
);

final perpPositionsClockProvider = Provider<PerpPositionsClock>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final perpPositionsExpirySchedulerProvider =
    Provider<PerpPositionsExpiryScheduler>(
      (ref) =>
          (delay, callback) => _TimerExpiryHandle(Timer(delay, callback)),
    );

final class _TimerExpiryHandle implements PerpPositionsExpiryHandle {
  const _TimerExpiryHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Owns the short-lived, backend-mediated D4 Core Perp position projection.
///
/// It exposes no wallet-binding or trading mutation. Binding remains an
/// explicit D8 account action, while continuation pages use only the opaque
/// cursor issued for the current principal, wallet, binding epoch, and route.
final class PerpPositionsController extends Notifier<PerpPositionsState> {
  static const int initialLimit = 2;

  Future<void>? _operation;
  PerpPositionsExpiryHandle? _expiry;
  var _generation = 0;

  @override
  PerpPositionsState build() {
    _generation += 1;
    _operation = null;
    _cancelExpiry();
    final mode = ref.watch(perpPrivateGatewayProvider).mode;
    ref.onDispose(() {
      _generation += 1;
      _operation = null;
      _cancelExpiry();
    });
    return PerpPositionsState.initial(mode);
  }

  /// Loads the first bounded page once for the current gateway owner.
  Future<void> load() {
    final active = _operation;
    if (active != null) return active;
    if (state.phase != PerpPositionsPhase.initial &&
        state.phase != PerpPositionsPhase.failure &&
        state.phase != PerpPositionsPhase.stale) {
      return Future<void>.value();
    }
    return _startInitialLoad();
  }

  /// Clears the previous projection before requesting a fresh first page.
  Future<void> refresh() => _startInitialLoad();

  /// Loads one continuation page. The original limit is encrypted into the
  /// cursor, so a continuation request must never send another limit.
  Future<void> loadMore() {
    final active = _operation;
    if (active != null) return active;
    if (!state.canLoadMore) return Future<void>.value();
    if (!state.hasFreshFactsAt(ref.read(perpPositionsClockProvider)())) {
      expireIfNeeded();
      return Future<void>.value();
    }

    final gateway = ref.read(perpPrivateGatewayProvider);
    if (gateway.mode == PerpGatewayMode.unavailable) {
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unavailable),
      );
      return Future<void>.value();
    }

    final cursor = state.nextCursor!;
    final generation = ++_generation;
    state = PerpPositionsState._(
      mode: state.mode,
      phase: PerpPositionsPhase.ready,
      items: state.items,
      nextCursor: state.nextCursor,
      lastFetchedAt: state.lastFetchedAt,
      expiresAt: state.expiresAt,
      pageCount: state.pageCount,
      isLoadingMore: true,
    );

    late final Future<void> operation;
    operation = _performLoadMore(gateway, generation, cursor).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  /// Clears facts synchronously when lifecycle suspension delayed the timer.
  void expireIfNeeded() {
    if (state.phase != PerpPositionsPhase.ready ||
        state.hasFreshFactsAt(ref.read(perpPositionsClockProvider)())) {
      return;
    }
    _expireProjection();
  }

  Future<void> _startInitialLoad() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(perpPrivateGatewayProvider);
    if (gateway.mode == PerpGatewayMode.unavailable) {
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unavailable),
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    _cancelExpiry();
    state = PerpPositionsState._(
      mode: gateway.mode,
      phase: PerpPositionsPhase.loading,
    );
    late final Future<void> operation;
    operation = _performInitialLoad(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performInitialLoad(
    PerpPrivateGateway gateway,
    int generation,
  ) async {
    try {
      final page = await gateway.listPositions(limit: initialLimit);
      if (!_isCurrent(generation)) return;
      _publishInitialPage(gateway.mode, page);
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, error);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
      );
    }
  }

  Future<void> _performLoadMore(
    PerpPrivateGateway gateway,
    int generation,
    String cursor,
  ) async {
    try {
      final page = await gateway.listPositions(cursor: cursor);
      if (!_isCurrent(generation) || state.phase != PerpPositionsPhase.ready) {
        return;
      }
      if (!state.hasFreshFactsAt(ref.read(perpPositionsClockProvider)())) {
        _expireProjection();
        return;
      }
      _publishContinuationPage(gateway.mode, cursor, page);
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishContinuationFailure(gateway.mode, error);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
      );
    }
  }

  void _publishInitialPage(PerpGatewayMode mode, PerpPage<PerpPosition> page) {
    final error = _validatePage(page, previousItems: const <PerpPosition>[]);
    if (error != null) {
      _publishFailure(mode, error);
      return;
    }
    final now = ref.read(perpPositionsClockProvider)().toUtc();
    if (!page.source.expiresAt.isAfter(now)) {
      _publishStale(mode);
      return;
    }

    state = PerpPositionsState._(
      mode: mode,
      phase: PerpPositionsPhase.ready,
      items: page.items,
      nextCursor: page.nextCursor,
      lastFetchedAt: page.source.fetchedAt,
      expiresAt: page.source.expiresAt,
      pageCount: 1,
    );
    _scheduleExpiry(page.source.expiresAt);
  }

  void _publishContinuationPage(
    PerpGatewayMode mode,
    String requestedCursor,
    PerpPage<PerpPosition> page,
  ) {
    final error = _validatePage(page, previousItems: state.items);
    if (error != null || page.nextCursor == requestedCursor) {
      _publishFailure(
        mode,
        error ?? const PerpGatewayException(PerpGatewayFailureKind.invalidData),
      );
      return;
    }
    final now = ref.read(perpPositionsClockProvider)().toUtc();
    if (!page.source.expiresAt.isAfter(now)) {
      _publishStale(mode);
      return;
    }

    final currentExpiry = state.expiresAt!;
    final projectionExpiry = page.source.expiresAt.isBefore(currentExpiry)
        ? page.source.expiresAt
        : currentExpiry;
    if (!projectionExpiry.isAfter(now)) {
      _publishStale(mode);
      return;
    }
    state = PerpPositionsState._(
      mode: mode,
      phase: PerpPositionsPhase.ready,
      items: <PerpPosition>[...state.items, ...page.items],
      nextCursor: page.nextCursor,
      lastFetchedAt: page.source.fetchedAt,
      expiresAt: projectionExpiry,
      pageCount: state.pageCount + 1,
    );
    _scheduleExpiry(projectionExpiry);
  }

  PerpGatewayException? _validatePage(
    PerpPage<PerpPosition> page, {
    required List<PerpPosition> previousItems,
  }) {
    if (page.source.dataset != PerpSourceDataset.positions ||
        page.coverage != null) {
      return const PerpGatewayException(PerpGatewayFailureKind.invalidData);
    }
    var previousCoin = previousItems.isEmpty
        ? -1
        : previousItems.last.coin.index;
    for (final item in page.items) {
      if (item.coin.index <= previousCoin) {
        return const PerpGatewayException(PerpGatewayFailureKind.invalidData);
      }
      previousCoin = item.coin.index;
    }
    if (page.nextCursor != null && page.items.isEmpty) {
      return const PerpGatewayException(PerpGatewayFailureKind.invalidData);
    }
    return null;
  }

  void _publishContinuationFailure(
    PerpGatewayMode mode,
    PerpGatewayException error,
  ) {
    final now = ref.read(perpPositionsClockProvider)();
    final mayKeepFreshPage =
        (error.kind == PerpGatewayFailureKind.timeout ||
            error.kind == PerpGatewayFailureKind.connection) &&
        state.hasFreshFactsAt(now);
    if (!mayKeepFreshPage) {
      _publishFailure(mode, error);
      return;
    }
    state = PerpPositionsState._(
      mode: state.mode,
      phase: PerpPositionsPhase.ready,
      items: state.items,
      nextCursor: state.nextCursor,
      lastFetchedAt: state.lastFetchedAt,
      expiresAt: state.expiresAt,
      pageCount: state.pageCount,
      pageFailureKind: error.kind,
      pageRequestId: error.requestId,
    );
  }

  void _publishFailure(PerpGatewayMode mode, PerpGatewayException error) {
    _cancelExpiry();
    state = PerpPositionsState._(
      mode: mode,
      phase: switch (error.kind) {
        PerpGatewayFailureKind.walletBindingRequired =>
          PerpPositionsPhase.bindingRequired,
        PerpGatewayFailureKind.unavailable => PerpPositionsPhase.unavailable,
        _ => PerpPositionsPhase.failure,
      },
      failureKind: error.kind,
      requestId: error.requestId,
    );
  }

  void _publishStale(PerpGatewayMode mode) {
    _cancelExpiry();
    state = PerpPositionsState._(mode: mode, phase: PerpPositionsPhase.stale);
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _cancelExpiry();
    final now = ref.read(perpPositionsClockProvider)().toUtc();
    if (!expiresAt.isAfter(now)) {
      _expireProjection();
      return;
    }
    final handle = ref.read(perpPositionsExpirySchedulerProvider)(
      expiresAt.difference(now),
      () => _expireAt(expiresAt),
    );
    if (ref.mounted &&
        state.phase == PerpPositionsPhase.ready &&
        state.expiresAt == expiresAt) {
      _expiry = handle;
    } else {
      handle.cancel();
    }
  }

  void _expireAt(DateTime expectedExpiry) {
    if (!ref.mounted ||
        state.phase != PerpPositionsPhase.ready ||
        state.expiresAt != expectedExpiry) {
      return;
    }
    _expiry = null;
    final now = ref.read(perpPositionsClockProvider)().toUtc();
    if (expectedExpiry.isAfter(now)) {
      _scheduleExpiry(expectedExpiry);
      return;
    }
    _expireProjection();
  }

  void _expireProjection() {
    if (state.phase != PerpPositionsPhase.ready) return;
    _generation += 1;
    _operation = null;
    _cancelExpiry();
    state = PerpPositionsState._(
      mode: state.mode,
      phase: PerpPositionsPhase.stale,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _cancelExpiry() {
    _expiry?.cancel();
    _expiry = null;
  }
}

final perpPositionsControllerProvider =
    NotifierProvider<PerpPositionsController, PerpPositionsState>(
      PerpPositionsController.new,
    );
