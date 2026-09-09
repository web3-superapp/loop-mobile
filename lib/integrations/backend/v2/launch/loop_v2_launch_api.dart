import 'package:dio/dio.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

/// Strict V2 transport for the `launch` module (loop-api decision 0036).
///
/// Reads carry no `Idempotency-Key`; idempotent writes carry exactly one
/// canonical UUIDv4 supplied by the caller; the compare-and-set edit carries
/// none, because the version is what makes it safe to repeat. Every response
/// is parsed with [LoopV2Contract.strictMap] against the frozen key set, so an
/// unknown field is an invalid payload rather than a partially trusted
/// projection.
abstract interface class LoopV2LaunchApi {
  Future<LaunchOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  });

  Future<LaunchDetail> getLaunch({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  });

  Future<LaunchEligibility> getEligibility({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  });

  Future<LaunchStake> getStake({
    required String accessToken,
    required String clientVersion,
  });

  Future<LaunchHolders> getHolders({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  });

  Future<LaunchHistory> getHistory({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  });

  Future<LaunchEconomy> getEconomy({
    required String accessToken,
    required String clientVersion,
  });

  Future<LaunchProjectPage> listProjects({
    required String accessToken,
    required String clientVersion,
    String? status,
    String? cursor,
  });

  Future<LaunchProject> getProject({
    required String accessToken,
    required String clientVersion,
    required String projectId,
  });

  Future<LaunchProject> createProject({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LaunchProjectDraft draft,
    LoopV2WriteOrigin? origin,
  });

  Future<LaunchProject> putProject({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
    LoopV2WriteOrigin? origin,
  });

  Future<LaunchProject> submitProject({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String projectId,
    LoopV2WriteOrigin? origin,
  });

  Future<LaunchMilestones> getMilestones({
    required String accessToken,
    required String clientVersion,
    required String projectId,
  });

  /// Always throws in this step: the server answers `503` while the Launch
  /// contract baseline is undelivered. It exists so the refusal is the
  /// server's, observed by the client, and never a silently hidden control.
  Future<Never> postPurchaseIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2LaunchApi implements LoopV2LaunchApi {
  DioLoopV2LaunchApi(this._dio);

  static const overviewPath = '/v2/launch/overview';
  static const stakePath = '/v2/launch/stake';
  static const economyPath = '/v2/launch/economy';
  static const projectsPath = '/v2/launch/projects';
  static const launchesPath = '/v2/launches';
  static const launchPath = '/v2/launch';

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

  static Never _rethrowWrite(DioException error) =>
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );

  // -------------------------------------------------------------------------
  // decoders
  // -------------------------------------------------------------------------

  static const _summaryKeys = <String>{
    'launchId',
    'projectId',
    'name',
    'ticker',
    'chainId',
    'contractAddress',
    'configDigest',
    'scheduleStatus',
    'onChainState',
    'configVersion',
    'createdAt',
  };

  static LaunchOnChainState _onChainState(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'saleState',
      'entitlementState',
      'liquidityState',
      'operationalState',
      'stateTupleDigest',
      'snapshotBlockNumber',
      'snapshotBlockHash',
      'source',
      'reasonCode',
    });
    const axisValues = <String>{'unavailable'};
    return LaunchOnChainState(
      saleState: LoopV2S7Codec.requireEnum(map, 'saleState', axisValues),
      entitlementState: LoopV2S7Codec.requireEnum(
        map,
        'entitlementState',
        axisValues,
      ),
      liquidityState: LoopV2S7Codec.requireEnum(
        map,
        'liquidityState',
        axisValues,
      ),
      operationalState: LoopV2S7Codec.requireEnum(
        map,
        'operationalState',
        axisValues,
      ),
      stateTupleDigest: LoopV2S7Codec.requireNull(map, 'stateTupleDigest'),
      snapshotBlockNumber: LoopV2S7Codec.requireNull(
        map,
        'snapshotBlockNumber',
      ),
      snapshotBlockHash: LoopV2S7Codec.requireNull(map, 'snapshotBlockHash'),
      source: LoopV2S7Codec.requireEnum(map, 'source', axisValues),
      reasonCode: LoopV2S7Codec.requireEnum(map, 'reasonCode', const <String>{
        'LAUNCH_CONTRACT_BASELINE_PENDING',
      }),
    );
  }

  static LaunchSummary _summary(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, _summaryKeys);
    final schedule = LaunchScheduleStatus.tryParse(
      LoopV2S7Codec.requireEnum(map, 'scheduleStatus', const <String>{
        'unscheduled',
        'scheduled',
        'live',
        'ended',
      }),
    );
    if (schedule == null) LoopV2S7Codec.invalid();
    return LaunchSummary(
      launchId: LoopV2S7Codec.requireId(map, 'launchId'),
      projectId: LoopV2S7Codec.requireId(map, 'projectId'),
      name: LoopV2S7Codec.requireText(map, 'name'),
      ticker: LoopV2S7Codec.requirePattern(
        map,
        'ticker',
        LoopV2S7Codec.tickerPattern,
        maxLength: 12,
      ),
      // Decision 0038: a launch carries the chain slot it was created on.
      // The set is closed — an unknown chain is an invalid payload, never a
      // network the client silently adopts.
      chainId: LoopV2S7Codec.requireEnum(map, 'chainId', loopKnownChainIds),
      contractAddress: LoopV2S7Codec.requireNull(map, 'contractAddress'),
      configDigest: LoopV2S7Codec.optionalPattern(
        map,
        'configDigest',
        LoopV2S7Codec.digestPattern,
        maxLength: 64,
      ),
      scheduleStatus: schedule,
      onChainState: _onChainState(map['onChainState']),
      configVersion: LoopV2S7Codec.optionalPattern(
        map,
        'configVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
      createdAt: LoopV2S7Codec.requireTimestamp(map, 'createdAt'),
    );
  }

  static List<LaunchSummary> _segment(Object? raw) {
    final items = <LaunchSummary>[];
    final seen = <String>{};
    for (final entry in LoopV2S7Codec.requireList(raw, maximum: 100)) {
      final summary = _summary(entry);
      if (!seen.add(summary.launchId)) LoopV2S7Codec.invalid();
      items.add(summary);
    }
    return List<LaunchSummary>.unmodifiable(items);
  }

  static LaunchOfficialLinks _officialLinks(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'website',
      'x',
      'telegram',
      'discord',
    });
    return LaunchOfficialLinks(
      website: LoopV2S7Codec.optionalHttpsUrl(map, 'website'),
      x: LoopV2S7Codec.optionalHttpsUrl(map, 'x'),
      telegram: LoopV2S7Codec.optionalHttpsUrl(map, 'telegram'),
      discord: LoopV2S7Codec.optionalHttpsUrl(map, 'discord'),
    );
  }

  static const _projectKeys = <String>{
    'projectId',
    'name',
    'ticker',
    'narrative',
    'officialLinks',
    'materialVersion',
    'reviewStatus',
    'reviewReasonCode',
    'kyb',
    'attachments',
    'submittedAt',
    'reviewedAt',
    'launchId',
    'version',
    'createdAt',
    'updatedAt',
    'configVersion',
  };

  static LaunchProject _project(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, _projectKeys);
    final review = LaunchReviewStatus.tryParse(
      LoopV2S7Codec.requireEnum(map, 'reviewStatus', const <String>{
        'draft',
        'submitted',
        'in_review',
        'returned',
        'approved',
        'rejected',
      }),
    );
    if (review == null) LoopV2S7Codec.invalid();
    final kybMap = LoopV2Contract.strictMap(map['kyb'], const <String>{
      'status',
      'state',
      'reasonCode',
    });
    return LaunchProject(
      projectId: LoopV2S7Codec.requireId(map, 'projectId'),
      name: LoopV2S7Codec.requireText(map, 'name'),
      ticker: LoopV2S7Codec.requirePattern(
        map,
        'ticker',
        LoopV2S7Codec.tickerPattern,
        maxLength: 12,
      ),
      narrative: LoopV2S7Codec.optionalText(map, 'narrative'),
      officialLinks: _officialLinks(map['officialLinks']),
      materialVersion: LoopV2S7Codec.requirePositiveInt(map, 'materialVersion'),
      reviewStatus: review,
      reviewReasonCode: LoopV2S7Codec.optionalPattern(
        map,
        'reviewReasonCode',
        LoopV2S7Codec.reviewReasonPattern,
        maxLength: 64,
      ),
      kyb: LaunchKyb(
        status: LoopV2S7Codec.requireEnum(kybMap, 'status', const <String>{
          'unavailable',
        }),
        state: LoopV2S7Codec.requireEnum(kybMap, 'state', const <String>{
          'pending',
          'unavailable',
        }),
        reasonCode: LoopV2S7Codec.requireReasonCode(kybMap, 'reasonCode'),
      ),
      attachments: LoopV2S7Codec.unavailable(map['attachments']),
      submittedAt: LoopV2S7Codec.optionalTimestamp(map, 'submittedAt'),
      reviewedAt: LoopV2S7Codec.optionalTimestamp(map, 'reviewedAt'),
      launchId: LoopV2S7Codec.optionalId(map, 'launchId'),
      version: LoopV2S7Codec.optionalPositiveInt(map, 'version'),
      createdAt: LoopV2S7Codec.requireTimestamp(map, 'createdAt'),
      updatedAt: LoopV2S7Codec.requireTimestamp(map, 'updatedAt'),
      configVersion: LoopV2S7Codec.requireEnum(
        map,
        'configVersion',
        const <String>{'launchCatalogV1'},
      ),
    );
  }

  static LaunchConfigSlot _slot(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] == 'confirmed') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'value',
      });
      return LaunchConfigSlotConfirmed(
        LoopV2S7Codec.requireText(map, 'value', maxLength: 256),
      );
    }
    return LaunchConfigSlotPending(LoopV2S7Codec.unavailable(raw).reasonCode);
  }

  static LaunchConfig? _config(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'status',
      'effectiveAt',
      'slots',
    });
    final status = LaunchConfigStatus.tryParse(
      LoopV2S7Codec.requireEnum(map, 'status', const <String>{
        'pending_confirmation',
        'confirmed',
      }),
    );
    if (status == null) LoopV2S7Codec.invalid();
    final slots = LoopV2Contract.strictMap(map['slots'], const <String>{
      'walletRoundCap',
      'walletProjectCap',
      'feeBps',
      'softCap',
      'hardCap',
      'tge',
      'vesting',
      'tierModeV1',
    });
    return LaunchConfig(
      configVersion: LoopV2S7Codec.requirePattern(
        map,
        'configVersion',
        LoopV2S7Codec.configVersionPattern,
      ),
      status: status,
      effectiveAt: LoopV2S7Codec.optionalTimestamp(map, 'effectiveAt'),
      slots: LaunchConfigSlots(
        walletRoundCap: _slot(slots['walletRoundCap']),
        walletProjectCap: _slot(slots['walletProjectCap']),
        feeBps: _slot(slots['feeBps']),
        softCap: _slot(slots['softCap']),
        hardCap: _slot(slots['hardCap']),
        tge: _slot(slots['tge']),
        vesting: _slot(slots['vesting']),
        tierModeV1: _slot(slots['tierModeV1']),
      ),
    );
  }

  static List<LaunchRound> _rounds(Object? raw) {
    final rounds = <LaunchRound>[];
    final seen = <int>{};
    for (final entry in LoopV2S7Codec.requireList(raw, maximum: 32)) {
      final map = LoopV2Contract.strictMap(entry, const <String>{
        'roundId',
        'roundIndex',
        'configVersion',
        'status',
        'startsAt',
        'endsAt',
        'priceUsd1',
        'eligibilityTier',
        'walletRoundCapRaw',
      });
      final status = LaunchConfigStatus.tryParse(
        LoopV2S7Codec.requireEnum(map, 'status', const <String>{
          'pending_confirmation',
          'confirmed',
        }),
      );
      if (status == null) LoopV2S7Codec.invalid();
      final index = LoopV2S7Codec.requirePositiveInt(map, 'roundIndex');
      if (!seen.add(index)) LoopV2S7Codec.invalid();
      final rawTier = map['eligibilityTier'];
      LaunchEligibilityTier? tier;
      if (rawTier != null) {
        tier = LaunchEligibilityTier.tryParse(
          LoopV2S7Codec.requireEnum(map, 'eligibilityTier', const <String>{
            'priority',
            'community',
            'public',
          }),
        );
        if (tier == null) LoopV2S7Codec.invalid();
      }
      rounds.add(
        LaunchRound(
          roundId: LoopV2S7Codec.requireId(map, 'roundId'),
          roundIndex: index,
          configVersion: LoopV2S7Codec.requirePattern(
            map,
            'configVersion',
            LoopV2S7Codec.configVersionPattern,
          ),
          status: status,
          startsAt: LoopV2S7Codec.optionalTimestamp(map, 'startsAt'),
          endsAt: LoopV2S7Codec.optionalTimestamp(map, 'endsAt'),
          priceUsd1: LoopV2S7Codec.optionalPattern(
            map,
            'priceUsd1',
            LoopV2S7Codec.decimalPattern,
            maxLength: 140,
          ),
          eligibilityTier: tier,
          walletRoundCapRaw: LoopV2S7Codec.optionalPattern(
            map,
            'walletRoundCapRaw',
            LoopV2S7Codec.integerAmountPattern,
            maxLength: 78,
          ),
        ),
      );
    }
    rounds.sort((a, b) => a.roundIndex.compareTo(b.roundIndex));
    return List<LaunchRound>.unmodifiable(rounds);
  }

  static LaunchGraduation _graduation(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'steps',
      'poolEvidence',
    });
    final steps = <LaunchGraduationStep>[];
    final seen = <LaunchGraduationStepKind>{};
    for (final entry in LoopV2S7Codec.requireList(map['steps'], maximum: 8)) {
      final stepMap = LoopV2Contract.strictMap(entry, const <String>{
        'step',
        'status',
      });
      final kind = LaunchGraduationStepKind.tryParse(
        LoopV2S7Codec.requireEnum(stepMap, 'step', const <String>{
          'stop_internal_trading',
          'prepare_pool',
          'add_and_lock_liquidity',
          'open_external_trading',
        }),
      );
      if (kind == null || !seen.add(kind)) LoopV2S7Codec.invalid();
      steps.add(
        LaunchGraduationStep(
          step: kind,
          status: LoopV2S7Codec.requireEnum(stepMap, 'status', const <String>{
            'pending',
          }),
        ),
      );
    }
    if (steps.length != LaunchGraduationStepKind.values.length) {
      LoopV2S7Codec.invalid();
    }
    return LaunchGraduation(
      steps: List<LaunchGraduationStep>.unmodifiable(steps),
      poolEvidence: LoopV2S7Codec.unavailable(map['poolEvidence']),
    );
  }

  // -------------------------------------------------------------------------
  // reads
  // -------------------------------------------------------------------------

  @override
  Future<LaunchOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        overviewPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'segments',
        'graduated',
        'myEligibility',
        'staking',
        'catalog',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final segments = LoopV2Contract.strictMap(
        root['segments'],
        const <String>{'live', 'upcoming', 'awaitingSchedule', 'ended'},
      );
      final catalog = LoopV2Contract.strictMap(root['catalog'], const <String>{
        'configVersion',
        'source',
        'observedAt',
      });
      return LaunchOverview(
        segments: LaunchSegments(
          live: _segment(segments['live']),
          upcoming: _segment(segments['upcoming']),
          awaitingSchedule: _segment(segments['awaitingSchedule']),
          ended: _segment(segments['ended']),
        ),
        graduated: LoopV2S7Codec.unavailable(root['graduated']),
        myEligibility: LoopV2S7Codec.unavailable(root['myEligibility']),
        staking: LoopV2S7Codec.unavailable(root['staking']),
        catalog: LaunchCatalogStamp(
          configVersion: LoopV2S7Codec.requireEnum(
            catalog,
            'configVersion',
            const <String>{'launchCatalogV1'},
          ),
          source: LoopV2S7Codec.requireEnum(catalog, 'source', const <String>{
            'loop_db',
          }),
          observedAt: LoopV2S7Codec.requireTimestamp(catalog, 'observedAt'),
        ),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchDetail> getLaunch({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$launchesPath/${_requireId(launchId)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'launch',
        'project',
        'config',
        'configPending',
        'rounds',
        'graduation',
        'market',
        'holders',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final project = LoopV2Contract.strictMap(root['project'], const <String>{
        'projectId',
        'name',
        'ticker',
        'narrative',
        'officialLinks',
        'materialVersion',
      });
      return LaunchDetail(
        launch: _summary(root['launch']),
        project: LaunchProjectBrief(
          projectId: LoopV2S7Codec.requireId(project, 'projectId'),
          name: LoopV2S7Codec.requireText(project, 'name'),
          ticker: LoopV2S7Codec.requirePattern(
            project,
            'ticker',
            LoopV2S7Codec.tickerPattern,
            maxLength: 12,
          ),
          narrative: LoopV2S7Codec.optionalText(project, 'narrative'),
          officialLinks: _officialLinks(project['officialLinks']),
          materialVersion: LoopV2S7Codec.requirePositiveInt(
            project,
            'materialVersion',
          ),
        ),
        config: _config(root['config']),
        configPending: root['configPending'] == null
            ? null
            : LoopV2S7Codec.unavailable(root['configPending']),
        rounds: _rounds(root['rounds']),
        graduation: _graduation(root['graduation']),
        market: LoopV2S7Codec.unavailable(root['market']),
        holders: LoopV2S7Codec.unavailable(root['holders']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchEligibility> getEligibility({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$launchPath/${_requireId(launchId)}/eligibility',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'launchId',
        'mode',
        'result',
        'configVersion',
        'effectiveAt',
        'dependsOnStaking',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final mode = LaunchEligibilityMode.tryParse(
        LoopV2S7Codec.requireEnum(root, 'mode', const <String>{
          'whitelist',
          'community',
          'activity',
          'unavailable',
        }),
      );
      if (mode == null) LoopV2S7Codec.invalid();
      final result = LoopV2Contract.strictMap(root['result'], const <String>{
        'tier',
        'reasonCode',
        'snapshotBlock',
      });
      return LaunchEligibility(
        launchId: LoopV2S7Codec.requireId(root, 'launchId'),
        mode: mode,
        tier: LoopV2S7Codec.requireNull(result, 'tier'),
        reasonCode: LoopV2S7Codec.requireReasonCode(result, 'reasonCode'),
        snapshotBlock: LoopV2S7Codec.requireNull(result, 'snapshotBlock'),
        configVersion: LoopV2S7Codec.optionalPattern(
          root,
          'configVersion',
          LoopV2S7Codec.configVersionPattern,
        ),
        effectiveAt: LoopV2S7Codec.optionalTimestamp(root, 'effectiveAt'),
        // Pinned false: eligibility never depends on staking.
        dependsOnStaking: LoopV2S7Codec.requireExactBool(
          root,
          'dependsOnStaking',
          false,
        ),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchStake> getStake({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        stakePath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'stake',
        'executable',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      return LaunchStake(
        stake: LoopV2S7Codec.unavailable(root['stake']),
        executable: LoopV2S7Codec.requireExactBool(root, 'executable', false),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchHolders> getHolders({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$launchPath/${_requireId(launchId)}/holders',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'launchId',
        'holders',
        'myPosition',
        'walletCap',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      return LaunchHolders(
        launchId: LoopV2S7Codec.requireId(root, 'launchId'),
        holders: LoopV2S7Codec.unavailable(root['holders']),
        myPosition: LoopV2S7Codec.unavailable(root['myPosition']),
        walletCap: LoopV2S7Codec.unavailable(root['walletCap']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchHistory> getHistory({
    required String accessToken,
    required String clientVersion,
    required String launchId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$launchPath/${_requireId(launchId)}/history',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'launchId',
        'purchaseRecords',
        'entitlements',
        'refunds',
        'source',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      // Empty by contract: the three collections have no item schema while the
      // baseline is undelivered, so a row would be unrenderable.
      LoopV2S7Codec.requireEmptyList(root['purchaseRecords']);
      LoopV2S7Codec.requireEmptyList(root['entitlements']);
      LoopV2S7Codec.requireEmptyList(root['refunds']);
      return LaunchHistory(
        launchId: LoopV2S7Codec.requireId(root, 'launchId'),
        source: LoopV2S7Codec.unavailable(root['source']),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchEconomy> getEconomy({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        economyPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'projects',
        'launches',
        'confirmedRoundCount',
        'totalSupply',
        'distributed',
        'ecosystemTax',
        'source',
        'observedAt',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final projects = LoopV2Contract.strictMap(
        root['projects'],
        const <String>{
          'draft',
          'submitted',
          'in_review',
          'returned',
          'approved',
          'rejected',
        },
      );
      final launches = LoopV2Contract.strictMap(
        root['launches'],
        const <String>{'unscheduled', 'scheduled', 'live', 'ended'},
      );
      return LaunchEconomy(
        projects: LaunchProjectCounts(
          draft: LoopV2S7Codec.requireCount(projects, 'draft'),
          submitted: LoopV2S7Codec.requireCount(projects, 'submitted'),
          inReview: LoopV2S7Codec.requireCount(projects, 'in_review'),
          returned: LoopV2S7Codec.requireCount(projects, 'returned'),
          approved: LoopV2S7Codec.requireCount(projects, 'approved'),
          rejected: LoopV2S7Codec.requireCount(projects, 'rejected'),
        ),
        launches: LaunchScheduleCounts(
          unscheduled: LoopV2S7Codec.requireCount(launches, 'unscheduled'),
          scheduled: LoopV2S7Codec.requireCount(launches, 'scheduled'),
          live: LoopV2S7Codec.requireCount(launches, 'live'),
          ended: LoopV2S7Codec.requireCount(launches, 'ended'),
        ),
        confirmedRoundCount: LoopV2S7Codec.requireCount(
          root,
          'confirmedRoundCount',
        ),
        totalSupply: LoopV2S7Codec.unavailable(root['totalSupply']),
        distributed: LoopV2S7Codec.unavailable(root['distributed']),
        ecosystemTax: LoopV2S7Codec.unavailable(root['ecosystemTax']),
        source: LoopV2S7Codec.requireEnum(root, 'source', const <String>{
          'loop_db',
        }),
        observedAt: LoopV2S7Codec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchProjectPage> listProjects({
    required String accessToken,
    required String clientVersion,
    String? status,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        projectsPath,
        queryParameters: <String, Object?>{
          'status': ?status,
          'cursor': ?cursor,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final items = <LaunchProject>[];
      final seen = <String>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['items'],
        maximum: 50,
      )) {
        final project = _project(entry);
        if (!seen.add(project.projectId)) LoopV2S7Codec.invalid();
        items.add(project);
      }
      return LaunchProjectPage(
        items: List<LaunchProject>.unmodifiable(items),
        nextCursor: LoopV2S7Codec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  static LaunchProject _projectEnvelope(Response<Object?> response, int code) {
    LoopV2Contract.validateSuccess(response, statusCode: code);
    final root = LoopV2Contract.strictMap(response.data, const <String>{
      'project',
      'contractVersion',
    });
    LoopV2S7Codec.requireContractVersion(root);
    return _project(root['project']);
  }

  @override
  Future<LaunchProject> getProject({
    required String accessToken,
    required String clientVersion,
    required String projectId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$projectsPath/${_requireId(projectId)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      return _projectEnvelope(response, 200);
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  @override
  Future<LaunchMilestones> getMilestones({
    required String accessToken,
    required String clientVersion,
    required String projectId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$projectsPath/${_requireId(projectId)}/milestones',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'projectId',
        'items',
        'contractVersion',
      });
      LoopV2S7Codec.requireContractVersion(root);
      final items = <LaunchMilestone>[];
      final seen = <String>{};
      for (final entry in LoopV2S7Codec.requireList(
        root['items'],
        maximum: 64,
      )) {
        final map = LoopV2Contract.strictMap(entry, const <String>{
          'venueMilestoneId',
          'venue',
          'marketType',
          'state',
          'evidence',
          'version',
          'updatedAt',
        });
        final venue = LaunchVenue.tryParse(
          LoopV2S7Codec.requireEnum(map, 'venue', const <String>{
            'lbank',
            'binance',
            'bithumb',
          }),
        );
        final marketType = LaunchMarketType.tryParse(
          LoopV2S7Codec.requireEnum(map, 'marketType', const <String>{
            'spot',
            'alpha',
            'perpetual',
          }),
        );
        final state = LaunchMilestoneState.tryParse(
          LoopV2S7Codec.requireEnum(map, 'state', const <String>{
            'PREPARING',
            'APPLIED',
            'EVIDENCE_PENDING',
            'LISTED',
            'FEATURED',
            'REJECTED',
            'DEFERRED',
            'EVIDENCE_INVALID',
            'DELISTED',
          }),
        );
        if (venue == null || marketType == null || state == null) {
          LoopV2S7Codec.invalid();
        }
        final evidence = LoopV2Contract.strictMap(
          map['evidence'],
          const <String>{'digest', 'recordedAt', 'observedAt', 'reviewer'},
        );
        // An implicit `PREPARING` row carries no id, no version and no
        // update time: the track is listed, but nothing is stored for it.
        final milestoneId = LoopV2S7Codec.optionalId(map, 'venueMilestoneId');
        final version = LoopV2S7Codec.requireCount(map, 'version');
        final updatedAt = LoopV2S7Codec.optionalTimestamp(map, 'updatedAt');
        final implicit = milestoneId == null;
        if (implicit &&
            (state != LaunchMilestoneState.preparing ||
                version != 0 ||
                updatedAt != null)) {
          LoopV2S7Codec.invalid();
        }
        if (!implicit && (version < 1 || updatedAt == null)) {
          LoopV2S7Codec.invalid();
        }
        // A track is addressed by venue and market type; only a stored row
        // also has an id, and neither may repeat.
        if (!seen.add('${venue.wireName}/${marketType.wireName}') ||
            (!implicit && !seen.add(milestoneId))) {
          LoopV2S7Codec.invalid();
        }
        items.add(
          LaunchMilestone(
            venueMilestoneId: milestoneId,
            venue: venue,
            marketType: marketType,
            state: state,
            evidence: LaunchMilestoneEvidence(
              digest: LoopV2S7Codec.optionalPattern(
                evidence,
                'digest',
                LoopV2S7Codec.digestPattern,
                maxLength: 64,
              ),
              recordedAt: LoopV2S7Codec.optionalTimestamp(
                evidence,
                'recordedAt',
              ),
              // Never derived from `recordedAt`: it is the operator's own
              // statement of when the evidence was verifiable on the venue.
              observedAt: LoopV2S7Codec.optionalTimestamp(
                evidence,
                'observedAt',
              ),
              reviewer: LoopV2S7Codec.optionalPattern(
                evidence,
                'reviewer',
                LoopV2S7Codec.reviewerPattern,
                maxLength: 64,
              ),
            ),
            version: version,
            updatedAt: updatedAt,
          ),
        );
      }
      // 03 §8.4 fixes five tracks and the server always returns all five.
      for (final track in launchMilestoneTracks) {
        if (!seen.contains('${track.$1.wireName}/${track.$2.wireName}')) {
          LoopV2S7Codec.invalid();
        }
      }
      return LaunchMilestones(
        projectId: LoopV2S7Codec.requireId(root, 'projectId'),
        items: List<LaunchMilestone>.unmodifiable(items),
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  // -------------------------------------------------------------------------
  // writes
  // -------------------------------------------------------------------------

  @override
  Future<LaunchProject> createProject({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LaunchProjectDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    if (draft.invalidField != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        projectsPath,
        data: draft.toRequestJson(),
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      return _projectEnvelope(response, 201);
    } on DioException catch (error) {
      _rethrowWrite(error);
    }
  }

  @override
  Future<LaunchProject> putProject({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    if (draft.invalidField != null || expectedVersion < 1) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        '$projectsPath/${_requireId(projectId)}',
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'project': draft.toRequestJson(),
        },
        // A compare-and-set write carries no `Idempotency-Key`: the server
        // answers `400` when one is present.
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      return _projectEnvelope(response, 200);
    } on DioException catch (error) {
      _rethrowWrite(error);
    }
  }

  @override
  Future<LaunchProject> submitProject({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String projectId,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        '$projectsPath/${_requireId(projectId)}/submit',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          origin: origin,
        ),
      );
      return _projectEnvelope(response, 200);
    } on DioException catch (error) {
      _rethrowWrite(error);
    }
  }

  @override
  Future<Never> postPurchaseIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!LoopV2S7Codec.decimalPattern.hasMatch(payAmount)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        '$launchPath/${_requireId(launchId)}/intents',
        data: <String, Object?>{
          'walletId': _requireId(walletId),
          'roundId': _requireId(roundId),
          // A string, never a number: the server answers `400` for a number.
          'payAmount': payAmount,
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      // The contract has no success response for this operation in step 7.
      LoopV2Contract.validateSuccess(response, statusCode: 599);
      LoopV2S7Codec.invalid();
    } on DioException catch (error) {
      _rethrowWrite(error);
    }
  }
}
