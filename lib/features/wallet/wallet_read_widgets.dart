import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/wallet_provisioning_controller.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Whether the wallet pages must stop at the capability gate.
bool walletCapabilityBlocks(
  LoopChainGatewayMode mode,
  LoopCapabilityProjection walletRead,
  LoopCapabilityProjection bscRead,
) =>
    mode != LoopChainGatewayMode.preview &&
    (!walletRead.isAvailable || !bscRead.isAvailable);

/// Builds one balance row.
///
/// The five balance meanings are never derived from one another, and a row
/// whose chain read failed renders its reason — "read failed" and "holds none"
/// are different facts.
LoopRecordRow walletBalanceRow(
  LoopAssetBalanceRow row, {
  VoidCallback? onTap,
  DateTime? now,
  String? miningText,
}) {
  final balance = row.balance;
  final valuation = row.valuation;

  final String? trailing;
  final String? caption;
  Widget? badge;
  switch (balance) {
    case LoopBalanceUnavailable():
      trailing = null;
      caption = null;
      // "read failed" is not "holds none": the row states it, never `0`.
      badge = const LoopBadge('读不到', kind: LoopBadgeKind.down);
    case LoopBalanceAvailable(displayBalance: final displayBalance):
      trailing = loopFormatDecimal(displayBalance);
      caption = switch (valuation) {
        LoopValuationAvailable(valueUsd: final valueUsd) => loopFormatUsd(
          valueUsd,
        ),
        LoopValuationUnavailable() => null,
      };
      if (valuation is LoopValuationAvailable && valuation.isProxied) {
        badge = const LoopBadge('以 WBNB 计价');
      }
  }

  final subtitleParts = <String>[
    row.name,
    switch (balance) {
      LoopBalanceUnavailable(reasonCode: final reasonCode) =>
        loopReasonCodeText(reasonCode),
      LoopBalanceAvailable(spendableBalance: final spendable) =>
        '可动用 ${loopFormatDecimal(spendable)}',
    },
    switch (row.pending) {
      LoopPendingUnavailable(reasonCode: final reasonCode) =>
        loopReasonCodeText(reasonCode),
      LoopPendingAvailable(value: final value) =>
        value == Decimal.zero ? '' : '待确认 ${loopFormatDecimal(value)}',
    },
    if (row.crossCheck.isMisaligned) '数据源尚未对齐',
    // The prototype's asset row carries the holding's mining power beside the
    // balance; the caller hands whatever the snapshot said, including its own
    // dash. This row never derives it.
    ?miningText,
  ].where((part) => part.isNotEmpty).toList(growable: false);

  return LoopRecordRow(
    key: ValueKey<String>('wallet-balance-${row.assetId}'),
    onTap: onTap,
    leading: LoopTokenLogo(
      assetSymbol: row.symbol,
      logoUrl: row.logoUrl,
      fallbackMonogram: row.symbol,
    ),
    title: row.symbol,
    subtitle: subtitleParts.join(' · '),
    subtitleMaxLines: miningText == null ? 1 : 3,
    trailing: trailing,
    trailingCaption: caption,
    trailingBadge: badge,
    semanticLabel:
        '${row.symbol}，'
        '${trailing == null ? '余额读不到' : '余额 $trailing'}'
        '${caption == null ? '' : '，估值 $caption'}',
  );
}

/// One indexed transfer, as both the history tape and the asset page list it.
///
/// The prototype heads every activity row with a circular glyph badge —
/// incoming, outgoing, claim — and the app's rows had no leading column at all
/// (visual audit item 7). Direction decides the glyph and its ground; nothing
/// else about the row changed.
LoopRecordRow walletActivityRow(
  LoopWalletActivityEntry entry, {
  DateTime? now,
  VoidCallback? onTap,
}) {
  final incoming = entry.direction == LoopTransferDirection.incoming;
  return LoopRecordRow(
    key: ValueKey<String>('tx-entry-${entry.entryId}'),
    onTap: onTap,
    leading: LoopRowIcon(
      icon: switch (entry.direction) {
        LoopTransferDirection.incoming => 'arrow-down',
        LoopTransferDirection.outgoing => 'arrow-up',
        LoopTransferDirection.self => 'shuffle',
      },
      tone: incoming ? LoopRowIconTone.accent : LoopRowIconTone.neutral,
    ),
    title:
        '${switch (entry.direction) {
          LoopTransferDirection.incoming => '收到',
          LoopTransferDirection.outgoing => '发出',
          LoopTransferDirection.self => '自转',
        }} ${entry.symbol}',
    subtitle: <String>[
      loopConfirmationLabel(entry.status),
      if (entry.confirmations != null)
        '${loopGroupedFigure(entry.confirmations.toString())} 确认',
      '区块 ${loopGroupedFigure(entry.blockNumber.toString())}',
      '对方 ${loopTruncatedAddress(entry.counterpartyAddress)}',
      loopRelativeTime(entry.observedAt, now: now),
    ].join(' · '),
    // Five facts beside a figure column: the line ended at
    // 「已确认 · 17 确认 · 区块 122235831 · 9 …」, losing the counterparty and
    // the stamp.
    subtitleMaxLines: 3,
    trailing: loopFormatDecimal(entry.displayValue),
    trailingCaptionUp: incoming,
    trailingCaption: loopTruncatedAddress(entry.transactionHash),
    trailingBadge: entry.status == LoopConfirmationStatus.reorged
        ? const LoopBadge('已回滚', kind: LoopBadgeKind.down)
        : null,
  );
}

/// The snapshot footer every balance block carries: all figures come from one
/// block height, observed at one moment.
class WalletSnapshotFooter extends StatelessWidget {
  const WalletSnapshotFooter({required this.snapshot, super.key, this.now});

  final LoopBalanceSnapshot snapshot;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return LoopProvenanceFooter(
      key: const ValueKey<String>('wallet-snapshot-footer'),
      text:
          '区块 ${loopGroupedFigure(snapshot.blockNumber.toString())} · '
          '${loopGroupedFigure(snapshot.confirmations.toString())} 确认 · '
          '观察于 ${loopRelativeTime(snapshot.observedAt, now: now)}',
    );
  }
}

/// The net-worth card. It always states that this is not a spendable balance,
/// and a `partial` total says how many rows could not be valued.
class WalletNetWorthCard extends StatelessWidget {
  const WalletNetWorthCard({
    required this.netWorth,
    super.key,
    this.now,
    this.compact = false,
  });

  final LoopNetWorth netWorth;
  final DateTime? now;

  /// Drops the label and the figure, keeping the badges and the provenance.
  ///
  /// The net-worth page heads itself with the total, so the card under it was
  /// the same figure a second time in a second type size (audit §A.2). What
  /// the card alone carries — 不是可用余额, the partial count, the quality mark
  /// and the source — stays, because the heading cannot say any of it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    switch (netWorth) {
      case LoopNetWorthUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('wallet-networth-unavailable'),
          label: '净值不可用',
          reasonCode: reasonCode,
        );
      case final LoopNetWorthValued valued:
        final marker = loopFactQualityMarker(valued.quality);
        // Compact is a strip, not a card: a card with a badge and one line in
        // it read as a block that had lost its figure.
        if (compact) {
          return Padding(
            key: const ValueKey<String>('wallet-networth-card'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    if (valued.partial)
                      LoopBadge(
                        '部分估值 · ${valued.unavailableCount} 项无价格',
                        key: const ValueKey<String>('wallet-networth-partial'),
                        kind: LoopBadgeKind.down,
                      ),
                    if (marker != null) LoopBadge(marker),
                    const LoopBadge(
                      '不是可用余额',
                      key: ValueKey<String>('wallet-networth-not-spendable'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  <String>[
                    '来源 ${loopFactSourceLabel(valued.priceSource)}',
                    '观察于 ${loopRelativeTime(valued.asOf, now: now)}',
                    if (valued.partial) '只是已估值资产的合计，不是总资产',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          );
        }
        return LoopSurfaceCard(
          key: const ValueKey<String>('wallet-networth-card'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('净值（${valued.valuationCurrency}）', style: LoopMono.label),
              const SizedBox(height: 6),
              Text(loopFormatUsd(valued.valueUsd), style: LoopMono.display),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (valued.partial)
                    LoopBadge(
                      '部分估值 · ${valued.unavailableCount} 项无价格',
                      key: const ValueKey<String>('wallet-networth-partial'),
                      kind: LoopBadgeKind.down,
                    ),
                  if (marker != null) LoopBadge(marker),
                  // The wire pins `isSpendable` to false; the copy says so.
                  const LoopBadge(
                    '不是可用余额',
                    key: ValueKey<String>('wallet-networth-not-spendable'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                <String>[
                  '来源 ${loopFactSourceLabel(valued.priceSource)}',
                  '观察于 ${loopRelativeTime(valued.asOf, now: now)}',
                  if (valued.partial) '只是已估值资产的合计，不是总资产',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        );
    }
  }
}

/// The wallet page's Launch chain block (loop-api decision 0038).
///
/// It exists only when the backend published a `launchChain` — that is, only
/// while the Launch slot differs from the primary chain. It holds exactly one
/// native balance read with one `eth_getBalance`: no registry, no ERC-20 row,
/// no pending amount, no valuation and no cross-check, so nothing here may be
/// added to the wallet's net worth or read as a spendable main-chain figure.
/// A failed read renders the server's own reason and never a `0`.
class WalletLaunchChainCard extends StatelessWidget {
  const WalletLaunchChainCard({required this.launchChain, super.key});

  final LoopLaunchChainBalance launchChain;

  @override
  Widget build(BuildContext context) {
    final native = launchChain.nativeBalance;
    return Column(
      key: const ValueKey<String>('wallet-launch-chain'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (native == null)
          LoopUnavailableCard(
            key: const ValueKey<String>('wallet-launch-chain-unavailable'),
            label: '${launchChain.name}余额不可用',
            reasonCode: launchChain.reasonCode ?? 'CAPABILITY_UNAVAILABLE',
          )
        else ...<Widget>[
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-launch-chain-row'),
                title: native.symbol,
                subtitle:
                    '${launchChain.name} · '
                    '可动用 ${loopFormatDecimal(native.spendableBalance)} · '
                    '手续费保留 ${loopFormatDecimal(native.gasReserve)}',
                // Chain, spendable and reserve beside a figure column: on a
                // phone the line ended at 「手续费保留 0…」.
                subtitleMaxLines: 2,
                trailing: loopFormatDecimal(native.displayBalance),
                trailingBadge: launchChain.isTestnet
                    ? const LoopTestnetBadge()
                    : null,
                semanticLabel:
                    '${launchChain.name} ${native.symbol} '
                    '${loopFormatDecimal(native.displayBalance)}',
              ),
            ],
          ),
          WalletSnapshotFooter(
            key: const ValueKey<String>('wallet-launch-chain-snapshot'),
            snapshot: native.snapshot,
          ),
        ],
        LoopTestnetNotice(visible: launchChain.isTestnet),
      ],
    );
  }
}

/// The "this account owns no wallet yet" block.
///
/// It is a read result, not a missing read: a page may only build it after
/// `GET /v2/wallets` answered `ready` with an empty list. Every other outcome
/// — loading, error, offline, unavailable, permission — belongs to
/// [LoopChainStateBlock], which says the list was not read rather than that
/// there is nothing in it.
///
/// The button calls the one creation path the product has. It is disabled
/// while any attempt is in flight, including the automatic one made at login,
/// and a failed attempt renders the provider's own sentence.
class WalletCreationBlock extends ConsumerWidget {
  const WalletCreationBlock({required this.keyPrefix, super.key});

  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(loopSessionProvider);
    final provisioning = ref.watch(loopWalletProvisioningProvider);
    final canCreate =
        session.canUseProviderBackedFeatures && session.account != null;

    if (!canCreate) {
      return LoopEmpty(
        key: ValueKey<String>('$keyPrefix-no-wallet'),
        message: '这个账号还没有钱包',
        reason: session.isPreview
            ? '开发预览不会创建真实钱包，也不会调用 Privy。'
            : '当前会话未完成验证，暂时不能创建钱包。重新登录后可以再试。',
      );
    }

    final reason = switch (provisioning.stage) {
      LoopWalletProvisioningStage.creating => '正在向 Privy 申请嵌入式钱包，完成后清单会自动刷新。',
      LoopWalletProvisioningStage.failed =>
        '上一次创建没有完成：${provisioning.errorMessage ?? '原因未知'}'
            ' 登录状态没有变化，可以再试一次。',
      _ => 'LOOP 会为这个账号创建一个 Privy 嵌入式钱包。地址是公开的链上事实，不是账号标识。',
    };

    return LoopEmpty(
      key: ValueKey<String>('$keyPrefix-no-wallet'),
      message: '这个账号还没有钱包',
      reason: reason,
      action: LoopButton(
        key: ValueKey<String>('$keyPrefix-create-wallet'),
        label: provisioning.isCreating ? '创建中…' : '创建钱包',
        primary: true,
        onPressed: provisioning.isCreating
            ? null
            : () => unawaited(_create(context, ref)),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await ref
        .read(loopWalletProvisioningProvider.notifier)
        .createWallet();
    if (!context.mounted || !created) return;
    LoopToast.show(context, message: '钱包已创建', kind: LoopToastKind.ok);
  }
}
