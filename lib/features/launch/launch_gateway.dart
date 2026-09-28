import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';

/// Feature-facing port for the `launch` module. It exposes no transport type,
/// no `/v2/` literal and no idempotency detail.
abstract interface class LaunchGateway {
  LaunchGatewayMode get mode;

  Future<LaunchOverview> loadOverview();

  Future<LaunchDetail> loadLaunch(String launchId);

  Future<LaunchEligibility> loadEligibility(String launchId);

  Future<LaunchStake> loadStake();

  Future<LaunchHolders> loadHolders(String launchId);

  Future<LaunchHistory> loadHistory(String launchId);

  Future<LaunchEconomy> loadEconomy();

  Future<LaunchProjectPage> listProjects({String? status, String? cursor});

  Future<LaunchProject> loadProject(String projectId);

  Future<LaunchProject> createProject(LaunchProjectDraft draft);

  /// Compare-and-set edit. There is no idempotency key: the version is what
  /// makes the write safe to repeat.
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  });

  Future<LaunchProject> submitProject(String projectId);

  Future<LaunchMilestones> loadMilestones(String projectId);

  /// Prepares one purchase intent (`201 {launchIntent, contractVersion}`).
  ///
  /// While the contract is unconfigured the server answers `503` and this
  /// fails with [LaunchFailureKind.unavailable]; the page renders that
  /// refusal. A prepared intent is only the server's canonical payload: it is
  /// signed through the signing exit, never assembled here.
  Future<LaunchPurchasePrepared> preparePurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  });

  /// Prepares one claim or refund intent (loop-api decision 0087). [kind] is
  /// never [LaunchIntentKind.buy]. The answer is the same envelope as a
  /// purchase; the page signs it through the same exit.
  Future<LaunchPurchasePrepared> prepareSettlementIntent({
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
  });

  /// Reads one Launch intent as the server holds it now (loop-api decision
  /// 0081). It never changes anything; only the server's lanes move `state`.
  Future<LaunchPurchaseIntent> loadIntent({
    required String launchId,
    required String launchIntentId,
  });

  /// Reports the hash the device broadcast for one purchase intent
  /// (decision 0089). The answer is the server's intent, `submitted` with that
  /// hash: pending evidence, never a purchase. It is idempotent for one hash.
  Future<LaunchPurchaseIntent> reportPurchaseBroadcast({
    required String launchId,
    required String launchIntentId,
    required String txHash,
  });
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing launch fact.
final class UnavailableLaunchGateway implements LaunchGateway {
  const UnavailableLaunchGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.unavailable;

  Future<Never> _unavailable() =>
      Future<Never>.error(const LaunchException(LaunchFailureKind.unavailable));

  @override
  Future<LaunchOverview> loadOverview() => _unavailable();

  @override
  Future<LaunchDetail> loadLaunch(String launchId) => _unavailable();

  @override
  Future<LaunchEligibility> loadEligibility(String launchId) => _unavailable();

  @override
  Future<LaunchStake> loadStake() => _unavailable();

  @override
  Future<LaunchHolders> loadHolders(String launchId) => _unavailable();

  @override
  Future<LaunchHistory> loadHistory(String launchId) => _unavailable();

  @override
  Future<LaunchEconomy> loadEconomy() => _unavailable();

  @override
  Future<LaunchProjectPage> listProjects({String? status, String? cursor}) =>
      _unavailable();

  @override
  Future<LaunchProject> loadProject(String projectId) => _unavailable();

  @override
  Future<LaunchProject> createProject(LaunchProjectDraft draft) =>
      _unavailable();

  @override
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  }) => _unavailable();

  @override
  Future<LaunchProject> submitProject(String projectId) => _unavailable();

  @override
  Future<LaunchMilestones> loadMilestones(String projectId) => _unavailable();

  @override
  Future<LaunchPurchasePrepared> preparePurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) => _unavailable();

  @override
  Future<LaunchPurchasePrepared> prepareSettlementIntent({
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
  }) => _unavailable();

  @override
  Future<LaunchPurchaseIntent> loadIntent({
    required String launchId,
    required String launchIntentId,
  }) => _unavailable();

  @override
  Future<LaunchPurchaseIntent> reportPurchaseBroadcast({
    required String launchId,
    required String launchIntentId,
    required String txHash,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launchGatewayProvider = Provider<LaunchGateway>(
  (ref) => const UnavailableLaunchGateway(),
);
