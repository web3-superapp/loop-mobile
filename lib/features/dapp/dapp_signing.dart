import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

// ---------------------------------------------------------------------------
// S342 · decision 0270 · DApp requests through the one signing exit
// ---------------------------------------------------------------------------
//
// A page's `eth_sendTransaction`, `personal_sign` or `eth_signTypedData_v4`
// reaches the wallet only as a `SigningIntent.backendCanonical` built from
// the server's `dapp_tx` / `dapp_sign` intent. Before the wallet opens, the
// intent is compared with what the page asked for: a server answer that names
// another target, call data, value or message is refused, never signed.

/// zh-CN for a refusal before or at the wallet. Every line says nothing was
/// signed.
String dappSignReasonText(String reasonCode) => switch (reasonCode) {
  loopStepUpCancelledCode => '已取消，没有发生任何变化。',
  loopStepUpFailedCode => '身份验证没有通过，没有发生任何变化。',
  'INTENT_EXPIRED' => '这笔请求已过期，没有签名。请回到页面重新发起。',
  'REVIEW_PAYLOAD_MISMATCH' => '待签内容与页面请求不一致，已拒绝签名。',
  'CHAIN_SIGNING_DISABLED' ||
  'INTENT_CHAIN_NOT_PERMITTED' ||
  'intent_chain_not_permitted' => dappMainnetSigningLine,
  'privy_chain_switch_unsupported' => '钱包暂时不能在这条链上签名，没有签名。',
  'privy_wallet_mismatch' => '当前登录的钱包不是这笔请求的钱包，没有签名。',
  _ => '钱包没有完成签名，没有发生任何变化。',
};

const String dappMainnetSigningLine = '暂不支持在这个网络签名';

/// The one path from a DApp intent to the wallet.
final class DappSigner {
  const DappSigner({required this.wallet, required this.intents});

  final WalletSigningGateway wallet;
  final DappIntentsGateway intents;

  static SigningIntent? signingIntent(
    DappIntent intent, {
    required String fromAddress,
  }) {
    final SigningPayload payload;
    switch (intent.kind) {
      case DappIntentKind.transaction:
        final tx = intent.unsignedTransaction;
        if (tx == null) return null;
        payload = DeviceTransactionPayload(
          fromAddress: fromAddress,
          transaction: tx.toWire(),
        );
      case DappIntentKind.message:
        final method = intent.signMethod;
        final message = intent.signPayload;
        if (method == null || message == null) return null;
        payload = MessageSignaturePayload(
          fromAddress: fromAddress,
          method: method,
          payload: message,
        );
    }
    return SigningIntent.backendCanonical(
      revision: intent.intentId,
      payloadDigest: intent.reviewSha256,
      title: dappSheetTitle(intent),
      kind: intent.kind == DappIntentKind.transaction
          ? IntentKind.dappTransaction
          : IntentKind.dappMessage,
      chainId: intent.chainId,
      payload: payload,
      observedAt: DateTime.now().toUtc(),
      expiresAt: intent.expiresAt,
      fields: <IntentField>[
        for (final fact in dappIntentFacts(intent))
          IntentField(label: fact.label, value: fact.value),
      ],
    );
  }

  /// Refusals that need only the intent, the request, the wallet and the
  /// clock. The sheet states them before the wallet ever opens.
  static String? refusalBeforeWallet(
    DappIntent intent, {
    required String fromAddress,
    required DateTime now,
    DappTxRequest? tx,
    DappSignRequest? sign,
  }) {
    final refusal = intent.refusalAt(now);
    if (refusal != null) return refusal;
    final matches = switch (intent.kind) {
      DappIntentKind.transaction =>
        tx != null && intent.matchesTx(tx, fromAddress: fromAddress),
      DappIntentKind.message => sign != null && intent.matchesSign(sign),
    };
    return matches ? null : 'REVIEW_PAYLOAD_MISMATCH';
  }

  Future<DappSignOutcome> sign(
    DappIntent intent, {
    required String fromAddress,
    required DateTime now,
    DappTxRequest? tx,
    DappSignRequest? sign,
  }) async {
    final refusal = refusalBeforeWallet(
      intent,
      fromAddress: fromAddress,
      now: now,
      tx: tx,
      sign: sign,
    );
    if (refusal != null) {
      return DappSignOutcome(
        status: DappSignStatus.failed,
        reasonCode: refusal,
      );
    }
    final signing = signingIntent(intent, fromAddress: fromAddress);
    if (signing == null || !signing.chainIsPermitted) {
      return const DappSignOutcome(
        status: DappSignStatus.failed,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    final handoff = await wallet.handoff(signing, now: now);
    if (!handoff.accepted || handoff.value == null) {
      final declined =
          handoff.code == 'privy_broadcast_rejected' ||
          handoff.code == 'privy_signature_rejected' ||
          handoff.code == loopStepUpCancelledCode;
      return DappSignOutcome(
        status: declined ? DappSignStatus.rejected : DappSignStatus.failed,
        reasonCode: handoff.code,
      );
    }
    // Past this line the wallet produced a hash or a signature. It goes back
    // to the page whatever the report does: the page asked for it, and a
    // broadcast transaction exists whether or not the server heard of it.
    final produced = handoff.value!;
    try {
      if (intent.kind == DappIntentKind.transaction) {
        await intents.reportBroadcast(
          intentId: intent.intentId,
          txHash: produced,
        );
      } else {
        await intents.reportSignature(
          intentId: intent.intentId,
          signature: produced,
        );
      }
      return DappSignOutcome(
        status: DappSignStatus.produced,
        reasonCode: 'REPORTED',
        value: produced,
        reported: true,
      );
    } on LoopChainException catch (failure) {
      return DappSignOutcome(
        status: DappSignStatus.produced,
        reasonCode: failure.reasonCode ?? failure.kind.name,
        value: produced,
      );
    } catch (_) {
      return DappSignOutcome(
        status: DappSignStatus.produced,
        reasonCode: 'REPORT_OUTCOME_UNKNOWN',
        value: produced,
      );
    }
  }
}

final dappSignerProvider = Provider<DappSigner>(
  (ref) => DappSigner(
    wallet: ref.watch(loopGuardedWalletSigningGatewayProvider),
    intents: ref.watch(dappIntentsGatewayProvider),
  ),
);

String dappSheetTitle(DappIntent intent) => switch (intent.kind) {
  DappIntentKind.transaction => '确认交易',
  DappIntentKind.message => '确认签名',
};

/// `1.5` for 1.5 × 10¹⁸ wei, exact.
String dappNativeAmount(BigInt wei) {
  final value =
      (Decimal.fromBigInt(wei) / Decimal.fromInt(10).pow(18).toDecimal())
          .toDecimal(scaleOnInfinitePrecision: 18);
  return value.toString();
}

String dappNativeSymbol(String chainId) =>
    chainId == loopPrimaryChainId ? 'BNB' : loopLaunchNativeSymbolText;

/// The facts the sheet lists, read from the server's review only.
List<LoopSignFact> dappIntentFacts(DappIntent intent) {
  final facts = <LoopSignFact>[];
  final tx = intent.txReview;
  final message = intent.signReview;
  if (tx != null) {
    final call = tx.decodedCall;
    facts.add(
      LoopSignFact(
        '方法',
        call == null
            ? (tx.toIsContract == false ? '转账' : '合约调用')
            : call.functionName ?? (call.selector ?? '未知方法'),
      ),
    );
    facts.add(LoopSignFact('目标合约', tx.to));
    facts.add(
      LoopSignFact(
        '数量',
        '${dappNativeAmount(tx.valueWei)} ${dappNativeSymbol(intent.chainId)}',
      ),
    );
    if (call != null) {
      for (final entry in call.args.entries) {
        facts.add(LoopSignFact(entry.key, entry.value));
      }
      if (call.functionName == null && call.dataLength != null) {
        facts.add(LoopSignFact('数据长度', '${call.dataLength} 字节'));
      }
    }
  }
  if (message != null) {
    facts.add(
      LoopSignFact(
        '类型',
        message.method == MessageSignaturePayload.signTypedDataV4
            ? '结构化数据'
            : '消息',
      ),
    );
  }
  facts.add(LoopSignFact('网络', DappChains.label(intent.chainId)));
  return facts;
}

// ---------------------------------------------------------------------------
// sheets
// ---------------------------------------------------------------------------

/// The site line on both sheets: icon and origin.
class DappSiteHeader extends StatelessWidget {
  const DappSiteHeader({required this.origin, super.key, this.faviconUrl});

  final String origin;
  final String? faviconUrl;

  @override
  Widget build(BuildContext context) {
    final icon = faviconUrl;
    return Row(
      key: const ValueKey<String>('dapp-site-header'),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(LoopRadius.innerValue),
          child: SizedBox(
            width: 36,
            height: 36,
            child: ColoredBox(
              color: LoopColors.plateRaised,
              child: icon == null
                  ? const Center(child: LoopIcon('globe', size: 18))
                  : Image.network(
                      icon,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const Center(child: LoopIcon('globe', size: 18)),
                    ),
            ),
          ),
        ),
        const SizedBox(width: LoopSpacing.tight),
        Expanded(
          child: Text(
            origin,
            key: const ValueKey<String>('dapp-site-origin'),
            style: LoopType.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The risk strip. It is drawn only when the server named at least one risk.
class DappRiskStrip extends StatelessWidget {
  const DappRiskStrip({required this.flags, super.key});

  final List<DappRiskFlag> flags;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey<String>('dapp-risk-strip'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LoopColors.fallSoft,
        borderRadius: BorderRadius.circular(LoopRadius.controlValue),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const LoopIcon('warn', size: 18, color: LoopColors.fall),
          const SizedBox(width: LoopSpacing.tight),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final flag in flags)
                  Text(
                    flag.label,
                    key: ValueKey<String>('dapp-risk-${flag.wireName}'),
                    style: LoopType.label.copyWith(color: LoopColors.fall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A `personal_sign` text or an `eth_signTypedData_v4` tree.
class DappMessageView extends StatelessWidget {
  const DappMessageView({required this.review, super.key});

  final DappSignReview review;

  @override
  Widget build(BuildContext context) {
    final typed = review.typedData;
    final rows = <Widget>[];
    if (typed != null) {
      void walk(Object? node, String label, int depth) {
        if (node is Map) {
          if (label.isNotEmpty) rows.add(_line(label, null, depth));
          for (final entry in node.entries) {
            walk(
              entry.value,
              '${entry.key}',
              label.isEmpty ? depth : depth + 1,
            );
          }
        } else if (node is List) {
          rows.add(_line(label, null, depth));
          for (var index = 0; index < node.length; index++) {
            walk(node[index], '[$index]', depth + 1);
          }
        } else {
          rows.add(_line(label, '$node', depth));
        }
      }

      for (final key in const <String>['primaryType', 'domain', 'message']) {
        if (typed.containsKey(key)) {
          walk(<String, Object?>{key: typed[key]}, '', 0);
        }
      }
    } else {
      rows.add(
        SelectableText(
          review.text ?? review.hex ?? '',
          key: const ValueKey<String>('dapp-message-text'),
          style: review.text != null ? LoopType.body : LoopType.code,
        ),
      );
    }
    return Container(
      key: const ValueKey<String>('dapp-message'),
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LoopColors.plateRaised,
        borderRadius: BorderRadius.circular(LoopRadius.controlValue),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }

  static Widget _line(String label, String? value, int depth) => Padding(
    padding: EdgeInsets.only(left: depth * 12.0, top: 2, bottom: 2),
    child: Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: value == null ? label : '$label: ',
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
          if (value != null) TextSpan(text: value, style: LoopType.code),
        ],
      ),
    ),
  );
}

/// The connection sheet: site, icon, address, 连接 / 取消.
Future<bool> showDappConnectSheet(
  BuildContext context, {
  required String origin,
  required String address,
  String? faviconUrl,
}) async {
  final agreed = await showLoopSheet<bool>(
    context,
    builder: (context) => Padding(
      key: const ValueKey<String>('dapp-connect-sheet'),
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('连接钱包', style: LoopType.heading),
          const SizedBox(height: LoopSpacing.card),
          DappSiteHeader(origin: origin, faviconUrl: faviconUrl),
          const SizedBox(height: LoopSpacing.card),
          LoopKeyValue(
            label: '钱包地址',
            value: loopTruncatedAddress(address),
            padding: const EdgeInsets.symmetric(vertical: 7),
          ),
          const SizedBox(height: LoopSpacing.card),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('dapp-connect-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              LoopButton(
                key: const ValueKey<String>('dapp-connect-confirm'),
                label: '连接',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return agreed ?? false;
}

/// Opens the DApp confirmation for one prepared intent. A sheet closed
/// before the wallet opened is a decline; one closed while signing still
/// waits for the wallet's answer.
Future<DappSignOutcome> showDappIntentSheet(
  BuildContext context, {
  required DappIntent intent,
  required DappSigner signer,
  required String fromAddress,
  DappTxRequest? tx,
  DappSignRequest? sign,
  String? faviconUrl,
  DateTime Function()? clock,
}) async {
  final latch = MoneySignLatch();
  final pending = Completer<DappSignOutcome>();
  final closed = await showLoopSheet<DappSignOutcome>(
    context,
    isDismissible: false,
    builder: (context) => DappIntentSheet(
      intent: intent,
      signer: signer,
      fromAddress: fromAddress,
      tx: tx,
      sign: sign,
      faviconUrl: faviconUrl,
      clock: clock,
      latch: latch,
      onOutcome: (outcome) {
        if (!pending.isCompleted) pending.complete(outcome);
      },
    ),
  );
  if (closed != null) return closed;
  if (latch.enteredSigning) return pending.future;
  return const DappSignOutcome.rejected();
}

/// The DApp confirmation: site, risk, decoded content, then the wallet.
class DappIntentSheet extends StatefulWidget {
  const DappIntentSheet({
    required this.intent,
    required this.signer,
    required this.fromAddress,
    super.key,
    this.tx,
    this.sign,
    this.faviconUrl,
    this.clock,
    this.latch,
    this.onOutcome,
  });

  final DappIntent intent;
  final DappSigner signer;
  final String fromAddress;
  final DappTxRequest? tx;
  final DappSignRequest? sign;
  final String? faviconUrl;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;
  final ValueChanged<DappSignOutcome>? onOutcome;

  @override
  State<DappIntentSheet> createState() => _DappIntentSheetState();
}

class _DappIntentSheetState extends State<DappIntentSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  DappSignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    final refusal = DappSigner.refusalBeforeWallet(
      widget.intent,
      fromAddress: widget.fromAddress,
      now: _now,
      tx: widget.tx,
      sign: widget.sign,
    );
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = dappSignReasonText(refusal);
      _outcome = DappSignOutcome(
        status: DappSignStatus.failed,
        reasonCode: refusal,
      );
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
      now: _now,
      tx: widget.tx,
      sign: widget.sign,
    );
    widget.onOutcome?.call(outcome);
    if (!mounted) return;
    if (outcome.status == DappSignStatus.produced) {
      Navigator.of(context).pop(outcome);
      return;
    }
    setState(() {
      _outcome = outcome;
      _state = LoopSignSheetState.simulationFailed;
      _reason = dappSignReasonText(outcome.reasonCode);
    });
  }

  void _cancel() {
    Navigator.of(context).pop(_outcome ?? const DappSignOutcome.rejected());
  }

  @override
  Widget build(BuildContext context) {
    final intent = widget.intent;
    final message = intent.signReview;
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: Column(
        key: const ValueKey<String>('dapp-intent-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: DappSiteHeader(
              origin: intent.origin,
              faviconUrl: widget.faviconUrl,
            ),
          ),
          if (intent.riskFlags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
              child: DappRiskStrip(flags: intent.riskFlags),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
              child: DappMessageView(review: message),
            ),
          const SizedBox(height: 12),
          LoopSignSheet(
            key: const ValueKey<String>('dapp-sign-sheet'),
            state: _state,
            title: dappSheetTitle(intent),
            networkBadge: loopTestnetBadgeFor(intent.chainId),
            facts: dappIntentFacts(intent),
            reason: _reason,
            confirmLabel: intent.kind == DappIntentKind.transaction
                ? '确认交易'
                : '确认签名',
            cancelLabel: '拒绝',
            signingTitle: intent.kind == DappIntentKind.transaction
                ? '正在签名并广播'
                : '正在签名',
            onConfirm: _submitted ? null : _confirm,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}
