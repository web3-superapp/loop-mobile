import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

// S138 · 挖矿奖励 controllers (decisions 0140, 0141).

/// `GET /v2/mining/rewards`. It opens on the stored answer of an earlier run
/// (decision 0095 / 0132) so the summary and the minute display have figures
/// in the first frame; the live read replaces it behind.
final class MiningRewardsController
    extends LoopChainReadController<MiningRewardsView> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(miningRewardsGatewayProvider.select((gateway) => gateway.mode));

  @override
  String? get snapshotResource => LoopSnapshotResource.miningRewards;

  @override
  Future<MiningRewardsView> fetch() =>
      ref.read(miningRewardsGatewayProvider).loadRewards();
}

final miningRewardsViewControllerProvider =
    NotifierProvider.autoDispose<
      MiningRewardsController,
      LoopChainResourceState<MiningRewardsView>
    >(MiningRewardsController.new);

/// Decision 0184: [miningTokenLive] for a surface outside 挖矿奖励, read from
/// the same provider (no second request when that page has read it) and
/// asked for when nobody has yet. Until it answers the surface counts power
/// only.
bool watchMiningTokenLive(WidgetRef ref, {bool enabled = true}) {
  final state = ref.watch(miningRewardsViewControllerProvider);
  if (enabled && state.phase == LoopChainViewPhase.loading) {
    scheduleMicrotask(
      () => unawaited(
        ref.read(miningRewardsViewControllerProvider.notifier).load(),
      ),
    );
  }
  return miningTokenLive(state.value);
}

// ---------------------------------------------------------------------------
// The claim record list
// ---------------------------------------------------------------------------

@immutable
final class MiningClaimsState {
  const MiningClaimsState({
    this.phase = LoopChainViewPhase.loading,
    this.items = const <MiningClaimRecord>[],
    this.nextCursor,
    this.failureKind,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  final LoopChainViewPhase phase;
  final List<MiningClaimRecord> items;
  final String? nextCursor;
  final LoopChainFailureKind? failureKind;
  final bool loadingMore;
  final bool moreFailed;
}

/// `GET /v2/mining/claims`, newest first, read on as the reader scrolls.
final class MiningClaimsController extends Notifier<MiningClaimsState> {
  int _generation = 0;

  @override
  MiningClaimsState build() {
    final mode = ref.watch(
      miningRewardsGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(() => _generation += 1);
    if (mode == LoopChainGatewayMode.unavailable) {
      return const MiningClaimsState(
        phase: LoopChainViewPhase.unavailable,
        failureKind: LoopChainFailureKind.unavailable,
      );
    }
    return const MiningClaimsState();
  }

  Future<void> reload() async {
    if (state.phase == LoopChainViewPhase.unavailable &&
        ref.read(miningRewardsGatewayProvider).mode ==
            LoopChainGatewayMode.unavailable) {
      return;
    }
    final generation = ++_generation;
    try {
      final page = await ref.read(miningRewardsGatewayProvider).loadClaims();
      if (generation != _generation || !ref.mounted) return;
      state = MiningClaimsState(
        phase: page.items.isEmpty
            ? LoopChainViewPhase.empty
            : LoopChainViewPhase.ready,
        items: page.items,
        nextCursor: page.nextCursor,
      );
    } on LoopChainException catch (failure) {
      if (generation != _generation || !ref.mounted) return;
      state = MiningClaimsState(
        phase: loopChainPhaseForFailure(failure.kind),
        failureKind: failure.kind,
        items: state.items,
      );
    } catch (_) {
      if (generation != _generation || !ref.mounted) return;
      state = MiningClaimsState(
        phase: LoopChainViewPhase.error,
        failureKind: LoopChainFailureKind.readFailed,
        items: state.items,
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    final generation = _generation;
    state = MiningClaimsState(
      phase: state.phase,
      items: state.items,
      nextCursor: cursor,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(miningRewardsGatewayProvider)
          .loadClaims(cursor: cursor);
      if (generation != _generation || !ref.mounted) return;
      final known = <String>{for (final item in state.items) item.claimId};
      state = MiningClaimsState(
        phase: LoopChainViewPhase.ready,
        items: <MiningClaimRecord>[
          ...state.items,
          for (final item in page.items)
            if (!known.contains(item.claimId)) item,
        ],
        nextCursor: page.nextCursor == cursor ? null : page.nextCursor,
      );
    } catch (_) {
      if (generation != _generation || !ref.mounted) return;
      state = MiningClaimsState(
        phase: state.phase,
        items: state.items,
        nextCursor: cursor,
        moreFailed: true,
      );
    }
  }
}

final miningClaimsControllerProvider =
    NotifierProvider.autoDispose<MiningClaimsController, MiningClaimsState>(
      MiningClaimsController.new,
    );

// ---------------------------------------------------------------------------
// The active wallet
// ---------------------------------------------------------------------------

/// The wallet a claim is prepared for: the account's active wallet, read from
/// the wallet directory and never guessed from an address.
@immutable
final class MiningClaimWallet {
  const MiningClaimWallet({
    required this.walletId,
    required this.address,
    required this.loading,
  });

  final String? walletId;
  final String? address;
  final bool loading;
}

/// Watches the wallet directory, starting its read when nothing asked yet.
MiningClaimWallet miningClaimWallet(WidgetRef ref) {
  final state = ref.watch(walletDirectoryControllerProvider);
  if (state.phase == LoopChainViewPhase.loading && state.value == null) {
    scheduleMicrotask(() {
      unawaited(ref.read(walletDirectoryControllerProvider.notifier).load());
    });
  }
  final directory = state.value;
  final walletId = directory?.activeWalletId;
  String? address;
  for (final wallet in directory?.wallets ?? const <LoopWalletAccount>[]) {
    if (wallet.walletId == walletId) address = wallet.address;
  }
  return MiningClaimWallet(
    walletId: walletId,
    address: address,
    loading: state.phase == LoopChainViewPhase.loading,
  );
}

// ---------------------------------------------------------------------------
// One claim: prepare → sign → report → read until it settles
// ---------------------------------------------------------------------------

enum MiningClaimPhase {
  idle,

  /// `claim/prepare` is in flight; no wallet has been opened.
  preparing,

  /// The voucher is ready and the confirmation sheet is open.
  prepared,

  /// The server refused to prepare. Nothing was signed.
  prepareFailed,

  /// Not enough BNB for the network fee; USDT can be swapped for it.
  gasInsufficient,

  /// Neither BNB nor USDT in the wallet.
  noGasSource,

  /// The exit or the wallet refused. Nothing was submitted; the balance is
  /// untouched.
  signRefused,

  /// Broadcast and reported; the claim is read until it settles.
  waiting,

  /// Broadcast, but the report did not land or the wallet's outcome is
  /// unknown. Locked: no second signature.
  locked,

  /// The claim was read until the window closed without a final state.
  pollTimedOut,

  succeeded,
  failed,
  expired,
}

@immutable
final class MiningClaimState {
  const MiningClaimState({
    this.phase = MiningClaimPhase.idle,
    this.intent,
    this.failure,
    this.outcome,
    this.record,
    this.gasSwap,
    this.requiredNative,
    this.attempts = 0,
  });

  final MiningClaimPhase phase;
  final MiningClaimIntent? intent;
  final LoopChainException? failure;
  final MiningClaimSignOutcome? outcome;

  /// The claim as the server last reported it.
  final MiningClaimRecord? record;
  final MiningSuggestedSwap? gasSwap;
  final String? requiredNative;
  final int attempts;

  bool get busy =>
      phase == MiningClaimPhase.preparing || phase == MiningClaimPhase.waiting;

  /// Past the wallet: nothing may offer another signature.
  bool get locked =>
      phase == MiningClaimPhase.waiting ||
      phase == MiningClaimPhase.locked ||
      phase == MiningClaimPhase.pollTimedOut;

  /// The hash this attempt broadcast, when there is one.
  String? get txHash => outcome?.txHash ?? record?.txHash;

  MiningClaimState copyWith({
    MiningClaimPhase? phase,
    MiningClaimRecord? record,
    int? attempts,
  }) => MiningClaimState(
    phase: phase ?? this.phase,
    intent: intent,
    failure: failure,
    outcome: outcome,
    record: record ?? this.record,
    gasSwap: gasSwap,
    requiredNative: requiredNative,
    attempts: attempts ?? this.attempts,
  );
}

/// How often a reported claim is read, and for how long.
@immutable
final class MiningClaimPolling {
  const MiningClaimPolling({
    this.interval = const Duration(seconds: 4),
    this.maxAttempts = 45,
  });

  final Duration interval;
  final int maxAttempts;
}

final miningClaimPollingProvider = Provider<MiningClaimPolling>(
  (ref) => const MiningClaimPolling(),
);

final class MiningClaimController extends Notifier<MiningClaimState> {
  Timer? _timer;
  int _generation = 0;

  @override
  MiningClaimState build() {
    ref.onDispose(_stop);
    return const MiningClaimState();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _generation += 1;
  }

  /// Prepares one claim for [walletId]. Returns the intent for the signing
  /// exit, or `null` when the server refused (kept in state).
  Future<MiningClaimIntent?> prepare({required String walletId}) async {
    if (state.busy || state.locked) return null;
    _stop();
    state = const MiningClaimState(phase: MiningClaimPhase.preparing);
    try {
      final result = await ref
          .read(miningRewardsGatewayProvider)
          .prepareClaim(walletId: walletId);
      if (!ref.mounted) return null;
      switch (result) {
        case MiningClaimPrepared(:final intent):
          state = MiningClaimState(
            phase: MiningClaimPhase.prepared,
            intent: intent,
          );
          return intent;
        case MiningClaimGasInsufficient(:final swap, :final requiredNative):
          state = MiningClaimState(
            phase: MiningClaimPhase.gasInsufficient,
            gasSwap: swap,
            requiredNative: requiredNative,
          );
        case MiningClaimNoGasSource(:final requiredNative):
          state = MiningClaimState(
            phase: MiningClaimPhase.noGasSource,
            requiredNative: requiredNative,
          );
      }
    } on LoopChainException catch (failure) {
      if (!ref.mounted) return null;
      state = MiningClaimState(
        phase: MiningClaimPhase.prepareFailed,
        failure: failure,
      );
    } catch (_) {
      if (!ref.mounted) return null;
      state = const MiningClaimState(
        phase: MiningClaimPhase.prepareFailed,
        failure: LoopChainException(LoopChainFailureKind.unexpected),
      );
    }
    return null;
  }

  /// Records what the signing exit reported. `null`: the sheet was closed
  /// before the wallet opened — nothing happened, the balance is untouched.
  void recordOutcome(MiningClaimSignOutcome? outcome) {
    final intent = state.intent;
    if (outcome == null) {
      state = const MiningClaimState();
      return;
    }
    switch (outcome.status) {
      case MoneySignStatus.refused:
      case MoneySignStatus.walletRejected:
        state = MiningClaimState(
          phase: MiningClaimPhase.signRefused,
          intent: intent,
          outcome: outcome,
        );
      case MoneySignStatus.submitted:
        state = MiningClaimState(
          phase: MiningClaimPhase.waiting,
          intent: intent,
          outcome: outcome,
          record: outcome.reported,
        );
        _settleOrPoll();
      case MoneySignStatus.locked:
      case MoneySignStatus.reportRefused:
        state = MiningClaimState(
          phase: MiningClaimPhase.locked,
          intent: intent,
          outcome: outcome,
        );
        // The server's worker may still find the transaction; reading the
        // claim is how the page learns of it. Nothing is signed again.
        if (intent != null) unawaited(_poll(_generation));
    }
  }

  /// Sends the same hash again after a report that did not land.
  Future<void> retryReport() async {
    final intent = state.intent;
    final outcome = state.outcome;
    final hash = outcome?.txHash;
    if (intent == null ||
        hash == null ||
        state.phase != MiningClaimPhase.locked ||
        outcome?.status != MoneySignStatus.reportRefused) {
      return;
    }
    final next = await ref
        .read(miningClaimSignerProvider)
        .report(intent, txHash: hash);
    if (!ref.mounted) return;
    recordOutcome(next);
  }

  /// Picks up a claim the server already has in flight (another session, a
  /// restart): it is read until it settles instead of being sent again.
  void follow(MiningClaimSummary claim) {
    if (state.phase != MiningClaimPhase.idle || !claim.status.inFlight) return;
    final claimId = claim.claimId;
    if (claimId == null) return;
    state = MiningClaimState(
      phase: MiningClaimPhase.waiting,
      record: MiningClaimRecord(
        claimId: claimId,
        status: claim.status,
        amount: claim.amount ?? BigInt.zero,
        createdAt: DateTime.now().toUtc(),
        txHash: claim.lastTx?.txHash,
        chainId: claim.lastTx?.chainId,
      ),
    );
    _stop();
    unawaited(_poll(_generation));
  }

  void resumePolling() {
    if (state.phase != MiningClaimPhase.pollTimedOut) return;
    state = state.copyWith(phase: MiningClaimPhase.waiting, attempts: 0);
    _settleOrPoll();
  }

  /// Back to idle after a refusal or a settled claim.
  void reset() {
    _stop();
    state = const MiningClaimState();
  }

  String? get _claimId => state.record?.claimId ?? state.intent?.claimId;

  void _settleOrPoll() {
    final record = state.record;
    if (record != null && record.status.isTerminal) {
      _settle(record.status);
      return;
    }
    _stop();
    unawaited(_poll(_generation));
  }

  void _settle(MiningClaimStatus status) {
    _stop();
    state = state.copyWith(
      phase: switch (status) {
        MiningClaimStatus.succeeded => MiningClaimPhase.succeeded,
        MiningClaimStatus.failed => MiningClaimPhase.failed,
        _ => MiningClaimPhase.expired,
      },
    );
    // The ledger moved (or did not): the page re-reads what it shows, over
    // the figures it already has.
    unawaited(ref.read(miningRewardsViewControllerProvider.notifier).reload());
    unawaited(ref.read(miningClaimsControllerProvider.notifier).reload());
  }

  /// Follows one claim until it settles.
  ///
  /// While a reported hash is waiting (`submitting` / `confirming`), the
  /// same hash is reported again each interval under a new idempotency key
  /// (contract §5.3): the report reads the receipt and answers the claim's
  /// new status. Without a hash, or while the attempt is locked after a
  /// report that did not land, the claim is read from `hourly.claim.latest`
  /// instead — nothing is reported on the page's own initiative then, the
  /// owner chooses 「重新上报」.
  Future<void> _poll(int generation) async {
    final polling = ref.read(miningClaimPollingProvider);
    final claimId = _claimId;
    if (claimId == null) return;
    _timer?.cancel();
    final completer = Completer<void>();
    _timer = Timer(polling.interval, completer.complete);
    await completer.future;
    if (generation != _generation || !ref.mounted) return;
    final hash = state.txHash;
    if (state.phase == MiningClaimPhase.waiting && hash != null) {
      try {
        final record = await ref
            .read(miningRewardsGatewayProvider)
            .reportClaim(claimId: claimId, txHash: hash);
        if (generation != _generation || !ref.mounted) return;
        if (record.status.isTerminal) {
          state = state.copyWith(record: record);
          _settle(record.status);
          return;
        }
        state = state.copyWith(record: record, attempts: state.attempts + 1);
      } catch (_) {
        if (generation != _generation || !ref.mounted) return;
        // A report that did not land does not end the wait.
        state = state.copyWith(attempts: state.attempts + 1);
      }
      _continue(generation, polling);
      return;
    }
    try {
      final view = await ref.read(miningRewardsGatewayProvider).loadRewards();
      if (generation != _generation || !ref.mounted) return;
      final claim = view.claim;
      if (claim.claimId == claimId) {
        final record = MiningClaimRecord(
          claimId: claimId,
          status: claim.status,
          amount: claim.amount ?? state.record?.amount ?? BigInt.zero,
          createdAt: state.record?.createdAt ?? DateTime.now().toUtc(),
          txHash: claim.lastTx?.txHash ?? state.txHash,
          chainId: claim.lastTx?.chainId ?? state.intent?.chainId,
          failureReasonCode: claim.failureReasonCode,
        );
        if (claim.status.isTerminal) {
          state = state.copyWith(record: record);
          _settle(claim.status);
          return;
        }
        state = state.copyWith(record: record, attempts: state.attempts + 1);
      } else {
        state = state.copyWith(attempts: state.attempts + 1);
      }
    } catch (_) {
      if (generation != _generation || !ref.mounted) return;
      // An unreadable answer does not end the wait.
      state = state.copyWith(attempts: state.attempts + 1);
    }
    _continue(generation, polling);
  }

  void _continue(int generation, MiningClaimPolling polling) {
    if (state.attempts >= polling.maxAttempts) {
      if (state.phase == MiningClaimPhase.waiting) {
        state = state.copyWith(phase: MiningClaimPhase.pollTimedOut);
      }
      return;
    }
    unawaited(_poll(generation));
  }
}

final miningClaimControllerProvider =
    NotifierProvider.autoDispose<MiningClaimController, MiningClaimState>(
      MiningClaimController.new,
    );
