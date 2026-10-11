import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

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
  });

  /// [MoneySignStatus.submitted] once the wallet broadcast the main
  /// transaction; [MoneySignStatus.locked] when its outcome is unknown.
  final MoneySignStatus status;
  final String reasonCode;
  final String? txHash;
  final String? approvalTxHash;

  bool get broadcast =>
      status == MoneySignStatus.submitted || status == MoneySignStatus.locked;
}

String launch2IntentNoun(Launch2IntentKind kind) => switch (kind) {
  Launch2IntentKind.nftMint => '购买 NFT',
  Launch2IntentKind.buy => '买入',
  Launch2IntentKind.sell => '卖出',
};

String launch2IntentTitle(
  Launch2IntentKind kind, {
  Launch2Venue venue = Launch2Venue.curve,
}) => venue == Launch2Venue.officialPool
    ? '确认外盘${launch2IntentNoun(kind)}'
    : '确认${launch2IntentNoun(kind)}';

/// Whom an approval lets spend: the curve, the NFT or the pool's router.
String _spenderNoun(Launch2Intent intent) =>
    intent.venue == Launch2Venue.officialPool
    ? '官方池路由'
    : intent.kind == Launch2IntentKind.nftMint
    ? 'NFT 合约'
    : '曲线合约';

/// The tax line's label: the intent's own rate, else the curve's 10%.
String _taxLabel(Launch2Intent intent) {
  final bps = intent.taxBps ?? 1000;
  return intent.venue == Launch2Venue.officialPool
      ? '外盘税 ${launch2BpsLabel(bps)}'
      : '税 ${launch2BpsLabel(bps)}';
}

/// The reviewed facts. The sheet renders exactly these, read from the same
/// object whose transactions the wallet gets.
List<IntentField> launch2IntentFields(
  Launch2Intent intent, {
  required String ticker,
}) {
  final approval = intent.approval;
  final meme = '\$$ticker';
  return <IntentField>[
    IntentField(
      label: '操作',
      value: switch (intent.kind) {
        Launch2IntentKind.nftMint => '购买 $meme 项目 NFT（每个地址 1 枚）',
        Launch2IntentKind.buy =>
          intent.venue == Launch2Venue.officialPool
              ? '在官方池买入 $meme'
              : '买入 $meme',
        Launch2IntentKind.sell =>
          intent.venue == Launch2Venue.officialPool
              ? '在官方池卖出 $meme'
              : '卖出 $meme',
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
    if (intent.kind != Launch2IntentKind.nftMint)
      IntentField(
        label: _taxLabel(intent),
        value: intent.taxMeme != null
            ? launch2MemeLabel(intent.taxMeme!, ticker)
            : launch2Usd1Label(intent.taxUsd1, maxFractionDigits: 4),
      ),
    if (approval != null)
      IntentField(
        label: '先授权',
        value: intent.kind == Launch2IntentKind.sell
            ? '${launch2MemeLabel(approval.amount, ticker)} 给${_spenderNoun(intent)}'
            : intent.kind == Launch2IntentKind.nftMint
            ? '${launch2Usd1Label(approval.amount)} 给${_spenderNoun(intent)}'
            : '${launch2Usd1Label(approval.amount, maxFractionDigits: 4)} 给${_spenderNoun(intent)}',
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
      label: intent.venue == Launch2Venue.officialPool ? '路由' : '合约',
      value: launch2ShortAddress(intent.contractAddress),
    ),
    IntentField(label: '网络', value: loopChainName(intent.chainId)),
  ];
}

/// zh-CN for a refusal before or at the wallet. Every line states that
/// nothing was submitted.
String launch2SignReasonText(String reasonCode) => switch (reasonCode) {
  'INTENT_EXPIRED' || 'LAUNCH2_INTENT_EXPIRED' => '这笔交易已过期，没有提交任何交易。请重新发起。',
  'LAUNCH2_SIMULATION_REVERTED' => '试算没有通过，这笔交易在链上会被拒绝。没有提交任何交易。',
  'REVIEW_PAYLOAD_MISMATCH' => '交易内容与确认内容不一致，已拒绝签名，没有提交任何交易。',
  'LAUNCH2_WALLET_ADDRESS_UNKNOWN' => '钱包目录里找不到这笔交易的钱包，没有提交任何交易。',
  'LAUNCH2_WALLET_ADDRESS_MISMATCH' => '服务端构造交易用的钱包与当前钱包不一致，已拒绝签名，没有提交任何交易。',
  'INTENT_CHAIN_NOT_PERMITTED' ||
  'intent_chain_not_permitted' => '这条链不允许签名，没有提交任何交易。',
  'privy_chain_switch_unsupported' => '钱包暂时不能在这条链上签名，没有提交任何交易。',
  'privy_wallet_mismatch' => '当前登录的钱包不是这笔交易的钱包，没有提交任何交易。',
  _ => '钱包没有完成签名，没有提交任何交易。',
};

/// The one sentence after a broadcast. A broadcast is never a result.
String launch2BroadcastText(
  Launch2SignOutcome outcome,
  Launch2IntentKind kind,
) {
  final noun = launch2IntentNoun(kind);
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

/// Where a two-transaction trip through the exit is (approval, then the
/// trade): the sheet draws it as a two-step strip.
enum Launch2SignStep { approving, signingMain }

/// The one path from a MEME v2 intent to the wallet.
final class Launch2IntentSigner {
  const Launch2IntentSigner({required this.wallet});

  final WalletSigningGateway wallet;

  static SigningIntent _signingIntent(
    Launch2Intent intent, {
    required String revision,
    required IntentKind kind,
    required String title,
    required Launch2UnsignedTransaction transaction,
    required String fromAddress,
    required String ticker,
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
    fields: launch2IntentFields(intent, ticker: ticker),
  );

  static SigningIntent? approvalSigningIntent(
    Launch2Intent intent, {
    required String fromAddress,
    required String ticker,
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
    );
  }

  static SigningIntent mainSigningIntent(
    Launch2Intent intent, {
    required String fromAddress,
    required String ticker,
  }) => _signingIntent(
    intent,
    revision: intent.intentId,
    kind: IntentKind.launchPurchase,
    title: launch2IntentTitle(intent.kind, venue: intent.venue),
    transaction: intent.unsignedTransaction,
    fromAddress: fromAddress,
    ticker: ticker,
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

  Future<Launch2SignOutcome> sign(
    Launch2Intent intent, {
    required String? fromAddress,
    required String ticker,
    required DateTime now,
    void Function(Launch2SignStep step)? onStep,
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
    final main = mainSigningIntent(intent, fromAddress: from, ticker: ticker);
    final approval = approvalSigningIntent(
      intent,
      fromAddress: from,
      ticker: ticker,
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
    onStep?.call(Launch2SignStep.signingMain);
    final handoff = await wallet.handoff(main, now: now);
    if (!handoff.accepted || handoff.value == null) {
      return Launch2SignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
        approvalTxHash: approvalHash,
      );
    }
    return Launch2SignOutcome(
      status: MoneySignStatus.submitted,
      reasonCode: 'BROADCAST',
      txHash: handoff.value,
      approvalTxHash: approvalHash,
    );
  }
}

final launch2IntentSignerProvider = Provider<Launch2IntentSigner>(
  (ref) => Launch2IntentSigner(wallet: ref.watch(walletSigningGatewayProvider)),
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
  });

  final Launch2Intent intent;
  final Launch2IntentSigner signer;
  final String? fromAddress;
  final String ticker;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;

  @override
  State<Launch2SignSheet> createState() => _Launch2SignSheetState();
}

class _Launch2SignSheetState extends State<Launch2SignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  Launch2SignOutcome? _outcome;
  bool _submitted = false;
  Launch2SignStep? _step;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

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
          '会依次打开两次钱包：先授权，再${launch2IntentNoun(widget.intent.kind)}。'
          '授权金额只够这一笔。';
    }
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    widget.latch?.enteredSigning = true;
    final outcome = await widget.signer.sign(
      widget.intent,
      fromAddress: widget.fromAddress,
      ticker: widget.ticker,
      now: _now,
      onStep: (step) {
        if (mounted) setState(() => _step = step);
      },
    );
    widget.latch?.txHash = outcome.txHash;
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      if (outcome.broadcast) {
        _state = LoopSignSheetState.complete;
        _reason = launch2BroadcastText(outcome, widget.intent.kind);
      } else {
        _state = LoopSignSheetState.simulationFailed;
        final noun = launch2IntentNoun(widget.intent.kind);
        _reason = outcome.approvalTxHash != null
            ? '授权已广播，$noun没有签名，没有提交$noun交易。可以关闭后重新发起。'
            : launch2SignReasonText(outcome.reasonCode);
        // A broadcast approval makes this intent's nonce plan stale: the
        // page prepares a new one instead of re-opening this sheet.
        _submitted = outcome.approvalTxHash != null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = launch2IntentFields(widget.intent, ticker: widget.ticker);
    final sheet = LoopSignSheet(
      key: const ValueKey<String>('launch2-sign-sheet'),
      state: _state,
      title: launch2IntentTitle(widget.intent.kind, venue: widget.intent.venue),
      networkBadge: loopIsTestnetChainId(widget.intent.chainId)
          ? loopTestnetBadgeLabel
          : null,
      facts: <LoopSignFact>[
        for (final IntentField field in fields)
          LoopSignFact(field.label, field.value),
      ],
      reason: _reason,
      onConfirm: _submitted ? null : _confirm,
      onCancel: () => Navigator.of(context).pop(_outcome),
    );
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: widget.intent.approval == null
          ? sheet
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Launch2SignStepStrip(
                  noun: launch2IntentNoun(widget.intent.kind),
                  approval: _approvalStatus,
                  main: _mainStatus,
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
    return _step == Launch2SignStep.signingMain
        ? Launch2StepStatus.active
        : Launch2StepStatus.waiting;
  }
}

/// One step of the two-step strip.
enum Launch2StepStatus { waiting, active, done, failed, unknown }

/// 「1 授权 → 2 买入」 above the signing sheet when an intent carries an
/// approval: which wallet prompt is open and which already broadcast.
class Launch2SignStepStrip extends StatelessWidget {
  const Launch2SignStepStrip({
    required this.noun,
    required this.approval,
    required this.main,
    super.key,
  });

  final String noun;
  final Launch2StepStatus approval;
  final Launch2StepStatus main;

  static String _status(Launch2StepStatus status) => switch (status) {
    Launch2StepStatus.waiting => '待签名',
    Launch2StepStatus.active => '请在钱包确认',
    Launch2StepStatus.done => '已广播',
    Launch2StepStatus.failed => '未完成',
    Launch2StepStatus.unknown => '结果未知',
  };

  /// The step the next wallet prompt is for, while nothing is open yet
  /// (decision 0149): before, both steps read 「待签名」 in the same grey and
  /// the strip did not say which one 「确认签名」 starts.
  bool get _approvalNext =>
      approval == Launch2StepStatus.waiting &&
      main == Launch2StepStatus.waiting;
  bool get _mainNext =>
      approval == Launch2StepStatus.done && main == Launch2StepStatus.waiting;

  Widget _step(
    String index,
    String label,
    Launch2StepStatus status, {
    required bool next,
  }) {
    final later = status == Launch2StepStatus.waiting && !next;
    final lit =
        status == Launch2StepStatus.active || status == Launch2StepStatus.done;
    final warn =
        status == Launch2StepStatus.failed ||
        status == Launch2StepStatus.unknown;
    return Expanded(
      child: Semantics(
        label: '第 $index 步 $label，${_status(status)}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          child: Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lit ? LoopColors.lime : LoopColors.card,
                  border: Border.all(
                    color: warn
                        ? LoopColors.warning
                        : next
                        ? LoopColors.chalk
                        : LoopColors.line,
                  ),
                ),
                child: Text(
                  index,
                  style: LoopTypography.label(
                    12,
                    weight: FontWeight.w700,
                    color: lit
                        ? LoopColors.ink
                        : next
                        ? LoopColors.chalk
                        : LoopColors.text2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: LoopTypography.title(
                        14,
                        color: later ? LoopColors.text2 : LoopColors.chalk,
                      ),
                    ),
                    Text(
                      _status(status),
                      style: LoopType.caption.copyWith(
                        color: warn
                            ? LoopColors.warning
                            : later
                            ? LoopColors.text3
                            : LoopColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('launch2-sign-steps'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<String>('launch2-sign-step-approval-${approval.name}'),
          child: _step('1', '授权', approval, next: _approvalNext),
        ),
        const SizedBox(width: 8),
        KeyedSubtree(
          key: ValueKey<String>('launch2-sign-step-main-${main.name}'),
          child: _step('2', noun, main, next: _mainNext),
        ),
      ],
    ),
  );
}

/// The sentence the NFT purchase must state in full (规格 §3, contract §3.4).
const String launch2NftRiskSentence = '不保证成交、不保证配售，公开内盘可能不发生';

/// The NFT purchase confirmation: the price, the one-per-address rule and the
/// risk sentence in full, which the buyer ticks before the server is asked
/// for anything. `true` when they confirmed.
Future<bool> showLaunch2NftConfirmSheet(
  BuildContext context, {
  required String ticker,
  required String priceLabel,
}) async {
  final confirmed = await showLoopSheet<bool>(
    context,
    builder: (context) =>
        _Launch2NftConfirm(ticker: ticker, priceLabel: priceLabel),
  );
  return confirmed ?? false;
}

class _Launch2NftConfirm extends StatefulWidget {
  const _Launch2NftConfirm({required this.ticker, required this.priceLabel});

  final String ticker;
  final String priceLabel;

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
      LoopSheetHeading('购买 \$${widget.ticker} 项目 NFT'),
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
              style: LoopTypography.body(14, color: LoopColors.text2),
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
                          style: LoopTypography.title(15),
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
              label: '继续购买',
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
