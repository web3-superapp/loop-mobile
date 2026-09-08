import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders shared by the S5 modules (`chain`, `wallet`, `market`,
/// `watchlist`, `alerts`, `notifications`).
///
/// Every decoder goes through [LoopV2Contract.strictMap], so an unknown or a
/// missing field is an invalid payload rather than a partially trusted value.
/// Every amount is parsed with [Decimal]; `double` never appears here.
abstract final class LoopV2ChainCodec {
  static const contractVersion = '2.0';
  static const maximumCursorLength = 1536;

  static final RegExp assetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:(native|0x[0-9a-f]{40})$',
  );
  static final RegExp chainIdPattern = RegExp(r'^eip155:[1-9][0-9]{0,9}$');
  static final RegExp addressPattern = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp hashPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp endpointRefPattern = RegExp(r'^rpc-[0-9a-f]{12}$');
  static final RegExp blockNumberPattern = RegExp(r'^(0|[1-9][0-9]{0,19})$');
  static final RegExp reasonCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
  static final RegExp cursorPattern = RegExp(
    r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );

  /// Unsigned decimal string (balances, amounts, thresholds).
  static final RegExp unsignedDecimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]+)?$',
  );

  /// Signed decimal string (24h change may be negative).
  static final RegExp signedDecimalPattern = RegExp(
    r'^-?(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$',
  );

  /// Raw integer minor units.
  static final RegExp rawAmountPattern = RegExp(r'^(0|[1-9][0-9]{0,77})$');

  /// Bounded free text: no control, format, surrogate or separator code point.
  static final RegExp displayTextPattern = RegExp(
    r'^[^\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]+$',
    unicode: true,
  );

  static Never invalid() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);

  static void requireContractVersion(Map<String, Object?> root) {
    if (root['contractVersion'] != contractVersion) invalid();
  }

  static bool requireBool(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! bool) invalid();
    return value;
  }

  static bool requireTrue(Map<String, Object?> source, String key) {
    if (!requireBool(source, key)) invalid();
    return true;
  }

  static bool requireFalse(Map<String, Object?> source, String key) {
    if (requireBool(source, key)) invalid();
    return false;
  }

  static int requireInt(
    Map<String, Object?> source,
    String key, {
    int minimum = 0,
    int? maximum,
  }) {
    final value = source[key];
    if (value is! int ||
        value < minimum ||
        (maximum != null && value > maximum)) {
      invalid();
    }
    return value;
  }

  static int? optionalInt(
    Map<String, Object?> source,
    String key, {
    int? minimum,
  }) {
    final value = source[key];
    if (value == null) return null;
    if (value is! int || (minimum != null && value < minimum)) invalid();
    return value;
  }

  static DateTime requireTimestamp(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || value.length > 64) invalid();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) invalid();
    return parsed.toUtc();
  }

  static DateTime? optionalTimestamp(Map<String, Object?> source, String key) {
    if (source[key] == null) return null;
    return requireTimestamp(source, key);
  }

  static String requireString(
    Map<String, Object?> source,
    String key, {
    required RegExp pattern,
    int minLength = 1,
    int maxLength = 256,
  }) {
    final value = source[key];
    if (value is! String ||
        value.length < minLength ||
        value.length > maxLength ||
        !pattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static String? optionalString(
    Map<String, Object?> source,
    String key, {
    required RegExp pattern,
    int minLength = 1,
    int maxLength = 256,
  }) {
    if (source[key] == null) return null;
    return requireString(
      source,
      key,
      pattern: pattern,
      minLength: minLength,
      maxLength: maxLength,
    );
  }

  static String requireText(
    Map<String, Object?> source,
    String key, {
    int maxLength = 128,
  }) => requireString(
    source,
    key,
    pattern: displayTextPattern,
    maxLength: maxLength,
  );

  static BigInt requireBlockNumber(Map<String, Object?> source, String key) {
    final value = requireString(
      source,
      key,
      pattern: blockNumberPattern,
      maxLength: 20,
    );
    final parsed = BigInt.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  static BigInt? optionalBlockNumber(Map<String, Object?> source, String key) {
    if (source[key] == null) return null;
    return requireBlockNumber(source, key);
  }

  static Decimal requireDecimal(
    Map<String, Object?> source,
    String key, {
    bool signed = false,
  }) {
    final value = requireString(
      source,
      key,
      pattern: signed ? signedDecimalPattern : unsignedDecimalPattern,
      maxLength: 160,
    );
    final parsed = Decimal.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  static Decimal? optionalDecimal(
    Map<String, Object?> source,
    String key, {
    bool signed = false,
  }) {
    if (source[key] == null) return null;
    return requireDecimal(source, key, signed: signed);
  }

  static String requireRawAmount(Map<String, Object?> source, String key) =>
      requireString(source, key, pattern: rawAmountPattern, maxLength: 80);

  static String requireReasonCode(Map<String, Object?> source, String key) =>
      requireString(source, key, pattern: reasonCodePattern, maxLength: 64);

  static String? optionalReasonCode(Map<String, Object?> source, String key) {
    if (source[key] == null) return null;
    return requireReasonCode(source, key);
  }

  /// The cursor is opaque: it is shape-checked and then echoed verbatim.
  static String? cursor(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String ||
        value.length < 3 ||
        value.length > maximumCursorLength ||
        !cursorPattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static List<Object?> requireList(Object? raw, {int maximum = 300}) {
    if (raw is! List || raw.length > maximum) invalid();
    return raw;
  }

  static String requireAssetId(Map<String, Object?> source, String key) =>
      requireString(source, key, pattern: assetIdPattern, maxLength: 64);

  /// A `{status: "unavailable", reasonCode}` block with exactly two keys.
  static LoopUnavailable unavailable(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
    });
    if (map['status'] != 'unavailable') invalid();
    return LoopUnavailable(requireReasonCode(map, 'reasonCode'));
  }

  static LoopFactSource requireFactSource(
    Map<String, Object?> source,
    String key,
  ) {
    final value = source[key];
    if (value is! String) invalid();
    final parsed = LoopFactSource.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  static LoopFactSource? optionalFactSource(
    Map<String, Object?> source,
    String key,
  ) {
    if (source[key] == null) return null;
    return requireFactSource(source, key);
  }

  /// The fixed six-field fact object.
  ///
  /// `value == null` is accepted only together with `quality == unavailable`,
  /// so a fact can never be rendered as a figure without provenance.
  static LoopFact fact(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'value',
      'source',
      'fetchedAt',
      'ttlSeconds',
      'quality',
      'reasonCode',
    });
    final rawQuality = map['quality'];
    if (rawQuality is! String) invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality == null) invalid();
    final value = optionalDecimal(map, 'value', signed: true);
    final unavailableQuality = quality == LoopFactQuality.unavailable;
    if (unavailableQuality != (value == null)) invalid();
    return LoopFact(
      value: value,
      source: optionalFactSource(map, 'source'),
      fetchedAt: optionalTimestamp(map, 'fetchedAt'),
      ttlSeconds: optionalInt(map, 'ttlSeconds', minimum: 1),
      quality: quality,
      reasonCode: optionalReasonCode(map, 'reasonCode'),
    );
  }

  static LoopAssetStatus requireAssetStatus(
    Map<String, Object?> source,
    String key,
  ) {
    final value = source[key];
    if (value is! String) invalid();
    final parsed = LoopAssetStatus.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  /// The inline four-field registry projection. `null` means "no longer
  /// readable" and the caller must carry a reason code alongside it.
  static LoopAssetSummary? assetSummary(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'symbol',
      'name',
      'decimals',
      'status',
    });
    return LoopAssetSummary(
      symbol: requireText(map, 'symbol', maxLength: 32),
      name: requireText(map, 'name'),
      decimals: requireInt(map, 'decimals', maximum: 36),
      status: requireAssetStatus(map, 'status'),
    );
  }

  static LoopAssetSource assetSource(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'kind',
      'blockNumber',
      'verifiedAt',
    });
    final rawKind = map['kind'];
    if (rawKind is! String) invalid();
    final kind = LoopAssetSourceKind.tryParse(rawKind);
    if (kind == null) invalid();
    return LoopAssetSource(
      kind: kind,
      blockNumber: optionalBlockNumber(map, 'blockNumber'),
      verifiedAt: optionalTimestamp(map, 'verifiedAt'),
    );
  }

  static LoopChainAsset chainAsset(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'chainId',
      'address',
      'symbol',
      'name',
      'decimals',
      'status',
      'source',
      'updatedAt',
    });
    return LoopChainAsset(
      assetId: requireAssetId(map, 'assetId'),
      chainId: requireString(
        map,
        'chainId',
        pattern: chainIdPattern,
        maxLength: 32,
      ),
      address: optionalString(
        map,
        'address',
        pattern: addressPattern,
        maxLength: 42,
      ),
      symbol: requireText(map, 'symbol', maxLength: 32),
      name: requireText(map, 'name'),
      decimals: requireInt(map, 'decimals', maximum: 36),
      status: requireAssetStatus(map, 'status'),
      source: assetSource(map['source']),
      updatedAt: requireTimestamp(map, 'updatedAt'),
    );
  }

  static LoopAssetCapability assetCapability(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'viewable',
      'swappable',
      'value',
      'reasonCode',
    });
    final rawValue = map['value'];
    if (rawValue is! String) invalid();
    final value = LoopAssetCapabilityValue.tryParse(rawValue);
    if (value == null) invalid();
    return LoopAssetCapability(
      viewable: requireBool(map, 'viewable'),
      // The contract pins `swappable` to false until Swap is delivered; any
      // other value is an invalid payload rather than a granted capability.
      swappable: requireFalse(map, 'swappable'),
      value: value,
      reasonCode: optionalReasonCode(map, 'reasonCode'),
    );
  }

  static LoopConfirmationStatus requireConfirmationStatus(
    Map<String, Object?> source,
    String key,
  ) {
    final value = source[key];
    if (value is! String) invalid();
    final parsed = LoopConfirmationStatus.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  static LoopIndexerFreshness freshness(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'indexerBlockNumber',
      'headBlockNumber',
      'lagBlocks',
      'observedAt',
    });
    return LoopIndexerFreshness(
      indexerBlockNumber: requireBlockNumber(map, 'indexerBlockNumber'),
      headBlockNumber: optionalBlockNumber(map, 'headBlockNumber'),
      lagBlocks: optionalInt(map, 'lagBlocks', minimum: 0),
      observedAt: requireTimestamp(map, 'observedAt'),
    );
  }
}
