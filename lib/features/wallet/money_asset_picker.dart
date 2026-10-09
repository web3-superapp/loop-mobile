import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

/// Whether [row] has anything that can leave the wallet: a read that worked
/// and a spendable amount above zero. A failed read is not zero and is not
/// "has a balance" either.
bool moneyRowHasSpendable(LoopAssetBalanceRow row) => switch (row.balance) {
  LoopBalanceAvailable(spendableBalance: final spendable) =>
    spendable > Decimal.zero,
  LoopBalanceUnavailable() => false,
};

/// Opens the asset chooser shared by 发送 and 兑换 (decision 0131).
///
/// Every row shows the balance it would spend from and the chosen row carries
/// a check, not a chevron: choosing is done in place, nothing opens. A search
/// line filters by symbol and name. With [requireBalance] (发送, the side of a
/// swap that pays), rows with nothing spendable are folded under one line
/// that says how many there are and cannot be chosen; a row whose chain read
/// failed stays in the list, says so, and cannot be chosen either. Returns
/// the chosen `assetId`, or null when the sheet was closed.
Future<String?> showMoneyAssetPicker(
  BuildContext context, {
  required LoopWalletBalances balances,
  required String rowKeyPrefix,
  String? selectedAssetId,
  bool requireBalance = true,
  String title = '选择资产',
}) => showLoopSheet<String>(
  context,
  builder: (context) => MoneyAssetPickerSheet(
    balances: balances,
    rowKeyPrefix: rowKeyPrefix,
    selectedAssetId: selectedAssetId,
    requireBalance: requireBalance,
    title: title,
  ),
);

/// The content of [showMoneyAssetPicker]; public so a test can pump it.
class MoneyAssetPickerSheet extends StatefulWidget {
  const MoneyAssetPickerSheet({
    required this.balances,
    required this.rowKeyPrefix,
    super.key,
    this.selectedAssetId,
    this.requireBalance = true,
    this.title = '选择资产',
  });

  final LoopWalletBalances balances;
  final String rowKeyPrefix;
  final String? selectedAssetId;
  final bool requireBalance;
  final String title;

  @override
  State<MoneyAssetPickerSheet> createState() => _MoneyAssetPickerSheetState();
}

class _MoneyAssetPickerSheetState extends State<MoneyAssetPickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(LoopAssetBalanceRow row) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return row.symbol.toLowerCase().contains(query) ||
        row.name.toLowerCase().contains(query);
  }

  LoopRecordRow _row(LoopAssetBalanceRow row, {required bool choosable}) {
    final balance = row.balance;
    return LoopRecordRow(
      key: ValueKey<String>('${widget.rowKeyPrefix}-${row.assetId}'),
      leading: LoopTokenLogo(
        assetSymbol: row.symbol,
        logoUrl: row.logoUrl,
        fallbackMonogram: row.symbol,
      ),
      title: row.symbol,
      subtitle: switch (balance) {
        LoopBalanceUnavailable(reasonCode: final reasonCode) =>
          loopReasonCodeText(reasonCode),
        LoopBalanceAvailable(spendableBalance: final spendable) =>
          '${row.name} · 可动用 ${loopFormatDecimal(spendable)}',
      },
      trailing: switch (balance) {
        LoopBalanceUnavailable() => null,
        LoopBalanceAvailable(displayBalance: final display) =>
          loopFormatDecimal(display),
      },
      trailingBadge: balance is LoopBalanceUnavailable
          ? const LoopBadge('读不到', kind: LoopBadgeKind.down)
          : null,
      selected: row.assetId == widget.selectedAssetId,
      chevron: false,
      onTap: choosable ? () => Navigator.of(context).pop(row.assetId) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.balances.balances.where(_matches).toList();
    final listed = <LoopAssetBalanceRow>[];
    final folded = <LoopAssetBalanceRow>[];
    for (final row in rows) {
      final empty =
          widget.requireBalance &&
          row.balance is LoopBalanceAvailable &&
          !moneyRowHasSpendable(row);
      (empty ? folded : listed).add(row);
    }
    bool choosable(LoopAssetBalanceRow row) =>
        widget.requireBalance ? moneyRowHasSpendable(row) : true;
    return Column(
      key: ValueKey<String>('${widget.rowKeyPrefix}-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(widget.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: ValueKey<String>('${widget.rowKeyPrefix}-search'),
            controller: _query,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索名称或代号',
              prefixIcon: Padding(
                padding: EdgeInsets.all(12),
                child: LoopIcon('search', size: 18, color: LoopColors.text3),
              ),
            ),
          ),
        ),
        if (listed.isEmpty && folded.isEmpty)
          LoopEmpty(
            key: ValueKey<String>('${widget.rowKeyPrefix}-none'),
            message: _query.text.trim().isEmpty ? '这个钱包还没有可读资产' : '没有匹配的资产',
          )
        else ...<Widget>[
          if (listed.isEmpty)
            LoopEmpty(
              key: ValueKey<String>('${widget.rowKeyPrefix}-none-spendable'),
              message: '没有可动用余额的资产',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final row in listed) _row(row, choosable: choosable(row)),
              ],
            ),
          if (folded.isNotEmpty)
            LoopDisclosure(
              key: ValueKey<String>('${widget.rowKeyPrefix}-zero'),
              summary: '余额为 0 的资产 · ${folded.length} 个',
              child: LoopRecordGroup(
                rows: <LoopRecordRow>[
                  for (final row in folded) _row(row, choosable: false),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
