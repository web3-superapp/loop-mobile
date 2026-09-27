import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_read_retention.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
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

  /// Whether an operation is running right now.
  bool get inFlight => _operation != null;

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
///
/// Since decision 0095 a block outlives its page for
/// [LoopSnapshotPolicy.memoryRetention]: a page that comes back draws the
/// answer it had, marked 更新中, while the block re-reads behind it. A block
/// that names a [snapshotResource] may also open on the answer a previous run
/// stored, when that answer is young enough; the page then says how old it is
/// until the live answer replaces it.
abstract base class LoopChainReadController<T>
    extends Notifier<LoopChainResourceState<T>>
    with LoopChainSingleFlight {
  /// Watches the owning gateway's mode so the block fails closed when the
  /// adapter is absent.
  LoopChainGatewayMode watchMode();

  Future<T> fetch();

  /// The cold-start snapshot this block may open on, or `null` for none.
  ///
  /// Only the four read-only first screens name one (decision 0095). A value
  /// a signature or a write is checked against never does.
  String? get snapshotResource => null;

  /// Whether the answer outlives the page. A block whose page promises a read
  /// taken on the spot turns it off.
  bool get retainsAnswer => true;

  DateTime? _readAt;
  DateTime? _restoredObservedAt;

  /// When this device received the answer on screen, live or restored.
  DateTime? get valueObservedAt => _readAt;

  /// Non-null while the answer on screen is a stored snapshot from an earlier
  /// run rather than an answer this run received: when it was received.
  DateTime? get restoredObservedAt => _restoredObservedAt;

  DateTime _now() => ref.read(loopReadClockProvider)();

  @override
  LoopChainResourceState<T> build() {
    nextGeneration();
    final mode = watchMode();
    // A different account is a different set of answers: the block starts
    // over rather than showing the last account's.
    ref.watch(loopAccountScopeProvider);
    ref.onDispose(nextGeneration);
    _readAt = null;
    _restoredObservedAt = null;
    if (retainsAnswer) loopRetainRead(ref, onRevisit: _revisit);
    final initial = LoopChainResourceState<T>.initial(mode);
    if (mode == LoopChainGatewayMode.unavailable) return initial;
    final resource = snapshotResource;
    if (resource == null) return initial;
    final restored = ref.read(loopSnapshotRestorerProvider)?.restore(resource);
    final value = restored?.value;
    if (restored == null || value is! T) return initial;
    _readAt = restored.observedAt;
    _restoredObservedAt = restored.observedAt;
    // The stored answer is drawn at once; the live read starts behind it.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(reload());
    });
    return LoopChainResourceState<T>(
      mode: mode,
      phase: LoopChainViewPhase.ready,
      value: value,
    );
  }

  void _revisit() {
    // A block that has not been asked for yet is loaded by its page.
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      return;
    }
    if (!loopRevisitIsDue(
      hasValue: state.value != null,
      inFlight: inFlight,
      readAt: _readAt,
      now: _now(),
    )) {
      return;
    }
    unawaited(reload());
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    // A first read has nothing to fall back on, so the phase it lands in is
    // the whole page. `offline` there must mean the device, not a socket the
    // peer closed while the app sat idle: that failure carries no server
    // answer and a fresh connection normally succeeds. The first read is
    // therefore allowed one silent re-attempt, during which the page stays in
    // its loading phase instead of announcing an outage it has not confirmed.
    //
    // The same dropped socket does not always arrive as `offline`. Dio reports
    // a connection the peer closed mid-response as `unknown`, which maps on a
    // read to `readFailed`, and that is how 关于 greeted its first open with an
    // error while the manual retry worked every time. Neither kind carries a
    // server answer, so both get the one silent re-attempt; a read that fails
    // the same way twice still reports what it failed with.
    final firstRead = state.value == null;
    state = state.loading();
    var reattempted = false;
    while (true) {
      try {
        final value = await fetch();
        if (!isCurrent(generation)) return;
        _readAt = _now();
        _restoredObservedAt = null;
        state = state.ready(value);
        return;
      } on LoopChainException catch (error) {
        if (!isCurrent(generation)) return;
        if (firstRead &&
            !reattempted &&
            _mayBeATransientFirstRead(error.kind)) {
          reattempted = true;
          continue;
        }
        state = state.failed(error.kind);
        return;
      } catch (_) {
        if (!isCurrent(generation)) return;
        if (firstRead && !reattempted) {
          reattempted = true;
          continue;
        }
        state = state.failed(LoopChainFailureKind.readFailed);
        return;
      }
    }
  });

  /// Whether a first read that failed this way may have failed on transport
  /// alone. Both kinds are reported with no server answer behind them.
  static bool _mayBeATransientFirstRead(LoopChainFailureKind kind) =>
      kind == LoopChainFailureKind.offline ||
      kind == LoopChainFailureKind.timedOut ||
      kind == LoopChainFailureKind.unexpected ||
      kind == LoopChainFailureKind.readFailed;
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
