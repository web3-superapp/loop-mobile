import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';

/// `alerts` · the list plus the create / edit / delete commands.
@immutable
final class AlertsState {
  const AlertsState({
    required this.mode,
    required this.phase,
    this.page,
    this.failureKind,
    this.busy = false,
    this.refreshing = false,
  });

  factory AlertsState.initial(LoopChainGatewayMode mode) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return AlertsState(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final LoopAlertPage? page;
  final LoopChainFailureKind? failureKind;
  final bool busy;

  /// A re-read over the list this page already shows. The alerts stay on
  /// screen wearing the 更新中 mark; only a page that has read nothing yet
  /// loads as a skeleton.
  final bool refreshing;

  bool get isReady => phase == LoopChainViewPhase.ready && page != null;

  List<LoopPriceAlert> get items => page?.items ?? const <LoopPriceAlert>[];

  AlertsState copyWith({
    LoopChainViewPhase? phase,
    LoopAlertPage? page,
    LoopChainFailureKind? failureKind,
    bool clearFailure = false,
    bool? busy,
    bool? refreshing,
  }) => AlertsState(
    mode: mode,
    phase: phase ?? this.phase,
    page: page ?? this.page,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
    refreshing: refreshing ?? this.refreshing,
  );
}

final class AlertsController extends Notifier<AlertsState>
    with LoopChainSingleFlight {
  @override
  AlertsState build() {
    nextGeneration();
    final mode = ref.watch(
      alertsGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return AlertsState.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.copyWith(
      phase: state.page == null
          ? LoopChainViewPhase.loading
          : LoopChainViewPhase.ready,
      clearFailure: true,
      // A list that is already on screen is being re-read, not loaded: it
      // keeps its rows and says 更新中 instead of blanking into a skeleton.
      refreshing: state.page != null,
    );
    try {
      final page = await ref.read(alertsGatewayProvider).listAlerts();
      if (!isCurrent(generation)) return;
      state = AlertsState(
        mode: state.mode,
        phase: LoopChainViewPhase.ready,
        page: page,
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      _fail(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      _fail(LoopChainFailureKind.unexpected);
    }
  });

  /// Creates one alert. The threshold travels as a string all the way to the
  /// wire; the client never parses it into a `double`.
  Future<bool> create(LoopAlertDraft draft) =>
      _command(() => ref.read(alertsGatewayProvider).createAlert(draft));

  Future<bool> update({
    required LoopPriceAlert alert,
    required LoopAlertDraft draft,
  }) => _command(
    () => ref
        .read(alertsGatewayProvider)
        .updateAlert(
          alertId: alert.alertId,
          expectedVersion: alert.version,
          draft: draft,
        ),
  );

  Future<bool> delete(LoopPriceAlert alert) => _command(
    () => ref
        .read(alertsGatewayProvider)
        .deleteAlert(alertId: alert.alertId, expectedVersion: alert.version),
  );

  Future<bool> _command(Future<void> Function() body) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await body();
    } on LoopChainException catch (error) {
      state = state.copyWith(busy: false, failureKind: error.kind);
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        failureKind: LoopChainFailureKind.unexpected,
      );
      return false;
    }
    state = state.copyWith(busy: false);
    // The list is re-read rather than patched locally: the server owns the
    // alert state machine (`triggered` is one-shot until it is re-armed).
    await reload();
    return true;
  }

  void _fail(LoopChainFailureKind kind) {
    state = state.copyWith(
      phase: state.page == null
          ? loopChainPhaseForFailure(kind)
          : LoopChainViewPhase.ready,
      failureKind: kind,
      busy: false,
      refreshing: false,
    );
  }
}

final alertsControllerProvider =
    NotifierProvider.autoDispose<AlertsController, AlertsState>(
      AlertsController.new,
    );
