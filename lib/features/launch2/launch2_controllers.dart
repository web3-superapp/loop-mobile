import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

LoopChainGatewayMode _launch2Mode(Ref ref) =>
    ref.watch(launch2GatewayProvider.select((gateway) => gateway.mode));

/// Whether the MEME v2 surface is drawn at all: the build switch is on and
/// the server published `launch2` as `available` (contract §1). A switch that
/// is off keeps the MEME Tab exactly as it was.
bool launch2SurfaceVisible(WidgetRef ref) {
  final switches = ref.watch(loopFeatureSwitchesProvider);
  if (!switches.launch2Visible) return false;
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.launch2),
  );
  final mode = ref.watch(launch2GatewayProvider.select((g) => g.mode));
  return mode == LoopChainGatewayMode.preview || capability.isAvailable;
}

/// Whether the `launch2` reads are closed for this build: no transport, or
/// the server said the capability is not available.
bool launch2ReadsBlocked(WidgetRef ref) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.launch2),
  );
  final mode = ref.watch(launch2GatewayProvider.select((g) => g.mode));
  return loopChainCapabilityBlocks(mode, capability);
}

/// The one clock every countdown on a MEME v2 surface reads. Tests replace
/// it; production reads the device clock in UTC.
final launch2ClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// How often a project page re-reads the instance.
@immutable
final class Launch2Polling {
  const Launch2Polling({
    this.detailInterval = const Duration(seconds: 15),
    this.tradingInterval = const Duration(seconds: 5),
    this.listInterval = const Duration(seconds: 60),
  });

  /// Every stage that only waits for a time or an event.
  final Duration detailInterval;

  /// `priority` / `public`: the curve moves with every order.
  final Duration tradingInterval;

  /// A v2 list while it is on screen (decision 0148).
  final Duration listInterval;
}

final launch2PollingProvider = Provider<Launch2Polling>(
  (ref) => const Launch2Polling(),
);

/// MEME Tab · one v2 list, read a page at a time as the reader scrolls. The
/// rows read so far stay when a later page fails.
final class Launch2ListController
    extends LoopChainReadController<Launch2InstancePage> {
  Launch2ListController(this.scope);

  final Launch2ListScope scope;
  bool _appendFailed = false;

  /// Pages appended below the first since the last full read.
  int _deeperPages = 0;

  /// The next [fetch] keeps the deeper rows (a poll, a return from a
  /// project page) instead of starting the list over.
  bool _keepDeeper = false;

  bool get appendFailed => _appendFailed;

  /// The stages move with the clock; a list from the last visit is stale.
  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _launch2Mode(ref);

  @override
  Future<Launch2InstancePage> fetch() async {
    _appendFailed = false;
    final keep = _keepDeeper;
    _keepDeeper = false;
    final head = await ref
        .read(launch2GatewayProvider)
        .listInstances(stage: scope.stage);
    final current = state.value;
    if (!keep || current == null || _deeperPages == 0) {
      _deeperPages = 0;
      return head;
    }
    if (head.nextCursor == null) _deeperPages = 0;
    return current.refreshHead(head);
  }

  /// Re-reads the first page and lays it over the rows already scrolled to
  /// (decision 0148: the 60 s poll and the return from a project page). A
  /// pull still starts the list over ([reload]).
  Future<void> refresh() {
    if (state.value == null || inFlight) return reload();
    _keepDeeper = true;
    return reload();
  }

  /// Reads the page after the rows on screen. A cursor the server no longer
  /// accepts (`400`) sends the list back to its first page.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || state.busy) return;
    _appendFailed = false;
    state = state.working(true);
    try {
      final page = await ref
          .read(launch2GatewayProvider)
          .listInstances(stage: scope.stage, cursor: cursor);
      if (!ref.mounted) return;
      _deeperPages += 1;
      state = state.working(false).ready(current.append(page));
    } on LoopChainException catch (error) {
      if (!ref.mounted) return;
      if (error.kind == LoopChainFailureKind.invalidData) {
        state = state.working(false);
        await reload();
        return;
      }
      _appendFailed = true;
      state = state.working(false).failed(error.kind);
    } catch (_) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(LoopChainFailureKind.readFailed);
    }
  }
}

final launch2ListControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2ListController,
      LoopChainResourceState<Launch2InstancePage>,
      Launch2ListScope
    >(Launch2ListController.new);

/// `launch2-instance` · `GET /v2/launch2/instances/{id}`.
final class Launch2InstanceController
    extends LoopChainReadController<Launch2InstanceDetail> {
  Launch2InstanceController(this.instanceId);

  final String instanceId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _launch2Mode(ref);

  @override
  Future<Launch2InstanceDetail> fetch() =>
      ref.read(launch2GatewayProvider).loadInstance(instanceId);
}

final launch2InstanceControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2InstanceController,
      LoopChainResourceState<Launch2InstanceDetail>,
      String
    >(Launch2InstanceController.new);

/// 回购面板 · `GET /v2/launch2/instances/{id}/buybacks` (first page).
final class Launch2BuybacksController
    extends LoopChainReadController<Launch2BuybackPage> {
  Launch2BuybacksController(this.instanceId);

  final String instanceId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _launch2Mode(ref);

  @override
  Future<Launch2BuybackPage> fetch() =>
      ref.read(launch2GatewayProvider).loadBuybacks(instanceId);
}

final launch2BuybacksControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2BuybacksController,
      LoopChainResourceState<Launch2BuybackPage>,
      String
    >(Launch2BuybacksController.new);

/// 钱包 · 资产 · `GET /v2/launch2/me/positions`.
final class Launch2PositionsController
    extends LoopChainReadController<Launch2Positions> {
  @override
  LoopChainGatewayMode watchMode() => _launch2Mode(ref);

  @override
  Future<Launch2Positions> fetch() =>
      ref.read(launch2GatewayProvider).loadPositions();
}

final launch2PositionsControllerProvider =
    NotifierProvider.autoDispose<
      Launch2PositionsController,
      LoopChainResourceState<Launch2Positions>
    >(Launch2PositionsController.new);

/// Which wallet's pool trades, and at which own-trade count: a count that
/// moved is a new key, so the list is read again (decision 0148).
typedef Launch2PoolTradesKey = ({
  String instanceId,
  String walletId,
  BigInt count,
});

/// 我的外盘成交 · `GET …/pool/trades?walletId=` (decision 0148).
final class Launch2PoolTradesController
    extends LoopChainReadController<Launch2PoolTrades> {
  Launch2PoolTradesController(this.key);

  final Launch2PoolTradesKey key;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _launch2Mode(ref);

  @override
  Future<Launch2PoolTrades> fetch() => ref
      .read(launch2GatewayProvider)
      .loadPoolTrades(instanceId: key.instanceId, walletId: key.walletId);
}

final launch2PoolTradesControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2PoolTradesController,
      LoopChainResourceState<Launch2PoolTrades>,
      Launch2PoolTradesKey
    >(Launch2PoolTradesController.new);

/// Starts [provider]'s first read when nothing asked yet. Call from `build`.
void launch2LoadOnce<T>(
  WidgetRef ref,
  LoopChainResourceState<T> state,
  Future<void> Function() load,
) {
  if (state.phase == LoopChainViewPhase.loading && state.value == null) {
    scheduleMicrotask(() => unawaited(load()));
  }
}
