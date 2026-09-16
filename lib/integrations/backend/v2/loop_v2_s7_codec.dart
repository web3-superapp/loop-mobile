import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders shared by the three S7 transports (`launch`, `mining` and
/// `referral`).
///
/// Every decoder goes through [LoopV2Contract.strictMap], so an unknown or a
/// missing field is an invalid payload rather than a partially trusted value.
abstract final class LoopV2S7Codec {
  static const contractVersion = '2.0';
  static const maximumTextLength = 4096;
  static const maximumCursorLength = 1536;

  static final RegExp configVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
  );
  static final RegExp priceVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,191}$',
  );
  static final RegExp tickerPattern = RegExp(r'^[A-Z0-9]{2,12}$');
  static final RegExp digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp blockHashPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp blockNumberPattern = RegExp(r'^(0|[1-9][0-9]{0,19})$');
  static final RegExp decimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$',
  );
  static final RegExp integerAmountPattern = RegExp(r'^(0|[1-9][0-9]{0,77})$');
  static final RegExp reviewReasonPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static final RegExp reviewerPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,63}$');
  static final RegExp httpsPattern = RegExp(r'^https://');
  static final RegExp cursorPattern = RegExp(
    r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );
  static final RegExp ruleKeyPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
  static final RegExp assetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:0x[0-9a-f]{40}$',
  );

  /// A mining row can weigh the chain's own coin, which has no contract
  /// address of its own; a community binding still cannot.
  static final RegExp holdingAssetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:(0x[0-9a-f]{40}|native)$',
  );
  static final RegExp textPattern = RegExp(
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

  /// A boolean the contract pins to one value, such as `executable: false`.
  static bool requireExactBool(
    Map<String, Object?> source,
    String key,
    bool expected,
  ) {
    if (requireBool(source, key) != expected) invalid();
    return expected;
  }

  static int requireCount(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! int || value < 0) invalid();
    return value;
  }

  static int requirePositiveInt(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! int || value < 1) invalid();
    return value;
  }

  static int? optionalPositiveInt(Map<String, Object?> source, String key) {
    if (source[key] == null) return null;
    return requirePositiveInt(source, key);
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

  /// Free text (a project name, a community name, a narrative). Control and
  /// bidirectional characters are refused so a payload can never smuggle a
  /// display trick into the page.
  static String requireText(
    Map<String, Object?> source,
    String key, {
    int maxLength = maximumTextLength,
  }) {
    final value = source[key];
    if (value is! String ||
        value.isEmpty ||
        value.length > maxLength ||
        !textPattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static String? optionalText(
    Map<String, Object?> source,
    String key, {
    int maxLength = maximumTextLength,
  }) {
    if (source[key] == null) return null;
    return requireText(source, key, maxLength: maxLength);
  }

  static String requirePattern(
    Map<String, Object?> source,
    String key,
    RegExp pattern, {
    int maxLength = 256,
  }) => LoopV2Contract.requiredString(
    source,
    key,
    pattern: pattern,
    maxLength: maxLength,
  );

  static String? optionalPattern(
    Map<String, Object?> source,
    String key,
    RegExp pattern, {
    int maxLength = 256,
  }) {
    if (source[key] == null) return null;
    return requirePattern(source, key, pattern, maxLength: maxLength);
  }

  static String requireId(Map<String, Object?> source, String key) =>
      LoopV2Contract.requiredString(
        source,
        key,
        pattern: LoopV2Contract.uuidPattern,
      );

  static String? optionalId(Map<String, Object?> source, String key) {
    if (source[key] == null) return null;
    return requireId(source, key);
  }

  /// A field the contract pins to `null` in this step (a contract address, a
  /// tier result, a snapshot block). A value would mean the baseline landed
  /// without a client update, so it is refused rather than rendered.
  static Null requireNull(Map<String, Object?> source, String key) {
    if (source[key] != null) invalid();
    return null;
  }

  static String requireEnum(
    Map<String, Object?> source,
    String key,
    Set<String> allowed,
  ) {
    final value = source[key];
    if (value is! String || !allowed.contains(value)) invalid();
    return value;
  }

  /// A nullable server `reasonCode`. Shape-checked, then rendered verbatim.
  static String requireReasonCode(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String ||
        value.length > 64 ||
        !LoopV2Contract.reasonCodePattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  /// The fixed `{status: "unavailable", reasonCode}` projection.
  static LaunchUnavailable unavailable(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
    });
    if (map['status'] != 'unavailable') invalid();
    return LaunchUnavailable(requireReasonCode(map, 'reasonCode'));
  }

  /// A decimal figure block: `{status: "available", value}` when the server
  /// settled it, `null` when it sent the unavailable projection instead. Any
  /// third shape is an invalid payload.
  static String? availableDecimal(Object? raw) {
    if (raw is! Map || raw['status'] != 'available') return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'value',
    });
    return requirePattern(map, 'value', decimalPattern, maxLength: 140);
  }

  /// A reviewed community weight. The mining panel and the `miningPower`
  /// projection on a community record are the same shape from the same
  /// server function, so they are the same decoder here.
  static MiningCommunityWeight communityWeight(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] == 'approved') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'value',
        'configVersion',
        'reviewedAt',
      });
      return MiningCommunityWeightApproved(
        value: requirePattern(map, 'value', decimalPattern, maxLength: 140),
        configVersion: requirePattern(
          map,
          'configVersion',
          configVersionPattern,
        ),
        reviewedAt: requireTimestamp(map, 'reviewedAt'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
      'reviewStatus',
    });
    if (map['status'] != 'unavailable') invalid();
    // Two states, not one: a bound community waiting for a review, and an
    // unbound one with nothing to review (Decision 0046).
    final reviewStatus = MiningWeightReviewStatus.tryParse(
      requireEnum(map, 'reviewStatus', const <String>{
        'pending_review',
        'not_applicable',
      }),
    );
    if (reviewStatus == null) invalid();
    return MiningCommunityWeightPending(
      reasonCode: requireReasonCode(map, 'reasonCode'),
      reviewStatus: reviewStatus,
    );
  }

  /// How many members a settlement counted. A zero count is a reading; an
  /// absent one is not.
  static MiningParticipants participants(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return MiningParticipantsUnavailable(unavailable(raw).reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'count',
    });
    return MiningParticipantsCount(requireCount(map, 'count'));
  }

  /// The scope a formula version declares about itself: the development
  /// baseline, or a product version (`null` on the wire). The key is
  /// required; only the client's reading of it is nullable.
  static MiningFormulaScope formulaScope(Map<String, Object?> source) {
    final raw = source['scope'];
    if (raw != null && raw is! String) invalid();
    final scope = MiningFormulaScope.tryParse(raw as String?);
    if (scope == null) invalid();
    return scope;
  }

  static List<Object?> requireList(Object? raw, {int maximum = 200}) {
    if (raw is! List || raw.length > maximum) invalid();
    return raw;
  }

  /// A collection the contract fixes to empty for this step. A non-empty list
  /// has no defined item schema, so it is an invalid payload rather than a
  /// partially trusted row.
  static void requireEmptyList(Object? raw) {
    if (raw is! List || raw.isNotEmpty) invalid();
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

  /// An `https://` official link. A value carrying credentials is refused.
  static String? optionalHttpsUrl(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String ||
        value.length < 9 ||
        value.length > 512 ||
        !httpsPattern.hasMatch(value) ||
        value.contains('@') ||
        !textPattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  /// A server-owned copy key such as `mining.rules.priceGuard.twap`.
  static String requireRuleKey(
    Map<String, Object?> source,
    String key, {
    int maxLength = 128,
  }) => requirePattern(source, key, ruleKeyPattern, maxLength: maxLength);
}

/// Maps the V2 error catalogue onto the narrow feature-facing kinds used by
/// the three S7 ports. No provider detail ever escapes.
///
/// [write] is what the request was, and it decides one case: a payload the
/// client cannot parse. After a write the outcome is genuinely unknown — the
/// server may have applied it — and the page must say so and warn against
/// submitting again. After a read nothing was submitted at all, so the same
/// transport failure is a page that did not load. Telling somebody who opened
/// 奖励与领取 not to submit twice names a submission they never made.
LaunchFailureKind launchFailureKindForV2(
  LoopBackendFailure failure, {
  required bool write,
}) {
  return switch (failure.code) {
    'PERMISSION_DENIED' => LaunchFailureKind.permissionDenied,
    'POLICY_BLOCKED' => LaunchFailureKind.policyBlocked,
    'NOT_FOUND' => LaunchFailureKind.notFound,
    'DATA_STALE' => LaunchFailureKind.stale,
    'VERSION_CONFLICT' => LaunchFailureKind.versionConflict,
    'PROFILE_ACTIVATION_REQUIRED' => LaunchFailureKind.activationRequired,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => LaunchFailureKind.bootstrapRequired,
    'IDEMPOTENCY_CONFLICT' => LaunchFailureKind.idempotencyConflict,
    'VALIDATION_FAILED' => LaunchFailureKind.validationFailed,
    'INVALID_REQUEST' => LaunchFailureKind.invalidData,
    _ => switch (failure.kind) {
      LoopBackendFailureKind.connection ||
      LoopBackendFailureKind.timeout => LaunchFailureKind.offline,
      LoopBackendFailureKind.cancelled => LaunchFailureKind.cancelled,
      // A payload the client could not parse leaves a write unresolved: the
      // server may already have applied it. A read has applied nothing.
      LoopBackendFailureKind.invalidPayload =>
        write
            ? LaunchFailureKind.outcomeUnknown
            : LaunchFailureKind.invalidData,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        LaunchFailureKind.unavailable,
      _ => LaunchFailureKind.unexpected,
    },
  };
}
