import 'package:flutter/foundation.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Copy for the frozen V2 error catalog (loop-api decision 0029,
/// extended to 30 codes by decision 0030's two alias codes and decision
/// 0031's `PROFILE_ACTIVATION_REQUIRED` and `RESOURCE_CONFLICT`).
///
/// The wire contract is `code` first; `userMessageKey` is the backend's
/// localisation key (`errors.<family>.<name>`, `errors.internal` keeps its
/// two-segment form) and is recorded here only so the two sides can be
/// diffed. Never branch on the key; branch on [LoopErrorCopy.code].
@immutable
final class LoopErrorCopy {
  const LoopErrorCopy({
    required this.code,
    required this.userMessageKey,
    required this.retryable,
  });

  final String code;
  final String userMessageKey;

  /// Title in the current App language (decision 0281).
  String get title => switch (code) {
    'UNKNOWN' => LoopL10n.current.coreText_errorTitle,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => LoopL10n.current.coreText_errorTitle2,
    'ALIAS_BLOCKED' => LoopL10n.current.coreText_errorTitle3,
    'ALIAS_RESERVED' => LoopL10n.current.coreText_errorTitle4,
    'AUTH_INVALID' => LoopL10n.current.coreText_errorTitle5,
    'AUTH_REQUIRED' => LoopL10n.current.coreText_errorTitle6,
    'AUTH_STEP_UP_REQUIRED' => LoopL10n.current.coreText_errorTitle7,
    'CAPABILITY_UNAVAILABLE' => LoopL10n.current.coreText_errorTitle8,
    'CHAIN_MISMATCH' => LoopL10n.current.coreText_errorTitle9,
    'DATA_STALE' => LoopL10n.current.coreText_errorTitle10,
    'IDEMPOTENCY_CONFLICT' => LoopL10n.current.coreText_errorTitle11,
    'INDEXING_DELAYED' => LoopL10n.current.coreText_errorTitle12,
    'INSUFFICIENT_BALANCE' => LoopL10n.current.coreText_errorTitle13,
    'INTERNAL_ERROR' => LoopL10n.current.coreText_errorTitle14,
    'INVALID_REQUEST' => LoopL10n.current.coreText_errorTitle15,
    'MAINTENANCE' => LoopL10n.current.coreText_errorTitle16,
    'NOT_FOUND' => LoopL10n.current.coreText_errorTitle17,
    'PERMISSION_DENIED' => LoopL10n.current.coreText_errorTitle18,
    'POLICY_BLOCKED' => LoopL10n.current.coreText_errorTitle19,
    'PROFILE_ACTIVATION_REQUIRED' => LoopL10n.current.coreText_errorTitle20,
    'PROVIDER_DISCONNECTED' => LoopL10n.current.coreText_errorTitle21,
    'QUOTE_EXPIRED' => LoopL10n.current.coreText_errorTitle22,
    'RATE_LIMITED' => LoopL10n.current.coreText_errorTitle23,
    'REGION_BLOCKED' => LoopL10n.current.coreText_errorTitle24,
    'REQUEST_TIMEOUT' => LoopL10n.current.coreText_errorTitle25,
    'RESOURCE_CONFLICT' => LoopL10n.current.coreText_errorTitle26,
    'SESSION_NOT_FOUND' => LoopL10n.current.coreText_errorTitle27,
    'SIMULATION_FAILED' => LoopL10n.current.coreText_errorTitle28,
    'SUBMISSION_UNKNOWN' => LoopL10n.current.coreText_errorTitle29,
    'VALIDATION_FAILED' => LoopL10n.current.coreText_errorTitle30,
    'VERSION_CONFLICT' => LoopL10n.current.coreText_errorTitle31,
    _ => LoopL10n.current.coreText_errorTitle,
  };

  /// Message in the current App language (decision 0281).
  String get message => switch (code) {
    'UNKNOWN' => LoopL10n.current.coreText_errorMessage,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => LoopL10n.current.coreText_errorMessage2,
    'ALIAS_BLOCKED' => LoopL10n.current.coreText_errorMessage3,
    'ALIAS_RESERVED' => LoopL10n.current.coreText_errorMessage4,
    'AUTH_INVALID' => LoopL10n.current.coreText_errorMessage5,
    'AUTH_REQUIRED' => LoopL10n.current.coreText_errorMessage6,
    'AUTH_STEP_UP_REQUIRED' => LoopL10n.current.coreText_errorMessage7,
    'CAPABILITY_UNAVAILABLE' => LoopL10n.current.coreText_errorMessage8,
    'CHAIN_MISMATCH' => LoopL10n.current.coreText_errorMessage9,
    'DATA_STALE' => LoopL10n.current.coreText_errorMessage10,
    'IDEMPOTENCY_CONFLICT' => LoopL10n.current.coreText_errorMessage11,
    'INDEXING_DELAYED' => LoopL10n.current.coreText_errorMessage12,
    'INSUFFICIENT_BALANCE' => LoopL10n.current.coreText_errorMessage13,
    'INTERNAL_ERROR' => LoopL10n.current.coreText_errorMessage14,
    'INVALID_REQUEST' => LoopL10n.current.coreText_errorMessage15,
    'MAINTENANCE' => LoopL10n.current.coreText_errorMessage16,
    'NOT_FOUND' => LoopL10n.current.coreText_errorMessage17,
    'PERMISSION_DENIED' => LoopL10n.current.coreText_errorMessage18,
    'POLICY_BLOCKED' => LoopL10n.current.coreText_errorMessage19,
    'PROFILE_ACTIVATION_REQUIRED' => LoopL10n.current.coreText_errorMessage20,
    'PROVIDER_DISCONNECTED' => LoopL10n.current.coreText_errorMessage21,
    'QUOTE_EXPIRED' => LoopL10n.current.coreText_errorMessage22,
    'RATE_LIMITED' => LoopL10n.current.coreText_errorMessage23,
    'REGION_BLOCKED' => LoopL10n.current.coreText_errorMessage24,
    'REQUEST_TIMEOUT' => LoopL10n.current.coreText_errorMessage25,
    'RESOURCE_CONFLICT' => LoopL10n.current.coreText_errorMessage26,
    'SESSION_NOT_FOUND' => LoopL10n.current.coreText_errorMessage27,
    'SIMULATION_FAILED' => LoopL10n.current.coreText_errorMessage28,
    'SUBMISSION_UNKNOWN' => LoopL10n.current.coreText_errorMessage29,
    'VALIDATION_FAILED' => LoopL10n.current.coreText_errorMessage30,
    'VERSION_CONFLICT' => LoopL10n.current.coreText_errorMessage31,
    _ => LoopL10n.current.coreText_errorMessage,
  };
  final bool retryable;
}

abstract final class LoopErrorText {
  /// Shown when the code is absent, unknown or the envelope was invalid.
  static const LoopErrorCopy unknown = LoopErrorCopy(
    code: 'UNKNOWN',
    userMessageKey: 'errors.internal',
    retryable: false,
  );

  static const List<LoopErrorCopy> catalog = <LoopErrorCopy>[
    LoopErrorCopy(
      code: 'ACCOUNT_BOOTSTRAP_REQUIRED',
      userMessageKey: 'errors.account.bootstrapRequired',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'ALIAS_BLOCKED',
      userMessageKey: 'errors.alias.blocked',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'ALIAS_RESERVED',
      userMessageKey: 'errors.alias.reserved',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_INVALID',
      userMessageKey: 'errors.auth.invalid',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_REQUIRED',
      userMessageKey: 'errors.auth.required',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_STEP_UP_REQUIRED',
      userMessageKey: 'errors.auth.stepUpRequired',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'CAPABILITY_UNAVAILABLE',
      userMessageKey: 'errors.capability.unavailable',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'CHAIN_MISMATCH',
      userMessageKey: 'errors.chain.mismatch',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'DATA_STALE',
      userMessageKey: 'errors.data.stale',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'IDEMPOTENCY_CONFLICT',
      userMessageKey: 'errors.idempotency.conflict',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INDEXING_DELAYED',
      userMessageKey: 'errors.indexing.delayed',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'INSUFFICIENT_BALANCE',
      userMessageKey: 'errors.balance.insufficient',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INTERNAL_ERROR',
      userMessageKey: 'errors.internal',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INVALID_REQUEST',
      userMessageKey: 'errors.request.invalid',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'MAINTENANCE',
      userMessageKey: 'errors.service.maintenance',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'NOT_FOUND',
      userMessageKey: 'errors.resource.notFound',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PERMISSION_DENIED',
      userMessageKey: 'errors.permission.denied',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'POLICY_BLOCKED',
      userMessageKey: 'errors.policy.blocked',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PROFILE_ACTIVATION_REQUIRED',
      userMessageKey: 'errors.profile.activationRequired',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PROVIDER_DISCONNECTED',
      userMessageKey: 'errors.provider.disconnected',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'QUOTE_EXPIRED',
      userMessageKey: 'errors.quote.expired',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'RATE_LIMITED',
      userMessageKey: 'errors.rateLimit.exceeded',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'REGION_BLOCKED',
      userMessageKey: 'errors.region.blocked',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'REQUEST_TIMEOUT',
      userMessageKey: 'errors.request.timeout',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'RESOURCE_CONFLICT',
      userMessageKey: 'errors.conflict.resource',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SESSION_NOT_FOUND',
      userMessageKey: 'errors.session.notFound',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SIMULATION_FAILED',
      userMessageKey: 'errors.simulation.failed',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SUBMISSION_UNKNOWN',
      userMessageKey: 'errors.submission.unknown',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'VALIDATION_FAILED',
      userMessageKey: 'errors.validation.failed',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'VERSION_CONFLICT',
      userMessageKey: 'errors.version.conflict',
      retryable: false,
    ),
  ];

  static final Map<String, LoopErrorCopy> _byCode = <String, LoopErrorCopy>{
    for (final copy in catalog) copy.code: copy,
  };

  /// Copy for a backend `code`; unknown or absent codes use [unknown].
  static LoopErrorCopy forCode(String? code) =>
      code == null ? unknown : (_byCode[code] ?? unknown);

  static bool isKnownCode(String code) => _byCode.containsKey(code);
}
