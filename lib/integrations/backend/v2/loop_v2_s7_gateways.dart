import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';

/// Runs one authenticated S7 request and maps every transport failure onto the
/// narrow feature-facing kind. No provider detail ever escapes.
Future<T> executeLaunchRequest<T>(
  LoopAuthenticatedSession session,
  Future<T> Function(String accessToken) request,
) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    throw LaunchException(launchFailureKindForV2(failure));
  } on LaunchException {
    rethrow;
  } catch (_) {
    throw const LaunchException(LaunchFailureKind.unexpected);
  }
}

/// Shared plumbing for the three authenticated S7 adapters.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. These adapters own no credential cache and no generic
/// transport retry; they own only the idempotency key of each idempotent
/// write.
base mixin _LoopV2S7Adapter {
  LoopV2ClientMetadata get clientMetadata;

  LoopAuthenticatedSession get session;

  LoopV2WriteOriginSource? get originSource;

  LoopV2CommandKeyring get keyring;

  String get clientVersion => clientMetadata.clientVersion;

  Future<T> read<T>(Future<T> Function(String accessToken) request) =>
      executeLaunchRequest(session, request);

  Future<LoopV2WriteOrigin?> origin() async =>
      originSource == null ? null : await originSource!.resolve();

  /// A compare-and-set write. There is no idempotency key: the version is what
  /// makes the write safe to repeat.
  Future<T> cas<T>(Future<T> Function(String accessToken) request) =>
      executeLaunchRequest(session, request);

  /// An idempotent write. One logical operation reserves exactly one key; the
  /// key is replayed only while the outcome stays unresolved.
  Future<T> idempotent<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = keyring.reserve(signature);
    try {
      final result = await executeLaunchRequest(
        session,
        (accessToken) => request(accessToken, key),
      );
      keyring.release(signature);
      return result;
    } on LaunchException catch (failure) {
      if (!launchOutcomeIsUnresolved(failure.kind)) {
        keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      keyring.release(signature);
      rethrow;
    }
  }
}

final class DioLoopV2LaunchGateway
    with _LoopV2S7Adapter
    implements LaunchGateway {
  DioLoopV2LaunchGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
    LoopV2CommandKeyring? keyring,
  }) : keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2LaunchApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;
  @override
  final LoopV2CommandKeyring keyring;

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<LaunchOverview> loadOverview() => read(
    (accessToken) => _api.getOverview(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<LaunchDetail> loadLaunch(String launchId) => read(
    (accessToken) => _api.getLaunch(
      accessToken: accessToken,
      clientVersion: clientVersion,
      launchId: launchId,
    ),
  );

  @override
  Future<LaunchEligibility> loadEligibility(String launchId) => read(
    (accessToken) => _api.getEligibility(
      accessToken: accessToken,
      clientVersion: clientVersion,
      launchId: launchId,
    ),
  );

  @override
  Future<LaunchStake> loadStake() => read(
    (accessToken) =>
        _api.getStake(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<LaunchHolders> loadHolders(String launchId) => read(
    (accessToken) => _api.getHolders(
      accessToken: accessToken,
      clientVersion: clientVersion,
      launchId: launchId,
    ),
  );

  @override
  Future<LaunchHistory> loadHistory(String launchId) => read(
    (accessToken) => _api.getHistory(
      accessToken: accessToken,
      clientVersion: clientVersion,
      launchId: launchId,
    ),
  );

  @override
  Future<LaunchEconomy> loadEconomy() => read(
    (accessToken) =>
        _api.getEconomy(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<LaunchProjectPage> listProjects({String? status, String? cursor}) =>
      read(
        (accessToken) => _api.listProjects(
          accessToken: accessToken,
          clientVersion: clientVersion,
          status: status,
          cursor: cursor,
        ),
      );

  @override
  Future<LaunchProject> loadProject(String projectId) => read(
    (accessToken) => _api.getProject(
      accessToken: accessToken,
      clientVersion: clientVersion,
      projectId: projectId,
    ),
  );

  @override
  Future<LaunchMilestones> loadMilestones(String projectId) => read(
    (accessToken) => _api.getMilestones(
      accessToken: accessToken,
      clientVersion: clientVersion,
      projectId: projectId,
    ),
  );

  @override
  Future<LaunchProject> createProject(LaunchProjectDraft draft) async {
    final invalid = draft.invalidField;
    if (invalid != null) {
      return Future<LaunchProject>.error(
        const LaunchException(LaunchFailureKind.validationFailed),
      );
    }
    final writeOrigin = await origin();
    // A changed draft is a new logical operation and gets a fresh key.
    return idempotent(
      'launch:create:${draft.ticker}:${draft.name.trim()}',
      (accessToken, key) => _api.createProject(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        draft: draft,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  }) async {
    final invalid = draft.invalidField;
    if (invalid != null) {
      return Future<LaunchProject>.error(
        const LaunchException(LaunchFailureKind.validationFailed),
      );
    }
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.putProject(
        accessToken: accessToken,
        clientVersion: clientVersion,
        projectId: projectId,
        expectedVersion: expectedVersion,
        draft: draft,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LaunchProject> submitProject(String projectId) async {
    final writeOrigin = await origin();
    return idempotent(
      'launch:submit:$projectId',
      (accessToken, key) => _api.submitProject(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        projectId: projectId,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<Never> submitPurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) async {
    final writeOrigin = await origin();
    return idempotent(
      'launch:intent:$launchId:$roundId:$walletId:$payAmount',
      (accessToken, key) => _api.postPurchaseIntent(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        launchId: launchId,
        walletId: walletId,
        roundId: roundId,
        payAmount: payAmount,
        origin: writeOrigin,
      ),
    );
  }
}

final class DioLoopV2MiningGateway
    with _LoopV2S7Adapter
    implements MiningGateway {
  DioLoopV2MiningGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
    LoopV2CommandKeyring? keyring,
  }) : keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2MiningApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;
  @override
  final LoopV2CommandKeyring keyring;

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningSummary> loadSummary() => read(
    (accessToken) =>
        _api.getSummary(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<MiningAssets> loadAssets() => read(
    (accessToken) =>
        _api.getAssets(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<MiningRewards> loadRewards() => read(
    (accessToken) =>
        _api.getRewards(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<MiningRank> loadRank(MiningRankScope scope) => read(
    (accessToken) => _api.getRank(
      accessToken: accessToken,
      clientVersion: clientVersion,
      scope: scope,
    ),
  );

  @override
  Future<MiningCommunity> loadCommunity(String communityId) => read(
    (accessToken) => _api.getCommunity(
      accessToken: accessToken,
      clientVersion: clientVersion,
      communityId: communityId,
    ),
  );

  @override
  Future<MiningRules> loadRules() => read(
    (accessToken) =>
        _api.getRules(accessToken: accessToken, clientVersion: clientVersion),
  );
}

final class DioLoopV2ReferralGateway
    with _LoopV2S7Adapter
    implements ReferralGateway {
  DioLoopV2ReferralGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
    LoopV2CommandKeyring? keyring,
  }) : keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2ReferralApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;
  @override
  final LoopV2CommandKeyring keyring;

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<ReferralOverview> loadOverview() => read(
    (accessToken) => _api.getOverview(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<ReferralBinding> claim(String inviteCode) async {
    if (!isReferralInviteCodeShaped(inviteCode)) {
      return Future<ReferralBinding>.error(
        const LaunchException(LaunchFailureKind.validationFailed),
      );
    }
    final normalised = normaliseReferralInviteCode(inviteCode);
    final writeOrigin = await origin();
    // A different code is a different logical operation: the server answers
    // `409 IDEMPOTENCY_CONFLICT` if one key were reused for two codes.
    return idempotent(
      'referral:claim:$normalised',
      (accessToken, key) => _api.postClaim(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        inviteCode: normalised,
        origin: writeOrigin,
      ),
    );
  }
}
