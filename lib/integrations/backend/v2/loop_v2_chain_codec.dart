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

  /// A displayable endpoint name: the RPC URL's host name and nothing else.
  static final RegExp endpointLabelPattern = RegExp(r'^[A-Za-z0-9._-]+$');
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

  /// One of the exactly two chain ids the backend may publish (decision
  /// 0038): the primary chain, or the Launch slot's BSC testnet. There is no
  /// chain list, so any other value is an invalid payload rather than a new
  /// network the client silently adopts.
  static String requireKnownChainId(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || !loopKnownChainIds.contains(value)) invalid();
    return value;
  }

  /// `{blockNumber, blockHash, observedAt}`, or `null` when the slot has no
  /// verified head.
  static LoopChainHead? optionalChainHead(
    Map<String, Object?> source,
    String key,
  ) {
    if (source[key] == null) return null;
    final map = LoopV2Contract.strictMap(source[key], const <String>{
      'blockNumber',
      'blockHash',
      'observedAt',
    });
    return LoopChainHead(
      blockNumber: requireBlockNumber(map, 'blockNumber'),
      blockHash: requireString(
        map,
        'blockHash',
        pattern: hashPattern,
        maxLength: 66,
      ),
      observedAt: requireTimestamp(map, 'observedAt'),
    );
  }

  /// The `verification` enum shared by the primary chain, one endpoint and
  /// the Launch chain slot.
  static LoopChainVerification requireVerification(
    Map<String, Object?> source,
    String key,
  ) {
    final value = source[key];
    if (value is! String) invalid();
    final parsed = LoopChainVerification.tryParse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  /// The optional `launchChain` projection of `GET /v2/chain/status`.
  ///
  /// The key is **absent** whenever the Launch slot equals the primary chain,
  /// which is the ordinary case; it is never `null` and never a placeholder.
  static LoopLaunchChainStatus? optionalLaunchChain(
    Map<String, Object?> root,
    String key,
  ) {
    if (!root.containsKey(key)) return null;
    final map = LoopV2Contract.strictMap(root[key], const <String>{
      'chainId',
      'chainReference',
      'verification',
      'confirmations',
      'reorgDepthBlocks',
      'head',
      'reasonCode',
    });
    final chainId = requireKnownChainId(map, 'chainId');
    final reference = requireInt(map, 'chainReference', minimum: 1);
    // The numeric reference and the CAIP id are two halves of one fact; a
    // payload where they disagree is not partially trusted.
    if ('eip155:$reference' != chainId) invalid();
    final verification = requireVerification(map, 'verification');
    final head = optionalChainHead(map, 'head');
    if (head != null && verification != LoopChainVerification.verified) {
      invalid();
    }
    return LoopLaunchChainStatus(
      chainId: chainId,
      chainReference: reference,
      verification: verification,
      confirmations: requireInt(map, 'confirmations', minimum: 1),
      reorgDepthBlocks: requireInt(map, 'reorgDepthBlocks', minimum: 1),
      head: head,
      reasonCode: optionalReasonCode(map, 'reasonCode'),
    );
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
    int? maximum,
  }) {
    final value = source[key];
    if (value == null) return null;
    if (value is! int ||
        (minimum != null && value < minimum) ||
        (maximum != null && value > maximum)) {
      invalid();
    }
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

  static String? optionalText(
    Map<String, Object?> source,
    String key, {
    int maxLength = 128,
  }) => source[key] == null
      ? null
      : requireText(source, key, maxLength: maxLength);

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

  /// Text a market data Provider wrote and the backend passes through.
  ///
  /// The contract bounds a pool name and a dex id by length only: the name is
  /// assembled from token names taken off the chain, and anyone may mint a
  /// token whose name carries a bidirectional override or a zero-width joiner.
  /// Refusing the payload would let one such token close the whole page, and
  /// printing it verbatim would let it rewrite the line the reader sees, so
  /// the code points that could reorder or hide the rest of the row are
  /// removed and what remains of the name is kept.
  ///
  /// The length bound counts code points, the way the published schema does;
  /// a name written in emoji is within the contract and must not be refused
  /// for the UTF-16 units Dart happens to store it in.
  static String providerText(
    Map<String, Object?> source,
    String key, {
    required int maxLength,
    int minLength = 0,
  }) {
    final value = source[key];
    if (value is! String) invalid();
    final length = value.runes.length;
    if (length < minLength || length > maxLength) invalid();
    return sanitizeProviderText(value);
  }

  /// Strips the control, format, surrogate and separator code points that a
  /// line of display text must never carry, then trims the edges the removal
  /// may have left behind. The result may be empty: a Provider is allowed to
  /// publish a nameless pool, and the page says so rather than dropping it.
  static String sanitizeProviderText(String value) =>
      value.replaceAll(_unsafeDisplayCodePoints, '').trim();

  static final RegExp _unsafeDisplayCodePoints = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
    unicode: true,
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
  /// A channel the server may now have: `{status, reasonCode}` where
  /// `available` carries a null reason and `unavailable` carries one.
  ///
  /// Decision 0067 gave `push` (and the alert resource's `delivery`) a second
  /// state. Reading them with [unavailable] was right while there was no push
  /// runtime and wrong the moment there is one: the whole feed would have
  /// become an invalid payload on the day delivery was switched on, which is
  /// the worst possible day for the notifications page to go blank.
  ///
  /// `null` means available. It is deliberately not a `LoopUnavailable` with
  /// an empty reason: there is nothing to say, and a surface that renders a
  /// reason-less refusal reads as a refusal.
  static LoopUnavailable? deliveryChannel(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
    });
    switch (map['status']) {
      case 'available':
        if (map['reasonCode'] != null) invalid();
        return null;
      case 'unavailable':
        return LoopUnavailable(requireReasonCode(map, 'reasonCode'));
      default:
        invalid();
    }
  }

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

  /// The hosts the `logo.url` may name (contract §2a, decision 0072).
  ///
  /// The server filters twice and anchors the pattern in OpenAPI. The client
  /// does not widen it: a URL whose host is not one of these three is treated
  /// as no artwork at all, so a compromised or mis-projected row cannot make
  /// the app fetch from an arbitrary origin.
  static const Set<String> logoHosts = <String>{
    'cdn.dexscreener.com',
    'dd.dexscreener.com',
    'raw.githubusercontent.com',
  };

  /// The required `logo` block every asset row now carries.
  ///
  /// Returns the address to load, or `null` when the server said it has none
  /// (`unavailable`) — the surface then draws the monogram it already draws.
  /// `source` and `observedAt` are read so the payload is validated in full,
  /// and deliberately not returned: they are for provenance and triage, and a
  /// logo is not a market fact (decision 0072).
  ///
  /// A logo is **not** an identity. It never merges, matches or names an
  /// asset; only `assetId` does (decision 0033).
  static String? logoUrl(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'status'},
      const <String>{'url', 'source', 'observedAt', 'reasonCode'},
    );
    final status = map['status'];
    if (status is! String) invalid();
    switch (status) {
      case 'unavailable':
        if (map['url'] != null ||
            map['source'] != null ||
            map['observedAt'] != null) {
          invalid();
        }
        requireText(map, 'reasonCode', maxLength: 64);
        return null;
      case 'available':
        if (map['reasonCode'] != null) invalid();
        final url = requireText(map, 'url', maxLength: 512);
        final source = requireText(map, 'source', maxLength: 32);
        if (source != 'dexscreener' && source != 'trustwallet') invalid();
        if (map['observedAt'] != null) requireTimestamp(map, 'observedAt');
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort ||
            !logoHosts.contains(uri.host)) {
          invalid();
        }
        return url;
      default:
        invalid();
    }
  }

  /// The asset's provenance block.
  ///
  /// A registry asset names the chain call it was read from. An address the
  /// registry does not carry names the market provider that described it, and
  /// carries that lookup's own freshness — four fields a chain call never
  /// has. They are optional on the wire and tied to the kind here, so a
  /// registry asset can never arrive wearing a provider's name.
  static LoopAssetSource assetSource(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'kind', 'blockNumber', 'verifiedAt'},
      const <String>{'provider', 'fetchedAt', 'ttlSeconds', 'quality'},
    );
    final rawKind = map['kind'];
    if (rawKind is! String) invalid();
    final kind = LoopAssetSourceKind.tryParse(rawKind);
    if (kind == null) invalid();
    final provider = optionalFactSource(map, 'provider');
    final lookup = kind == LoopAssetSourceKind.providerLookup;
    if (lookup != (provider != null)) invalid();
    final rawQuality = map['quality'];
    LoopFactQuality? quality;
    if (rawQuality != null) {
      if (rawQuality is! String) invalid();
      quality = LoopFactQuality.tryParse(rawQuality);
      if (quality == null) invalid();
    }
    // A lookup with no observation time could not be marked stale or fresh,
    // and the card would have to state a freshness nobody reported.
    if (lookup && (quality == null || map['fetchedAt'] == null)) invalid();
    return LoopAssetSource(
      kind: kind,
      blockNumber: optionalBlockNumber(map, 'blockNumber'),
      verifiedAt: optionalTimestamp(map, 'verifiedAt'),
      provider: provider,
      fetchedAt: optionalTimestamp(map, 'fetchedAt'),
      ttlSeconds: optionalInt(map, 'ttlSeconds', minimum: 1),
      quality: quality,
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
      // A provider that reported no ticker, no name or no precision leaves
      // them null; the surface shows the address and formats no quantity.
      symbol: optionalText(map, 'symbol', maxLength: 32),
      name: optionalText(map, 'name'),
      decimals: optionalInt(map, 'decimals', maximum: 36),
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
