import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// The route argument for `approval-guard`.
@immutable
final class ApprovalGuardRequest {
  const ApprovalGuardRequest({
    required this.walletId,
    required this.assetId,
    required this.symbol,
    required this.spenderAddress,
    this.suggestedAmount,
  });

  final String walletId;
  final String assetId;
  final String symbol;
  final String spenderAddress;

  /// The exact amount this operation needs, when one is known.
  final String? suggestedAmount;
}

// ---------------------------------------------------------------------------
// approval-guard
// ---------------------------------------------------------------------------

/// `approval-guard` · the exact-versus-unlimited decision.
///
/// The default is always the exact amount this operation needs. Unlimited is
/// reachable, but only behind its own warning and a second confirmation, which
/// the server also requires as `acknowledgeUnlimited`.
class ApprovalGuardScreen extends ConsumerStatefulWidget {
  const ApprovalGuardScreen({
    required this.request,
    super.key,
    this.onBack,
    this.onNavigate,
    this.clock,
  });

  final ApprovalGuardRequest request;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;
  final DateTime Function()? clock;

  @override
  ConsumerState<ApprovalGuardScreen> createState() =>
      _ApprovalGuardScreenState();
}

class _ApprovalGuardScreenState extends ConsumerState<ApprovalGuardScreen> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.request.suggestedAmount ?? '',
  );

  LoopWalletIntent? _intent;
  LoopChainException? _failure;
  bool _busy = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = sendCapabilityBlocks(ref);
    final intent = _intent;
    final amount = TransferAmount.tryParse(_amount.text.trim());

    return LoopFocusPage(
      key: const ValueKey<String>('approval-guard-screen'),
      archetype: LoopPageArchetype.action,
      title: '授权拦截',
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('approval-guard-folio'),
        kicker: 'APPROVAL REQUEST',
        heading: intent == null
            ? '${widget.request.symbol} 授权'
            : intent.review.amount.isUnlimited
            ? '无限 ${widget.request.symbol} 授权'
            : '${intent.review.amount.display} ${widget.request.symbol} 限额',
        caption: '代币、Spender、额度与解码后的调用在签名前完整显示。',
        stamp: 'GUARDED',
      ),
      primaryAction: intent == null
          ? null
          : MoneyCountdown(
              expiresAt: intent.expiresAt,
              clock: widget.clock,
              builder: (context, remaining) => LoopButton(
                key: const ValueKey<String>('approval-guard-sign'),
                label: remaining == Duration.zero
                    ? '事实已过期 · 重新准备'
                    : '确认授权（${moneyCountdownLabel(remaining)}）',
                primary: true,
                block: true,
                onPressed: _busy
                    ? null
                    : remaining == Duration.zero
                    ? () => setState(() => _intent = null)
                    : intent.canSignAt(_now)
                    ? () => unawaited(_sign(intent))
                    : null,
              ),
            ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('approval-guard-capability-block'),
            label: '授权当前不可用',
            reasonCode: sendCapabilityReason(ref),
          )
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LoopSurfaceCard(
              key: const ValueKey<String>('approval-guard-request'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('APPROVAL GUARD · REQUEST', style: LoopMono.label),
                  const SizedBox(height: 10),
                  LoopKeyValue(
                    label: '代币',
                    value: widget.request.symbol,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: 'Spender',
                    value: widget.request.spenderAddress,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: '网络',
                    value: 'BNB Smart Chain',
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ],
              ),
            ),
          ),
          const LoopNotice(
            key: ValueKey<String>('approval-guard-unlimited-warning'),
            icon: 'shield',
            tone: LoopNoticeTone.danger,
            title: '无限授权意味着持续动用全部余额',
            body:
                '获得无限额度的合约可以在任何时间转走这个代币的全部余额，直到你主动回收。'
                'LOOP 的默认是只授权本次需要的额度。',
          ),
          if (intent == null) ...<Widget>[
            const LoopLabel('限额授权（默认）'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LoopSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      key: const ValueKey<String>('approval-guard-amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      maxLength: TransferAmount.maxWireLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '授权额度（${widget.request.symbol}）',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '只授权本次交易需要的额度。',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            LoopButton(
              key: const ValueKey<String>('approval-guard-exact'),
              label: amount == null
                  ? '按限额授权'
                  : '按 ${amount.wire} ${widget.request.symbol} 限额授权',
              primary: true,
              block: true,
              onPressed: _busy || amount == null
                  ? null
                  : () => unawaited(
                      _prepare(LoopExactAllowanceRequest(amount.wire)),
                    ),
            ),
            const SizedBox(height: 10),
            LoopButton(
              key: const ValueKey<String>('approval-guard-unlimited'),
              label: '仍要无限授权',
              block: true,
              onPressed: _busy ? null : () => unawaited(_confirmUnlimited()),
            ),
          ] else ...<Widget>[
            const LoopLabel('解码后的调用'),
            _DecodedCallCard(intent: intent),
            MoneyIntentReviewCard(intent: intent, clock: widget.clock),
            if (intent.review.spender?.isUnlimited ?? false)
              const LoopNotice(
                key: ValueKey<String>('approval-guard-unlimited-confirmed'),
                icon: 'warn',
                tone: LoopNoticeTone.danger,
                title: '这是一次无限额度授权',
                body:
                    '你已二次确认。签名后该 Spender 可持续动用这个代币的全部余额，'
                    '离开对方界面后权限依然有效，直到你在授权盘点里回收。',
              ),
            LoopButton(
              key: const ValueKey<String>('approval-guard-restart'),
              label: '改回限额授权',
              block: true,
              onPressed: _busy ? null : () => setState(() => _intent = null),
            ),
          ],
          if (MoneyPolicyNotice.covers(_failure))
            MoneyPolicyNotice(
              blockKey: 'approval-guard-permission',
              failure: _failure!,
              onOpenSecurity: () => _open('/profile/security'),
            )
          // A prepare that never reached the server has not opened a wallet.
          // The guard pauses; it never says the approval failed.
          else if (MoneyOfflinePause.covers(_failure))
            const MoneyOfflinePause(
              blockKey: 'approval-guard-offline',
              pausedActions: <String>['准备授权', '签名'],
            )
          else if (_failure != null)
            LoopErrorState(
              key: const ValueKey<String>('approval-guard-error'),
              title: '授权没有准备成功',
              reason: loopChainFailureReason(_failure!.kind),
            ),
        ],
      ],
    );
  }

  /// The prototype's "仍要无限授权" path: a full explanation and an explicit
  /// second confirmation, which the server independently requires.
  Future<void> _confirmUnlimited() async {
    final accepted = await showLoopSheet<bool>(
      context,
      builder: (context) => Column(
        key: const ValueKey<String>('approval-unlimited-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('确认无限授权', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            '无限额度不会随时间或这笔交易结束而失效。'
            '该 Spender 之后可以在不再询问你的情况下转走这个代币的全部余额。'
            '只有你在授权盘点里发送一笔 approve(spender, 0) 才会收回。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('approval-unlimited-cancel'),
                label: '改用限额',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              LoopButton(
                key: const ValueKey<String>('approval-unlimited-accept'),
                label: '我了解，仍要无限授权',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (accepted ?? false) {
      await _prepare(const LoopUnlimitedAllowanceRequest());
    }
  }

  Future<void> _prepare(LoopAllowanceRequest allowance) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final intent = await ref
          .read(walletIntentsGatewayProvider)
          .prepareApproval(
            walletId: widget.request.walletId,
            assetId: widget.request.assetId,
            spenderAddress: widget.request.spenderAddress,
            allowance: allowance,
          );
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _busy = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = const LoopChainException(LoopChainFailureKind.unexpected);
        _busy = false;
      });
    }
  }

  Future<void> _sign(LoopWalletIntent intent) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await showMoneySignSheet(
      context,
      intent: intent,
      signer: ref.read(moneyActionSignerProvider),
      clock: widget.clock,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == null) return;
    if (outcome.opensResult) {
      _open('/wallet/tx/result?intentId=${intent.intentId}');
    }
  }
}

/// The decoded ERC-20 call, exactly as the server decoded the payload it built.
class _DecodedCallCard extends StatelessWidget {
  const _DecodedCallCard({required this.intent});

  final LoopWalletIntent intent;

  @override
  Widget build(BuildContext context) {
    final decoded = intent.review.decodedCall;
    if (decoded == null) {
      return const LoopUnavailableCard(
        key: ValueKey<String>('approval-decoded-unavailable'),
        label: '调用无法解码',
        reasonCode: 'SIGNING_PAYLOAD_UNAVAILABLE',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LoopSurfaceCard(
        key: const ValueKey<String>('approval-decoded-call'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopKeyValue(
              label: '函数',
              value: '${decoded.functionName.wireName}()',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              label: 'selector',
              value: decoded.selector,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            for (final entry in decoded.args.entries)
              LoopKeyValue(
                key: ValueKey<String>('approval-decoded-${entry.key}'),
                label: entry.key,
                value: entry.value,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            LoopKeyValue(
              label: '合约',
              value: intent.review.asset.address ?? '原生资产没有授权面',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// approvals
// ---------------------------------------------------------------------------

/// `approvals` · the inventory of live allowances for the active wallet.
///
/// Every row's allowance is a fresh `allowance()` read, not the indexed event:
/// the event only says a candidate exists. A row that cannot be read says so
/// and is never rendered as zero.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key, this.onBack, this.onNavigate, this.clock});

  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;
  final DateTime Function()? clock;

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  bool _busy = false;
  LoopChainException? _revokeFailure;

  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    // The approval inventory is a read: it stays available while the write
    // switch is closed, so it waits on its own adapter and nothing else.
    final blocked = moneyReadBlocks(ref.watch(approvalsGatewayProvider).mode);
    final walletId = watchActiveMoneyWalletId(ref, blocked: blocked);
    final state = walletId == null
        ? null
        : ref.watch(approvalsControllerProvider(walletId));
    if (!blocked &&
        walletId != null &&
        state != null &&
        state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(approvalsControllerProvider(walletId).notifier).load(),
          );
        }
      });
    }
    final inventory = state?.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('approvals-screen'),
      archetype: LoopPageArchetype.listing,
      title: '授权盘点',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('approvals-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET APPROVALS',
        heading: inventory == null
            ? '授权盘点'
            : '${inventory.summary.activeCount} 个有效授权',
        caption: inventory == null
            ? '有效额度来自当场重读的 allowance()，不是索引里的历史事件。'
            : '${inventory.summary.unlimitedCount} 个无限额度需要复核 · '
                  '观察于 ${loopRelativeTime(inventory.freshness.observedAt, now: widget.clock?.call())}',
        stamp: inventory == null
            ? null
            : '${inventory.summary.activeCount} ACTIVE',
      ),
      sections: <Widget>[
        if (blocked)
          const LoopUnavailableCard(
            key: ValueKey<String>('approvals-capability-block'),
            label: '授权盘点当前不可用',
            reasonCode: 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
          )
        else if (walletId == null || state == null || !state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'approvals',
            phase: state?.phase ?? LoopChainViewPhase.loading,
            failureKind: state?.failureKind,
            emptyMessage: '这个钱包没有有效授权',
            emptyReason: '当前额度为 0 的授权不会列出。',
            onRetry: walletId == null
                ? null
                : () => unawaited(
                    ref
                        .read(approvalsControllerProvider(walletId).notifier)
                        .reload(),
                  ),
          )
        else ...<Widget>[
          if (MoneyPolicyNotice.covers(_revokeFailure))
            MoneyPolicyNotice(
              blockKey: 'approvals-revoke-permission',
              failure: _revokeFailure!,
              onOpenSecurity: () => _open('/profile/security'),
            )
          // The inventory above still renders: only the revoke prepare went
          // offline, and it opened no wallet, so the row list stays readable.
          else if (MoneyOfflinePause.covers(_revokeFailure))
            const MoneyOfflinePause(
              blockKey: 'approvals-revoke-offline',
              pausedActions: <String>['回收授权', '改额度', '签名'],
            )
          else if (_revokeFailure != null)
            LoopErrorState(
              key: const ValueKey<String>('approvals-revoke-error'),
              title: '回收没有准备成功',
              reason: loopChainFailureReason(_revokeFailure!.kind),
            ),
          const LoopLabel('按额度排序'),
          if (inventory!.items.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('approvals-empty'),
              message: '这个钱包没有有效授权',
              reason: '当前额度为 0 的授权不会列出；读不到的行会单独说明。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final row in inventory.items) _approvalRow(row, walletId),
              ],
            ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('approvals-freshness'),
            text:
                '授权记录自区块 '
                '${inventory.freshness.approvalCoverageFromBlockNumber} 起 · '
                '索引高度 ${inventory.freshness.indexerBlockNumber} / 链头 '
                '${inventory.freshness.headBlockNumber} · 观察于 '
                '${loopRelativeTime(inventory.freshness.observedAt, now: widget.clock?.call())}',
          ),
          const LoopNotice(
            key: ValueKey<String>('approvals-source-notice'),
            title: '数据出处',
            body:
                '候选来自链上 Approval 事件，每一行的额度都是当场重读的 allowance()。'
                '覆盖起点以下的区块只索引了转账，更早授予的授权不会出现在这里。'
                '回收会发送一笔 approve(spender, 0) 交易并产生网络费。',
          ),
        ],
      ],
    );
  }

  LoopRecordRow _approvalRow(LoopApprovalRow row, String walletId) {
    final allowance = row.allowance;
    final String subtitle;
    final Widget badge;
    switch (allowance) {
      case LoopAllowanceUnavailable(reasonCode: final reasonCode):
        subtitle = loopReasonCodeText(reasonCode);
        badge = const LoopBadge('读不到', kind: LoopBadgeKind.down);
      case LoopAllowanceAvailable(
        isUnlimited: final unlimited,
        displayValue: final display,
        blockNumber: final blockNumber,
      ):
        subtitle =
            '${row.spender.checksumAddress} · '
            '${unlimited ? '无限额度' : '额度 $display'} · 区块 $blockNumber';
        badge = unlimited
            ? const LoopBadge('无限', kind: LoopBadgeKind.down)
            : const LoopBadge('限额');
    }
    return LoopRecordRow(
      key: ValueKey<String>('approval-${row.assetId}-${row.spender.address}'),
      title: row.symbol,
      subtitle: subtitle,
      trailingBadge: badge,
      onTap: _busy ? null : () => unawaited(_openActions(row, walletId)),
    );
  }

  Future<void> _openActions(LoopApprovalRow row, String walletId) async {
    final action = await showLoopSheet<String>(
      context,
      builder: (context) => Column(
        key: const ValueKey<String>('approval-actions-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${row.symbol} · ${row.spender.checksumAddress}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            loopReasonCodeText(row.riskFacts.reasonCode),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 16),
          LoopButton(
            key: const ValueKey<String>('approval-action-limit'),
            label: '改为限额授权',
            block: true,
            onPressed: () => Navigator.of(context).pop('limit'),
          ),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('approval-action-revoke'),
            label: '回收授权（approve 0）',
            primary: true,
            block: true,
            onPressed: () => Navigator.of(context).pop('revoke'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'limit') {
      _open(
        '/wallet/approval-guard',
        extra: ApprovalGuardRequest(
          walletId: walletId,
          assetId: row.assetId,
          symbol: row.symbol,
          spenderAddress: row.spender.checksumAddress,
        ),
      );
      return;
    }
    await _revoke(row, walletId);
  }

  Future<void> _revoke(LoopApprovalRow row, String walletId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _revokeFailure = null;
    });
    try {
      final intent = await ref
          .read(walletIntentsGatewayProvider)
          .prepareRevoke(
            walletId: walletId,
            assetId: row.assetId,
            spenderAddress: row.spender.address,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await showMoneySignSheet(
        context,
        intent: intent,
        signer: ref.read(moneyActionSignerProvider),
        clock: widget.clock,
      );
      if (!mounted || outcome == null) return;
      if (outcome.opensResult) {
        _open('/wallet/tx/result?intentId=${intent.intentId}');
      }
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _revokeFailure = failure;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _revokeFailure = const LoopChainException(
          LoopChainFailureKind.unexpected,
        );
        _busy = false;
      });
    }
  }
}
