import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_settlement.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// `launch-detail` · 我的份额: claim and refund (decision 0103).
///
/// The step comes from [launchSettlementView]; the one action prepares a
/// server intent after the capability was re-read (decision 0099), and the
/// intent goes through the Launch signing exit exactly as a purchase does.
/// After the broadcast the block states the server's intent state as it
/// reads it back, and re-reads the position and the history once it settles.
class LaunchSettlementSection extends ConsumerStatefulWidget {
  const LaunchSettlementSection({
    required this.launchId,
    required this.detail,
    super.key,
    this.clock,
  });

  final String? launchId;
  final LaunchDetail detail;
  final DateTime Function()? clock;

  @override
  ConsumerState<LaunchSettlementSection> createState() =>
      _LaunchSettlementSectionState();
}

class _LaunchSettlementSectionState
    extends ConsumerState<LaunchSettlementSection> {
  bool _checkingCapability = false;

  void _reread({bool detail = true}) {
    final launchId = widget.launchId;
    if (launchId == null) return;
    if (detail) {
      unawaited(ref.read(launchDetailControllerProvider.notifier).reload());
    }
    final holders = ref.read(launchHoldersControllerProvider);
    unawaited(
      holders.isReady
          ? ref.read(launchHoldersControllerProvider.notifier).reload()
          : ref.read(launchHoldersControllerProvider.notifier).open(launchId),
    );
    final history = ref.read(launchHistoryControllerProvider);
    unawaited(
      history.isReady
          ? ref.read(launchHistoryControllerProvider.notifier).reload()
          : ref.read(launchHistoryControllerProvider.notifier).open(launchId),
    );
  }

  Future<void> _act(LaunchSettlementView view) async {
    final launchId = widget.launchId;
    final kind = view.kind;
    final walletId = view.position?.walletId;
    if (launchId == null || kind == null || walletId == null) return;
    if (_checkingCapability) return;
    // Decision 0099: the capability is re-read before anything is prepared
    // or signed; a gate that closed meanwhile is drawn by the page itself.
    setState(() => _checkingCapability = true);
    await loopRefreshCapabilitiesBeforeSigning(ref);
    if (!mounted) return;
    setState(() => _checkingCapability = false);
    final capability = ref.read(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    if (launchCapabilityBlocks(capability) || capability.evidencePending) {
      return;
    }
    final controller = ref.read(launchSettlementControllerProvider.notifier);
    final prepared = await controller.prepare(
      launchId: launchId,
      walletId: walletId,
      kind: kind,
      snapshot: view.snapshot,
    );
    if (!mounted) return;
    if (prepared == null) {
      final code = ref
          .read(launchSettlementControllerProvider)
          .refusalReasonCode;
      if (launchSettlementRereadCodes.contains(code)) _reread();
      return;
    }
    String? fromAddress;
    final directory = ref.read(walletDirectoryControllerProvider).value;
    for (final wallet in directory?.wallets ?? const <LoopWalletAccount>[]) {
      if (wallet.walletId == prepared.intent.walletId) {
        fromAddress = wallet.address;
      }
    }
    final outcome = await showLaunchSignSheet(
      context,
      prepared: prepared,
      signer: ref.read(launchPurchaseSignerProvider),
      fromAddress: fromAddress,
      ticker: widget.detail.launch.ticker,
      clock: widget.clock,
    );
    if (!mounted) return;
    if (outcome == null) {
      // Closed before the wallet was opened: nothing was signed.
      controller.reset();
      return;
    }
    controller.recordSignOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final holdersState = ref.watch(launchHoldersControllerProvider);
    final holders = holdersState.value;
    final view = launchSettlementView(
      onChain: widget.detail.launch.onChainState,
      position: holders?.myPosition,
      positionFailed:
          holders == null &&
          !holdersState.isReady &&
          holdersState.phase != LaunchViewPhase.loading,
    );
    final settlement = ref.watch(launchSettlementControllerProvider);
    // Once the server settles an intent, the position and the records are
    // re-read: a confirmed claim moves them, an expired one may have landed
    // late (S92a.6).
    ref.listen<LaunchIntentState?>(
      launchSettlementControllerProvider.select((state) => state.intent?.state),
      (previous, next) {
        if (previous == next) return;
        if (next == LaunchIntentState.confirmed ||
            next == LaunchIntentState.expired ||
            next == LaunchIntentState.reverted) {
          _reread();
        }
      },
    );
    if (view == null && settlement.kind == null) return const SizedBox.shrink();

    final kind = view?.kind;
    if (kind != null) {
      // The signing wallet's address is read from the wallet directory.
      final directory = ref.watch(walletDirectoryControllerProvider);
      if (directory.phase == LoopChainViewPhase.loading &&
          directory.value == null) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).load(),
            );
          }
        });
      }
    }
    final evidenceClosed =
        launchCapabilityBlocks(capability) || capability.evidencePending;
    // A named refusal stands over the blocks the page read when it came; a
    // newer reading re-opens the action (decision 0103).
    final refusalStands =
        settlement.refusalReasonCode != null &&
        view != null &&
        settlement.refusalSnapshot == view.snapshot;
    final hideForRefusal =
        refusalStands &&
        settlement.refusalReasonCode == 'LAUNCH_NOT_PARTICIPANT';

    final children = <Widget>[const LoopLabel('我的份额')];
    if (view != null) {
      children.add(_stageBlock(view, hideAction: hideForRefusal));
      if (kind != null && !hideForRefusal) {
        final enabled =
            !view.paused &&
            !evidenceClosed &&
            !_checkingCapability &&
            !settlement.busy &&
            !settlement.locked &&
            !refusalStands &&
            widget.launchId != null;
        final label = launchSettlementActionLabel(view);
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              key: ValueKey<String>(
                kind == LaunchIntentKind.claim
                    ? 'launch-settlement-claim'
                    : 'launch-settlement-refund',
              ),
              label: _checkingCapability
                  ? moneyCapabilityCheckingLabel
                  : settlement.busy
                  ? '正在准备'
                  : label,
              primary: true,
              block: true,
              onPressed: enabled ? () => unawaited(_act(view)) : null,
              semanticLabel: enabled ? label : '$label，当前不可执行',
            ),
          ),
        );
        if (view.paused) {
          children.add(
            const LoopNotice(
              key: ValueKey<String>('launch-settlement-paused'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: '合约已暂停',
              body: '暂停期间领取与退款都会被合约拒绝，按钮已停用。恢复后这里会重新开放。',
            ),
          );
        } else if (evidenceClosed) {
          children.add(
            LoopNotice(
              key: const ValueKey<String>('launch-settlement-evidence'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: '暂不可执行',
              body:
                  '${launchReasonCodeText(capability.evidenceReasonCode ?? capability.reasonCode)}'
                  '本页因此不构造任何交易，也不打开签名。',
            ),
          );
        }
      }
    }
    final progress = _progressBlock(settlement);
    if (progress != null) children.add(progress);
    return Column(
      key: const ValueKey<String>('launch-settlement'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _stageBlock(LaunchSettlementView view, {required bool hideAction}) {
    final position = view.position;
    final block = position == null
        ? null
        : '读自区块 ${loopGroupedFigure(position.snapshotBlockNumber)}';
    Widget row({
      required String key,
      required String title,
      required String subtitle,
      String? badge,
      bool done = false,
    }) => LoopRecordGroup(
      key: ValueKey<String>(key),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: 3,
          trailingBadge: badge == null
              ? null
              : LoopBadge(
                  badge,
                  kind: done ? LoopBadgeKind.launch : LoopBadgeKind.mute,
                ),
          chevron: false,
        ),
      ],
    );
    LoopNotice notice(String key, String title, String body) => LoopNotice(
      key: ValueKey<String>(key),
      icon: 'clock',
      title: title,
      body: body,
    );
    switch (view.stage) {
      case LaunchSettlementStage.awaitingFinalize:
        return notice(
          'launch-settlement-awaiting-finalize',
          '等待最终化',
          '销售已结束，等待最终化。最终化后，募集达到软顶则按释放计划开放领取，'
              '未达到则开放退款；参与过的钱包会在这里看到对应的按钮。',
        );
      case LaunchSettlementStage.awaitingTge:
        return notice(
          'launch-settlement-awaiting-tge',
          '等待 TGE',
          '销售成功，份额已冻结'
              '${position == null || !_positive(position.entitledTokens) ? '' : '（${launchUnitsFigure(position.entitledTokens)} 代币）'}。'
              'TGE 到达且流动性池上线后开放领取。',
        );
      case LaunchSettlementStage.refundPending:
        return notice(
          'launch-settlement-refund-pending',
          '退款准备中',
          '销售没有成功。退款负债冻结后开放退款，参与过的钱包会在这里看到按钮。',
        );
      case LaunchSettlementStage.positionReading:
        return row(
          key: 'launch-settlement-reading',
          title: '正在读取我的份额',
          subtitle: '读到持仓之前不显示领取或退款按钮。',
        );
      case LaunchSettlementStage.positionUnread:
        return LoopNotice(
          key: const ValueKey<String>('launch-settlement-unread'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '我的份额暂时读不到',
          body:
              '${view.reasonCode == null ? '这次没有读到当前钱包的持仓。' : launchReasonCodeText(view.reasonCode)}'
              '读到之前不显示领取或退款按钮，下拉可重新读取。',
        );
      case LaunchSettlementStage.claim:
        return row(
          key: 'launch-settlement-claimable',
          title: '可领取 ${launchUnitsFigure(position!.claimableTokens)} 代币',
          subtitle:
              '已领取 ${launchUnitsFigure(position.claimedTokens)} 代币 · $block\n'
              '领取由合约执行，代币直接到当前钱包。',
          badge: '可领取',
          done: true,
        );
      case LaunchSettlementStage.claimNothingYet:
        return row(
          key: 'launch-settlement-nothing-yet',
          title: '暂无可领取',
          subtitle:
              '份额 ${launchUnitsFigure(position!.entitledTokens)} 代币，'
              '按释放计划成熟后可领取 · $block',
        );
      case LaunchSettlementStage.claimedSoFar:
        return row(
          key: 'launch-settlement-claimed-so-far',
          title: '已领取 ${launchUnitsFigure(position!.claimedTokens)} 代币',
          subtitle: '当前没有可领取的部分，下一次释放后再来 · $block',
          badge: '已领取',
          done: true,
        );
      case LaunchSettlementStage.claimedAll:
        return row(
          key: 'launch-settlement-claimed-all',
          title: '已全部领取',
          subtitle:
              '累计领取 ${launchUnitsFigure(position!.claimedTokens)} 代币 · $block',
          badge: '已完成',
          done: true,
        );
      case LaunchSettlementStage.refund:
        return row(
          key: 'launch-settlement-refundable',
          title: '可退款 ${launchUsd1Label(position!.refundableUsd1)}',
          subtitle:
              '已退款 ${launchUsd1Label(position.refundedUsd1)} · $block\n'
              '退款由合约执行，一次退回全部，USD1 直接到当前钱包。',
          badge: '可退款',
          done: true,
        );
      case LaunchSettlementStage.refundedAll:
        return row(
          key: 'launch-settlement-refunded-all',
          title: '已全部退款',
          subtitle: '累计退回 ${launchUsd1Label(position!.refundedUsd1)} · $block',
          badge: '已完成',
          done: true,
        );
      case LaunchSettlementStage.refundClosed:
        return LoopNotice(
          key: const ValueKey<String>('launch-settlement-refund-closed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '退款窗口已关闭',
          body:
              '合约记录仍有 ${launchUsd1Label(position!.refundableUsd1)} 未退回，'
              '但退款窗口已经关闭，合约不再接受退款。',
        );
    }
  }

  static bool _positive(String raw) => BigInt.parse(raw) > BigInt.zero;

  Widget? _progressBlock(LaunchSettlementState settlement) {
    final kind = settlement.kind;
    if (kind == null) return null;
    final controller = ref.read(launchSettlementControllerProvider.notifier);
    if (settlement.busy) {
      return const LoopNotice(
        key: ValueKey<String>('launch-settlement-preparing'),
        icon: 'clock',
        title: '正在准备',
        body: '正在向服务端读取本次可操作的份额，读到后打开签名确认。',
      );
    }
    final refusal = settlement.refusalReasonCode;
    if (settlement.refusalKind != null) {
      return LoopNotice(
        key: ValueKey<String>('launch-settlement-refusal-${refusal ?? 'none'}'),
        icon: 'shield',
        tone: LoopNoticeTone.warn,
        title: launchSettlementRefusalTitle(refusal),
        body: launchSettlementRefusalText(
          kind,
          settlement.refusalKind,
          refusal,
        ),
      );
    }
    final signReason = settlement.signReasonCode;
    if (settlement.txHash == null &&
        settlement.signOutcomeStatus != null &&
        settlement.signOutcomeStatus != 'locked' &&
        signReason != null) {
      return LoopNotice(
        key: const ValueKey<String>('launch-settlement-sign-refused'),
        icon: 'shield',
        tone: LoopNoticeTone.warn,
        title: '没有签名',
        body: launchSignReasonTextFor(kind, signReason),
      );
    }
    if (settlement.signOutcomeStatus == null) return null;
    final intent = settlement.intent;
    if (intent == null) {
      // Broadcast, but the server has not recorded it (or the wallet's
      // outcome is unknown): never a result, and never a second signature.
      return Column(
        key: const ValueKey<String>('launch-settlement-locked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopNotice(
            icon: 'clock',
            tone: LoopNoticeTone.warn,
            title: settlement.txHash == null ? '已提交给钱包，结果未确认' : '已广播，服务端未记录',
            body: launchBroadcastText(
              LaunchSignOutcome(
                status: MoneySignStatus.values.byName(
                  settlement.signOutcomeStatus!,
                ),
                reasonCode: signReason ?? '',
                txHash: settlement.txHash,
              ),
              kind: kind,
            ),
          ),
          if (settlement.reportRetryable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LoopButton(
                key: const ValueKey<String>('launch-settlement-report-retry'),
                label: settlement.reporting ? '正在重新上报' : '重新上报',
                block: true,
                onPressed: settlement.reporting
                    ? null
                    : () => unawaited(controller.retryReport()),
              ),
            ),
        ],
      );
    }
    final text = launchSettlementProgressText(kind, intent);
    final confirmed = intent.state == LaunchIntentState.confirmed;
    return Column(
      key: ValueKey<String>('launch-settlement-state-${intent.state.wireName}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopNotice(
          icon: confirmed ? 'check' : 'clock',
          tone: confirmed || settlement.settled
              ? LoopNoticeTone.normal
              : LoopNoticeTone.warn,
          title: text.title,
          body: settlement.pollTimedOut
              ? '${text.body}还没有读到链上结果，可以稍后重新查询。'
              : text.body,
        ),
        if (settlement.pollTimedOut)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              key: const ValueKey<String>('launch-settlement-poll-resume'),
              label: '重新查询',
              block: true,
              onPressed: controller.resumePolling,
            ),
          ),
      ],
    );
  }
}
