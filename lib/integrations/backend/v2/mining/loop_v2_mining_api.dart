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

  static MiningFigure _figure(Object? raw) {
    final value = LoopV2S7Codec.availableDecimal(raw);
    if (value != null) return MiningFigureValue(value);
    return MiningFigureUnavailable(LoopV2S7Codec.unavailable(raw).reasonCode);
  }

  static MiningAssetRow _assetRow(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'holding',
      'referencePriceUsd',
      'referencePriceQuality',
      'referencePriceProxyAssetId',
      'weight',
      'power',
      'blockNumber',
    });
    final quality = MiningReferencePriceQuality.tryParse(
      LoopV2S7Codec.requireEnum(map, 'referencePriceQuality', const <String>{
        'fresh',
        'proxied',
      }),
    );
    if (quality == null) LoopV2S7Codec.invalid();
    final proxy = LoopV2S7Codec.optionalPattern(
      map,
      'referencePriceProxyAssetId',
      LoopV2S7Codec.holdingAssetIdPattern,
      maxLength: 80,
    );
    // A proxied price with no proxy, and a fresh price carrying one, both
    // leave the row unable to say where its price came from.
    if (quality.isProxied != (proxy != null)) LoopV2S7Codec.invalid();
    return MiningAssetRow(
      assetId: LoopV2S7Codec.requirePattern(
        map,
        'assetId',
        LoopV2S7Codec.holdingAssetIdPattern,
        maxLength: 80,
      ),
      holding: _decimal(map, 'holding'),
      referencePriceUsd: _decimal(map, 'referencePriceUsd'),
      referencePriceQuality: quality,
      referencePriceProxyAssetId: proxy,
      weight: _decimal(map, 'weight'),
      power: _decimal(map, 'power'),
      blockNumber: LoopV2S7Codec.requirePattern(
        map,
        'blockNumber',
        LoopV2S7Codec.blockNumberPattern,
        maxLength: 20,
      ),
    );
  }

  static MiningExcludedAsset _excludedAsset(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'reasonCode',
    });
    return MiningExcludedAsset(
      assetId: LoopV2S7Codec.requirePattern(
        map,
        'assetId',
        LoopV2S7Codec.holdingAssetIdPattern,
        maxLength: 80,
      ),
      reasonCode: LoopV2S7Codec.requireReasonCode(map, 'reasonCode'),
    );
  }

  static MiningReferencePrice _referencePrice(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] != 'available') {
      return MiningReferencePriceUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'priceVersion',
    });
    return MiningReferencePriceSettled(
      LoopV2S7Codec.requirePattern(
        map,
        'priceVersion',
        LoopV2S7Codec.priceVersionPattern,
      ),
    );
  }

  static String _decimal(Map<String, Object?> source, String key) =>
      LoopV2S7Codec.requirePattern(
        source,
        key,
        LoopV2S7Codec.decimalPattern,
        maxLength: 140,
      );

  /// The board. Both scopes are refused unless the rows agree with the two
  /// facts the board is built on: a row without a position is a zero power,
  /// and the rows that have no position come last.
  static MiningRanking _ranking(Object? raw, MiningRankScope scope) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] != 'available') {
      return MiningRankingUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'scope',
      'items',
      'participants',
    });
    if (LoopV2S7Codec.requireEnum(map, 'scope', const <String>{
          'users',
          'communities',
        }) !=
        scope.wireName) {
      LoopV2S7Codec.invalid();
    }
    final entries = LoopV2S7Codec.requireList(map['items'], maximum: 100);
    final participants = LoopV2S7Codec.requireCount(map, 'participants');
    switch (scope) {
      case MiningRankScope.users:
        final items = <MiningRankUserRow>[];
        final profileIds = <String>{};
        var selfSeen = false;
        var unrankedSeen = false;
        for (final entry in entries) {
          final row = _rankUserRow(entry);
          unrankedSeen = _requireRankOrder(unrankedSeen, row.position);
          if (row.isSelf) {
            // Two rows cannot both be the reader.
            if (selfSeen) LoopV2S7Codec.invalid();
            selfSeen = true;
          }
          final display = row.display;
          if (display is MiningRankAlias &&
              !profileIds.add(display.publicProfileId)) {
            LoopV2S7Codec.invalid();
          }
          items.add(row);
        }
        return MiningRankingUsers(
          items: List<MiningRankUserRow>.unmodifiable(items),
          participants: participants,
        );
      case MiningRankScope.communities:
        final items = <MiningRankCommunityRow>[];
        final communityIds = <String>{};
        var unrankedSeen = false;
        for (final entry in entries) {
          final row = _rankCommunityRow(entry);
          unrankedSeen = _requireRankOrder(unrankedSeen, row.position);
          if (!communityIds.add(row.community.communityId)) {
            LoopV2S7Codec.invalid();
          }
          items.add(row);
        }
        return MiningRankingCommunities(
          items: List<MiningRankCommunityRow>.unmodifiable(items),
          participants: participants,
        );
    }
  }

  /// A ranked row may never follow an unranked one: the board puts every
  /// zero power after the positions, and a page reading it the other way
  /// would print a rank the settlement never gave. Answers whether an
  /// unranked row has been seen by now.
  static bool _requireRankOrder(bool unrankedSeen, int? position) {
    if (position == null) return true;
    if (unrankedSeen) LoopV2S7Codec.invalid();
    return false;
  }

  /// The position and the power a row carries must agree: a position with a
  /// zero power, or a zero power holding a position, is a contradiction.
  static int? _rankItemPosition(Map<String, Object?> map, String power) {
    final position = LoopV2S7Codec.optionalPositiveInt(map, 'position');
    if ((position == null) != miningPowerIsZero(power)) {
      LoopV2S7Codec.invalid();
    }
    return position;
  }

  static MiningRankUserRow _rankUserRow(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'position',
      'power',
      'display',
      'isSelf',
    });
    final power = _decimal(map, 'power');
    return MiningRankUserRow(
      position: _rankItemPosition(map, power),
      power: power,
      display: _rankIdentity(map['display']),
      isSelf: LoopV2S7Codec.requireBool(map, 'isSelf'),
    );
  }

  static MiningRankIdentity _rankIdentity(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['kind'] == 'alias') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'kind',
        'alias',
        'publicProfileId',
      });
      return MiningRankAlias(
        alias: LoopV2S7Codec.requireText(map, 'alias', maxLength: 64),
        publicProfileId: LoopV2S7Codec.requireId(map, 'publicProfileId'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'kind',
      'labelKey',
    });
    if (map['kind'] != 'anonymous') LoopV2S7Codec.invalid();
    return MiningRankAnonymous(
      LoopV2S7Codec.requireEnum(map, 'labelKey', const <String>{
        'mining.rank.anonymousMember',
      }),
    );
  }

  static MiningRankCommunityRow _rankCommunityRow(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'position',
      'power',
      'community',
      'weight',
      'participants',
    });
    final community = LoopV2Contract.strictMap(map['community'], const <String>{
      'communityId',
      'name',
      'boundAssetId',
    });
    final power = _decimal(map, 'power');
    return MiningRankCommunityRow(
      position: _rankItemPosition(map, power),
      power: power,
      community: MiningCommunityRef(
        communityId: LoopV2S7Codec.requireId(community, 'communityId'),
        name: LoopV2S7Codec.requireText(community, 'name', maxLength: 1024),
        // A ranked community is a bound one: the binding is what gave it a
        // power at all.
        boundAssetId: LoopV2S7Codec.requirePattern(
          community,
          'boundAssetId',
          LoopV2S7Codec.assetIdPattern,
          maxLength: 80,
        ),
      ),
      weight: _decimal(map, 'weight'),
      participants: LoopV2S7Codec.requireCount(map, 'participants'),
    );
  }

  /// The reader's own place. A settled position never carries a zero power:
  /// that account is not ranked, and the server says so with its own reason.
  static MiningRankPosition _rankPosition(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] != 'available') {
      return MiningRankPositionUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'position',
      'power',
    });
    final power = _decimal(map, 'power');
    if (miningPowerIsZero(power)) LoopV2S7Codec.invalid();
    return MiningRankPositionSettled(
      position: LoopV2S7Codec.requirePositiveInt(map, 'position'),
      power: power,
    );
  }

  static MiningDailyOutput _dailyOutput(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] != 'available') {
      return MiningDailyOutputUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'value',
      'budget',
      'unitKey',
      'budgetStatus',
      'formulaVersion',
      'scope',
    });
    return MiningDailyOutputEstimate(
      value: LoopV2S7Codec.requirePattern(
        map,
        'value',
        LoopV2S7Codec.decimalPattern,
        maxLength: 140,
      ),
      budget: LoopV2S7Codec.requirePattern(
        map,
        'budget',
        LoopV2S7Codec.decimalPattern,
        maxLength: 140,
      ),
      unitKey: LoopV2S7Codec.requireEnum(map, 'unitKey', const <String>{
        'mining.rules.dailyOutput.unit.loopTokenPending',
      }),
      budgetStatus: LoopV2S7Codec.requireEnum(
        map,
        'budgetStatus',
        const <String>{'development_placeholder'},
      ),
      formulaVersion: LoopV2S7Codec.requirePattern(
        map,
        'formulaVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
      scope: LoopV2S7Codec.formulaScope(map),
    );
  }

  static MiningFormulaGate _formulaGate(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] == 'approved') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'configVersion',
        'effectiveAt',
        'scope',
      });
      return MiningFormulaEffective(
        configVersion: LoopV2S7Codec.requirePattern(
          map,
          'configVersion',
          LoopV2S7Codec.configVersionPattern,
        ),
        effectiveAt: LoopV2S7Codec.requireTimestamp(map, 'effectiveAt'),
        scope: LoopV2S7Codec.formulaScope(map),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
      'pendingVersion',
    });
    if (map['status'] != 'unavailable') LoopV2S7Codec.invalid();
    return MiningFormulaPending(
      reasonCode: LoopV2S7Codec.requireEnum(map, 'reasonCode', const <String>{
        'MINING_FORMULA_BASELINE_PENDING',
      }),
      pendingVersion: LoopV2S7Codec.optionalPattern(
        map,
        'pendingVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
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
      return MiningSummary(
        power: _figure(root['power']),
        networkPower: _figure(root['networkPower']),
        estimatedToday: _dailyOutput(root['estimatedToday']),
        // No reward ledger exists, so these three stay unavailable by
        // contract rather than by absence of data.
        accumulated: LoopV2S7Codec.unavailable(root['accumulated']),
        claimable: LoopV2S7Codec.unavailable(root['claimable']),
        referralBoost: LoopV2S7Codec.unavailable(root['referralBoost']),
        formula: _formulaGate(root['formula']),
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
      final source = _snapshot(root['source']);
      final included = <MiningAssetRow>[];
      final includedIds = <String>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['included'],
        maximum: 500,
      )) {
        final row = _assetRow(entry);
        // The same asset twice would be counted twice by any reader adding
        // the column up.
        if (!includedIds.add(row.assetId)) LoopV2S7Codec.invalid();
        included.add(row);
      }
      final excluded = <MiningExcludedAsset>[];
      final excludedIds = <String>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['excluded'],
        maximum: 500,
      )) {
        final row = _excludedAsset(entry);
        if (!excludedIds.add(row.assetId)) LoopV2S7Codec.invalid();
        excluded.add(row);
      }
      // Without a settlement both lists are empty by contract, so a row here
      // would be a classification nothing produced.
      if (source is MiningSnapshotUnavailable &&
          (included.isNotEmpty || excluded.isNotEmpty)) {
        LoopV2S7Codec.invalid();
      }
      return MiningAssets(
        totalPower: _figure(root['totalPower']),
        included: List<MiningAssetRow>.unmodifiable(included),
        excluded: List<MiningExcludedAsset>.unmodifiable(excluded),
        source: source,
        referencePrice: _referencePrice(root['referencePrice']),
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
        ranking: _ranking(root['ranking'], answered),
        myPosition: _rankPosition(root['myPosition']),
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
        'snapshot',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final community = LoopV2Contract.strictMap(
        root['community'],
        const <String>{'communityId', 'name', 'boundAssetId'},
      );
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
        weight: LoopV2S7Codec.communityWeight(root['weight']),
        communityPower: _figure(root['communityPower']),
        myContribution: _figure(root['myContribution']),
        rank: _rankPosition(root['rank']),
        participants: LoopV2S7Codec.participants(root['participants']),
        snapshot: _snapshot(root['snapshot']),
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
