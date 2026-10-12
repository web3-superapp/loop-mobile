import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the testnet faucet (client decision 0154, loop-api
/// S156).
///
/// Every object is read through [LoopV2Contract.strictMap]: an unknown or a
/// missing key is an invalid payload. Amounts are decimal strings parsed into
/// [Decimal], never `double`; addresses and hashes are accepted in either
/// case and kept lower-case.
abstract final class LoopV2TestnetFaucetCodec {
  static final RegExp walletIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');
  static final RegExp amountPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
  );

  static const statusKeys = <String>{
    'walletId',
    'address',
    'bnbAmount',
    'usd1Amount',
    'cooldownSeconds',
    'available',
    'nextAvailableAt',
    'lastGrant',
  };

  static const lastGrantKeys = <String>{
    'grantedAt',
    'bnbTransactionHash',
    'usd1TransactionHash',
  };

  static const grantKeys = <String>{
    'walletId',
    'address',
    'bnb',
    'usd1',
    'grantedAt',
    'nextAvailableAt',
  };

  static const transferKeys = <String>{'amount', 'transactionHash'};

  static Never invalid() => LoopV2ChainCodec.invalid();

  static String _walletId(Map<String, Object?> map) =>
      LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: walletIdPattern,
        maxLength: 36,
      );

  static String _address(Map<String, Object?> map) =>
      LoopV2ChainCodec.requireString(
        map,
        'address',
        pattern: addressPattern,
        maxLength: 42,
      ).toLowerCase();

  static String? _optionalHash(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.optionalString(
        map,
        key,
        pattern: hashPattern,
        maxLength: 66,
      )?.toLowerCase();

  static String _hash(Map<String, Object?> map, String key) =>
      _optionalHash(map, key) ?? invalid();

  /// A positive decimal amount. A grant of nothing is not a grant.
  static Decimal _amount(Map<String, Object?> map, String key) {
    final value = Decimal.parse(
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: amountPattern,
        maxLength: 97,
      ),
    );
    if (value <= Decimal.zero) invalid();
    return value;
  }

  /// `GET /v2/testnet/faucet?walletId=`.
  ///
  /// `nextAvailableAt` is `null` exactly while `available` is true: a wallet
  /// that may claim now has no next time, and one that may not always has.
  static TestnetFaucetStatus status(Object? body) {
    final map = LoopV2Contract.strictMap(body, statusKeys);
    final available = LoopV2ChainCodec.requireBool(map, 'available');
    final nextAvailableAt = LoopV2ChainCodec.optionalTimestamp(
      map,
      'nextAvailableAt',
    );
    if (available != (nextAvailableAt == null)) invalid();
    final rawLastGrant = map['lastGrant'];
    return TestnetFaucetStatus(
      walletId: _walletId(map),
      address: _address(map),
      bnbAmount: _amount(map, 'bnbAmount'),
      usd1Amount: _amount(map, 'usd1Amount'),
      cooldownSeconds: LoopV2ChainCodec.requireInt(
        map,
        'cooldownSeconds',
        minimum: 1,
        maximum: 31 * 86400,
      ),
      available: available,
      nextAvailableAt: nextAvailableAt,
      lastGrant: rawLastGrant == null ? null : _lastGrant(rawLastGrant),
    );
  }

  static TestnetFaucetLastGrant _lastGrant(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, lastGrantKeys);
    // tBNB is sent first and is always recorded; tUSD1 is `null` when it was
    // never minted (a partial grant, or one whose outcome is unknown).
    return TestnetFaucetLastGrant(
      grantedAt: LoopV2ChainCodec.requireTimestamp(map, 'grantedAt'),
      bnbTransactionHash: _hash(map, 'bnbTransactionHash'),
      usd1TransactionHash: _optionalHash(map, 'usd1TransactionHash'),
    );
  }

  static TestnetFaucetTransfer _transfer(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, transferKeys);
    return TestnetFaucetTransfer(
      amount: _amount(map, 'amount'),
      transactionHash: _hash(map, 'transactionHash'),
    );
  }

  /// `201` of `POST /v2/testnet/faucet`.
  static TestnetFaucetGranted granted(Object? body) {
    final map = LoopV2Contract.strictMap(body, grantKeys);
    final grantedAt = LoopV2ChainCodec.requireTimestamp(map, 'grantedAt');
    final nextAvailableAt = LoopV2ChainCodec.requireTimestamp(
      map,
      'nextAvailableAt',
    );
    if (!nextAvailableAt.isAfter(grantedAt)) invalid();
    return TestnetFaucetGranted(
      walletId: _walletId(map),
      address: _address(map),
      bnb: _transfer(map['bnb']),
      usd1: _transfer(map['usd1']),
      grantedAt: grantedAt,
      nextAvailableAt: nextAvailableAt,
    );
  }

  /// `detailsSafe.nextAvailableAt` of a cooldown refusal. A missing or
  /// unreadable value is `null`: the refusal still stands, only the time is
  /// not shown.
  static DateTime? cooldownNextAvailableAt(Object? detailsSafe) {
    if (detailsSafe is! Map) return null;
    final value = detailsSafe['nextAvailableAt'];
    if (value is! String || value.length > 64) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  /// The hashes a partial refusal reports as sent, and the next time. Each
  /// one is optional and an unreadable value is dropped, never guessed.
  /// [unconfirmed] marks `TESTNET_FAUCET_SUBMISSION_UNKNOWN`.
  static TestnetFaucetPartial partial(
    Object? detailsSafe, {
    bool unconfirmed = false,
  }) {
    String? hash(String key) {
      if (detailsSafe is! Map) return null;
      final value = detailsSafe[key];
      if (value is! String || !hashPattern.hasMatch(value)) return null;
      return value.toLowerCase();
    }

    return TestnetFaucetPartial(
      bnbTransactionHash: hash('bnbTransactionHash'),
      usd1TransactionHash: hash('usd1TransactionHash'),
      nextAvailableAt: cooldownNextAvailableAt(detailsSafe),
      unconfirmed: unconfirmed,
    );
  }
}
