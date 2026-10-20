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

  /// `GET /v2/referral/invitees` (loop-api decision 0162 §B.1).
  Future<ReferralInviteePage> getInvitees({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  });
}

final class DioLoopV2ReferralApi implements LoopV2ReferralApi {
  DioLoopV2ReferralApi(this._dio);

  static const referralPath = '/v2/referral';
  static const claimPath = '/v2/referral/claim';
  static const inviteesPath = '/v2/referral/invitees';

  static const inviteeKeys = <String>{
    'publicProfileId',
    'alias',
    'avatarRef',
    'boundAt',
    'validationStatus',
  };

  static final RegExp avatarRefPattern = RegExp(
    r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
  );

  final Dio _dio;

  /// The six keys every server sends (decision 0036).
  static const overviewKeys = <String>{
    'inviteCode',
    'binding',
    'levels',
    'boost',
    'rules',
    'contractVersion',
  };

  /// Keys sent only with `REFERRAL_CENTER_EMIT=on` (loop-api decisions 0162
  /// §B.2 / 0166). Absent, the overview decodes exactly as before; any key
  /// outside both sets is still an invalid payload.
  static const overviewOptionalKeys = <String>{'inviteLink', 'stats'};

  static const statsKeys = <String>{
    'directCount',
    'validCount',
    'level2to5Count',
    'validAsOf',
  };

  static const boostAvailableKeys = <String>{
    'status',
    'referralPower',
    'nftReferralPower',
    'assetReferralPower',
    'levels',
    'epochId',
    'hourStart',
    'hourEnd',
  };

  static const boostLevelKeys = <String>{
    'level',
    'effectiveMembers',
    'nftPower',
    'assetPower',
  };

  /// Mining Power: at most 18 fraction digits (the server's `trim_scale`).
  static final RegExp powerPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
  );

  /// `{PUBLIC_BASE_URL}/i/{code}`. An http(s) address without credentials
  /// whose path ends in this account's own code; anything else is refused.
  static String _inviteLink(Object? raw, String code) {
    if (raw is! String ||
        raw.length > 512 ||
        !LoopV2S7Codec.textPattern.hasMatch(raw)) {
      LoopV2S7Codec.invalid();
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.endsWith('/i/$code')) {
      LoopV2S7Codec.invalid();
    }
    return raw;
  }

  static ReferralStats _stats(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, statsKeys);
    final direct = LoopV2S7Codec.requireCount(map, 'directCount');
    final valid = LoopV2S7Codec.requireCount(map, 'validCount');
    if (valid > direct) LoopV2S7Codec.invalid();
    return ReferralStats(
      directCount: direct,
      validCount: valid,
      level2to5Count: LoopV2S7Codec.requireCount(map, 'level2to5Count'),
      validAsOf: LoopV2S7Codec.optionalTimestamp(map, 'validAsOf'),
    );
  }

  static ReferralBoostAvailable _boostAvailable(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, boostAvailableKeys);
    if (map['status'] != 'available') LoopV2S7Codec.invalid();
    String power(Map<String, Object?> source, String key) =>
        LoopV2S7Codec.requirePattern(source, key, powerPattern, maxLength: 97);
    final levels = <ReferralBoostLevel>[];
    final seen = <int>{};
    for (final entry in LoopV2S7Codec.requireList(map['levels'], maximum: 5)) {
      final level = LoopV2Contract.strictMap(entry, boostLevelKeys);
      final depth = LoopV2S7Codec.requirePositiveInt(level, 'level');
      if (depth > 5 || !seen.add(depth)) LoopV2S7Codec.invalid();
      levels.add(
        ReferralBoostLevel(
          level: depth,
          effectiveMembers: LoopV2S7Codec.requireCount(
            level,
            'effectiveMembers',
          ),
          nftPower: power(level, 'nftPower'),
          assetPower: power(level, 'assetPower'),
        ),
      );
    }
    if (levels.length != 5) LoopV2S7Codec.invalid();
    levels.sort((a, b) => a.level.compareTo(b.level));
    final hourStart = LoopV2S7Codec.requireTimestamp(map, 'hourStart');
    final hourEnd = LoopV2S7Codec.requireTimestamp(map, 'hourEnd');
    if (!hourEnd.isAfter(hourStart)) LoopV2S7Codec.invalid();
    return ReferralBoostAvailable(
      referralPower: power(map, 'referralPower'),
      nftReferralPower: power(map, 'nftReferralPower'),
      assetReferralPower: power(map, 'assetReferralPower'),
      levels: List<ReferralBoostLevel>.unmodifiable(levels),
      epochId: LoopV2S7Codec.requireId(map, 'epochId'),
      hourStart: hourStart,
      hourEnd: hourEnd,
    );
  }

  static ReferralInvitee _invitee(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, inviteeKeys);
    final status = ReferralInviteeStatus.tryParse(map['validationStatus']);
    if (status == null) LoopV2S7Codec.invalid();
    final id = LoopV2S7Codec.optionalId(map, 'publicProfileId');
    final alias = LoopV2S7Codec.optionalText(map, 'alias', maxLength: 1024);
    final avatar = LoopV2S7Codec.optionalPattern(
      map,
      'avatarRef',
      avatarRefPattern,
      maxLength: 134,
    );
    // A hidden profile hides all of it: an alias or a face without the id
    // would draw a row that opens nothing while looking like it should.
    if (id == null && (alias != null || avatar != null)) {
      LoopV2S7Codec.invalid();
    }
    return ReferralInvitee(
      publicProfileId: id,
      alias: alias,
      avatarRef: avatar,
      boundAt: LoopV2S7Codec.requireTimestamp(map, 'boundAt'),
      status: status,
    );
  }

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
      final root = LoopV2Contract.strictMapWithOptional(
        response.data,
        overviewKeys,
        overviewOptionalKeys,
      );
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
      final inviteCode = LoopV2S7Codec.requirePattern(
        code,
        'code',
        ReferralInviteCode.pattern,
        maxLength: 10,
      );
      final boost = root['boost'];
      final boostAvailable = boost is Map && boost['status'] == 'available'
          ? _boostAvailable(boost)
          : null;
      return ReferralOverview(
        inviteCode: ReferralInviteCode(
          code: inviteCode,
          issuedAt: LoopV2S7Codec.requireTimestamp(code, 'issuedAt'),
        ),
        binding: _binding(root['binding']),
        levels: List<ReferralLevel>.unmodifiable(levels),
        boost: boostAvailable == null ? LoopV2S7Codec.unavailable(boost) : null,
        boostAvailable: boostAvailable,
        inviteLink: root.containsKey('inviteLink')
            ? _inviteLink(root['inviteLink'], inviteCode)
            : null,
        stats: root.containsKey('stats') ? _stats(root['stats']) : null,
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

  @override
  Future<ReferralInviteePage> getInvitees({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > 1536 ||
            !LoopV2S7Codec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        inviteesPath,
        queryParameters: <String, Object?>{'cursor': ?cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final items = <ReferralInvitee>[
        for (final entry in LoopV2S7Codec.requireList(
          root['items'],
          maximum: 50,
        ))
          _invitee(entry),
      ];
      return ReferralInviteePage(
        items: List<ReferralInvitee>.unmodifiable(items),
        nextCursor: LoopV2S7Codec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }
}
