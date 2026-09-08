import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

LoopChainGatewayMode _walletMode(Ref ref) =>
    ref.watch(walletReadGatewayProvider.select((gateway) => gateway.mode));

/// `wallets` · `GET /v2/wallets` plus the active-wallet compare-and-set.
final class WalletDirectoryController
    extends LoopChainReadController<LoopWalletDirectory> {
  @override
  LoopChainGatewayMode watchMode() => _walletMode(ref);

  @override
  Future<LoopWalletDirectory> fetch() =>
      ref.read(walletReadGatewayProvider).loadWallets();

  /// Switches the active wallet under a compare-and-set on the currently
  /// rendered active id.
  ///
  /// A concurrent switch fails with `versionConflict`. The directory is then
  /// re-read before the action is offered again, because the id this page was
  /// rendered from is provably no longer the server's. The controller stays
  /// busy across both the write and that reload, so no row can be tapped while
  /// the page is showing an id the server has already replaced.
  Future<bool> setActive(String walletId) async {
    final current = state.value;
    if (current == null || state.busy) return false;
    state = state.working(true);
    try {
      final next = await ref
          .read(walletReadGatewayProvider)
          .setActiveWallet(
            walletId: walletId,
            expectedActiveWalletId: current.activeWalletId,
          );
      state = state.ready(next);
      return true;
    } on LoopChainException catch (error) {
      state = state.working(false).failed(error.kind);
      if (error.kind == LoopChainFailureKind.versionConflict) {
        await _reloadAfterConflict();
      }
      return false;
    } catch (_) {
      state = state.working(false).failed(LoopChainFailureKind.unexpected);
      return false;
    }
  }

  /// Re-reads the directory while keeping the conflict visible.
  ///
  /// The failure kind survives the reload so the page can still say the switch
  /// did not happen; only the stale id is replaced.
  Future<void> _reloadAfterConflict() async {
    final conflict = state.failureKind;
    state = state.working(true);
    try {
      final directory = await ref.read(walletReadGatewayProvider).loadWallets();
      state = state
          .ready(directory)
          .failed(conflict ?? LoopChainFailureKind.versionConflict);
    } on LoopChainException catch (error) {
      state = state.working(false).failed(error.kind);
    } catch (_) {
      state = state.working(false).failed(LoopChainFailureKind.unexpected);
    }
  }
}

final walletDirectoryControllerProvider =
    NotifierProvider.autoDispose<
      WalletDirectoryController,
      LoopChainResourceState<LoopWalletDirectory>
    >(WalletDirectoryController.new);

/// The active wallet id, or `null` while the directory has not been read. It
/// is never guessed from an address.
final activeWalletIdProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(walletDirectoryControllerProvider).value?.activeWalletId;
});

/// `wallet` / `networth` / `asset` · `…/balances`.
final class WalletBalancesController
    extends LoopChainReadController<LoopWalletBalances> {
  WalletBalancesController(this.walletId);

  final String walletId;

  @override
  LoopChainGatewayMode watchMode() => _walletMode(ref);

  @override
  Future<LoopWalletBalances> fetch() =>
      ref.read(walletReadGatewayProvider).loadBalances(walletId);
}

final walletBalancesControllerProvider = NotifierProvider.autoDispose
    .family<
      WalletBalancesController,
      LoopChainResourceState<LoopWalletBalances>,
      String
    >(WalletBalancesController.new);

/// `tx-history` · `…/activity`, with cursor paging that keeps the rows it
/// already showed when a later page fails.
final class WalletActivityController
    extends LoopChainReadController<LoopWalletActivityPage> {
  WalletActivityController(this.walletId);

  final String walletId;

  bool _loadingMore = false;

  bool get isLoadingMore => _loadingMore;

  @override
  LoopChainGatewayMode watchMode() => _walletMode(ref);

  @override
  Future<LoopWalletActivityPage> fetch() =>
      ref.read(walletReadGatewayProvider).loadActivity(walletId);

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || _loadingMore) return;
    _loadingMore = true;
    final generation = nextGeneration();
    try {
      final next = await ref
          .read(walletReadGatewayProvider)
          .loadActivity(walletId, cursor: cursor);
      if (!isCurrent(generation)) return;
      // One indexed log is unique by transaction hash plus log index, so a
      // row that was already shown is never appended twice.
      final seen = current.items.map((entry) => entry.entryId).toSet();
      state = state.ready(
        LoopWalletActivityPage(
          walletId: current.walletId,
          items: <LoopWalletActivityEntry>[
            ...current.items,
            ...next.items.where((entry) => seen.add(entry.entryId)),
          ],
          nextCursor: next.nextCursor,
          freshness: next.freshness,
          nativeTransfers: next.nativeTransfers,
          crossChain: next.crossChain,
        ),
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      // The rows already shown stay; only the paging failure is surfaced.
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(LoopChainFailureKind.unexpected);
    } finally {
      _loadingMore = false;
    }
  }
}

final walletActivityControllerProvider = NotifierProvider.autoDispose
    .family<
      WalletActivityController,
      LoopChainResourceState<LoopWalletActivityPage>,
      String
    >(WalletActivityController.new);

/// `receive` · `…/receive`.
final class WalletReceiveController
    extends LoopChainReadController<LoopWalletReceive> {
  WalletReceiveController(this.walletId);

  final String walletId;

  @override
  LoopChainGatewayMode watchMode() => _walletMode(ref);

  @override
  Future<LoopWalletReceive> fetch() =>
      ref.read(walletReadGatewayProvider).loadReceive(walletId);
}

final walletReceiveControllerProvider = NotifierProvider.autoDispose
    .family<
      WalletReceiveController,
      LoopChainResourceState<LoopWalletReceive>,
      String
    >(WalletReceiveController.new);
