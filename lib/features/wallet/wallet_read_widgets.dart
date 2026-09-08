import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

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
  ].where((part) => part.isNotEmpty).toList(growable: false);

  return LoopRecordRow(
    key: ValueKey<String>('wallet-balance-${row.assetId}'),
    onTap: onTap,
    leading: LoopTokenLogo(
      assetSymbol: row.symbol,
      fallbackMonogram: row.symbol,
    ),
    title: row.symbol,
    subtitle: subtitleParts.join(' · '),
    trailing: trailing,
    trailingCaption: caption,
    trailingBadge: badge,
    semanticLabel:
        '${row.symbol}，'
        '${trailing == null ? '余额读不到' : '余额 $trailing'}'
        '${caption == null ? '' : '，估值 $caption'}',
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
          '区块 ${snapshot.blockNumber} · '
          '${snapshot.confirmations} 确认 · '
          '观察于 ${loopRelativeTime(snapshot.observedAt, now: now)}',
    );
  }
}

/// The net-worth card. It always states that this is not a spendable balance,
/// and a `partial` total says how many rows could not be valued.
class WalletNetWorthCard extends StatelessWidget {
  const WalletNetWorthCard({required this.netWorth, super.key, this.now});

  final LoopNetWorth netWorth;
  final DateTime? now;

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
