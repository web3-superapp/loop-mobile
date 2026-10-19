import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_steps.dart';

// ---------------------------------------------------------------------------
// The MEME v2 signing exit (client decision 0139, contract §3.4–3.5)
// ---------------------------------------------------------------------------
//
// An NFT mint, a curve buy and a curve sell are one server intent each. When
// the intent carries an `approval`, its transaction is signed first (nonce N)
// and the main one straight after (N+1). Both go through the shared
// `LoopSignSheet` and reach the wallet as `SigningIntent.backendCanonical`
// with the server's transaction verbatim and the intent's `payloadDigest`;
// nothing is assembled on the device. There is no report route: a broadcast
// is 「已广播」 and the page re-reads the instance until the lane shows it.
//
// The instance lives on the Launch chain slot, so the two halves travel
// under the two Launch-slot intent kinds — the only kinds the wallet boundary
// admits off the primary chain.

/// How one trip through the exit ended.
@immutable
final class Launch2SignOutcome {
  const Launch2SignOutcome({
    required this.status,
    required this.reasonCode,
    this.txHash,
    this.approvalTxHash,
    this.refreshed,
    this.refreshFailure,
  });

  /// [MoneySignStatus.submitted] once the wallet broadcast the main
  /// transaction; [MoneySignStatus.locked] when its outcome is unknown.
  final MoneySignStatus status;
  final String reasonCode;
  final String? txHash;
  final String? approvalTxHash;

  /// The intent the trade was signed from when the exit refreshed it after
  /// the approval (decision 0148); `null` when the reviewed one was signed.
  final Launch2Intent? refreshed;

  /// The read that failed while refreshing after the approval.
  final LoopChainException? refreshFailure;

  bool get broadcast =>
      status == MoneySignStatus.submitted || status == MoneySignStatus.locked;
}

String launch2IntentNoun(Launch2IntentKind kind) => switch (kind) {
  Launch2IntentKind.nftMint => '铸造',
  Launch2IntentKind.buy => '买入',
  Launch2IntentKind.sell => '卖出',
  Launch2IntentKind.rewardClaim => '领取奖励',
};

/// [noun] replaces the action's name (decision 0163: 「铸造」 when the NFT
/// mint starts from 共识勋章).
String launch2IntentTitle(
  Launch2IntentKind kind, {
  Launch2Venue venue = Launch2Venue.curve,
  String? noun,
}) => switch (venue) {
  Launch2Venue.officialPool => '确认外盘${noun ?? launch2IntentNoun(kind)}',
  Launch2Venue.loopDynamicRewards => '确认领取外盘奖励',
  Launch2Venue.curve => '确认${noun ?? launch2IntentNoun(kind)}',
};

/// Whom an approval lets spend: the curve, the NFT or the pool's router.
String _spenderNoun(Launch2Intent intent) =>
    intent.venue == Launch2Venue.loopDynamicRewards
    ? '奖励合约'
    : intent.venue == Launch2Venue.officialPool
    ? '官方池路由'
    : intent.kind == Launch2IntentKind.nftMint
    ? 'NFT 合约'
    : '曲线合约';

/// The address row: the router or the contract, and when the intent carries
/// an approval, that it is also the spender.
String _addressLabel(Launch2Intent intent) => intent.approval == null
    ? switch (intent.venue) {
        Launch2Venue.officialPool => '路由',
        Launch2Venue.loopDynamicRewards => '奖励合约',
        Launch2Venue.curve => '合约',
      }
    : '授权给${_spenderNoun(intent)}';

/// The tax line's label: the intent's own rate, else the curve's 10%. A
/// LoopDynamic sell names both halves of what it pays (decision 0159).
String _taxLabel(Launch2Intent intent) {
  final bps = intent.taxBps ?? 1000;
  final dynamicBps = intent.dynamicTaxBps;
  if (intent.venue == Launch2Venue.officialPool && dynamicBps != null) {
    return '基础税 ${launch2BpsLabel(bps)} + 动态税 ${launch2BpsLabel(dynamicBps)}';
  }
  return intent.venue == Launch2Venue.officialPool
      ? '外盘税 ${launch2BpsLabel(bps)}'
      : '税 ${launch2BpsLabel(bps)}';
}

/// The reviewed facts. The sheet renders exactly these, read from the same
/// object whose transactions the wallet gets.
/// [noun] 「铸造」 (decision 0163, from 共识勋章) names the NFT mint
/// 「铸造 T 共识勋章」 instead of 「购买 $T 项目 NFT」.
List<IntentField> launch2IntentFields(
  Launch2Intent intent, {
  required String ticker,
  String? noun,
}) {
  final approval = intent.approval;
  final meme = loopTickerLabel(ticker);
  return <IntentField>[
    IntentField(
      label: '操作',
      value: switch (intent.kind) {
        Launch2IntentKind.nftMint =>
          '${noun ?? launch2IntentNoun(intent.kind)} $ticker 共识勋章（每个地址 1 枚）',
        Launch2IntentKind.buy =>
          intent.venue == Launch2Venue.officialPool
              ? '在官方池买入 $meme'
              : '买入 $meme',
        Launch2IntentKind.sell =>
          intent.venue == Launch2Venue.officialPool
              ? '在官方池卖出 $meme'
              : '卖出 $meme',
        Launch2IntentKind.rewardClaim => '领取 $meme 外盘奖励',
      },
    ),
    switch (intent.kind) {
      Launch2IntentKind.nftMint => IntentField(
        label: '支付',
        value: launch2Usd1Label(intent.amountIn),
      ),
      Launch2IntentKind.buy => IntentField(
        label: intent.venue == Launch2Venue.officialPool ? '最多支付' : '最多支付（含税）',
        value: launch2Usd1Label(intent.amountIn, maxFractionDigits: 4),
      ),
      Launch2IntentKind.sell => IntentField(
        label: '卖出',
        value: launch2MemeLabel(intent.amountIn, ticker),
      ),
      // Decision 0157: what the claim pays out, the intent's own figure.
      Launch2IntentKind.rewardClaim => IntentField(
        label: '领取',
        value: launch2Usd1Label(intent.expectedOut, maxFractionDigits: 4),
      ),
    },
    if (intent.kind == Launch2IntentKind.buy) ...<IntentField>[
      IntentField(
        label: '预计获得',
        value: launch2MemeLabel(intent.expectedOut, ticker),
      ),
      IntentField(
        label: '最少获得',
        value: launch2MemeLabel(intent.minOut, ticker),
      ),
    ],
    if (intent.kind == Launch2IntentKind.sell) ...<IntentField>[
      IntentField(
        label: '预计到手',
        value: launch2Usd1Label(intent.expectedOut, maxFractionDigits: 4),
      ),
      IntentField(
        label: '最少到手',
        value: launch2Usd1Label(intent.minOut, maxFractionDigits: 4),
      ),
    ],
    if (intent.kind != Launch2IntentKind.nftMint &&
        intent.kind != Launch2IntentKind.rewardClaim)
      IntentField(
        label: _taxLabel(intent),
        value: intent.taxMeme != null
            ? launch2MemeLabel(intent.taxMeme!, ticker)
            : launch2Usd1Label(intent.taxUsd1, maxFractionDigits: 4),
      ),
    // Decision 0148: the amount alone; whom it lets spend is the address
    // row's own label (路由 / 合约), so the line never wraps right-aligned.
    if (approval != null)
      IntentField(
        label: '先授权',
        value: intent.kind == Launch2IntentKind.sell
            ? launch2MemeLabel(approval.amount, ticker)
            : intent.kind == Launch2IntentKind.nftMint
            ? launch2Usd1Label(approval.amount)
            : launch2Usd1Label(approval.amount, maxFractionDigits: 4),
      ),
    IntentField(
      label: '模拟结果',
      value: switch (intent.simulationStatus) {
        'passed' => '试算通过',
        'reverted' => '试算被拒绝',
        _ => approval != null ? '授权前无法试算' : '试算不可用',
      },
    ),
    IntentField(label: '有效期至', value: loopDateTimeLabel(intent.expiresAt)),
    IntentField(
      label: '快照区块',
      value: loopGroupedFigure(intent.snapshotBlockNumber.toString()),
    ),
    IntentField(
      label: _addressLabel(intent),
      value: launch2ShortAddress(intent.contractAddress),
    ),
    IntentField(label: '网络', value: loopChainName(intent.chainId)),
  ];
}

/// zh-CN for a refusal before or at the wallet. Every line states that
/// nothing was submitted.
///
/// [approvalSent]: an approval of the same operation was already broadcast,
/// so a step-up cancel or failure says the approval went out and the trade
/// did not (decision 0158) instead of "nothing changed".
String launch2SignReasonText(String reasonCode, {bool approvalSent = false}) =>
    switch (reasonCode) {
      // Decision 0152: the large-amount step-up stopped before the wallet.
      loopStepUpCancelledCode ||
      loopStepUpFailedCode when approvalSent => loopStepUpAfterApprovalText,
      loopStepUpCancelledCode => '已取消，没有发生任何变化。',
      loopStepUpFailedCode => '身份验证没有通过，没有发生任何变化。',
      'INTENT_EXPIRED' || 'LAUNCH2_INTENT_EXPIRED' => '这笔交易已过期，没有提交任何交易。请重新发起。',
      'LAUNCH2_SIMULATION_REVERTED' => '试算没有通过，这笔交易在链上会被拒绝。没有提交任何交易。',
      'REVIEW_PAYLOAD_MISMATCH' => '交易内容与确认内容不一致，已拒绝签名，没有提交任何交易。',
      'LAUNCH2_WALLET_ADDRESS_UNKNOWN' => '钱包目录里找不到这笔交易的钱包，没有提交任何交易。',
      'LAUNCH2_WALLET_ADDRESS_MISMATCH' =>
        '服务端构造交易用的钱包与当前钱包不一致，已拒绝签名，没有提交任何交易。',
      'INTENT_CHAIN_NOT_PERMITTED' ||
      'intent_chain_not_permitted' => '这条链不允许签名，没有提交任何交易。',
      'privy_chain_switch_unsupported' => '钱包暂时不能在这条链上签名，没有提交任何交易。',
      'privy_wallet_mismatch' => '当前登录的钱包不是这笔交易的钱包，没有提交任何交易。',
      _ => '钱包没有完成签名，没有提交任何交易。',
    };

/// Why the trade after a broadcast approval was not signed when the exit
/// tried to refresh an expiring quote (decision 0148). The approval stands;
/// the next attempt needs only the trade.
String launch2RefreshReasonText(Launch2SignOutcome outcome, String noun) {
  final failure = outcome.refreshFailure;
  final why = switch (outcome.reasonCode) {
    launch2RefreshApprovalPendingCode => '授权还在链上确认',
    launch2RefreshOutOfRangeCode => '最新报价超出了你确认的范围',
    launch2RefreshFailedCode =>
      failure == null
          ? '没有取到新报价'
          : '没有取到新报价（${launch2PoolFailureText(failure)}）',
    _ => '新的交易内容没有通过核对',
  };
  return '授权已广播。原报价即将到期，刷新时$why，$noun没有签名，'
      '没有提交$noun交易。稍后重新发起，授权足够时只需签一次。';
}

/// Whether [outcome] stopped at the refresh between the two signatures.
bool launch2StoppedAtRefresh(Launch2SignOutcome outcome) =>
    outcome.approvalTxHash != null &&
    outcome.txHash == null &&
    outcome.status != MoneySignStatus.locked &&
    (outcome.reasonCode == launch2RefreshApprovalPendingCode ||
        outcome.reasonCode == launch2RefreshOutOfRangeCode ||
        outcome.reasonCode == launch2RefreshFailedCode ||
        outcome.status == MoneySignStatus.refused);

/// The intent's main transaction can no longer be built from the approval's
/// quote: the trade-only intent still asks for an approval after the retries.
const String launch2RefreshApprovalPendingCode =
    'LAUNCH2_REFRESH_APPROVAL_PENDING';

/// The refreshed intent is worse than the one reviewed: it pays more, or
/// accepts less, than the sheet showed.
const String launch2RefreshOutOfRangeCode = 'LAUNCH2_REFRESH_OUT_OF_RANGE';

/// The re-quote or the re-prepare failed.
const String launch2RefreshFailedCode = 'LAUNCH2_REFRESH_FAILED';

/// How close to its expiry an intent may be signed after an approval
/// (decision 0148): below this the exit refreshes it first.
const Duration launch2RefreshMargin = Duration(seconds: 20);

/// A fresh intent for the same trade: re-quote, then re-prepare. Supplied
/// by the panel that prepared the original (the official pool, decision
/// 0148).
typedef Launch2IntentRefresher = Future<Launch2Intent> Function();

/// The project page's line when the approval went out and the trade was
/// never signed (decision 0159): a step-up stop says it the way the three
/// MEME / MEME v2 sheets do (`loopStepUpAfterApprovalText`, decision 0158);
/// any other stop keeps the page's own sentence.
String launch2ApprovalOnlyText(String reasonCode, String noun) =>
    loopStepUpStopped(reasonCode)
    ? launch2SignReasonText(reasonCode, approvalSent: true)
    : '授权已广播，$noun没有签名。可以重新发起。';

/// The one sentence after a broadcast. A broadcast is never a result.
String launch2BroadcastText(
  Launch2SignOutcome outcome,
  Launch2IntentKind kind, {
  String? noun,
}) {
  noun ??= launch2IntentNoun(kind);
  final hash = outcome.txHash;
  if (hash == null) {
    if (outcome.approvalTxHash != null) {
      return '授权已广播（${launch2ShortAddress(outcome.approvalTxHash!)}），'
          '但$noun交易的钱包结果未知，已锁定。不要重复签名，稍后刷新查看。';
    }
    return '钱包的结果未知，这笔$noun已锁定。不要重复签名，稍后刷新查看。';
  }
  return '已广播（${launch2ShortAddress(hash)}）。广播不代表已成交，'
      '链上确认后这里会更新。';
}

/// The one figure of the viewer's own position that [intent] moves, or
/// `null` when the read model carries no signal of the viewer's own
/// (decision 0203): `viewer.nftHeld` for a mint, `viewer.curve.bought` for a
/// curve buy, `viewer.curve.sold` for a curve sell, the wallet's own pool
/// trade count (decision 0148) for an official-pool trade. Another wallet's
/// mint or trade (`nftSale.soldCount`, the pool's total) never moves it.
/// `null` too for a reward claim, no viewer, or a viewer that is not the
/// intent's wallet.
Decimal? launch2OwnConfirmationFigure(
  Launch2InstanceDetail detail,
  Launch2Intent intent,
) {
  final viewer = detail.viewer;
  if (viewer == null || viewer.walletId != intent.walletId) return null;
  return switch (intent.kind) {
    Launch2IntentKind.nftMint => Decimal.fromInt(viewer.nftHeld),
    Launch2IntentKind.buy || Launch2IntentKind.sell => switch (intent.venue) {
      Launch2Venue.curve =>
        intent.kind == Launch2IntentKind.buy
            ? viewer.curve.bought
            : viewer.curve.sold,
      Launch2Venue.officialPool => switch (viewer.holding) {
        final Launch2WalletHolding own => Decimal.fromBigInt(
          own.poolTradeCount,
        ),
        null => null,
      },
      Launch2Venue.loopDynamicRewards => null,
    },
    Launch2IntentKind.rewardClaim => null,
  };
}

/// Whether [now] is [kind]'s own trade landing on top of [baseline], the
/// figure read when the wallet broadcast (decision 0203): a mint only when
/// `nftHeld` goes from 0 to more than 0, a buy only when `bought` grows, a
/// sell only when `sold` grows, a pool trade only when the own count grows.
/// Equal or smaller is never a confirmation.
bool launch2OwnConfirmationAdvanced(
  Launch2IntentKind kind, {
  required Decimal baseline,
  required Decimal now,
}) => switch (kind) {
  Launch2IntentKind.nftMint => baseline == Decimal.zero && now > Decimal.zero,
  Launch2IntentKind.buy || Launch2IntentKind.sell => now > baseline,
  Launch2IntentKind.rewardClaim => false,
};

/// The read model watched after a broadcast (decision 0203, S234-4): it
/// completes [confirmed] once the instance the page keeps reading shows the
/// viewer's own change. [close] stops it; a closed watch never completes.
abstract interface class Launch2ConfirmationWatch {
  Future<void> get confirmed;
  void close();
}

/// Starts a [Launch2ConfirmationWatch] at the broadcast. Supplied by the
/// page that opened the sheet, which owns the instance's read model.
typedef Launch2ConfirmationProbe = Launch2ConfirmationWatch Function();

/// How long the sheet shows 「已确认」 before it closes itself.
const Duration launch2SignConfirmedCloseDelay = Duration(seconds: 2);

/// The sheet's line once the read model shows the broadcast (the same
/// sentence the project page uses).
String launch2ConfirmedText(String noun) => '$noun已在链上确认。';

/// Where a two-transaction trip through the exit is (approval, then the
/// trade): the sheet draws it as a two-step strip.
enum Launch2SignStep { approving, refreshing, signingMain }

/// What one MEME v2 intent is worth in USD1, for the large-amount step-up
/// (decision 0152): the most a buy or an NFT purchase pays (`amountIn`, tax
/// included), what a sell expects to receive (`expectedOut`).
Decimal launch2IntentStepUpUsd1(Launch2Intent intent) => switch (intent.kind) {
  Launch2IntentKind.sell || Launch2IntentKind.rewardClaim => intent.expectedOut,
  Launch2IntentKind.buy || Launch2IntentKind.nftMint => intent.amountIn,
};

/// The one path from a MEME v2 intent to the wallet.
final class Launch2IntentSigner {
  const Launch2IntentSigner({
    required this.wallet,
    this.refreshAttempts = 4,
    this.refreshRetryDelay = const Duration(seconds: 3),
  });

  final WalletSigningGateway wallet;

  /// How many re-prepares the exit asks for while the fresh intent still
  /// carries an approval (the broadcast approval is not yet in a block).
  final int refreshAttempts;
  final Duration refreshRetryDelay;

  static SigningIntent _signingIntent(
    Launch2Intent intent, {
    required String revision,
    required IntentKind kind,
    required String title,
    required Launch2UnsignedTransaction transaction,
    required String fromAddress,
    required String ticker,
    String? noun,
  }) => SigningIntent.backendCanonical(
    revision: revision,
    payloadDigest: intent.payloadDigest,
    title: title,
    kind: kind,
    chainId: intent.chainId,
    payload: DeviceTransactionPayload(
      fromAddress: fromAddress,
      transaction: transaction.wire,
    ),
    observedAt: intent.createdAt,
    expiresAt: intent.expiresAt,
    fields: launch2IntentFields(intent, ticker: ticker, noun: noun),
    stepUpUsd1: launch2IntentStepUpUsd1(intent),
  );

  static SigningIntent? approvalSigningIntent(
    Launch2Intent intent, {
    required String fromAddress,
    required String ticker,
    String? noun,
  }) {
    final approval = intent.approval;
    if (approval == null) return null;
    return _signingIntent(
      intent,
      revision: '${intent.intentId}:approval',
      kind: IntentKind.launchApproval,
      title: '授权',
      transaction: approval.unsignedTransaction,
      fromAddress: fromAddress,
      ticker: ticker,
      noun: noun,
    );
  }

  static SigningIntent mainSigningIntent(
    Launch2Intent intent, {
    required String fromAddress,
    required String ticker,
    String? noun,
  }) => _signingIntent(
    intent,
    revision: intent.intentId,
    kind: IntentKind.launchPurchase,
    title: launch2IntentTitle(intent.kind, venue: intent.venue, noun: noun),
    transaction: intent.unsignedTransaction,
    fromAddress: fromAddress,
    ticker: ticker,
    noun: noun,
  );

  /// Refusals that need nothing but the intent, the wallet address and the
  /// clock; the sheet states them before any wallet opens.
  static String? refusalBeforeWallet(
    Launch2Intent intent, {
    required String? fromAddress,
    required DateTime now,
  }) {
    if (!intent.canSignAt(now)) {
      if (!intent.signingAllowed && intent.signingReasonCode != null) {
        return intent.signingReasonCode;
      }
      return 'INTENT_EXPIRED';
    }
    if (!intent.payloadMatchesReview) return 'REVIEW_PAYLOAD_MISMATCH';
    if (fromAddress == null) return 'LAUNCH2_WALLET_ADDRESS_UNKNOWN';
    final from = fromAddress.toLowerCase();
    if (intent.unsignedTransaction.from != from ||
        (intent.approval != null &&
            intent.approval!.unsignedTransaction.from != from)) {
      return 'LAUNCH2_WALLET_ADDRESS_MISMATCH';
    }
    return null;
  }

  /// Why [fresh] may not replace [reviewed] for the trade after an
  /// approval, or `null` when it may (decision 0148): same trade, same
  /// wallet, no approval of its own, signable now, and never worse than
  /// what the sheet showed — it pays at most [reviewed]'s `amountIn` and
  /// accepts at least its `minOut`.
  static String? refreshRefusal(
    Launch2Intent reviewed,
    Launch2Intent fresh, {
    required String fromAddress,
    required DateTime now,
  }) {
    if (fresh.kind != reviewed.kind ||
        fresh.venue != reviewed.venue ||
        fresh.instanceId != reviewed.instanceId ||
        fresh.walletId != reviewed.walletId ||
        fresh.chainId != reviewed.chainId ||
        fresh.contractAddress.toLowerCase() !=
            reviewed.contractAddress.toLowerCase()) {
      return 'REVIEW_PAYLOAD_MISMATCH';
    }
    if (fresh.approval != null) return launch2RefreshApprovalPendingCode;
    final refusal = refusalBeforeWallet(
      fresh,
      fromAddress: fromAddress,
      now: now,
    );
    if (refusal != null) return refusal;
    if (fresh.amountIn > reviewed.amountIn || fresh.minOut < reviewed.minOut) {
      return launch2RefreshOutOfRangeCode;
    }
    return null;
  }

  /// Asks [refresh] for the trade-only intent, again while the approval is
  /// not yet visible to the server.
  Future<Launch2SignOutcome?> _refreshed(
    Launch2Intent reviewed, {
    required Launch2IntentRefresher refresh,
    required String fromAddress,
    required DateTime Function() clock,
    required String approvalHash,
    required void Function(Launch2Intent fresh) accept,
  }) async {
    for (var attempt = 1; ; attempt += 1) {
      final Launch2Intent fresh;
      try {
        fresh = await refresh();
      } on LoopChainException catch (failure) {
        return Launch2SignOutcome(
          status: MoneySignStatus.walletRejected,
          reasonCode: launch2RefreshFailedCode,
          approvalTxHash: approvalHash,
          refreshFailure: failure,
        );
      } catch (_) {
        return Launch2SignOutcome(
          status: MoneySignStatus.walletRejected,
          reasonCode: launch2RefreshFailedCode,
          approvalTxHash: approvalHash,
          refreshFailure: const LoopChainException(
            LoopChainFailureKind.unexpected,
          ),
        );
      }
      final refusal = refreshRefusal(
        reviewed,
        fresh,
        fromAddress: fromAddress,
        now: clock(),
      );
      if (refusal == launch2RefreshApprovalPendingCode &&
          attempt < refreshAttempts) {
        await Future<void>.delayed(refreshRetryDelay);
        continue;
      }
      if (refusal != null) {
        return Launch2SignOutcome(
          status: MoneySignStatus.refused,
          reasonCode: refusal,
          approvalTxHash: approvalHash,
        );
      }
      accept(fresh);
      return null;
    }
  }

  /// Signs [intent]: its approval first when it carries one, then the
  /// trade.
  ///
  /// Decision 0148: when [refresh] is given and, once the approval is
  /// broadcast, the intent has less than [launch2RefreshMargin] left on
  /// [clock], the trade is signed from a fresh intent instead (re-quote and
  /// re-prepare; [onRefreshed] tells the sheet). A refresh that fails, still
  /// needs an approval after the retries, or is worse than the reviewed
  /// intent stops before the second wallet prompt.
  Future<Launch2SignOutcome> sign(
    Launch2Intent intent, {
    required String? fromAddress,
    required String ticker,
    required DateTime now,
    void Function(Launch2SignStep step)? onStep,
    DateTime Function()? clock,
    Launch2IntentRefresher? refresh,
    void Function(Launch2Intent fresh)? onRefreshed,
    String? noun,
  }) async {
    final refusal = refusalBeforeWallet(
      intent,
      fromAddress: fromAddress,
      now: now,
    );
    if (refusal != null) {
      return Launch2SignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: refusal,
      );
    }
    final from = fromAddress!;
    final main = mainSigningIntent(
      intent,
      fromAddress: from,
      ticker: ticker,
      noun: noun,
    );
    final approval = approvalSigningIntent(
      intent,
      fromAddress: from,
      ticker: ticker,
      noun: noun,
    );
    if (!main.chainIsPermitted ||
        (approval != null && !approval.chainIsPermitted)) {
      return const Launch2SignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    String? approvalHash;
    if (approval != null) {
      onStep?.call(Launch2SignStep.approving);
      final handoff = await wallet.handoff(approval, now: now);
      if (!handoff.accepted || handoff.value == null) {
        return Launch2SignOutcome(
          status: handoff.code == 'wallet_outcome_unknown'
              ? MoneySignStatus.locked
              : MoneySignStatus.walletRejected,
          reasonCode: handoff.code,
        );
      }
      approvalHash = handoff.value;
    }
    var signed = main;
    Launch2Intent? fresh;
    final at = clock ?? () => now;
    if (approvalHash != null &&
        refresh != null &&
        intent.expiresAt.difference(at()) < launch2RefreshMargin) {
      onStep?.call(Launch2SignStep.refreshing);
      final stopped = await _refreshed(
        intent,
        refresh: refresh,
        fromAddress: from,
        clock: at,
        approvalHash: approvalHash,
        accept: (next) => fresh = next,
      );
      if (stopped != null) return stopped;
      signed = mainSigningIntent(
        fresh!,
        fromAddress: from,
        ticker: ticker,
        noun: noun,
      );
      if (!signed.chainIsPermitted) {
        return Launch2SignOutcome(
          status: MoneySignStatus.refused,
          reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
          approvalTxHash: approvalHash,
        );
      }
      onRefreshed?.call(fresh!);
    }
    onStep?.call(Launch2SignStep.signingMain);
    final handoff = await wallet.handoff(
      signed,
      now: clock == null ? now : at(),
    );
    if (!handoff.accepted || handoff.value == null) {
      return Launch2SignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
        approvalTxHash: approvalHash,
        refreshed: fresh,
      );
    }
    return Launch2SignOutcome(
      status: MoneySignStatus.submitted,
      reasonCode: 'BROADCAST',
      txHash: handoff.value,
      approvalTxHash: approvalHash,
      refreshed: fresh,
    );
  }
}

final launch2IntentSignerProvider = Provider<Launch2IntentSigner>(
  (ref) => Launch2IntentSigner(
    wallet: ref.watch(loopGuardedWalletSigningGatewayProvider),
  ),
);

/// Opens the signing exit for one prepared intent. `null` means the sheet
/// was closed before the wallet opened; a sheet torn down afterwards still
/// reports a locked outcome.
Future<Launch2SignOutcome?> showLaunch2SignSheet(
  BuildContext context, {
  required Launch2Intent intent,
  required Launch2IntentSigner signer,
  required String? fromAddress,
  required String ticker,
  DateTime Function()? clock,
  Launch2IntentRefresher? refresh,
  String? noun,
  Launch2ConfirmationProbe? confirmation,
}) async {
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<Launch2SignOutcome>(
    context,
    isDismissible: false,
    builder: (context) => Launch2SignSheet(
      intent: intent,
      signer: signer,
      fromAddress: fromAddress,
      ticker: ticker,
      clock: clock,
      latch: latch,
      refresh: refresh,
      noun: noun,
      confirmation: confirmation,
    ),
  );
  if (outcome != null) return outcome;
  if (!latch.enteredSigning) return null;
  return Launch2SignOutcome(
    status: MoneySignStatus.locked,
    reasonCode: 'SIGNING_INTERRUPTED',
    txHash: latch.txHash,
  );
}

class Launch2SignSheet extends StatefulWidget {
  const Launch2SignSheet({
    required this.intent,
    required this.signer,
    required this.fromAddress,
    required this.ticker,
    super.key,
    this.clock,
    this.latch,
    this.refresh,
    this.noun,
    this.confirmation,
    this.confirmedCloseDelay = launch2SignConfirmedCloseDelay,
  });

  final Launch2Intent intent;
  final Launch2IntentSigner signer;

  /// The action's name on the sheet, its steps and the wallet prompt
  /// (decision 0163); `null` is the kind's own ([launch2IntentNoun]).
  final String? noun;
  final String? fromAddress;
  final String ticker;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;

  /// Re-quotes and re-prepares the same trade when the approval took the
  /// quote too close to its expiry (decision 0148).
  final Launch2IntentRefresher? refresh;

  /// Decision 0203 (S234-4): after a broadcast the sheet watches the read
  /// model through this, turns 「已确认」 when it shows the change and closes
  /// itself [confirmedCloseDelay] later. `null`: the sheet stays at
  /// 「已广播」 until it is closed by hand.
  final Launch2ConfirmationProbe? confirmation;
  final Duration confirmedCloseDelay;

  @override
  State<Launch2SignSheet> createState() => _Launch2SignSheetState();
}

class _Launch2SignSheetState extends State<Launch2SignSheet>
    with LoopStepUpSheetMixin<Launch2SignSheet> {
  String get _noun => widget.noun ?? launch2IntentNoun(widget.intent.kind);

  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  Launch2SignOutcome? _outcome;
  bool _submitted = false;
  Launch2SignStep? _step;

  /// The intent the facts are read from: the reviewed one, or the fresh one
  /// the trade is signed from after a refresh.
  late Launch2Intent _intent = widget.intent;
  bool _refreshed = false;

  /// Decision 0203: the read model showed the broadcast.
  bool _confirmed = false;
  Launch2ConfirmationWatch? _watch;
  Timer? _autoClose;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  WalletSigningGateway get stepUpWallet => widget.signer.wallet;

  @override
  Decimal? get stepUpUsd1 => launch2IntentStepUpUsd1(widget.intent);

  @override
  void initState() {
    super.initState();
    final refusal = Launch2IntentSigner.refusalBeforeWallet(
      widget.intent,
      fromAddress: widget.fromAddress,
      now: _now,
    );
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = launch2SignReasonText(refusal);
    } else if (widget.intent.approval != null) {
      _reason =
          '会依次打开两次钱包：先授权，再$_noun。'
          '授权金额只够这一笔。';
    }
    if (refusal == null) planStepUp();
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    // Decision 0152: the large-amount step-up runs before the first wallet
    // prompt and covers the approval, the trade and a refreshed trade.
    final stopped = await runStepUp();
    if (!mounted) return;
    if (stopped != null) {
      setState(() {
        _state = LoopSignSheetState.pending;
        _reason = loopStepUpReasonText(stopped);
        _submitted = false;
      });
      return;
    }
    widget.latch?.enteredSigning = true;
    final outcome = await widget.signer.sign(
      widget.intent,
      fromAddress: widget.fromAddress,
      ticker: widget.ticker,
      now: _now,
      clock: () => _now,
      refresh: widget.refresh,
      onStep: (step) {
        if (mounted) setState(() => _step = step);
      },
      noun: widget.noun,
      onRefreshed: (fresh) {
        if (!mounted) return;
        setState(() {
          _intent = fresh;
          _refreshed = true;
        });
      },
    );
    widget.latch?.txHash = outcome.txHash;
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      if (outcome.broadcast) {
        _state = LoopSignSheetState.complete;
        _reason = launch2BroadcastText(
          outcome,
          widget.intent.kind,
          noun: widget.noun,
        );
        _watchConfirmation(outcome);
      } else {
        _state = LoopSignSheetState.simulationFailed;
        final noun = _noun;
        _reason = launch2StoppedAtRefresh(outcome)
            ? launch2RefreshReasonText(outcome, noun)
            : outcome.approvalTxHash != null
            ? (loopStepUpStopped(outcome.reasonCode)
                  ? launch2SignReasonText(
                      outcome.reasonCode,
                      approvalSent: true,
                    )
                  : '授权已广播，$noun没有签名，没有提交$noun交易。可以关闭后重新发起。')
            : launch2SignReasonText(outcome.reasonCode);
        // A broadcast approval makes this intent's nonce plan stale: the
        // page prepares a new one instead of re-opening this sheet.
        _submitted = outcome.approvalTxHash != null;
      }
    });
  }

  /// Decision 0203 (S234-4): a broadcast with a hash is watched on the read
  /// model; a locked outcome (no hash, or the wallet's answer unknown) is
  /// never declared confirmed here.
  void _watchConfirmation(Launch2SignOutcome outcome) {
    final probe = widget.confirmation;
    if (probe == null ||
        outcome.status != MoneySignStatus.submitted ||
        outcome.txHash == null) {
      return;
    }
    final watch = probe();
    _watch = watch;
    unawaited(
      watch.confirmed.then((_) {
        if (!mounted || _confirmed) return;
        setState(() {
          _confirmed = true;
          _reason = launch2ConfirmedText(_noun);
        });
        _autoClose = Timer(widget.confirmedCloseDelay, () {
          if (mounted) Navigator.of(context).pop(_outcome);
        });
      }),
    );
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _watch?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = launch2IntentFields(
      _intent,
      ticker: widget.ticker,
      noun: widget.noun,
    );
    final sheet = LoopSignSheet(
      key: const ValueKey<String>('launch2-sign-sheet'),
      state: _state,
      signingTitle: stepUpSigningTitle,
      title: launch2IntentTitle(
        widget.intent.kind,
        venue: widget.intent.venue,
        noun: widget.noun,
      ),
      networkBadge: loopTestnetBadgeFor(widget.intent.chainId),
      facts: <LoopSignFact>[
        for (final IntentField field in fields)
          LoopSignFact(field.label, field.value),
      ],
      reason: _reason,
      completeLabel: _confirmed ? '已确认' : '已广播',
      onConfirm: _submitted ? null : _confirm,
      onCancel: () => Navigator.of(context).pop(_outcome),
    );
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: widget.intent.approval == null
          ? withStepUpStrip(
              sheet,
              signLabel: _noun,
              signStatus: stepUpSignStatus(
                _state,
                locked: _outcome?.status == MoneySignStatus.locked,
              ),
              signCaption: _confirmed ? '已确认' : null,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Launch2SignStepStrip(
                  noun: _noun,
                  verify: stepUpStep,
                  approval: _approvalStatus,
                  main: _mainStatus,
                  mainConfirmed: _confirmed,
                ),
                if (_refreshed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      launch2RefreshedText,
                      key: const ValueKey<String>('launch2-sign-refreshed'),
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                  ),
                sheet,
              ],
            ),
    );
  }

  Launch2StepStatus get _approvalStatus {
    final outcome = _outcome;
    if (outcome != null) {
      return outcome.approvalTxHash != null
          ? Launch2StepStatus.done
          : outcome.status == MoneySignStatus.locked
          ? Launch2StepStatus.unknown
          : Launch2StepStatus.failed;
    }
    return switch (_step) {
      null => Launch2StepStatus.waiting,
      Launch2SignStep.approving => Launch2StepStatus.active,
      Launch2SignStep.refreshing ||
      Launch2SignStep.signingMain => Launch2StepStatus.done,
    };
  }

  Launch2StepStatus get _mainStatus {
    final outcome = _outcome;
    if (outcome != null) {
      if (outcome.txHash != null) return Launch2StepStatus.done;
      if (outcome.approvalTxHash == null) return Launch2StepStatus.waiting;
      return outcome.status == MoneySignStatus.locked
          ? Launch2StepStatus.unknown
          : Launch2StepStatus.failed;
    }
    return switch (_step) {
      Launch2SignStep.signingMain => Launch2StepStatus.active,
      Launch2SignStep.refreshing => Launch2StepStatus.refreshing,
      _ => Launch2StepStatus.waiting,
    };
  }
}

/// One step of the two-step strip (decision 0152 made the strip shared).
typedef Launch2StepStatus = LoopSignStepStatus;

/// The one line the sheet shows once the trade is signed from a fresh
/// intent (decision 0148).
const String launch2RefreshedText = '已刷新报价：原报价即将到期，已按最新区块重新报价，金额在你确认的范围内';

/// 「1 授权 → 2 买入」 above the signing sheet when an intent carries an
/// approval: which wallet prompt is open and which already broadcast.
///
/// Decision 0152: when the large-amount step-up runs, [verify] puts
/// 「验证身份」 in front of both.
class Launch2SignStepStrip extends StatelessWidget {
  const Launch2SignStepStrip({
    required this.noun,
    required this.approval,
    required this.main,
    super.key,
    this.verify,
    this.mainConfirmed = false,
  });

  final String noun;
  final Launch2StepStatus approval;
  final Launch2StepStatus main;

  /// Decision 0203: the read model showed the trade, so its step says
  /// 「已确认」 instead of 「已广播」.
  final bool mainConfirmed;

  /// The step-up's own step, or `null` when it does not run.
  final LoopStepUpStep? verify;

  static String _status(Launch2StepStatus status) => switch (status) {
    Launch2StepStatus.waiting => '待签名',
    Launch2StepStatus.active => '请在钱包确认',
    Launch2StepStatus.refreshing => '正在刷新报价',
    Launch2StepStatus.done => '已广播',
    Launch2StepStatus.failed => '未完成',
    Launch2StepStatus.unknown => '结果未知',
  };

  @override
  Widget build(BuildContext context) => LoopSignStepStrip(
    keyPrefix: 'launch2-sign',
    steps: <LoopSignStep>[
      if (verify != null) verify!.step,
      LoopSignStep(
        id: 'approval',
        label: '授权',
        status: approval,
        caption: _status(approval),
      ),
      LoopSignStep(
        id: 'main',
        label: noun,
        status: main,
        caption: mainConfirmed && main == Launch2StepStatus.done
            ? '已确认'
            : _status(main),
      ),
    ],
  );
}

/// The sentence the NFT purchase must state in full (规格 §3, contract §3.4).
const String launch2NftRiskSentence = '不保证成交、不保证配售，公开内盘可能不发生';

/// The NFT purchase confirmation: the price, the one-per-address rule and the
/// risk sentence in full, which the buyer ticks before the server is asked
/// for anything. `true` when they confirmed.
/// [heading] / [confirmLabel] replace 「购买 $T 项目 NFT」 / 「继续购买」
/// (decision 0163: 共识勋章 says 「铸造 T 共识勋章」 / 「继续铸造」).
Future<bool> showLaunch2NftConfirmSheet(
  BuildContext context, {
  required String ticker,
  required String priceLabel,
  String? heading,
  String confirmLabel = '继续铸造',
}) async {
  final confirmed = await showLoopSheet<bool>(
    context,
    builder: (context) => _Launch2NftConfirm(
      ticker: ticker,
      priceLabel: priceLabel,
      heading: heading ?? '铸造 $ticker 共识勋章',
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed ?? false;
}

class _Launch2NftConfirm extends StatefulWidget {
  const _Launch2NftConfirm({
    required this.ticker,
    required this.priceLabel,
    required this.heading,
    required this.confirmLabel,
  });

  final String ticker;
  final String priceLabel;
  final String heading;
  final String confirmLabel;

  @override
  State<_Launch2NftConfirm> createState() => _Launch2NftConfirmState();
}

class _Launch2NftConfirmState extends State<_Launch2NftConfirm> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('launch2-nft-confirm'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopSheetHeading(widget.heading),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopKeyValue(
              label: '价格',
              value: widget.priceLabel,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
            const LoopKeyValue(
              label: '数量',
              value: '每个地址终身 1 枚',
              padding: EdgeInsets.symmetric(vertical: 6),
            ),
            const SizedBox(height: 10),
            Text(
              '持有 NFT 的地址进入快照名单，可参加 1 小时提前购。',
              // M18 R19 sheet support copy: bodySm 13 (decision 0191).
              style: LoopType.bodySm,
            ),
            const SizedBox(height: 12),
            Semantics(
              checked: _ticked,
              button: true,
              label: '我已知晓：$launch2NftRiskSentence',
              excludeSemantics: true,
              child: LoopPressable(
                key: const ValueKey<String>('launch2-nft-risk-tick'),
                onTap: () => setState(() => _ticked = !_ticked),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          _ticked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 22,
                          color: _ticked ? LoopColors.lime : LoopColors.text2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '我已知晓：$launch2NftRiskSentence。',
                          key: const ValueKey<String>('launch2-nft-risk'),
                          style: LoopType.title,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            LoopButton(
              key: const ValueKey<String>('launch2-nft-confirm-button'),
              label: widget.confirmLabel,
              primary: true,
              block: true,
              onPressed: _ticked ? () => Navigator.of(context).pop(true) : null,
            ),
          ],
        ),
      ),
    ],
  );
}
