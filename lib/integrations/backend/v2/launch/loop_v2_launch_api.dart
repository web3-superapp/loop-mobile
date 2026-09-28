import 'package:dio/dio.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot_tap.dart';

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

  /// `201 {launchIntent, contractVersion}` once the contract is configured;
  /// `503 CAPABILITY_UNAVAILABLE` until then (decision 0076), which reaches
  /// the caller as a [LoopBackendFailure].
  Future<LaunchPurchasePrepared> postPurchaseIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
    LoopV2WriteOrigin? origin,
  });

  /// `POST /v2/launch/{launchId}/intents` with `{kind, walletId}` (loop-api
  /// decision 0087): a claim or a refund intent, the same `201` envelope as a
  /// purchase with `kind` set.
  Future<LaunchPurchasePrepared> postSettlementIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
    LoopV2WriteOrigin? origin,
  });

  /// `GET /v2/launch/{launchId}/intents/{launchIntentId}` (loop-api decision
  /// 0081): the same envelope as the prepare and the report, read-only.
  Future<LaunchPurchaseIntent> getIntent({
    required String accessToken,
    required String clientVersion,
    required String launchId,
    required String launchIntentId,
  });

  /// `POST /v2/launch/{launchId}/intents/{launchIntentId}/broadcast-report`
  /// (loop-api decision 0077): `200 {launchIntent, contractVersion}`, the
  /// same shape as the `201`, now `submitted` with the reported hash.
  Future<LaunchPurchaseIntent> postPurchaseBroadcastReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String launchIntentId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2LaunchApi implements LoopV2LaunchApi {
  DioLoopV2LaunchApi(this._dio, {this._snapshotTap});

  /// Hands the body of a cold-start read to the snapshot store (decision
  /// 0095). `null` stores nothing.
  final LoopV2SnapshotTap? _snapshotTap;

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

  static Never _rethrowIntentWrite(DioException error) =>
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.launchIntentWriteErrors,
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
      // Decision 0076: `null`, or the registered contract (0x + 40 lower hex).
      contractAddress: LoopV2LaunchChainCodec.contractAddress(map),
      configDigest: LoopV2S7Codec.optionalPattern(
        map,
        'configDigest',
        LoopV2S7Codec.digestPattern,
        maxLength: 64,
      ),
      scheduleStatus: schedule,
      onChainState: LoopV2LaunchChainCodec.onChainState(map['onChainState']),
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
    'reviewReasonText',
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
    // Decision 0041: the code is the contract and the text is its display
    // projection, so they arrive or stay absent together. A text without a
    // code, or a code the server forgot to project, is a broken payload and
    // is refused rather than half-rendered.
    final reasonCode = LoopV2S7Codec.optionalPattern(
      map,
      'reviewReasonCode',
      LoopV2S7Codec.reviewReasonPattern,
      maxLength: 64,
    );
    final reasonText = LoopV2S7Codec.optionalText(
      map,
      'reviewReasonText',
      maxLength: 256,
    );
    if ((reasonCode == null) != (reasonText == null)) LoopV2S7Codec.invalid();
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
      reviewReasonCode: reasonCode,
      reviewReasonText: reasonText,
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

  static List<LaunchRound> _rounds(List<Object?> entries) {
    final rounds = <LaunchRound>[];
    final seen = <int>{};
    for (final entry in entries) {
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

  /// The `available` round branch (`getRounds` at the snapshot block).
  static List<LaunchChainRound> _chainRounds(List<Object?> entries) {
    final rounds = <LaunchChainRound>[];
    final seen = <int>{};
    for (final entry in entries) {
      final round = LoopV2LaunchChainCodec.chainRound(entry);
      if (!seen.add(round.roundIndex)) LoopV2S7Codec.invalid();
      rounds.add(round);
    }
    rounds.sort((a, b) => a.roundIndex.compareTo(b.roundIndex));
    return List<LaunchChainRound>.unmodifiable(rounds);
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

  /// The strict decoder of this read, shared by the live answer and by a
  /// stored snapshot of it (decision 0095).
  static LaunchOverview decodeOverview(Object? data) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'segments',
      'graduated',
      'myEligibility',
      'staking',
      'catalog',
      'contractVersion',
    });
    LoopV2S7Codec.requireContractVersion(root);
    final segments = LoopV2Contract.strictMap(root['segments'], const <String>{
      'live',
      'upcoming',
      'awaitingSchedule',
      'ended',
    });
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
          'loop',
        }),
        observedAt: LoopV2S7Codec.requireTimestamp(catalog, 'observedAt'),
      ),
    );
  }

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
      final decoded = decodeOverview(response.data);
      _snapshotTap?.call(LoopSnapshotResource.launchOverview, response.data);
      return decoded;
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
      final launch = _summary(root['launch']);
      final onChain = launch.onChainState is LaunchOnChainAvailable;
      final rawConfig = root['config'];
      final configIsChain = LoopV2LaunchChainCodec.isAvailable(rawConfig);
      // The rounds are decoded in one branch only: a list mixing LOOP slots
      // and contract rounds describes two different sources at once.
      final roundEntries = LoopV2S7Codec.requireList(
        root['rounds'],
        maximum: 64,
      );
      final chainEntries = roundEntries
          .where(LoopV2LaunchChainCodec.isAvailable)
          .length;
      if (chainEntries != 0 && chainEntries != roundEntries.length) {
        LoopV2S7Codec.invalid();
      }
      final roundsAreChain = chainEntries != 0;
      // Decision 0076 reads the axes, the rounds and the config at one block,
      // and publishes the contract address under the same condition. Any
      // other combination is two sources pretending to be one.
      if (onChain != configIsChain ||
          (roundsAreChain && !onChain) ||
          (onChain && launch.contractAddress == null)) {
        LoopV2S7Codec.invalid();
      }
      final saleConfig = configIsChain
          ? LoopV2LaunchChainCodec.saleConfig(rawConfig)
          : null;
      if (saleConfig != null &&
          saleConfig.configVersion !=
              (launch.onChainState as LaunchOnChainAvailable).configVersion) {
        LoopV2S7Codec.invalid();
      }
      return LaunchDetail(
        launch: launch,
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
        config: configIsChain ? null : _config(rawConfig),
        configPending: root['configPending'] == null
            ? null
            : LoopV2S7Codec.unavailable(root['configPending']),
        rounds: roundsAreChain ? const <LaunchRound>[] : _rounds(roundEntries),
        graduation: _graduation(root['graduation']),
        market: LoopV2S7Codec.unavailable(root['market']),
        holders: LoopV2S7Codec.unavailable(root['holders']),
        saleConfig: saleConfig,
        chainRounds: roundsAreChain
            ? _chainRounds(roundEntries)
            : const <LaunchChainRound>[],
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
      return LaunchEligibility(
        launchId: LoopV2S7Codec.requireId(root, 'launchId'),
        mode: mode,
        result: LoopV2LaunchChainCodec.eligibilityResult(root['result']),
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
        holders: LoopV2LaunchChainCodec.holderCount(root['holders']),
        myPosition: LoopV2LaunchChainCodec.position(root['myPosition']),
        walletCap: LoopV2LaunchChainCodec.walletCap(root['walletCap']),
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
      // Decision 0087: `settlements` is optional; the codec decides where it
      // may appear.
      final root = LoopV2Contract.strictMapWithOptional(
        response.data,
        const <String>{
          'launchId',
          'purchaseRecords',
          'entitlements',
          'refunds',
          'source',
          'contractVersion',
        },
        const <String>{'settlements'},
      );
      LoopV2S7Codec.requireContractVersion(root);
      // An unavailable source keeps the three collections empty, exactly as
      // in step 7; an indexed one decodes each row strictly.
      return LoopV2LaunchChainCodec.history(
        root,
        LoopV2S7Codec.requireId(root, 'launchId'),
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
      final root = LoopV2Contract.strictMapWithOptional(
        response.data,
        const <String>{
          'projects',
          'launches',
          'confirmedRoundCount',
          'totalSupply',
          'distributed',
          'ecosystemTax',
          'source',
          'observedAt',
          'contractVersion',
        },
        // S83b.10: present only while a Launch contract is configured.
        const <String>{'onChain'},
      );
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
          'loop',
        }),
        observedAt: LoopV2S7Codec.requireTimestamp(root, 'observedAt'),
        onChain: root.containsKey('onChain')
            ? decodeEconomyOnChain(root['onChain'])
            : null,
      );
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  /// `economy.onChain` (loop-api S83b.10): exactly one of the unavailable
  /// projection or the indexed counts. A `null` value is not the absent key
  /// and is an invalid payload.
  static LaunchEconomyOnChain decodeEconomyOnChain(Object? raw) {
    if (raw is! Map) LoopV2S7Codec.invalid();
    if (raw['status'] == 'unavailable') {
      return LaunchEconomyOnChainUnavailable(
        LoopV2S7Codec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'registeredSaleCount',
      'totalRaisedUsd1',
      'lockedLpCount',
      'source',
      'indexedBlockNumber',
      'indexedBlockHash',
    });
    if (map['status'] != 'available') LoopV2S7Codec.invalid();
    return LaunchEconomyOnChainAvailable(
      registeredSaleCount: LoopV2S7Codec.requireCount(
        map,
        'registeredSaleCount',
      ),
      totalRaisedUsd1: LoopV2S7Codec.requirePattern(
        map,
        'totalRaisedUsd1',
        LoopV2S7Codec.integerAmountPattern,
      ),
      lockedLpCount: LoopV2S7Codec.requireCount(map, 'lockedLpCount'),
      source: LoopV2S7Codec.requireEnum(map, 'source', const <String>{
        'loop_indexer',
      }),
      indexedBlockNumber: LoopV2S7Codec.requirePattern(
        map,
        'indexedBlockNumber',
        LoopV2S7Codec.blockNumberPattern,
      ),
      indexedBlockHash: LoopV2S7Codec.requirePattern(
        map,
        'indexedBlockHash',
        LoopV2S7Codec.blockHashPattern,
      ),
    );
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
  Future<LaunchPurchasePrepared> postPurchaseIntent({
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
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      final intent = _intentEnvelope(response.data);
      // The server answered for this request and no other.
      if (intent.kind != LaunchIntentKind.buy ||
          intent.launchId != launchId ||
          intent.walletId != walletId ||
          intent.roundId != roundId) {
        LoopV2S7Codec.invalid();
      }
      return LaunchPurchasePrepared(intent: intent);
    } on DioException catch (error) {
      _rethrowIntentWrite(error);
    }
  }

  @override
  Future<LaunchPurchasePrepared> postSettlementIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!kind.isSettlement) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        '$launchPath/${_requireId(launchId)}/intents',
        // Exactly these two keys: a round or an amount on a claim / refund
        // is `400 INVALID_REQUEST` (decision 0087).
        data: <String, Object?>{
          'kind': kind.wireName,
          'walletId': _requireId(walletId),
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      final intent = _intentEnvelope(response.data);
      if (intent.kind != kind ||
          intent.launchId != launchId ||
          intent.walletId != walletId) {
        LoopV2S7Codec.invalid();
      }
      return LaunchPurchasePrepared(intent: intent);
    } on DioException catch (error) {
      _rethrowIntentWrite(error);
    }
  }

  @override
  Future<LaunchPurchaseIntent> getIntent({
    required String accessToken,
    required String clientVersion,
    required String launchId,
    required String launchIntentId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$launchPath/${_requireId(launchId)}/intents/'
        '${_requireId(launchIntentId)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final intent = _intentEnvelope(response.data);
      if (intent.launchIntentId != launchIntentId ||
          intent.launchId != launchId) {
        LoopV2S7Codec.invalid();
      }
      return intent;
    } on DioException catch (error) {
      _rethrowRead(error);
    }
  }

  /// `{launchIntent, contractVersion}` and nothing else (decision 0089: the
  /// USD1 balance and allowance are read from the wallet balances, never
  /// from this response).
  static LaunchPurchaseIntent _intentEnvelope(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'launchIntent',
      'contractVersion',
    });
    LoopV2S7Codec.requireContractVersion(root);
    return LoopV2LaunchChainCodec.purchaseIntent(root['launchIntent']);
  }

  static final RegExp _txHashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  @override
  Future<LaunchPurchaseIntent> postPurchaseBroadcastReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String launchId,
    required String launchIntentId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!_txHashPattern.hasMatch(txHash)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        '$launchPath/${_requireId(launchId)}/intents/'
        '${_requireId(launchIntentId)}/broadcast-report',
        data: <String, Object?>{'txHash': txHash},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final intent = _intentEnvelope(response.data);
      // The answer is about this intent and this hash, or it is not an
      // answer to this report.
      final reported = intent.transactionHash;
      if (intent.launchIntentId != launchIntentId ||
          intent.launchId != launchId ||
          (reported != null && reported != txHash.toLowerCase())) {
        LoopV2S7Codec.invalid();
      }
      return intent;
    } on DioException catch (error) {
      _rethrowIntentWrite(error);
    }
  }
}
