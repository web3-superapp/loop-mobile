import 'package:dio/dio.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict V2 transport for the `community` module (loop-api decision 0031).
///
/// Reads carry no `Idempotency-Key`; writes carry exactly one canonical
/// UUIDv4 supplied by the caller, which owns the logical-operation identity.
/// Every response is parsed with [LoopV2Contract.strictMap] against the frozen
/// key set, so an unknown field is an invalid payload rather than a partially
/// trusted projection.
abstract interface class LoopV2CommunityApi {
  Future<CommunityHome> getHome({
    required String accessToken,
    required String clientVersion,
  });

  Future<CommunityDirectoryPage> listCommunities({
    required String accessToken,
    required String clientVersion,
    required CommunityDirectorySort sort,
    required CommunityVerificationFilter verification,
    required CommunityMembershipFilter membership,
    String? cursor,
  });

  Future<CommunityDetail> createCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required CommunityApplication application,
  });

  Future<CommunityDetail> getCommunity({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  });

  Future<CommunityDetail> patchCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required Map<String, Object?> body,
  });

  Future<CommunityDetail> join({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  });

  Future<CommunityDetail> leave({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  });

  Future<CommunityMemberDirectory> listMembers({
    required String accessToken,
    required String clientVersion,
    required String communityId,
    required CommunityMemberFilter role,
    String? cursor,
  });

  Future<CommunityMemberDirectory> changeMemberRole({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  });

  Future<CommunityMemberDirectory> setMuted({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool muted,
  });

  Future<CommunityMemberDirectory> setBanned({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool banned,
  });

  Future<ReferralRules> getReferralRules({
    required String accessToken,
    required String clientVersion,
  });
}

final class DioLoopV2CommunityApi implements LoopV2CommunityApi {
  DioLoopV2CommunityApi(this._dio);

  static const homePath = '/v2/community/home';
  static const communitiesPath = '/v2/communities';
  static const referralRulesPath = '/v2/mining/referral/rules';

  final Dio _dio;

  static String _requireId(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static Map<String, Object?>? _cursorQuery(String? cursor) {
    if (cursor == null) return null;
    if (cursor.length < 3 ||
        cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
        !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    // `cursor` and `limit` are mutually exclusive: the page size is already
    // encoded in the cursor, so no limit is ever sent alongside it.
    return <String, Object?>{'cursor': cursor};
  }

  @override
  Future<CommunityHome> getHome({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        homePath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'joined',
        'discover',
        'unread',
        'liveVoice',
        'freshness',
        'recommendation',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final joined = LoopV2Contract.strictMap(root['joined'], const <String>{
        'items',
        'truncated',
      });
      final joinedItems = <JoinedCommunity>[];
      for (final raw in LoopV2ProjectionCodec.requireList(
        joined['items'],
        maximum: 50,
      )) {
        final item = LoopV2Contract.strictMap(raw, const <String>{
          'community',
          'membership',
        });
        joinedItems.add(
          JoinedCommunity(
            community: LoopV2ProjectionCodec.community(item['community']),
            membership: LoopV2ProjectionCodec.membership(item['membership']),
          ),
        );
      }
      final discover = <CommunitySummary>[
        for (final raw in LoopV2ProjectionCodec.requireList(
          root['discover'],
          maximum: 5,
        ))
          LoopV2ProjectionCodec.community(raw),
      ];
      final freshness = LoopV2Contract.strictMap(
        root['freshness'],
        const <String>{'observedAt', 'source'},
      );
      if (freshness['source'] != 'database') {
        LoopV2ProjectionCodec.invalid();
      }
      return CommunityHome(
        joined: List<JoinedCommunity>.unmodifiable(joinedItems),
        joinedTruncated: LoopV2ProjectionCodec.requireBool(joined, 'truncated'),
        discover: List<CommunitySummary>.unmodifiable(discover),
        unread: LoopV2ProjectionCodec.unavailable(root['unread']),
        liveVoice: LoopV2ProjectionCodec.unavailable(root['liveVoice']),
        observedAt: LoopV2ProjectionCodec.requireTimestamp(
          freshness,
          'observedAt',
        ),
        source: freshness['source']! as String,
        recommendation: LoopV2ProjectionCodec.recommendation(
          root['recommendation'],
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
  Future<CommunityDirectoryPage> listCommunities({
    required String accessToken,
    required String clientVersion,
    required CommunityDirectorySort sort,
    required CommunityVerificationFilter verification,
    required CommunityMembershipFilter membership,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        communitiesPath,
        queryParameters: <String, Object?>{
          'sort': sort.wireName,
          'verification': verification.wireName,
          'membership': membership.wireName,
          ...?_cursorQuery(cursor),
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'recommendation',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      return CommunityDirectoryPage(
        items: List<CommunitySummary>.unmodifiable(<CommunitySummary>[
          for (final raw in LoopV2ProjectionCodec.requireList(
            root['items'],
            maximum: 50,
          ))
            LoopV2ProjectionCodec.community(raw),
        ]),
        nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
        recommendation: LoopV2ProjectionCodec.recommendation(
          root['recommendation'],
        ),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  Future<CommunityDetail> _detailRequest(
    Future<Response<Object?>> Function() send, {
    required Map<int, Set<String>> allowedCodes,
    int statusCode = 200,
  }) async {
    try {
      final response = await send();
      LoopV2Contract.validateSuccess(response, statusCode: statusCode);
      final root = LoopV2Contract.strictMap(
        response.data,
        LoopV2ProjectionCodec.detailKeys,
      );
      LoopV2ProjectionCodec.requireContractVersion(root);
      return LoopV2ProjectionCodec.detail(root);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: allowedCodes);
    }
  }

  Future<CommunityMemberDirectory> _memberRequest(
    Future<Response<Object?>> Function() send, {
    required Map<int, Set<String>> allowedCodes,
  }) async {
    try {
      final response = await send();
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(
        response.data,
        LoopV2ProjectionCodec.memberDirectoryKeys,
      );
      LoopV2ProjectionCodec.requireContractVersion(root);
      return LoopV2ProjectionCodec.memberDirectory(root);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: allowedCodes);
    }
  }

  @override
  Future<CommunityDetail> createCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required CommunityApplication application,
  }) {
    if (application.invalidField != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return _detailRequest(
      () => _dio.post<Object?>(
        communitiesPath,
        // All five fields are always submitted; three of them may be null.
        data: <String, Object?>{
          'name': application.name,
          'slug': application.slug,
          'description': application.description,
          'logoRef': application.logoRef,
          'boundAssetKey': application.boundAssetKey,
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      ),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
      statusCode: 201,
    );
  }

  @override
  Future<CommunityDetail> getCommunity({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) {
    final id = _requireId(communityId);
    return _detailRequest(
      () => _dio.get<Object?>(
        '$communitiesPath/$id',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      ),
      allowedCodes: LoopV2ModuleRequest.readErrors,
    );
  }

  @override
  Future<CommunityDetail> patchCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required Map<String, Object?> body,
  }) {
    final id = _requireId(communityId);
    if (body.isEmpty) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return _detailRequest(
      () => _dio.patch<Object?>(
        '$communitiesPath/$id',
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      ),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<CommunityDetail> join({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) {
    final id = _requireId(communityId);
    return _detailRequest(
      () => _dio.post<Object?>(
        '$communitiesPath/$id/join',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
        ),
      ),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<CommunityDetail> leave({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) {
    final id = _requireId(communityId);
    return _detailRequest(
      () => _dio.delete<Object?>(
        '$communitiesPath/$id/membership',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
        ),
      ),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<CommunityMemberDirectory> listMembers({
    required String accessToken,
    required String clientVersion,
    required String communityId,
    required CommunityMemberFilter role,
    String? cursor,
  }) {
    final id = _requireId(communityId);
    return _memberRequest(
      () => _dio.get<Object?>(
        '$communitiesPath/$id/members',
        queryParameters: <String, Object?>{
          'role': role.wireName,
          ...?_cursorQuery(cursor),
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      ),
      allowedCodes: LoopV2ModuleRequest.readErrors,
    );
  }

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) {
    final id = _requireId(communityId);
    final target = _requireId(publicProfileId);
    return _memberRequest(
      () => _dio.post<Object?>(
        '$communitiesPath/$id/members/$target/role',
        data: <String, Object?>{'role': role.wireName},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      ),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) {
    final id = _requireId(communityId);
    final target = _requireId(publicProfileId);
    final path = '$communitiesPath/$id/members/$target/mute';
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
    );
    return _memberRequest(
      () => muted
          ? _dio.post<Object?>(path, options: options)
          : _dio.delete<Object?>(path, options: options),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) {
    final id = _requireId(communityId);
    final target = _requireId(publicProfileId);
    final path = '$communitiesPath/$id/members/$target/ban';
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
    );
    return _memberRequest(
      () => banned
          ? _dio.post<Object?>(path, options: options)
          : _dio.delete<Object?>(path, options: options),
      allowedCodes: LoopV2ModuleRequest.writeErrors,
    );
  }

  @override
  Future<ReferralRules> getReferralRules({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        referralRulesPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'configVersion',
        'effectiveAt',
        'appliesTo',
        'levels',
        'edges',
        'inviteCode',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      if (root['configVersion'] != 'referralRulesV1' ||
          root['appliesTo'] != 'miningPower') {
        LoopV2ProjectionCodec.invalid();
      }
      final levels = <ReferralLevel>[];
      for (final raw in LoopV2ProjectionCodec.requireList(
        root['levels'],
        maximum: 5,
      )) {
        final item = LoopV2Contract.strictMap(raw, const <String>{
          'level',
          'boostPercent',
          'descriptionKey',
        });
        final level = item['level'];
        final descriptionKey = item['descriptionKey'];
        if (level is! int ||
            level != levels.length + 1 ||
            level > 5 ||
            descriptionKey is! String ||
            descriptionKey.isEmpty ||
            descriptionKey.length > 128) {
          LoopV2ProjectionCodec.invalid();
        }
        levels.add(
          ReferralLevel(
            level: level,
            // Kept as the server's decimal string; never parsed into a double.
            boostPercent: LoopV2Contract.requiredString(
              item,
              'boostPercent',
              pattern: LoopV2ProjectionCodec.boostPercentPattern,
              maxLength: 16,
            ),
            descriptionKey: descriptionKey,
          ),
        );
      }
      if (levels.length != 5) LoopV2ProjectionCodec.invalid();
      return ReferralRules(
        configVersion: root['configVersion']! as String,
        effectiveAt: LoopV2ProjectionCodec.requireTimestamp(
          root,
          'effectiveAt',
        ),
        appliesTo: root['appliesTo']! as String,
        levels: List<ReferralLevel>.unmodifiable(levels),
        edges: LoopV2ProjectionCodec.unavailable(root['edges']),
        inviteCode: LoopV2ProjectionCodec.unavailable(root['inviteCode']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }
}

/// Maps the V2 error catalogue onto the narrow feature-facing kinds.
CommunityFailureKind communityFailureKindForV2(LoopBackendFailure failure) {
  return switch (failure.code) {
    'PERMISSION_DENIED' ||
    'POLICY_BLOCKED' => CommunityFailureKind.permissionDenied,
    'NOT_FOUND' => CommunityFailureKind.notFound,
    'DATA_STALE' => CommunityFailureKind.stale,
    'PROFILE_ACTIVATION_REQUIRED' => CommunityFailureKind.activationRequired,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => CommunityFailureKind.bootstrapRequired,
    'RESOURCE_CONFLICT' => CommunityFailureKind.resourceConflict,
    'IDEMPOTENCY_CONFLICT' => CommunityFailureKind.idempotencyConflict,
    'VALIDATION_FAILED' => CommunityFailureKind.validationFailed,
    'ALIAS_RESERVED' => CommunityFailureKind.aliasReserved,
    'ALIAS_BLOCKED' => CommunityFailureKind.aliasBlocked,
    'RATE_LIMITED' => CommunityFailureKind.rateLimited,
    'INVALID_REQUEST' || 'VERSION_CONFLICT' => CommunityFailureKind.invalidData,
    _ => switch (failure.kind) {
      LoopBackendFailureKind.connection ||
      LoopBackendFailureKind.timeout => CommunityFailureKind.offline,
      LoopBackendFailureKind.cancelled => CommunityFailureKind.cancelled,
      // A payload the client could not parse leaves a write unresolved: the
      // server may already have applied it.
      LoopBackendFailureKind.invalidPayload =>
        CommunityFailureKind.outcomeUnknown,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        CommunityFailureKind.unavailable,
      _ => CommunityFailureKind.unexpected,
    },
  };
}
