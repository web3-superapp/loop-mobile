import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

/// Feature-facing port for the `wallet` read module.
///
/// Every method addresses a wallet by its opaque `walletId`. There is no
/// address-selected variant: the server refuses a client-chosen address.
abstract interface class WalletReadGateway {
  LoopChainGatewayMode get mode;

  Future<LoopWalletDirectory> loadWallets();

  /// Compare-and-set switch of the active wallet. [expectedActiveWalletId] is
  /// the value the page was rendered from — `null` when there was none.
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  });

  Future<LoopWalletBalances> loadBalances(String walletId);

  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  });

  Future<LoopWalletReceive> loadReceive(String walletId);
}

/// Production default: fails closed. A missing wallet fact is never a zero.
final class UnavailableWalletReadGateway implements WalletReadGateway {
  const UnavailableWalletReadGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopWalletDirectory> loadWallets() => _unavailable();

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) => _unavailable();

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) => _unavailable();

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => _unavailable();

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) => _unavailable();
}

final walletReadGatewayProvider = Provider<WalletReadGateway>(
  (ref) => const UnavailableWalletReadGateway(),
);

/// How one wallet-inventory sync ended (S306, decision 0246).
enum WalletInventorySyncStatus {
  /// The server re-read Privy and answered with the fresh list.
  synced,

  /// This server has no sync route; the ordinary re-read applies.
  unsupported,

  /// `503 PROVIDER_DISCONNECTED`: Privy could not be reached. The ordinary
  /// re-read applies and the page says the list will refresh later.
  providerDisconnected,

  /// Any other failure; the ordinary re-read applies.
  failed,
}

@immutable
final class WalletInventorySyncResult {
  const WalletInventorySyncResult(this.status, {this.directory});

  final WalletInventorySyncStatus status;

  /// The fresh list; present exactly when [status] is
  /// [WalletInventorySyncStatus.synced].
  final LoopWalletDirectory? directory;
}

/// Feature-facing port that asks the server to re-read the account's wallets
/// from Privy right after a bind or an unbind (S306, decision 0246).
///
/// A port of its own, like the net-worth history: a server that has not
/// deployed the route leaves the wallet list on its ordinary refresh.
abstract interface class WalletInventorySyncGateway {
  /// Never throws; every failure is a [WalletInventorySyncStatus].
  Future<WalletInventorySyncResult> requestSync();
}

final class UnavailableWalletInventorySyncGateway
    implements WalletInventorySyncGateway {
  const UnavailableWalletInventorySyncGateway();

  @override
  Future<WalletInventorySyncResult> requestSync() async =>
      const WalletInventorySyncResult(WalletInventorySyncStatus.unsupported);
}

final walletInventorySyncGatewayProvider = Provider<WalletInventorySyncGateway>(
  (ref) => const UnavailableWalletInventorySyncGateway(),
);

/// Feature-facing port for the wallet's net-worth history (decision 0188).
///
/// A port of its own rather than a sixth [WalletReadGateway] method: the
/// history is display information the first screen can do without, and a
/// server that has not deployed it yet must leave every balance untouched.
abstract interface class WalletNetWorthHistoryGateway {
  LoopChainGatewayMode get mode;

  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  );
}

/// Production default: fails closed, so no chart and no 今日盈亏 is drawn.
final class UnavailableWalletNetWorthHistoryGateway
    implements WalletNetWorthHistoryGateway {
  const UnavailableWalletNetWorthHistoryGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) => Future<LoopNetWorthHistory>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final walletNetWorthHistoryGatewayProvider =
    Provider<WalletNetWorthHistoryGateway>(
      (ref) => const UnavailableWalletNetWorthHistoryGateway(),
    );
