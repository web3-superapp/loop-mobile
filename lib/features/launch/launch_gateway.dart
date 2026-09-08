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

  /// The purchase intent. It exists so the page can prove the action is
  /// refused by the server rather than hidden by the client; in this step it
  /// always fails with [LaunchFailureKind.unavailable].
  Future<Never> submitPurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
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
  Future<Never> submitPurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launchGatewayProvider = Provider<LaunchGateway>(
  (ref) => const UnavailableLaunchGateway(),
);
