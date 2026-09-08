import 'package:dio/dio.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

/// Strict V2 transport for the `mining` module (loop-api decision 0036).
///
/// Reads only. Every figure arrives as `{status: "unavailable", reasonCode}`
/// while no mining formula version is approved, and the decoders refuse any
/// other shape rather than inventing a number.
abstract interface class LoopV2MiningApi {
  Future<MiningSummary> getSummary({
    required String accessToken,
    required String clientVersion,
  });

  Future<MiningAssets> getAssets({
    required String accessToken,
    required String clientVersion,
  });

  Future<MiningRewards> getRewards({
    required String accessToken,
    required String clientVersion,
  });

  Future<MiningRank> getRank({
    required String accessToken,
    required String clientVersion,
    required MiningRankScope scope,
  });

  Future<MiningCommunity> getCommunity({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  });

  Future<MiningRules> getRules({
    required String accessToken,
    required String clientVersion,
  });
}

final class DioLoopV2MiningApi implements LoopV2MiningApi {
  DioLoopV2MiningApi(this._dio);

  static const summaryPath = '/v2/mining/summary';
  static const assetsPath = '/v2/mining/assets';
  static const rewardsPath = '/v2/mining/rewards';
  static const rankPath = '/v2/mining/rank';
  static const rulesPath = '/v2/mining/rules';
  static const communitiesPath = '/v2/mining/communities';

  final Dio _dio;

  static String _requireId(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static Never _rethrowRead(DioException error) =>
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );

  static MiningSnapshotRef _snapshot(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] == 'unavailable') {
      return MiningSnapshotUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'snapshotId',
      'blockNumber',
      'blockHash',
      'formulaVersion',
      'priceVersion',
      'computedAt',
    });
    return MiningSnapshotComputed(
      snapshotId: LoopV2S7Codec.requireId(map, 'snapshotId'),
      blockNumber: LoopV2S7Codec.requirePattern(
        map,
        'blockNumber',
        LoopV2S7Codec.blockNumberPattern,
        maxLength: 20,
      ),
      blockHash: LoopV2S7Codec.requirePattern(
        map,
        'blockHash',
        LoopV2S7Codec.blockHashPattern,
        maxLength: 66,
      ),
      formulaVersion: LoopV2S7Codec.requirePattern(
        map,
        'formulaVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
      priceVersion: LoopV2S7Codec.requirePattern(
        map,
        'priceVersion',
        LoopV2S7Codec.priceVersionPattern,
      ),
      computedAt: LoopV2S7Codec.requireTimestamp(map, 'computedAt'),
    );
  }

  static MiningFormulaStatus _formulaStatus(
    Map<String, Object?> source,
    String key, {
    Set<String> allowed = const <String>{'pending_approval', 'approved'},
  }) {
    final status = MiningFormulaStatus.tryParse(
      LoopV2S7Codec.requireEnum(source, key, allowed),
    );
    if (status == null) LoopV2S7Codec.invalid();
    return status;
  }

  static MiningWeightBand _band(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'descriptionKey',
    });
    return MiningWeightBand(
      status: _formulaStatus(map, 'status'),
      descriptionKey: LoopV2S7Codec.requireRuleKey(map, 'descriptionKey'),
    );
  }

  static MiningFormulaVersion _formulaVersion(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'status',
      'effectiveAt',
      'approvedAt',
      'expressionKey',
      'dailyOutputKey',
      'weightRange',
      'priceGuardRules',
      'referralBoost',
    });
    final weightRange = LoopV2Contract.strictMap(
      map['weightRange'],
      const <String>{'loop', 'community', 'reviewFactorKeys'},
    );
    final factors = <String>[];
    for (final entry in LoopV2S7Codec.requireList(
      weightRange['reviewFactorKeys'],
      maximum: 32,
    )) {
      if (entry is! String ||
          entry.isEmpty ||
          entry.length > 128 ||
          !LoopV2S7Codec.ruleKeyPattern.hasMatch(entry)) {
        LoopV2S7Codec.invalid();
      }
      factors.add(entry);
    }
    final guards = <MiningPriceGuardRule>[];
    for (final entry in LoopV2S7Codec.requireList(
      map['priceGuardRules'],
      maximum: 32,
    )) {
      final guard = LoopV2Contract.strictMap(entry, const <String>{
        'ruleKey',
        'status',
      });
      guards.add(
        MiningPriceGuardRule(
          ruleKey: LoopV2S7Codec.requireRuleKey(guard, 'ruleKey'),
          status: _formulaStatus(guard, 'status'),
        ),
      );
    }
    final boost = LoopV2Contract.strictMap(map['referralBoost'], const <String>{
      'status',
    });
    return MiningFormulaVersion(
      configVersion: LoopV2S7Codec.requirePattern(
        map,
        'configVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
      status: _formulaStatus(
        map,
        'status',
        allowed: const <String>{'pending_approval', 'approved', 'retired'},
      ),
      effectiveAt: LoopV2S7Codec.optionalTimestamp(map, 'effectiveAt'),
      approvedAt: LoopV2S7Codec.optionalTimestamp(map, 'approvedAt'),
      expressionKey: LoopV2S7Codec.requireRuleKey(map, 'expressionKey'),
      dailyOutputKey: LoopV2S7Codec.requireRuleKey(map, 'dailyOutputKey'),
      weightRange: MiningWeightRange(
        loop: _band(weightRange['loop']),
        community: _band(weightRange['community']),
        reviewFactorKeys: List<String>.unmodifiable(factors),
      ),
      priceGuardRules: List<MiningPriceGuardRule>.unmodifiable(guards),
      referralBoostStatus: _formulaStatus(boost, 'status'),
    );
  }

  static MiningReferralLevelRule _referralLevel(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'level',
      'boostPercent',
      'descriptionKey',
    });
    final level = LoopV2S7Codec.requirePositiveInt(map, 'level');
    if (level > 5) LoopV2S7Codec.invalid();
    return MiningReferralLevelRule(
      level: level,
      boostPercent: LoopV2S7Codec.requirePattern(
        map,
        'boostPercent',
        RegExp(r'^(0|[1-9][0-9]?)$'),
        maxLength: 2,
      ),
      descriptionKey: LoopV2S7Codec.requireRuleKey(map, 'descriptionKey'),
    );
  }

  @override
  Future<MiningSummary> getSummary({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        summaryPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'power',
        'networkPower',
        'estimatedToday',
        'accumulated',
        'claimable',
        'referralBoost',
        'formula',
        'snapshot',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final formula = LoopV2Contract.strictMap(root['formula'], const <String>{
        'status',
        'reasonCode',
        'pendingVersion',
      });
      if (formula['status'] != 'unavailable') LoopV2S7Codec.invalid();
      return MiningSummary(
        power: LoopV2S7Codec.unavailable(root['power']),
        networkPower: LoopV2S7Codec.unavailable(root['networkPower']),
        estimatedToday: LoopV2S7Codec.unavailable(root['estimatedToday']),
        accumulated: LoopV2S7Codec.unavailable(root['accumulated']),
        claimable: LoopV2S7Codec.unavailable(root['claimable']),
        referralBoost: LoopV2S7Codec.unavailable(root['referralBoost']),
        formula: MiningFormulaGate(
          reasonCode: LoopV2S7Codec.requireEnum(
            formula,
            'reasonCode',
            const <String>{'MINING_FORMULA_BASELINE_PENDING'},
          ),
          pendingVersion: LoopV2S7Codec.optionalPattern(
            formula,
            'pendingVersion',
            LoopV2S7Codec.configVersionPattern,
          ),
        ),
        snapshot: _snapshot(root['snapshot']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<MiningAssets> getAssets({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        assetsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'totalPower',
        'included',
        'excluded',
        'source',
        'referencePrice',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      // Empty by contract, not "this wallet holds nothing".
      LoopV2S7Codec.requireEmptyList(root['included']);
      LoopV2S7Codec.requireEmptyList(root['excluded']);
      return MiningAssets(
        totalPower: LoopV2S7Codec.unavailable(root['totalPower']),
        source: LoopV2S7Codec.unavailable(root['source']),
        referencePrice: LoopV2S7Codec.unavailable(root['referencePrice']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<MiningRewards> getRewards({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        rewardsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'claimable',
        'claimExecutable',
        'estimatedToday',
        'accumulated',
        'ledger',
        'source',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      LoopV2S7Codec.requireEmptyList(root['ledger']);
      return MiningRewards(
        claimable: LoopV2S7Codec.unavailable(root['claimable']),
        // Pinned false: there is no reward authority to claim against.
        claimExecutable: LoopV2S7Codec.requireExactBool(
          root,
          'claimExecutable',
          false,
        ),
        estimatedToday: LoopV2S7Codec.unavailable(root['estimatedToday']),
        accumulated: LoopV2S7Codec.unavailable(root['accumulated']),
        source: LoopV2S7Codec.unavailable(root['source']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<MiningRank> getRank({
    required String accessToken,
    required String clientVersion,
    required MiningRankScope scope,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        rankPath,
        queryParameters: <String, Object?>{'scope': scope.wireName},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'scope',
        'ranking',
        'myPosition',
        'snapshot',
        'display',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final answered = MiningRankScope.tryParse(
        LoopV2S7Codec.requireEnum(root, 'scope', const <String>{
          'users',
          'communities',
        }),
      );
      if (answered != scope) LoopV2S7Codec.invalid();
      final display = LoopV2Contract.strictMap(root['display'], const <String>{
        'anonymousMemberKey',
        'ruleKey',
      });
      return MiningRank(
        scope: answered!,
        ranking: LoopV2S7Codec.unavailable(root['ranking']),
        myPosition: LoopV2S7Codec.unavailable(root['myPosition']),
        snapshot: _snapshot(root['snapshot']),
        display: MiningRankDisplayRule(
          anonymousMemberKey: LoopV2S7Codec.requireEnum(
            display,
            'anonymousMemberKey',
            const <String>{'mining.rank.anonymousMember'},
          ),
          ruleKey: LoopV2S7Codec.requireEnum(display, 'ruleKey', const <String>{
            'mining.rank.display.aliasOrAnonymous',
          }),
        ),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<MiningCommunity> getCommunity({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$communitiesPath/${_requireId(communityId)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'community',
        'weight',
        'communityPower',
        'myContribution',
        'rank',
        'participants',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final community = LoopV2Contract.strictMap(
        root['community'],
        const <String>{'communityId', 'name', 'boundAssetId'},
      );
      final rawWeight = root['weight'];
      if (rawWeight is! Map) LoopV2S7Codec.invalid();
      final MiningCommunityWeight weight;
      if (rawWeight['status'] == 'approved') {
        final map = LoopV2Contract.strictMap(rawWeight, const <String>{
          'status',
          'value',
          'configVersion',
          'reviewedAt',
        });
        weight = MiningCommunityWeightApproved(
          value: LoopV2S7Codec.requirePattern(
            map,
            'value',
            LoopV2S7Codec.decimalPattern,
            maxLength: 140,
          ),
          configVersion: LoopV2S7Codec.requirePattern(
            map,
            'configVersion',
            LoopV2S7Codec.configVersionPattern,
          ),
          reviewedAt: LoopV2S7Codec.requireTimestamp(map, 'reviewedAt'),
        );
      } else {
        final map = LoopV2Contract.strictMap(rawWeight, const <String>{
          'status',
          'reasonCode',
          'reviewStatus',
        });
        if (map['status'] != 'unavailable') LoopV2S7Codec.invalid();
        weight = MiningCommunityWeightPending(
          reasonCode: LoopV2S7Codec.requireReasonCode(map, 'reasonCode'),
          reviewStatus: LoopV2S7Codec.requireEnum(
            map,
            'reviewStatus',
            const <String>{'pending_review'},
          ),
        );
      }
      return MiningCommunity(
        community: MiningCommunityRef(
          communityId: LoopV2S7Codec.requireId(community, 'communityId'),
          name: LoopV2S7Codec.requireText(community, 'name', maxLength: 1024),
          boundAssetId: LoopV2S7Codec.optionalPattern(
            community,
            'boundAssetId',
            LoopV2S7Codec.assetIdPattern,
            maxLength: 80,
          ),
        ),
        weight: weight,
        communityPower: LoopV2S7Codec.unavailable(root['communityPower']),
        myContribution: LoopV2S7Codec.unavailable(root['myContribution']),
        rank: LoopV2S7Codec.unavailable(root['rank']),
        participants: LoopV2S7Codec.unavailable(root['participants']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<MiningRules> getRules({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        rulesPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'approved',
        'pendingApproval',
        'baseline',
        'referral',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final pending = <MiningFormulaVersion>[];
      final seen = <String>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['pendingApproval'],
        maximum: 16,
      )) {
        final version = _formulaVersion(entry);
        if (!seen.add(version.configVersion)) LoopV2S7Codec.invalid();
        pending.add(version);
      }
      final referral = LoopV2Contract.strictMap(
        root['referral'],
        const <String>{'configVersion', 'effectiveAt', 'levels'},
      );
      final levels = <MiningReferralLevelRule>[];
      for (final entry in LoopV2S7Codec.requireList(
        referral['levels'],
        maximum: 5,
      )) {
        levels.add(_referralLevel(entry));
      }
      if (levels.length != 5) LoopV2S7Codec.invalid();
      return MiningRules(
        approved: root['approved'] == null
            ? null
            : _formulaVersion(root['approved']),
        pendingApproval: List<MiningFormulaVersion>.unmodifiable(pending),
        baseline: LoopV2S7Codec.unavailable(root['baseline']),
        referral: MiningReferralRules(
          configVersion: LoopV2S7Codec.requireEnum(
            referral,
            'configVersion',
            const <String>{'referralRulesV1'},
          ),
          effectiveAt: LoopV2S7Codec.requireTimestamp(referral, 'effectiveAt'),
          levels: List<MiningReferralLevelRule>.unmodifiable(levels),
        ),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }
}
