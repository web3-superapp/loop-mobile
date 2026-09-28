import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';

/// Claim and refund on `launch-detail` (client decision 0103, loop-api
/// decision 0087).
///
/// The page decides which step to show only from what it read: the four
/// axes of the detail and `holders.myPosition`. Everything after the tap is
/// the server's answer — the prepare may still refuse — and the result is the
/// server's intent state, read back through `GET …/intents/{id}`.

// ---------------------------------------------------------------------------
// which step the page shows (the decision table of 0103)
// ---------------------------------------------------------------------------

enum LaunchSettlementStage {
  /// Sale ENDED, not finalized: neither claim nor refund exists yet.
  awaitingFinalize,

  /// Sale succeeded, shares frozen (or not yet frozen): waiting for TGE.
  awaitingTge,

  /// Sale failed or was cancelled, refund liability not frozen yet.
  refundPending,

  /// `holders.myPosition` is being read.
  positionReading,

  /// `holders.myPosition` is `unavailable` or the read failed.
  positionUnread,

  /// VESTING / COMPLETED with `claimableTokens > 0`.
  claim,

  /// VESTING, nothing matured yet and nothing claimed.
  claimNothingYet,

  /// VESTING, something claimed, nothing claimable right now.
  claimedSoFar,

  /// COMPLETED and nothing left to claim.
  claimedAll,

  /// FAILED / CANCELLED + REFUNDING with `refundableUsd1 > 0`.
  refund,

  /// Everything refunded.
  refundedAll,

  /// REFUNDED (window closed) with USD1 still recorded as refundable.
  refundClosed,
}

/// The page's reading of one launch for the claim / refund block.
@immutable
final class LaunchSettlementView {
  const LaunchSettlementView({
    required this.stage,
    this.position,
    this.paused = false,
    this.reasonCode,
    this.onChain,
  });

  final LaunchSettlementStage stage;
  final LaunchPosition? position;

  /// `operationalState == PAUSED`: the contract refuses both calls.
  final bool paused;

  /// The holders' own reason while the position is unreadable.
  final String? reasonCode;
  final LaunchOnChainAvailable? onChain;

  /// The contract call this stage offers, if any.
  LaunchIntentKind? get kind => switch (stage) {
    LaunchSettlementStage.claim => LaunchIntentKind.claim,
    LaunchSettlementStage.refund => LaunchIntentKind.claimRefund,
    _ => null,
  };

  /// The raw amount the action would move (18-decimal base unit).
  String? get amount => switch (stage) {
    LaunchSettlementStage.claim => position?.claimableTokens,
    LaunchSettlementStage.refund => position?.refundableUsd1,
    _ => null,
  };

  /// A block that says where the page read its facts; a refusal is held
  /// against it (see [LaunchSettlementState.refusalSnapshot]).
  String get snapshot =>
      '${onChain?.snapshotBlockNumber ?? '-'}/'
      '${position?.snapshotBlockNumber ?? '-'}';
}

bool _positive(String raw) => BigInt.parse(raw) > BigInt.zero;

/// Whether the wallet ever took part: any of the seven position figures.
bool launchPositionParticipated(LaunchPosition position) =>
    _positive(position.cumulativeUsd1) ||
    _positive(position.purchasedTokens) ||
    _positive(position.entitledTokens) ||
    _positive(position.claimableTokens) ||
    _positive(position.claimedTokens) ||
    _positive(position.refundableUsd1) ||
    _positive(position.refundedUsd1);

/// The decision table of 0103: `null` means the block is not drawn.
///
/// - unreadable axes, SCHEDULED, LIVE → `null` (the purchase owns the page);
/// - ENDED → [LaunchSettlementStage.awaitingFinalize], whatever the position;
/// - otherwise the position decides, and an unreadable position is said so,
///   never guessed;
/// - VESTING / COMPLETED → claim by `claimableTokens` (COMPLETED can still
///   claim what is left, 06 §4.1);
/// - FAILED / CANCELLED + REFUNDING → refund by `refundableUsd1`;
/// - a pause keeps the stage and marks it [LaunchSettlementView.paused].
LaunchSettlementView? launchSettlementView({
  required LaunchOnChainState? onChain,
  required LaunchReading<LaunchPosition>? position,
  bool positionFailed = false,
}) {
  if (onChain is! LaunchOnChainAvailable) return null;
  final paused = onChain.operationalState == LaunchOperationalState.paused;
  LaunchSettlementView view(
    LaunchSettlementStage stage, {
    LaunchPosition? held,
    String? reasonCode,
  }) => LaunchSettlementView(
    stage: stage,
    position: held,
    paused: paused,
    reasonCode: reasonCode,
    onChain: onChain,
  );

  switch (onChain.saleState) {
    case LaunchSaleState.scheduled:
    case LaunchSaleState.live:
      return null;
    case LaunchSaleState.ended:
      return view(LaunchSettlementStage.awaitingFinalize);
    case LaunchSaleState.succeeded:
    case LaunchSaleState.failed:
    case LaunchSaleState.cancelled:
      break;
  }
  final LaunchPosition held;
  switch (position) {
    case null:
      return view(
        positionFailed
            ? LaunchSettlementStage.positionUnread
            : LaunchSettlementStage.positionReading,
      );
    case LaunchReadingUnavailable<LaunchPosition>(:final reasonCode):
      return view(LaunchSettlementStage.positionUnread, reasonCode: reasonCode);
    case LaunchReadingAvailable<LaunchPosition>(:final value):
      held = value;
  }
  if (!launchPositionParticipated(held)) return null;

  final entitlement = onChain.entitlementState;
  if (entitlement == LaunchEntitlementState.vesting ||
      entitlement == LaunchEntitlementState.completed) {
    if (_positive(held.claimableTokens)) {
      return view(LaunchSettlementStage.claim, held: held);
    }
    if (_positive(held.claimedTokens)) {
      return view(
        entitlement == LaunchEntitlementState.completed
            ? LaunchSettlementStage.claimedAll
            : LaunchSettlementStage.claimedSoFar,
        held: held,
      );
    }
    return view(LaunchSettlementStage.claimNothingYet, held: held);
  }
  final refundSale =
      onChain.saleState == LaunchSaleState.failed ||
      onChain.saleState == LaunchSaleState.cancelled;
  if (refundSale) {
    final refundable = _positive(held.refundableUsd1);
    final refunded = _positive(held.refundedUsd1);
    switch (entitlement) {
      case LaunchEntitlementState.refunding:
        if (refundable) return view(LaunchSettlementStage.refund, held: held);
        if (refunded) {
          return view(LaunchSettlementStage.refundedAll, held: held);
        }
        return null;
      case LaunchEntitlementState.refunded:
        if (refundable) {
          return view(LaunchSettlementStage.refundClosed, held: held);
        }
        if (refunded) {
          return view(LaunchSettlementStage.refundedAll, held: held);
        }
        return null;
      default:
        return view(LaunchSettlementStage.refundPending, held: held);
    }
  }
  // SUCCEEDED with NONE / FROZEN: the shares wait for TGE and the pool.
  if (entitlement == LaunchEntitlementState.none ||
      entitlement == LaunchEntitlementState.frozen) {
    return view(LaunchSettlementStage.awaitingTge, held: held);
  }
  return null;
}

// ---------------------------------------------------------------------------
// copy
// ---------------------------------------------------------------------------

/// The primary action's label, from the position figure the page read.
String launchSettlementActionLabel(LaunchSettlementView view) =>
    switch (view.kind) {
      LaunchIntentKind.claim => '领取 ${launchUnitsFigure(view.amount!)} 代币',
      LaunchIntentKind.claimRefund =>
        '申请退款 ${launchUnitsFigure(view.amount!)} USD1',
      _ => '',
    };

/// The six refusals decision 0087 added, each with the next step the page
/// takes (0103). Every one is `409 DATA_STALE`: no intent was stored and no
/// transaction exists.
const Set<String> launchSettlementRefusalCodes = <String>{
  'LAUNCH_CLAIM_NOT_OPEN',
  'LAUNCH_REFUND_NOT_OPEN',
  'LAUNCH_SALE_PAUSED',
  'LAUNCH_NOT_PARTICIPANT',
  'LAUNCH_NOTHING_TO_CLAIM',
  'LAUNCH_NOTHING_TO_REFUND',
};

/// Refusals after which the page re-reads the detail and the position: the
/// server has seen a newer block than the page.
const Set<String> launchSettlementRereadCodes = <String>{
  ...launchSettlementRefusalCodes,
  'LAUNCH_CONFIG_VERSION_MISMATCH',
};

String launchSettlementRefusalTitle(String? reasonCode) => switch (reasonCode) {
  'LAUNCH_CLAIM_NOT_OPEN' => '尚未开放领取',
  'LAUNCH_REFUND_NOT_OPEN' => '当前不可退款',
  'LAUNCH_SALE_PAUSED' => '合约已暂停',
  'LAUNCH_NOT_PARTICIPANT' => '这个钱包没有参与',
  'LAUNCH_NOTHING_TO_CLAIM' => '暂无可领取',
  'LAUNCH_NOTHING_TO_REFUND' => '已退款',
  _ => '这次没有通过',
};

String launchSettlementRefusalText(
  LaunchIntentKind kind,
  LaunchFailureKind? failure,
  String? reasonCode,
) {
  final noun = launchIntentNoun(kind);
  return switch (reasonCode) {
    'LAUNCH_CLAIM_NOT_OPEN' =>
      '合约还没有开放领取（未到 TGE，或流动性池还没有上线），没有提交任何交易。'
          '已重新读取详情，开放后这里会出现领取按钮。',
    'LAUNCH_REFUND_NOT_OPEN' => '只有销售失败或被取消、且退款窗口开放时才能退款，没有提交任何交易。已重新读取详情。',
    'LAUNCH_SALE_PAUSED' => '合约暂停期间领取与退款都会被拒绝，没有提交任何交易。请稍后再试。',
    'LAUNCH_NOT_PARTICIPANT' =>
      '当前钱包没有参与这次发射，没有可领取或可退款的份额，没有提交任何交易。'
          '如果用其他钱包参与过，请在钱包中切换后再来。',
    'LAUNCH_NOTHING_TO_CLAIM' => '当前可领取为 0：还没到下一次释放，或已经全部领取。没有提交任何交易，下一次释放后再来。',
    'LAUNCH_NOTHING_TO_REFUND' => '这个钱包的 USD1 已经全部退回，没有提交任何交易。',
    _ => launchPurchaseRefusalText(
      failure,
      reasonCode,
    ).replaceAll('认购', noun).replaceAll('支付钱包', '当前钱包'),
  };
}

/// The line for the intent's state once the wallet has broadcast (S92a.6).
/// Only `confirmed` names a result, and it is the server's. The purchase
/// uses the same lines since S92b2.
({String title, String body}) launchSettlementProgressText(
  LaunchIntentKind kind,
  LaunchPurchaseIntent intent,
) {
  final noun = launchIntentNoun(kind);
  final done = switch (kind) {
    LaunchIntentKind.buy => '认购已确认',
    LaunchIntentKind.claim => '已领取',
    LaunchIntentKind.claimRefund => '已退款',
  };
  final landed = kind == LaunchIntentKind.buy ? '份额以「我的参与记录」为准' : '到账以钱包余额为准';
  final hash = intent.transactionHash;
  final tx = hash == null ? '' : '交易 ${launchShortHex(hash)}。';
  return switch (intent.state) {
    LaunchIntentState.confirmed => (
      title: done,
      body: '$tx链上已确认这笔$noun，$landed。',
    ),
    LaunchIntentState.reverted => (
      title: '交易失败（仅消耗 gas）',
      body: '$tx链上执行被拒绝，资金没有移动。可以重新发起。',
    ),
    LaunchIntentState.expired => (
      title: '未上链，可重新发起',
      body: '$tx签名窗口结束后仍没有看到这笔交易。已重新读取持仓；晚到的交易仍可能成功，请先核对再重新发起。',
    ),
    LaunchIntentState.failed => (
      title: '回报的交易不匹配',
      body: '$tx链上的交易与签名时复核的内容不一致，服务端没有记录它。请核对后重新发起，并联系支持。',
    ),
    _ => (title: '已广播，等待链上确认', body: '$tx广播不代表已到账，结果以链上索引为准。不要重复$noun。'),
  };
}

// ---------------------------------------------------------------------------
// controller
// ---------------------------------------------------------------------------

@immutable
final class LaunchSettlementState {
  const LaunchSettlementState({
    required this.mode,
    this.kind,
    this.busy = false,
    this.refusalKind,
    this.refusalReasonCode,
    this.refusalSnapshot,
    this.prepared,
    this.signOutcomeStatus,
    this.signReasonCode,
    this.txHash,
    this.intent,
    this.reporting = false,
    this.polling = false,
    this.pollTimedOut = false,
  });

  final LaunchGatewayMode mode;

  /// The kind of the attempt on screen.
  final LaunchIntentKind? kind;

  /// A prepare is in flight.
  final bool busy;
  final LaunchFailureKind? refusalKind;
  final String? refusalReasonCode;

  /// [LaunchSettlementView.snapshot] when the server refused. While the page
  /// still reads the same blocks, the server's answer stands over them.
  final String? refusalSnapshot;

  final LaunchPurchasePrepared? prepared;
  final String? signOutcomeStatus;
  final String? signReasonCode;
  final String? txHash;

  /// The server's latest intent after the broadcast: the report's answer,
  /// then each read-back.
  final LaunchPurchaseIntent? intent;
  final bool reporting;
  final bool polling;
  final bool pollTimedOut;

  /// The intent reached a state the server will not move on its own
  /// (S92a.6), so a new attempt may start.
  bool get settled => intent?.state.isSettled ?? false;

  /// Once the wallet has produced a hash, or its outcome is unknown, the page
  /// offers no second signature until the server settles the first.
  bool get locked =>
      !settled &&
      (signOutcomeStatus == 'locked' ||
          signOutcomeStatus == 'reportRefused' ||
          signOutcomeStatus == 'submitted' ||
          txHash != null);

  bool get reportRetryable =>
      signOutcomeStatus == 'reportRefused' &&
      txHash != null &&
      launchReportRetryable(signReasonCode ?? '');
}

final class LaunchSettlementController extends Notifier<LaunchSettlementState>
    with LaunchSingleFlight {
  late final LaunchIntentPoller _poller = LaunchIntentPoller(
    load: (current) => ref
        .read(launchGatewayProvider)
        .loadIntent(
          launchId: current.launchId,
          launchIntentId: current.launchIntentId,
        ),
    onRead: (intent, {required polling, required timedOut}) {
      if (!ref.mounted) return;
      state = _with(intent: intent, polling: polling, pollTimedOut: timedOut);
    },
  );

  @override
  LaunchSettlementState build() {
    nextGeneration();
    final mode = ref.watch(launchGatewayProvider).mode;
    ref.onDispose(() {
      nextGeneration();
      _poller.stop();
    });
    return LaunchSettlementState(mode: mode);
  }

  /// Asks the server for one claim or refund intent. Returns it when the
  /// server prepared one; a refusal is kept on the state with [snapshot].
  Future<LaunchPurchasePrepared?> prepare({
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
    required String snapshot,
  }) async {
    if (state.locked || state.busy || !kind.isSettlement) return null;
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    _poller.stop();
    state = LaunchSettlementState(mode: state.mode, kind: kind, busy: true);
    try {
      final prepared = await gateway.prepareSettlementIntent(
        launchId: launchId,
        walletId: walletId,
        kind: kind,
      );
      if (!isCurrent(generation)) return null;
      state = LaunchSettlementState(
        mode: state.mode,
        kind: kind,
        prepared: prepared,
      );
      return prepared;
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return null;
      state = LaunchSettlementState(
        mode: state.mode,
        kind: kind,
        refusalKind: error.kind,
        refusalReasonCode: error.reasonCode,
        refusalSnapshot: snapshot,
      );
    } catch (_) {
      if (!isCurrent(generation)) return null;
      state = LaunchSettlementState(
        mode: state.mode,
        kind: kind,
        refusalKind: LaunchFailureKind.unexpected,
        refusalSnapshot: snapshot,
      );
    }
    return null;
  }

  /// Records what the signing exit reported. A broadcast the server recorded
  /// is then read back until it settles.
  void recordSignOutcome(LaunchSignOutcome outcome) {
    final prepared = state.prepared;
    switch (outcome.status.name) {
      case 'refused':
      case 'walletRejected':
        // Nothing was broadcast. The prepared intent is dropped; the next
        // tap prepares a fresh one under a new key.
        state = LaunchSettlementState(
          mode: state.mode,
          kind: state.kind,
          signOutcomeStatus: outcome.status.name,
          signReasonCode: outcome.reasonCode,
        );
        return;
    }
    state = LaunchSettlementState(
      mode: state.mode,
      kind: state.kind,
      prepared: prepared,
      signOutcomeStatus: outcome.status.name,
      signReasonCode: outcome.reasonCode,
      txHash: outcome.txHash,
      intent: outcome.reported,
    );
    if (outcome.reported != null) _startPolling();
  }

  /// Sends the same hash again after a report that did not land.
  Future<void> retryReport() => single(() async {
    final prepared = state.prepared;
    final hash = state.txHash;
    if (prepared == null || hash == null || !state.reportRetryable) return;
    final before = state;
    state = LaunchSettlementState(
      mode: before.mode,
      kind: before.kind,
      prepared: prepared,
      signOutcomeStatus: before.signOutcomeStatus,
      signReasonCode: before.signReasonCode,
      txHash: hash,
      reporting: true,
    );
    final outcome = await ref
        .read(launchPurchaseSignerProvider)
        .report(prepared.intent, txHash: hash);
    if (!ref.mounted) return;
    recordSignOutcome(outcome);
  });

  /// Reads the intent again after the window ran out without an answer.
  void resumePolling() {
    if (state.intent == null || state.settled) return;
    _startPolling();
  }

  /// Clears a refusal or a settled attempt. A broadcast in flight is never
  /// discarded.
  void reset() {
    if (state.locked) return;
    nextGeneration();
    _poller.stop();
    state = LaunchSettlementState(mode: state.mode);
  }

  void _startPolling() {
    final intent = state.intent;
    if (intent == null) return;
    state = _with(polling: !intent.state.isSettled, pollTimedOut: false);
    _poller.start(intent, ref.read(launchIntentPollIntervalProvider));
  }

  LaunchSettlementState _with({
    LaunchPurchaseIntent? intent,
    required bool polling,
    bool pollTimedOut = false,
  }) => LaunchSettlementState(
    mode: state.mode,
    kind: state.kind,
    prepared: state.prepared,
    signOutcomeStatus: state.signOutcomeStatus,
    signReasonCode: state.signReasonCode,
    txHash: state.txHash,
    intent: intent ?? state.intent,
    polling: polling,
    pollTimedOut: pollTimedOut,
  );
}

final launchSettlementControllerProvider =
    NotifierProvider.autoDispose<
      LaunchSettlementController,
      LaunchSettlementState
    >(LaunchSettlementController.new);
