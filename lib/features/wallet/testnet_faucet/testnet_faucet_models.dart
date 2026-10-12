import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// The testnet faucet (client decision 0154, loop-api S156): one grant of a
/// little tBNB and tUSD1 to the signed-in account's own embedded wallet, at
/// most once per wallet per cooldown window.
///
/// Every model here is a view of what LOOP answered. Nothing is derived on
/// the device: whether the wallet can claim now is the server's `available`,
/// and the next time it can is the server's `nextAvailableAt`.

/// The last grant `GET /v2/testnet/faucet` remembers for the wallet.
@immutable
final class TestnetFaucetLastGrant {
  const TestnetFaucetLastGrant({
    required this.grantedAt,
    required this.bnbTransactionHash,
    required this.usd1TransactionHash,
  });

  final DateTime grantedAt;

  /// Lower-case `0x` hashes. Either may be `null` when that half of the grant
  /// never reached the chain (a partial grant).
  final String? bnbTransactionHash;
  final String? usd1TransactionHash;
}

/// `GET /v2/testnet/faucet?walletId=`.
@immutable
final class TestnetFaucetStatus {
  const TestnetFaucetStatus({
    required this.walletId,
    required this.address,
    required this.bnbAmount,
    required this.usd1Amount,
    required this.cooldownSeconds,
    required this.available,
    required this.nextAvailableAt,
    required this.lastGrant,
  });

  final String walletId;

  /// Lower-case `0x` address of the wallet the grant goes to.
  final String address;
  final Decimal bnbAmount;
  final Decimal usd1Amount;
  final int cooldownSeconds;

  /// Whether the server would grant now.
  final bool available;

  /// When the server will grant again; `null` while [available].
  final DateTime? nextAvailableAt;
  final TestnetFaucetLastGrant? lastGrant;
}

/// One transfer of a grant: the amount and the hash that carried it.
@immutable
final class TestnetFaucetTransfer {
  const TestnetFaucetTransfer({
    required this.amount,
    required this.transactionHash,
  });

  final Decimal amount;
  final String transactionHash;
}

/// What `POST /v2/testnet/faucet` answered.
///
/// The cooldown and the partial grant are not failures of the request but
/// facts about the wallet, so they come back as values; every other refusal
/// is a `LoopChainException` carrying the server's own reason code.
@immutable
sealed class TestnetFaucetClaimResult {
  const TestnetFaucetClaimResult();
}

/// `201`: both transfers were sent.
final class TestnetFaucetGranted extends TestnetFaucetClaimResult {
  const TestnetFaucetGranted({
    required this.walletId,
    required this.address,
    required this.bnb,
    required this.usd1,
    required this.grantedAt,
    required this.nextAvailableAt,
  });

  final String walletId;
  final String address;
  final TestnetFaucetTransfer bnb;
  final TestnetFaucetTransfer usd1;
  final DateTime grantedAt;
  final DateTime nextAvailableAt;
}

/// `429 RATE_LIMITED` + `TESTNET_FAUCET_COOLDOWN`. [nextAvailableAt] is
/// `null` only when the server did not publish one.
final class TestnetFaucetCoolingDown extends TestnetFaucetClaimResult {
  const TestnetFaucetCoolingDown({this.nextAvailableAt});

  final DateTime? nextAvailableAt;
}

/// `TESTNET_FAUCET_PARTIAL`: one transfer went through and the other did
/// not. The hashes are the ones the server reported as sent.
final class TestnetFaucetPartial extends TestnetFaucetClaimResult {
  const TestnetFaucetPartial({
    this.bnbTransactionHash,
    this.usd1TransactionHash,
  });

  final String? bnbTransactionHash;
  final String? usd1TransactionHash;
}

/// The server's reason codes this surface turns into its own sentences.
abstract final class TestnetFaucetReason {
  static const disabled = 'TESTNET_FAUCET_DISABLED';
  static const wrongChain = 'TESTNET_FAUCET_WRONG_CHAIN';
  static const operatorNotConfigured = 'TESTNET_FAUCET_OPERATOR_NOT_CONFIGURED';
  static const operatorLow = 'TESTNET_FAUCET_OPERATOR_LOW';
  static const walletNotOwned = 'TESTNET_FAUCET_WALLET_NOT_OWNED';
  static const cooldown = 'TESTNET_FAUCET_COOLDOWN';
  static const partial = 'TESTNET_FAUCET_PARTIAL';

  /// The client's own code for a capability document that does not list
  /// `testnetFaucet` at all (a backend from before loop-api S156). No
  /// backend emits it.
  static const capabilityAbsent = 'TESTNET_FAUCET_CAPABILITY_ABSENT';
}
