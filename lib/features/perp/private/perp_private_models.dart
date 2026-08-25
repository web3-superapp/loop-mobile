import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

enum PerpWalletBindingState { bound, unbound }

enum PerpAccountKind { master }

enum PerpCoin { btc, eth, sol }

enum PerpSourceDataset { config, account, positions, orders, fills, funding }

enum PerpMarginMode { crossAndIsolated, isolatedOnly }

enum PerpFactState { unavailable, available }

enum PerpPositionSide { long, short }

enum PerpLeverageMode { cross, isolated }

enum PerpPositionMode { oneWay }

enum PerpOrderSide { buy, sell }

enum PerpOrderType { limit }

enum PerpTimeInForce { gtc, alo, ioc }

enum PerpOrderStatus { open }

enum PerpFeeAsset { usdc }

enum PerpCoverageKind { recentWindow }

@immutable
final class PerpWalletBinding {
  factory PerpWalletBinding({
    required PerpWalletBindingState state,
    required String bindingVersion,
    required PerpAccountKind? accountKind,
    required DateTime? lastVerifiedAt,
  }) => PerpWalletBinding._(
    state,
    bindingVersion,
    accountKind,
    lastVerifiedAt?.toUtc(),
  );

  const PerpWalletBinding._(
    this.state,
    this.bindingVersion,
    this.accountKind,
    this.lastVerifiedAt,
  );

  final PerpWalletBindingState state;
  final String bindingVersion;
  final PerpAccountKind? accountKind;
  final DateTime? lastVerifiedAt;

  bool get isBound => state == PerpWalletBindingState.bound;
}

@immutable
final class PerpDataSource {
  factory PerpDataSource({
    required PerpSourceDataset dataset,
    required DateTime fetchedAt,
    required DateTime expiresAt,
  }) => PerpDataSource._(dataset, fetchedAt.toUtc(), expiresAt.toUtc());

  const PerpDataSource._(this.dataset, this.fetchedAt, this.expiresAt);

  static const provider = 'hyperliquid';
  static const network = 'testnet';
  static const market = 'core_perps';
  static const dex = '';

  final PerpSourceDataset dataset;
  final DateTime fetchedAt;
  final DateTime expiresAt;
}

@immutable
final class PerpDecimalFact {
  const PerpDecimalFact.unavailable()
    : state = PerpFactState.unavailable,
      value = null;

  const PerpDecimalFact.available(Decimal this.value)
    : state = PerpFactState.available;

  final PerpFactState state;
  final Decimal? value;

  bool get isAvailable => state == PerpFactState.available;
}

@immutable
final class PerpScope {
  factory PerpScope({required Iterable<PerpCoin> coins}) =>
      PerpScope._(List<PerpCoin>.unmodifiable(coins));

  const PerpScope._(this.coins);

  static const network = 'testnet';
  static const market = 'core_perps';
  static const dex = '';

  final List<PerpCoin> coins;
}

@immutable
final class PerpAssetConfig {
  const PerpAssetConfig({
    required this.coin,
    required this.sizeDecimals,
    required this.sizeIncrement,
    required this.maxLeverage,
    required this.marginMode,
    required this.minimumOrderNotionalUsdc,
  });

  final PerpCoin coin;
  final int sizeDecimals;
  final Decimal sizeIncrement;
  final Decimal maxLeverage;
  final PerpMarginMode marginMode;
  final PerpDecimalFact minimumOrderNotionalUsdc;
}

@immutable
final class PerpFees {
  const PerpFees({required this.makerRate, required this.takerRate});

  final PerpDecimalFact makerRate;
  final PerpDecimalFact takerRate;
}

@immutable
final class PerpCapabilities {
  const PerpCapabilities({
    required this.privateReadsAvailable,
    required this.tradingMutationsEnabled,
  });

  final bool privateReadsAvailable;
  final bool tradingMutationsEnabled;
}

@immutable
final class PerpConfig {
  factory PerpConfig({
    required PerpScope scope,
    required Iterable<PerpAssetConfig> assets,
    required PerpFees fees,
    required PerpCapabilities capabilities,
    required PerpDataSource source,
  }) => PerpConfig._(
    scope,
    List<PerpAssetConfig>.unmodifiable(assets),
    fees,
    capabilities,
    source,
  );

  const PerpConfig._(
    this.scope,
    this.assets,
    this.fees,
    this.capabilities,
    this.source,
  );

  final PerpScope scope;
  final List<PerpAssetConfig> assets;
  final PerpFees fees;
  final PerpCapabilities capabilities;
  final PerpDataSource source;
}

@immutable
final class PerpMarginSummary {
  const PerpMarginSummary({
    required this.accountValue,
    required this.totalMarginUsed,
    required this.totalNotionalPosition,
    required this.totalRawUsd,
  });

  final Decimal accountValue;
  final Decimal totalMarginUsed;
  final Decimal totalNotionalPosition;
  final Decimal totalRawUsd;
}

@immutable
final class PerpAccount {
  const PerpAccount({
    required this.marginSummary,
    required this.crossMarginSummary,
    required this.withdrawable,
    required this.crossMaintenanceMarginUsed,
    required this.source,
  });

  final PerpMarginSummary marginSummary;
  final PerpMarginSummary crossMarginSummary;
  final Decimal withdrawable;
  final Decimal? crossMaintenanceMarginUsed;
  final PerpDataSource source;
}

@immutable
final class PerpLeverage {
  const PerpLeverage({
    required this.mode,
    required this.value,
    required this.rawUsd,
  });

  final PerpLeverageMode mode;
  final Decimal value;
  final Decimal? rawUsd;
}

@immutable
final class PerpPosition {
  const PerpPosition({
    required this.coin,
    required this.side,
    required this.size,
    required this.entryPrice,
    required this.leverage,
    required this.liquidationPrice,
    required this.marginUsed,
    required this.positionValue,
    required this.returnOnEquity,
    required this.unrealizedPnl,
    required this.positionMode,
  });

  final PerpCoin coin;
  final PerpPositionSide side;
  final Decimal size;
  final Decimal? entryPrice;
  final PerpLeverage leverage;
  final Decimal? liquidationPrice;
  final Decimal marginUsed;
  final Decimal positionValue;
  final Decimal returnOnEquity;
  final Decimal unrealizedPnl;
  final PerpPositionMode positionMode;
}

@immutable
final class PerpOrder {
  factory PerpOrder({
    required String orderId,
    required String? clientOrderId,
    required PerpCoin coin,
    required PerpOrderSide side,
    required PerpOrderType orderType,
    required PerpTimeInForce timeInForce,
    required Decimal limitPrice,
    required Decimal originalSize,
    required Decimal remainingSize,
    required bool reduceOnly,
    required PerpOrderStatus status,
    required DateTime createdAt,
    required DateTime statusAt,
  }) => PerpOrder._(
    orderId,
    clientOrderId,
    coin,
    side,
    orderType,
    timeInForce,
    limitPrice,
    originalSize,
    remainingSize,
    reduceOnly,
    status,
    createdAt.toUtc(),
    statusAt.toUtc(),
  );

  const PerpOrder._(
    this.orderId,
    this.clientOrderId,
    this.coin,
    this.side,
    this.orderType,
    this.timeInForce,
    this.limitPrice,
    this.originalSize,
    this.remainingSize,
    this.reduceOnly,
    this.status,
    this.createdAt,
    this.statusAt,
  );

  final String orderId;
  final String? clientOrderId;
  final PerpCoin coin;
  final PerpOrderSide side;
  final PerpOrderType orderType;
  final PerpTimeInForce timeInForce;
  final Decimal limitPrice;
  final Decimal originalSize;
  final Decimal remainingSize;
  final bool reduceOnly;
  final PerpOrderStatus status;
  final DateTime createdAt;
  final DateTime statusAt;
}

@immutable
final class PerpFill {
  factory PerpFill({
    required String tradeId,
    required String orderId,
    required String transactionHash,
    required PerpCoin coin,
    required PerpOrderSide side,
    required Decimal price,
    required Decimal size,
    required Decimal startPosition,
    required Decimal closedPnl,
    required Decimal fee,
    required PerpFeeAsset feeAsset,
    required bool crossed,
    required DateTime filledAt,
  }) => PerpFill._(
    tradeId,
    orderId,
    transactionHash,
    coin,
    side,
    price,
    size,
    startPosition,
    closedPnl,
    fee,
    feeAsset,
    crossed,
    filledAt.toUtc(),
  );

  const PerpFill._(
    this.tradeId,
    this.orderId,
    this.transactionHash,
    this.coin,
    this.side,
    this.price,
    this.size,
    this.startPosition,
    this.closedPnl,
    this.fee,
    this.feeAsset,
    this.crossed,
    this.filledAt,
  );

  final String tradeId;
  final String orderId;
  final String transactionHash;
  final PerpCoin coin;
  final PerpOrderSide side;
  final Decimal price;
  final Decimal size;
  final Decimal startPosition;
  final Decimal closedPnl;
  final Decimal fee;
  final PerpFeeAsset feeAsset;
  final bool crossed;
  final DateTime filledAt;
}

@immutable
final class PerpFundingEntry {
  factory PerpFundingEntry({
    required String transactionHash,
    required PerpCoin coin,
    required Decimal fundingRate,
    required Decimal positionSize,
    required Decimal paymentUsdc,
    required DateTime settledAt,
  }) => PerpFundingEntry._(
    transactionHash,
    coin,
    fundingRate,
    positionSize,
    paymentUsdc,
    settledAt.toUtc(),
  );

  const PerpFundingEntry._(
    this.transactionHash,
    this.coin,
    this.fundingRate,
    this.positionSize,
    this.paymentUsdc,
    this.settledAt,
  );

  final String transactionHash;
  final PerpCoin coin;
  final Decimal fundingRate;
  final Decimal positionSize;
  final Decimal paymentUsdc;
  final DateTime settledAt;
}

@immutable
final class PerpRecentWindowCoverage {
  factory PerpRecentWindowCoverage({
    required PerpCoverageKind kind,
    required DateTime startedAt,
    required DateTime endedAt,
    required bool truncated,
  }) => PerpRecentWindowCoverage._(
    kind,
    startedAt.toUtc(),
    endedAt.toUtc(),
    truncated,
  );

  const PerpRecentWindowCoverage._(
    this.kind,
    this.startedAt,
    this.endedAt,
    this.truncated,
  );

  final PerpCoverageKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool truncated;
}

@immutable
final class PerpPage<T> {
  factory PerpPage({
    required Iterable<T> items,
    required PerpDataSource source,
    required String? nextCursor,
    required PerpRecentWindowCoverage? coverage,
  }) =>
      PerpPage<T>._(List<T>.unmodifiable(items), source, nextCursor, coverage);

  const PerpPage._(this.items, this.source, this.nextCursor, this.coverage);

  final List<T> items;
  final PerpDataSource source;
  final String? nextCursor;
  final PerpRecentWindowCoverage? coverage;
}
