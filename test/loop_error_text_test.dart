import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/text/loop_error_text.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

void main() {
  test(
    'catalog covers the 28 frozen V2 codes with errors.<family>.<name> keys',
    () {
      expect(LoopErrorText.catalog, hasLength(28));
      expect(
        LoopErrorText.catalog.map((copy) => copy.code).toSet(),
        hasLength(28),
      );
      expect(LoopErrorText.catalog.map((copy) => copy.code), <String>[
        'ACCOUNT_BOOTSTRAP_REQUIRED',
        'ALIAS_BLOCKED',
        'ALIAS_RESERVED',
        'AUTH_INVALID',
        'AUTH_REQUIRED',
        'AUTH_STEP_UP_REQUIRED',
        'CAPABILITY_UNAVAILABLE',
        'CHAIN_MISMATCH',
        'DATA_STALE',
        'IDEMPOTENCY_CONFLICT',
        'INDEXING_DELAYED',
        'INSUFFICIENT_BALANCE',
        'INTERNAL_ERROR',
        'INVALID_REQUEST',
        'MAINTENANCE',
        'NOT_FOUND',
        'PERMISSION_DENIED',
        'POLICY_BLOCKED',
        'PROVIDER_DISCONNECTED',
        'QUOTE_EXPIRED',
        'RATE_LIMITED',
        'REGION_BLOCKED',
        'REQUEST_TIMEOUT',
        'SESSION_NOT_FOUND',
        'SIMULATION_FAILED',
        'SUBMISSION_UNKNOWN',
        'VALIDATION_FAILED',
        'VERSION_CONFLICT',
      ]);
      for (final copy in LoopErrorText.catalog) {
        expect(
          LoopV2Contract.userMessageKeyPattern.hasMatch(copy.userMessageKey),
          isTrue,
          reason: copy.code,
        );
        if (copy.code == 'INTERNAL_ERROR') {
          expect(copy.userMessageKey, 'errors.internal');
        } else {
          expect(
            copy.userMessageKey.split('.'),
            hasLength(3),
            reason: copy.code,
          );
        }
        expect(copy.title, isNotEmpty, reason: copy.code);
        expect(copy.message, isNotEmpty, reason: copy.code);
        expect(copy.message, isNot(contains('成功')), reason: copy.code);
      }
      // Retired per-V1 keys must not reappear.
      final keys = LoopErrorText.catalog.map((copy) => copy.userMessageKey);
      for (final retired in <String>[
        'errors.intent.expired',
        'errors.authorization.expired',
        'errors.wallet.bindingRequired',
        'errors.idempotency.resourceUnavailable',
      ]) {
        expect(keys, isNot(contains(retired)));
      }
    },
  );

  test('retryable flags mirror decision 0029 and lookups branch on code', () {
    const retryable = <String>{
      'CAPABILITY_UNAVAILABLE',
      'INDEXING_DELAYED',
      'MAINTENANCE',
      'PROVIDER_DISCONNECTED',
      'RATE_LIMITED',
      'REQUEST_TIMEOUT',
    };
    for (final copy in LoopErrorText.catalog) {
      expect(copy.retryable, retryable.contains(copy.code), reason: copy.code);
    }
    for (final notRetryable in <String>[
      'SUBMISSION_UNKNOWN',
      'QUOTE_EXPIRED',
      'DATA_STALE',
    ]) {
      expect(LoopErrorText.forCode(notRetryable).retryable, isFalse);
    }
    expect(LoopErrorText.forCode('QUOTE_EXPIRED').title, '报价已过期');
    expect(
      LoopErrorText.forCode('errors.quote.expired'),
      LoopErrorText.unknown,
    );
    expect(LoopErrorText.forCode(null), LoopErrorText.unknown);
    expect(LoopErrorText.forCode('FUTURE_CODE'), LoopErrorText.unknown);
    expect(LoopErrorText.isKnownCode('INTERNAL_ERROR'), isTrue);
    expect(LoopErrorText.isKnownCode('INTERNAL'), isFalse);
    expect(LoopErrorText.unknown.message, isNot(contains('成功')));
  });

  test('alias and policy copy stay neutral and route-free', () {
    expect(LoopErrorText.forCode('ALIAS_RESERVED').title, '这个名称已被保留');
    expect(LoopErrorText.forCode('ALIAS_BLOCKED').title, '这个名称不可用');
    for (final code in <String>['ALIAS_RESERVED', 'ALIAS_BLOCKED']) {
      final copy = LoopErrorText.forCode(code);
      expect(copy.retryable, isFalse, reason: code);
      expect(
        copy.userMessageKey,
        'errors.alias.${code == 'ALIAS_RESERVED' ? 'reserved' : 'blocked'}',
      );
    }
    // POLICY_BLOCKED must not send the user to a surface LOOP does not have.
    final policy = LoopErrorText.forCode('POLICY_BLOCKED');
    expect(policy.message, isNot(contains('安全中心')));
    expect(policy.message, isNot(contains('设置')));
  });
}
