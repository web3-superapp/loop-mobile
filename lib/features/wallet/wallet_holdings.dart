import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';

/// What the account holds, as 钱包 and 我 both list it (S334 · decision
/// 0263): the main chain's rows that are not zero, the Launch chain's BNB
/// and USD1 (decision 0038: never added to the net worth) and the MEME v2
/// tokens, in the 「代币」 order ([walletSortTokenEntries]); and the project
/// NFTs, drawn as [launch2]'s picture cards.
@immutable
final class WalletHoldings {
  const WalletHoldings({
    required this.tokens,
    required this.nfts,
    required this.unreadCount,
  });

  /// Every token row, sorted. A row whose balance was not read stays in the
  /// list with its reason (it is never a zero) and is counted in
  /// [unreadCount].
  final List<WalletTokenEntry> tokens;

  /// The project NFT cards (S273 · decision 0232).
  final List<Widget> nfts;

  /// Rows in [tokens] whose balance nobody read.
  final int unreadCount;

  /// The rows that are holdings: read, not zero, plus every NFT card.
  int get heldCount => tokens.length - unreadCount + nfts.length;

  /// Nothing listed at all, not even an unread row.
  bool get isEmpty => tokens.isEmpty && nfts.isEmpty;
}

/// Builds [WalletHoldings] from the balances read and the MEME v2 positions.
///
/// [balances] is `null` while the main read has no value (loading, failed,
/// chain closed): the MEME v2 rows still stand on their own. [mainRow] draws
/// one main-chain row; the two pages differ only in where a row opens.
WalletHoldings walletHoldings({
  required LoopWalletBalances? balances,
  required Launch2WalletEntries launch2,
  required bool hidden,
  required Widget Function(LoopAssetBalanceRow row) mainRow,
}) {
  final launch = balances?.launchChain;
  final launchNative = launch?.nativeBalance;
  final launchUsd1 = launch?.usd1;
  var unread = 0;
  final entries = <WalletTokenEntry>[
    if (balances != null)
      for (final row in balances.balances)
        if (!walletRowIsZero(row))
          (
            valueUsd: switch (row.valuation) {
              LoopValuationAvailable(valueUsd: final value) => value,
              LoopValuationUnavailable() => null,
            },
            quantity: switch (row.balance) {
              LoopBalanceAvailable(displayBalance: final value) => value,
              _ => Decimal.zero,
            },
            row: mainRow(row),
          ),
    // Decision 0038: the Launch rows exist only when the backend published
    // a Launch slot. Their figures are never added to the total or to the
    // net worth.
    if (launch != null && launchNative != null)
      if (launchNative.displayBalance > Decimal.zero)
        (
          valueUsd: null,
          quantity: launchNative.displayBalance,
          row: walletLaunchNativeRow(launch, launchNative, hidden: hidden),
        ),
    // A USD1 nobody read is not a zero: its row stays with its reason.
    if (launch != null)
      if (launchUsd1 == null ||
          walletLaunchUsd1Figure(launchUsd1.balance) > Decimal.zero)
        (
          valueUsd: null,
          quantity: launchUsd1 == null
              ? Decimal.zero
              : walletLaunchUsd1Figure(launchUsd1.balance),
          row: walletLaunchUsd1Row(launch, hidden: hidden),
        ),
    for (final entry in launch2.tokens)
      (valueUsd: entry.valueUsd1, quantity: entry.quantity, row: entry.row),
  ];
  if (balances != null) {
    unread += balances.balances
        .where((row) => row.balance is LoopBalanceUnavailable)
        .length;
  }
  if (launch != null && launchUsd1 == null) unread += 1;
  return WalletHoldings(
    tokens: walletSortTokenEntries(entries),
    nfts: launch2.nfts,
    unreadCount: unread,
  );
}
