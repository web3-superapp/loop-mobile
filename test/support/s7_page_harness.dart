import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 's7_fixtures.dart';

/// A port double that answers with a fixed value, a fixed failure, or never.
///
/// `pending` keeps the loading state visible; `failure` drives the error,
/// offline, unavailable and permission states from one place.
final class S7Answer<T> {
  S7Answer({this.value, this.failure, this.pending = false});

  final T? value;
  final LaunchFailureKind? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final kind = failure;
    if (kind != null) return Future<T>.error(LaunchException(kind));
    return Future<T>.value(value as T);
  }
}

final class FakeLaunchGateway implements LaunchGateway {
  FakeLaunchGateway({
    S7Answer<LaunchOverview>? overview,
    S7Answer<LaunchDetail>? detail,
    S7Answer<LaunchEligibility>? eligibility,
    S7Answer<LaunchStake>? stake,
    S7Answer<LaunchHolders>? holders,
    S7Answer<LaunchHistory>? history,
    S7Answer<LaunchEconomy>? economy,
    S7Answer<LaunchProjectPage>? projects,
    S7Answer<LaunchMilestones>? milestones,
    this.createFailure,
    this.updateFailure,
    this.submitFailure,
    this.intentFailure = LaunchFailureKind.unavailable,
    this.mode = LaunchGatewayMode.production,
  }) : overview = overview ?? S7Answer<LaunchOverview>(value: s7Overview()),
       detail = detail ?? S7Answer<LaunchDetail>(value: s7Detail()),
       eligibility =
           eligibility ?? S7Answer<LaunchEligibility>(value: s7Eligibility()),
       stake = stake ?? S7Answer<LaunchStake>(value: s7Stake()),
       holders = holders ?? S7Answer<LaunchHolders>(value: s7Holders()),
       history = history ?? S7Answer<LaunchHistory>(value: s7History()),
       economy = economy ?? S7Answer<LaunchEconomy>(value: s7Economy()),
       projects =
           projects ??
           S7Answer<LaunchProjectPage>(
             value: const LaunchProjectPage(
               items: <LaunchProject>[],
               nextCursor: null,
             ),
           ),
       milestones =
           milestones ?? S7Answer<LaunchMilestones>(value: s7Milestones());

  final S7Answer<LaunchOverview> overview;
  final S7Answer<LaunchDetail> detail;
  final S7Answer<LaunchEligibility> eligibility;
  final S7Answer<LaunchStake> stake;
  final S7Answer<LaunchHolders> holders;
  final S7Answer<LaunchHistory> history;
  final S7Answer<LaunchEconomy> economy;
  final S7Answer<LaunchProjectPage> projects;
  final S7Answer<LaunchMilestones> milestones;
  final LaunchFailureKind? createFailure;
  final LaunchFailureKind? updateFailure;
  final LaunchFailureKind? submitFailure;
  final LaunchFailureKind intentFailure;

  final List<LaunchProjectDraft> created = <LaunchProjectDraft>[];
  final List<LaunchProjectDraft> updated = <LaunchProjectDraft>[];
  final List<int> expectedVersions = <int>[];
  final List<String> submitted = <String>[];
  final List<String> intents = <String>[];
  final List<String> requestedLaunchIds = <String>[];

  @override
  final LaunchGatewayMode mode;

  @override
  Future<LaunchOverview> loadOverview() => overview.resolve();

  @override
  Future<LaunchDetail> loadLaunch(String launchId) {
    requestedLaunchIds.add(launchId);
    return detail.resolve();
  }

  @override
  Future<LaunchEligibility> loadEligibility(String launchId) {
    requestedLaunchIds.add(launchId);
    return eligibility.resolve();
  }

  @override
  Future<LaunchStake> loadStake() => stake.resolve();

  @override
  Future<LaunchHolders> loadHolders(String launchId) {
    requestedLaunchIds.add(launchId);
    return holders.resolve();
  }

  @override
  Future<LaunchHistory> loadHistory(String launchId) {
    requestedLaunchIds.add(launchId);
    return history.resolve();
  }

  @override
  Future<LaunchEconomy> loadEconomy() => economy.resolve();

  @override
  Future<LaunchProjectPage> listProjects({String? status, String? cursor}) =>
      projects.resolve();

  @override
  Future<LaunchProject> loadProject(String projectId) =>
      Future<LaunchProject>.value(s7Project(projectId: projectId));

  @override
  Future<LaunchMilestones> loadMilestones(String projectId) =>
      milestones.resolve();

  @override
  Future<LaunchProject> createProject(LaunchProjectDraft draft) {
    created.add(draft);
    final failure = createFailure;
    if (failure != null) {
      return Future<LaunchProject>.error(LaunchException(failure));
    }
    return Future<LaunchProject>.value(s7Project());
  }

  @override
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  }) {
    updated.add(draft);
    expectedVersions.add(expectedVersion);
    final failure = updateFailure;
    if (failure != null) {
      return Future<LaunchProject>.error(LaunchException(failure));
    }
    return Future<LaunchProject>.value(
      s7Project(projectId: projectId, version: expectedVersion + 1),
    );
  }

  @override
  Future<LaunchProject> submitProject(String projectId) {
    submitted.add(projectId);
    final failure = submitFailure;
    if (failure != null) {
      return Future<LaunchProject>.error(LaunchException(failure));
    }
    return Future<LaunchProject>.value(
      s7Project(
        projectId: projectId,
        reviewStatus: LaunchReviewStatus.submitted,
        submittedAt: DateTime.utc(2026, 9, 9, 7),
      ),
    );
  }

  @override
  Future<Never> submitPurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) {
    intents.add('$launchId:$roundId:$payAmount');
    return Future<Never>.error(LaunchException(intentFailure));
  }
}

final class FakeMiningGateway implements MiningGateway {
  FakeMiningGateway({
    S7Answer<MiningSummary>? summary,
    S7Answer<MiningAssets>? assets,
    S7Answer<MiningRewards>? rewards,
    S7Answer<MiningRank>? rank,
    S7Answer<MiningCommunity>? community,
    S7Answer<MiningRules>? rules,
    this.mode = LaunchGatewayMode.production,
  }) : summary = summary ?? S7Answer<MiningSummary>(value: s7MiningSummary()),
       assets = assets ?? S7Answer<MiningAssets>(value: s7MiningAssets()),
       rewards = rewards ?? S7Answer<MiningRewards>(value: s7MiningRewards()),
       rank = rank ?? S7Answer<MiningRank>(value: s7MiningRank()),
       community =
           community ?? S7Answer<MiningCommunity>(value: s7MiningCommunity()),
       rules = rules ?? S7Answer<MiningRules>(value: s7MiningRules());

  final S7Answer<MiningSummary> summary;
  final S7Answer<MiningAssets> assets;
  final S7Answer<MiningRewards> rewards;
  final S7Answer<MiningRank> rank;
  final S7Answer<MiningCommunity> community;
  final S7Answer<MiningRules> rules;

  final List<MiningRankScope> scopes = <MiningRankScope>[];
  final List<String> requestedCommunityIds = <String>[];

  @override
  final LaunchGatewayMode mode;

  @override
  Future<MiningSummary> loadSummary() => summary.resolve();

  @override
  Future<MiningAssets> loadAssets() => assets.resolve();

  @override
  Future<MiningRewards> loadRewards() => rewards.resolve();

  @override
  Future<MiningRank> loadRank(MiningRankScope scope) {
    scopes.add(scope);
    final answer = rank;
    if (answer.value == null) return answer.resolve();
    return Future<MiningRank>.value(s7MiningRank(scope: scope));
  }

  @override
  Future<MiningCommunity> loadCommunity(String communityId) {
    requestedCommunityIds.add(communityId);
    return community.resolve();
  }

  @override
  Future<MiningRules> loadRules() => rules.resolve();
}

final class FakeReferralGateway implements ReferralGateway {
  FakeReferralGateway({
    S7Answer<ReferralOverview>? overview,
    this.claimFailure,
    this.mode = LaunchGatewayMode.production,
  }) : overview = overview ?? S7Answer<ReferralOverview>(value: s7Referral());

  final S7Answer<ReferralOverview> overview;
  final LaunchFailureKind? claimFailure;

  final List<String> claims = <String>[];

  @override
  final LaunchGatewayMode mode;

  @override
  Future<ReferralOverview> loadOverview() => overview.resolve();

  @override
  Future<ReferralBinding> claim(String inviteCode) {
    claims.add(inviteCode);
    final failure = claimFailure;
    if (failure != null) {
      return Future<ReferralBinding>.error(LaunchException(failure));
    }
    return Future<ReferralBinding>.value(s7BoundBinding());
  }
}

/// The wallet directory `launch-trade` reads to find the paying wallet. Only
/// the active id matters here; every other wallet read stays unavailable.
final class FakeWalletDirectory implements WalletReadGateway {
  FakeWalletDirectory({this.activeWalletId});

  final String? activeWalletId;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopWalletDirectory> loadWallets() =>
      Future<LoopWalletDirectory>.value(
        LoopWalletDirectory(
          wallets: const <LoopWalletAccount>[],
          activeWalletId: activeWalletId,
          observedAt: DateTime.utc(2026, 9, 9, 6),
        ),
      );

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) => _unavailable();

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) => _unavailable();

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => _unavailable();

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) => _unavailable();
}

/// A capability document where the three S7 ids can be flipped independently.
///
/// `launch` and `mining` read `available` with **pending evidence**: the
/// catalogue works while the contract and formula baselines are undelivered.
LoopV2MetaSnapshot s7MetaSnapshot({
  LoopV2CapabilityAvailability launch = LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability mining = LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability referral =
      LoopV2CapabilityAvailability.available,
  // Step 7's real server always reports pending Launch evidence. Setting this
  // false is how a test proves the page is driven by the evidence rather than
  // by a hard-coded reason code of its own.
  bool launchEvidencePending = true,
  // Decision 0038: the backend publishes this only while the Launch slot
  // differs from the primary chain, so `null` is the ordinary document.
  String? launchChainId,
}) {
  return LoopV2MetaSnapshot(
    clientPolicy: LoopV2ClientPolicy(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      defaultRoute: LoopV2PrimaryTab.community,
      navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
      versionGate: const LoopV2VersionGate.unavailable(
        reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
      ),
      regionGate: const LoopV2RegionGate(
        status: LoopV2RegionGateStatus.unavailable,
        reasonCode: 'REGION_POLICY_UNAVAILABLE',
        supportUrl: null,
        readOnlyAssetAccess: null,
      ),
      termsGate: const LoopV2TermsGate(
        status: LoopV2TermsGateStatus.unavailable,
        requiredVersion: null,
        reasonCode: 'TERMS_POLICY_UNAVAILABLE',
      ),
    ),
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      capabilities: <LoopV2Capability>[
        for (final id in LoopV2CapabilityId.values)
          LoopV2Capability(
            id: id,
            availability: switch (id) {
              LoopV2CapabilityId.launch => launch,
              LoopV2CapabilityId.mining => mining,
              LoopV2CapabilityId.referral => referral,
              _ => LoopV2CapabilityAvailability.unavailable,
            },
            reasonCode: switch (id) {
              LoopV2CapabilityId.launch =>
                launch == LoopV2CapabilityAvailability.available
                    ? null
                    : 'LAUNCH_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.mining =>
                mining == LoopV2CapabilityAvailability.available
                    ? null
                    : 'MINING_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.referral =>
                referral == LoopV2CapabilityAvailability.available
                    ? null
                    : 'REFERRAL_RUNTIME_UNAVAILABLE',
              _ => 'CAPABILITY_NOT_DELIVERED',
            },
            evidence: switch (id) {
              LoopV2CapabilityId.launch => LoopV2CapabilityEvidence(
                status: launchEvidencePending
                    ? LoopV2CapabilityEvidenceStatus.pending
                    : LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: launchEvidencePending
                    ? 'LAUNCH_CONTRACT_BASELINE_PENDING'
                    : null,
                launchChainId: launchChainId,
              ),
              LoopV2CapabilityId.mining ||
              LoopV2CapabilityId.referral => const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.pending,
                reasonCode: 'MINING_FORMULA_BASELINE_PENDING',
              ),
              _ => const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            },
          ),
      ],
    ),
  );
}

/// Mounts one S7 page with the three ports and the capability document.
Future<void> pumpS7Page(
  WidgetTester tester,
  Widget page, {
  LaunchGateway? launch,
  MiningGateway? mining,
  ReferralGateway? referral,
  WalletReadGateway? wallet,
  LoopV2MetaSnapshot? meta,
  Size size = const Size(390, 2600),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (launch != null) launchGatewayProvider.overrideWithValue(launch),
        if (mining != null) miningGatewayProvider.overrideWithValue(mining),
        if (referral != null)
          referralGatewayProvider.overrideWithValue(referral),
        if (wallet != null) walletReadGatewayProvider.overrideWithValue(wallet),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => meta ?? s7MetaSnapshot(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A never-completing read keeps the skeleton animating, so the frame is
    // pumped a fixed number of times instead of settled.
    await tester.pump();
    await tester.pump();
  }
}

/// Scrolls the page's own collection until [finder] is built and visible.
Future<void> scrollToS7Section(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
}
