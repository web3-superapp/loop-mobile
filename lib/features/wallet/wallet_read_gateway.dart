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

/// Feature-facing port that asks the server to re-read the account's wallets
/// from Privy right after a bind or an unbind (S306, decision 0246).
///
/// A port of its own, like the net-worth history: a server that has not
/// deployed the route leaves the wallet list on its ordinary refresh.
abstract interface class WalletInventorySyncGateway {
  /// `true` when the server acknowledged; `false` when it has no such route
  /// or could not be reached. It never throws: the caller re-reads the list
  /// either way.
  Future<bool> requestSync();
}

final class UnavailableWalletInventorySyncGateway
    implements WalletInventorySyncGateway {
  const UnavailableWalletInventorySyncGateway();

  @override
  Future<bool> requestSync() async => false;
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
