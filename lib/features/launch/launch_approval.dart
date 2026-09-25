import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

/// The USD1 approval in front of a Launch purchase (decision 0089).
///
/// `buy()` pulls USD1 from the wallet, so the Launch contract must hold an
/// allowance of at least the amount first. The page reads that allowance from
/// `GET /v2/wallets/{id}/balances` (`launchChain.usd1`, strict) and never
/// guesses it: a missing reading keeps the purchase closed. An insufficient
/// one turns the main action into 「先授权 USD1」, which goes through the
/// existing wallet approval intent (`POST /v2/wallet-intents/approve`) and the
/// one signing exit, for exactly this purchase's amount.

/// The three funding refusals of `POST …/intents` (`409
/// INSUFFICIENT_BALANCE`). Each has its own sentence and its own guidance.
const String launchAllowanceInsufficientCode =
    'LAUNCH_USD1_ALLOWANCE_INSUFFICIENT';
const String launchBalanceInsufficientCode = 'LAUNCH_USD1_BALANCE_INSUFFICIENT';
const String launchGasInsufficientCode = 'LAUNCH_GAS_INSUFFICIENT';
const Set<String> launchFundingReasonCodes = <String>{
  launchAllowanceInsufficientCode,
  launchBalanceInsufficientCode,
  launchGasInsufficientCode,
};

/// USD1 is an 18-decimal token (06 §3).
const int launchUsd1Decimals = 18;

final RegExp _decimalAmount = RegExp(r'^(0|[1-9][0-9]{0,59})(\.[0-9]{1,18})?$');

/// The exact base-unit value of a typed USD1 amount, or `null` when the text
/// is not a positive amount with at most 18 decimals. No `double` is involved.
BigInt? launchUsd1Units(String? amount) {
  if (amount == null || !_decimalAmount.hasMatch(amount)) return null;
  final parts = amount.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final units = BigInt.parse(
    '${parts[0]}${fraction.padRight(launchUsd1Decimals, '0')}',
  );
  return units > BigInt.zero ? units : null;
}

/// What the page knows about the allowance for one amount.
enum LaunchAllowanceStatus {
  /// The balances read is in flight and nothing was read before.
  reading,

  /// Nothing usable was read: the read failed, the Launch slot block is
  /// absent, it names another chain, or `usd1` is absent. Purchase closed.
  unread,

  /// The allowance is below the amount: approve first.
  insufficient,

  /// The allowance covers the amount: the purchase may be prepared.
  sufficient,
}

@immutable
final class LaunchAllowanceView {
  const LaunchAllowanceView({
    required this.status,
    this.usd1,
    this.native,
    this.failureKind,
  });

  final LaunchAllowanceStatus status;

  /// The balance and allowance, when both were read at one block.
  final LoopLaunchUsd1Reading? usd1;

  /// The Launch slot's native balance (the network fee), when read.
  final LoopLaunchChainNativeBalance? native;

  /// Why nothing usable was read, when a read failed.
  final LoopChainFailureKind? failureKind;
}

/// Evaluates the allowance for [required] from one balances state.
///
/// [required] is `null` while no valid amount is typed; the status then only
/// says whether a reading exists. [launchChainId] is the launch's own slot: a
/// `launchChain` block for any other chain is a different fact.
LaunchAllowanceView launchAllowanceView({
  required LoopChainResourceState<LoopWalletBalances>? balances,
  required String launchChainId,
  required BigInt? required,
}) {
  final value = balances?.value;
  if (value == null) {
    final loading =
        balances == null || balances.phase == LoopChainViewPhase.loading;
    return LaunchAllowanceView(
      status: loading
          ? LaunchAllowanceStatus.reading
          : LaunchAllowanceStatus.unread,
      failureKind: balances?.failureKind,
    );
  }
  final slot = value.launchChain;
  if (slot == null || slot.chainId != launchChainId) {
    return const LaunchAllowanceView(status: LaunchAllowanceStatus.unread);
  }
  final usd1 = slot.usd1;
  if (usd1 == null) {
    return LaunchAllowanceView(
      status: LaunchAllowanceStatus.unread,
      native: slot.nativeBalance,
    );
  }
  final insufficient =
      required != null && BigInt.parse(usd1.allowance) < required;
  return LaunchAllowanceView(
    status: insufficient
        ? LaunchAllowanceStatus.insufficient
        : LaunchAllowanceStatus.sufficient,
    usd1: usd1,
    native: slot.nativeBalance,
  );
}

enum LaunchApprovalPhase {
  idle,

  /// `POST /v2/wallet-intents/approve` is in flight.
  preparing,

  /// The server refused to prepare the approval. Nothing was signed.
  prepareFailed,

  /// The signing exit or the wallet refused. Nothing was submitted.
  signRefused,

  /// The approval was broadcast; the balances are re-read until the
  /// allowance covers the amount.
  polling,

  /// The approval was broadcast but the allowance has not caught up within
  /// the polling window. It is not a failure; the owner re-reads by hand.
  pollTimedOut,

  /// The server recorded the approval as reverted or failed on chain.
  failedOnChain,
}

@immutable
final class LaunchApprovalState {
  const LaunchApprovalState({
    this.phase = LaunchApprovalPhase.idle,
    this.failure,
    this.reasonCode,
    this.intent,
    this.txHash,
    this.amount,
    this.walletId,
    this.required,
    this.attempts = 0,
  });

  final LaunchApprovalPhase phase;

  /// The prepare refusal, when [phase] is `prepareFailed`.
  final LoopChainException? failure;

  /// The exit's or the wallet's reason, when [phase] is `signRefused`.
  final String? reasonCode;

  /// The server's approval intent: the prepared one, then the reported one.
  final LoopWalletIntent? intent;
  final String? txHash;

  /// The decimal amount the approval was prepared for.
  final String? amount;
  final String? walletId;
  final BigInt? required;

  /// How many balances reads the poll has made.
  final int attempts;

  bool get busy =>
      phase == LaunchApprovalPhase.preparing ||
      phase == LaunchApprovalPhase.polling;

  LaunchApprovalState copyWith({
    LaunchApprovalPhase? phase,
    LoopWalletIntent? intent,
    int? attempts,
  }) => LaunchApprovalState(
    phase: phase ?? this.phase,
    failure: failure,
    reasonCode: reasonCode,
    intent: intent ?? this.intent,
    txHash: txHash,
    amount: amount,
    walletId: walletId,
    required: required,
    attempts: attempts ?? this.attempts,
  );
}

/// How often and how long a broadcast approval is waited for.
@immutable
final class LaunchAllowancePolling {
  const LaunchAllowancePolling({
    this.interval = const Duration(seconds: 3),
    this.maxAttempts = 40,
  });

  final Duration interval;
  final int maxAttempts;
}

final launchAllowancePollingProvider = Provider<LaunchAllowancePolling>(
  (ref) => const LaunchAllowancePolling(),
);

final class LaunchApprovalController extends Notifier<LaunchApprovalState> {
  Timer? _timer;
  int _generation = 0;

  @override
  LaunchApprovalState build() {
    ref.onDispose(_stop);
    return const LaunchApprovalState();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _generation += 1;
  }

  /// Prepares the exact-amount approval of USD1 on the Launch slot towards the
  /// Launch contract. Returns the server's intent for the signing exit, or
  /// `null` when the server refused (the refusal is kept in state).
  Future<LoopWalletIntent?> prepare({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required String amount,
  }) async {
    if (state.busy) return null;
    _stop();
    state = LaunchApprovalState(
      phase: LaunchApprovalPhase.preparing,
      amount: amount,
      walletId: walletId,
      required: launchUsd1Units(amount),
    );
    try {
      final intent = await ref
          .read(walletIntentsGatewayProvider)
          .prepareApproval(
            walletId: walletId,
            assetId: assetId,
            spenderAddress: spenderAddress,
            // Decision 0089: this purchase's amount, never unlimited.
            allowance: LoopExactAllowanceRequest(amount),
          );
      state = state.copyWith(phase: LaunchApprovalPhase.idle, intent: intent);
      return intent;
    } on LoopChainException catch (failure) {
      state = LaunchApprovalState(
        phase: LaunchApprovalPhase.prepareFailed,
        failure: failure,
        amount: amount,
        walletId: walletId,
      );
    } catch (_) {
      state = LaunchApprovalState(
        phase: LaunchApprovalPhase.prepareFailed,
        failure: const LoopChainException(LoopChainFailureKind.unexpected),
        amount: amount,
        walletId: walletId,
      );
    }
    return null;
  }

  /// Records what the signing exit reported for the approval.
  ///
  /// `null` means the sheet was closed before the wallet opened. A refusal
  /// submitted nothing. Anything else may be on chain, so the page waits for
  /// the allowance instead of offering the approval again.
  void recordOutcome(MoneySignOutcome? outcome) {
    if (outcome == null) {
      state = LaunchApprovalState(
        amount: state.amount,
        walletId: state.walletId,
        required: state.required,
      );
      return;
    }
    switch (outcome.status) {
      case MoneySignStatus.refused:
      case MoneySignStatus.walletRejected:
        state = LaunchApprovalState(
          phase: LaunchApprovalPhase.signRefused,
          reasonCode: outcome.reasonCode,
          amount: state.amount,
          walletId: state.walletId,
          required: state.required,
        );
      case MoneySignStatus.submitted:
      case MoneySignStatus.locked:
      case MoneySignStatus.reportRefused:
        final reported = outcome.intent ?? state.intent;
        state = LaunchApprovalState(
          phase: _failedOnChain(reported)
              ? LaunchApprovalPhase.failedOnChain
              : LaunchApprovalPhase.polling,
          intent: reported,
          txHash: outcome.txHash ?? reported?.result.transactionHash,
          amount: state.amount,
          walletId: state.walletId,
          required: state.required,
        );
        if (state.phase == LaunchApprovalPhase.polling) {
          unawaited(_poll(_generation));
        }
    }
  }

  static bool _failedOnChain(LoopWalletIntent? intent) =>
      intent != null &&
      (intent.state == LoopIntentState.reverted ||
          intent.state == LoopIntentState.failed);

  /// Re-reads by hand after the polling window closed.
  void resumePolling() {
    if (state.phase != LaunchApprovalPhase.pollTimedOut) return;
    _stop();
    state = state.copyWith(phase: LaunchApprovalPhase.polling, attempts: 0);
    unawaited(_poll(_generation));
  }

  /// Returns to the plain form, e.g. after the allowance was read as enough
  /// or after the owner dismissed a refusal.
  void reset() {
    _stop();
    state = const LaunchApprovalState();
  }

  /// One poll step: re-read the balances (and the approval intent, so a
  /// revert on chain is stated), then either finish or schedule the next.
  Future<void> _poll(int generation) async {
    final walletId = state.walletId;
    final required = state.required;
    if (walletId == null || required == null) return;
    final balances = ref.read(
      walletBalancesControllerProvider(walletId).notifier,
    );
    await balances.reload();
    if (generation != _generation) return;
    final intentId = state.intent?.intentId;
    if (intentId != null) {
      try {
        final latest = await ref
            .read(walletIntentsGatewayProvider)
            .loadIntent(intentId);
        if (generation != _generation) return;
        if (_failedOnChain(latest)) {
          state = state.copyWith(
            phase: LaunchApprovalPhase.failedOnChain,
            intent: latest,
          );
          return;
        }
        state = state.copyWith(intent: latest);
      } catch (_) {
        // The allowance is the fact that matters; an unreadable intent does
        // not stop the wait.
      }
    }
    final usd1 = ref
        .read(walletBalancesControllerProvider(walletId))
        .value
        ?.launchChain
        ?.usd1;
    final attempts = state.attempts + 1;
    if (usd1 != null && BigInt.parse(usd1.allowance) >= required) {
      _stop();
      state = const LaunchApprovalState();
      return;
    }
    final polling = ref.read(launchAllowancePollingProvider);
    if (attempts >= polling.maxAttempts) {
      state = state.copyWith(
        phase: LaunchApprovalPhase.pollTimedOut,
        attempts: attempts,
      );
      return;
    }
    state = state.copyWith(attempts: attempts);
    _timer?.cancel();
    _timer = Timer(polling.interval, () {
      if (generation == _generation) unawaited(_poll(generation));
    });
  }
}

final launchApprovalControllerProvider =
    NotifierProvider.autoDispose<LaunchApprovalController, LaunchApprovalState>(
      LaunchApprovalController.new,
    );

/// zh-CN for one approval state. None of them claims the allowance changed
/// before a balances read says so.
String? launchApprovalText(LaunchApprovalState state) => switch (state.phase) {
  LaunchApprovalPhase.idle => null,
  LaunchApprovalPhase.preparing => '正在准备授权，还没有打开钱包。',
  LaunchApprovalPhase.prepareFailed => null,
  LaunchApprovalPhase.signRefused => '授权没有签名，没有提交任何交易。可以重新发起授权。',
  LaunchApprovalPhase.polling =>
    '授权已提交给钱包，正在等待链上授权额度更新'
        '（已读取 ${state.attempts} 次）。额度到账前不能购买，不要重复授权。',
  LaunchApprovalPhase.pollTimedOut =>
    '授权已提交，但授权额度还没有更新。它可能仍在确认中，'
        '请稍后重新读取；不要重复授权。',
  LaunchApprovalPhase.failedOnChain => '授权交易在链上没有成功，授权额度没有变化。可以重新发起授权。',
};
