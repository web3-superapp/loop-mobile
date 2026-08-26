import 'package:flutter/foundation.dart';

/// A labelled layout fixture. It is never a provider balance or asset record.
@immutable
final class WalletPreviewAsset {
  const WalletPreviewAsset._({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.value,
    required this.change,
    required this.networkLabel,
  });

  static const ethereum = WalletPreviewAsset._(
    symbol: 'ETH',
    name: 'Ethereum',
    amount: '4.82 ETH',
    value: r'$22,319.01',
    change: '+3.8%',
    networkLabel: 'Ethereum',
  );

  static const usdCoin = WalletPreviewAsset._(
    symbol: 'USDC',
    name: 'USD Coin',
    amount: '6,810.20 USDC',
    value: r'$6,810.20',
    change: '0.0%',
    networkLabel: 'Ethereum',
  );

  static const solana = WalletPreviewAsset._(
    symbol: 'SOL',
    name: 'Solana',
    amount: '13.44 SOL',
    value: r'$2,110.79',
    change: '-1.2%',
    networkLabel: 'Solana',
  );

  static const all = <WalletPreviewAsset>[ethereum, usdCoin, solana];

  final String symbol;
  final String name;
  final String amount;
  final String value;
  final String change;
  final String networkLabel;
}
