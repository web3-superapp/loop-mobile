import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

/// Single-flight guard shared by the S5 controllers: one in-flight operation
/// per controller, and a generation counter so a result that arrives after a
/// rebuild is dropped instead of overwriting newer truth.
mixin LoopChainSingleFlight {
  Future<void>? _operation;
  int _generation = 0;

  int nextGeneration() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  Future<void> single(Future<void> Function() body) {
    final active = _operation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = body().whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }
}

/// Base for one read-only S5 resource block.
///
/// Every S5 page composes several of these, so one failing block leaves the
/// blocks that did load untouched.
abstract base class LoopChainReadController<T>
    extends Notifier<LoopChainResourceState<T>>
    with LoopChainSingleFlight {
  /// Watches the owning gateway's mode so the block fails closed when the
  /// adapter is absent.
  LoopChainGatewayMode watchMode();

  Future<T> fetch();

  @override
  LoopChainResourceState<T> build() {
    nextGeneration();
    final mode = watchMode();
    ref.onDispose(nextGeneration);
    return LoopChainResourceState<T>.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.loading();
    try {
      final value = await fetch();
      if (!isCurrent(generation)) return;
      state = state.ready(value);
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(LoopChainFailureKind.unexpected);
    }
  });
}

/// `networks` · `GET /v2/chain/status`.
final class ChainStatusController
    extends LoopChainReadController<LoopChainStatus> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(chainGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopChainStatus> fetch() =>
      ref.read(chainGatewayProvider).loadStatus();
}

final chainStatusControllerProvider =
    NotifierProvider.autoDispose<
      ChainStatusController,
      LoopChainResourceState<LoopChainStatus>
    >(ChainStatusController.new);

/// `asset` header · `GET /v2/assets/{assetId}`.
final class ChainAssetController
    extends LoopChainReadController<LoopChainAssetView> {
  ChainAssetController(this.assetId);

  final String assetId;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(chainGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopChainAssetView> fetch() =>
      ref.read(chainGatewayProvider).loadAsset(assetId);
}

final chainAssetControllerProvider = NotifierProvider.autoDispose
    .family<
      ChainAssetController,
      LoopChainResourceState<LoopChainAssetView>,
      String
    >(ChainAssetController.new);

/// Whether the one-time "Launch 当前运行在 BSC 测试网" explanation has been
/// closed in this run.
///
/// It is shared by every Launch surface and by the signing exit, so the
/// explanation appears once rather than once per page. Dismissing it is a
/// convenience, never a stored decision and never a permission: the badge
/// itself stays on every surface that is on the testnet.
final class LoopTestnetNoticeController extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final loopTestnetNoticeDismissedProvider =
    NotifierProvider<LoopTestnetNoticeController, bool>(
      LoopTestnetNoticeController.new,
    );
