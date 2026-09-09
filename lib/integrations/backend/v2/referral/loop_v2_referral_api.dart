import 'package:dio/dio.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

/// Strict V2 transport for the `referral` module (loop-api decision 0036).
///
/// The read issues this account's single invite code server-side; the claim is
/// an idempotent write carrying exactly one canonical UUIDv4. The inviter's
/// identity is never part of either projection.
abstract interface class LoopV2ReferralApi {
  Future<ReferralOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  });

  Future<ReferralBinding> postClaim({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String inviteCode,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2ReferralApi implements LoopV2ReferralApi {
  DioLoopV2ReferralApi(this._dio);

  static const referralPath = '/v2/referral';
  static const claimPath = '/v2/referral/claim';

  final Dio _dio;

  static ReferralClaimWindow _claimWindow(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] == 'unavailable') {
      return ReferralClaimWindowUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'activatedAt',
      'closesAt',
    });
    final status = LoopV2S7Codec.requireEnum(map, 'status', const <String>{
      'open',
      'closed',
    });
    return ReferralClaimWindowTimed(
      isOpen: status == 'open',
      activatedAt: LoopV2S7Codec.requireTimestamp(map, 'activatedAt'),
      closesAt: LoopV2S7Codec.requireTimestamp(map, 'closesAt'),
    );
  }

  static ReferralBinding _binding(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'inviter',
      'claimWindow',
    });
    final status = LoopV2S7Codec.requireEnum(map, 'status', const <String>{
      'bound',
      'unbound',
    });
    ReferralInviter? inviter;
    if (map['inviter'] != null) {
      final source = LoopV2Contract.strictMap(map['inviter'], const <String>{
        'depth',
        'validationStatus',
        'lockedAt',
        'effectiveFrom',
        'configVersion',
      });
      final validation = ReferralValidationStatus.tryParse(
        LoopV2S7Codec.requireEnum(source, 'validationStatus', const <String>{
          'pending_activation',
          'pending_wallet',
          'pending_mining',
          'valid',
          'invalidated',
        }),
      );
      final depth = LoopV2S7Codec.requirePositiveInt(source, 'depth');
      if (validation == null || depth != 1) LoopV2S7Codec.invalid();
      inviter = ReferralInviter(
        depth: depth,
        validationStatus: validation,
        lockedAt: LoopV2S7Codec.requireTimestamp(source, 'lockedAt'),
        effectiveFrom: LoopV2S7Codec.requireTimestamp(source, 'effectiveFrom'),
        configVersion: LoopV2S7Codec.requirePattern(
          source,
          'configVersion',
          LoopV2S7Codec.configVersionPattern,
        ),
      );
    }
    final isBound = status == 'bound';
    // The two facts must agree: a bound account carries its edge, an unbound
    // one carries none.
    if (isBound != (inviter != null)) LoopV2S7Codec.invalid();
    return ReferralBinding(
      isBound: isBound,
      inviter: inviter,
      claimWindow: _claimWindow(map['claimWindow']),
    );
  }

  static ReferralBinding _bindingEnvelope(Response<Object?> response) {
    LoopV2Contract.validateSuccess(response, statusCode: 200);
    final root = LoopV2Contract.strictMap(response.data, const <String>{
      'binding',
      'contractVersion',
    });
    LoopV2S7Codec.requireContractVersion(root);
    return _binding(root['binding']);
  }

  @override
  Future<ReferralOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        referralPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'inviteCode',
        'binding',
        'levels',
        'boost',
        'rules',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final code = LoopV2Contract.strictMap(root['inviteCode'], const <String>{
        'code',
        'issuedAt',
      });
      final levels = <ReferralLevel>[];
      final seen = <int>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['levels'],
        maximum: 5,
      )) {
        final map = LoopV2Contract.strictMap(entry, const <String>{
          'level',
          'boostPercent',
          'counts',
          'total',
        });
        final level = LoopV2S7Codec.requirePositiveInt(map, 'level');
        if (level > 5 || !seen.add(level)) LoopV2S7Codec.invalid();
        final counts = LoopV2Contract.strictMap(map['counts'], const <String>{
          'pending_activation',
          'pending_wallet',
          'pending_mining',
          'valid',
          'invalidated',
        });
        final parsed = ReferralValidationCounts(
          pendingActivation: LoopV2S7Codec.requireCount(
            counts,
            'pending_activation',
          ),
          pendingWallet: LoopV2S7Codec.requireCount(counts, 'pending_wallet'),
          pendingMining: LoopV2S7Codec.requireCount(counts, 'pending_mining'),
          valid: LoopV2S7Codec.requireCount(counts, 'valid'),
          invalidated: LoopV2S7Codec.requireCount(counts, 'invalidated'),
        );
        final total = LoopV2S7Codec.requireCount(map, 'total');
        if (total !=
            parsed.pendingActivation +
                parsed.pendingWallet +
                parsed.pendingMining +
                parsed.valid +
                parsed.invalidated) {
          LoopV2S7Codec.invalid();
        }
        levels.add(
          ReferralLevel(
            level: level,
            boostPercent: LoopV2S7Codec.requirePattern(
              map,
              'boostPercent',
              RegExp(r'^(0|[1-9][0-9]?)$'),
              maxLength: 2,
            ),
            counts: parsed,
            total: total,
          ),
        );
      }
      if (levels.length != 5) LoopV2S7Codec.invalid();
      levels.sort((a, b) => a.level.compareTo(b.level));
      final rules = LoopV2Contract.strictMap(root['rules'], const <String>{
        'configVersion',
        'effectiveAt',
        'appliesTo',
        'maximumDepth',
        'claimWindowDays',
      });
      return ReferralOverview(
        inviteCode: ReferralInviteCode(
          code: LoopV2S7Codec.requirePattern(
            code,
            'code',
            ReferralInviteCode.pattern,
            maxLength: 10,
          ),
          issuedAt: LoopV2S7Codec.requireTimestamp(code, 'issuedAt'),
        ),
        binding: _binding(root['binding']),
        levels: List<ReferralLevel>.unmodifiable(levels),
        boost: LoopV2S7Codec.unavailable(root['boost']),
        rules: ReferralRulesInfo(
          configVersion: LoopV2S7Codec.requireEnum(
            rules,
            'configVersion',
            const <String>{'referralRulesV1'},
          ),
          effectiveAt: LoopV2S7Codec.requireTimestamp(rules, 'effectiveAt'),
          appliesTo: LoopV2S7Codec.requireEnum(
            rules,
            'appliesTo',
            const <String>{'miningPower'},
          ),
          maximumDepth: LoopV2S7Codec.requirePositiveInt(rules, 'maximumDepth'),
          claimWindowDays: LoopV2S7Codec.requirePositiveInt(
            rules,
            'claimWindowDays',
          ),
        ),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<ReferralBinding> postClaim({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String inviteCode,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!isReferralInviteCodeShaped(inviteCode)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        claimPath,
        data: <String, Object?>{
          'inviteCode': normaliseReferralInviteCode(inviteCode),
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      return _bindingEnvelope(response);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }
}
