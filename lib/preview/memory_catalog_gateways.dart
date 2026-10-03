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

import 'package:loop_mobile/preview/chain_catalog.dart';
import 'package:loop_mobile/preview/launch_mining_catalog.dart';
import 'package:loop_mobile/preview/launch_sale_catalog.dart';

/// Read-only specimens. Reward claims remain unavailable in the contract.
final class MemoryPreviewMiningGateway implements MiningGateway {
  static const communities = <(String, String)>[
    ('4bb85f64-5717-4562-b3fc-2c963f66afb7', '演示社区 · Builders'),
    ('3fa85f64-5717-4562-b3fc-2c963f66afa6', '演示社区 · Frogs'),
    ('61a11111-2222-4333-8444-555555555551', 'BNB 中文社区'),
    ('61a11111-2222-4333-8444-555555555552', 'MoonCat Club'),
    ('61a11111-2222-4333-8444-555555555553', 'Web3 夜航'),
  ];

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.preview;
  MiningSnapshotComputed get snapshot => previewLaunchMiningSnapshot(
    holdingsSource: MiningHoldingsSource.mockSeed,
  );
  static const estimate = MiningDailyOutputEstimate(
    value: '1250',
    budget: '1000000',
    unitKey: 'mining.rules.dailyOutput.unit.loopTokenPending',
    budgetStatus: 'development_placeholder',
    formulaVersion: previewLaunchBaselineVersion,
    scope: MiningFormulaScope.developmentBaseline,
  );
  @override
  Future<MiningSummary> loadSummary() async => previewLaunchMiningSummary(
    power: const MiningFigureValue('12500'),
    networkPower: const MiningFigureValue('10000000'),
    estimatedToday: estimate,
    accumulated: const LaunchUnavailable(previewLaunchRewardPending),
    formula: previewLaunchEffectiveFormula(),
    snapshot: snapshot,
  );
  @override
  Future<MiningAssets> loadAssets() async => previewLaunchMiningAssets(
    totalPower: const MiningFigureValue('12500'),
    included: [
      previewLaunchMiningAssetRow(
        holding: '2500',
        referencePriceUsd: '2',
        weight: '1',
        power: '5000',
      ),
      previewLaunchMiningAssetRow(
        assetId: previewLaunchUsdtAssetId,
        symbol: 'USDT',
        holding: '6000',
        referencePriceUsd: '1',
        weight: '1',
        power: '6000',
      ),
      previewLaunchMiningAssetRow(
        assetId: previewLaunchWbnbAssetId,
        symbol: 'WBNB',
        holding: '2',
        referencePriceUsd: '750',
        weight: '1',
        power: '1500',
      ),
    ],
    source: snapshot,
    referencePrice: const MiningReferencePriceSettled(
      'preview-fixed-2026-10-02',
    ),
    formula: previewLaunchEffectiveFormula(),
  );
  @override
  Future<MiningRewards> loadRewards() async => previewLaunchMiningRewards(
    estimatedToday: estimate,
    accumulated: const LaunchUnavailable(previewLaunchRewardPending),
    source: const LaunchUnavailable(previewLaunchRewardPending),
  );
  @override
  Future<MiningRank> loadRank(
    MiningRankScope scope,
  ) async => previewLaunchMiningRank(
    scope: scope,
    formula: previewLaunchEffectiveFormula(),
    snapshot: snapshot,
    myPosition: const MiningRankPositionSettled(position: 8, power: '12500'),
    ranking: scope == MiningRankScope.users
        ? previewLaunchMiningUserBoard(
            participants: 1286,
            items: List.generate(
              8,
              (i) => MiningRankUserRow(
                position: i + 1,
                power: '${100000 - i * 12500}',
                powerVisibility: MiningRankAudience.everyone,
                display: MiningRankAlias(
                  alias: [
                    'QuietComet',
                    'MintNomad',
                    '星河',
                    'Orbit',
                    'BlueWhale',
                    '链上漫游',
                    'MoonCat',
                    '我',
                  ][i],
                  publicProfileId:
                      '71b11111-2222-4333-8444-${(i + 1).toString().padLeft(12, '0')}',
                  audience: MiningRankAudience.everyone,
                ),
                isSelf: i == 7,
              ),
            ),
          )
        : previewLaunchMiningCommunityBoard(
            participants: 86,
            items: List.generate(
              5,
              (i) => MiningRankCommunityRow(
                position: i + 1,
                power: '${980000 - i * 115000}',
                community: MiningCommunityRef(
                  communityId: communities[i].$1,
                  name: communities[i].$2,
                  boundAssetId: previewLaunchCakeAssetId,
                ),
                weight: '1.5',
                participants: 286 - i * 31,
              ),
            ),
          ),
  );
  @override
  Future<MiningCommunity> loadCommunity(String communityId) async {
    final index = communities.indexWhere((c) => c.$1 == communityId);
    if (index < 0) throw const LaunchException(LaunchFailureKind.unavailable);
    return previewLaunchMiningCommunity(
      community: MiningCommunityRef(
        communityId: communityId,
        name: communities[index].$2,
        boundAssetId: previewLaunchCakeAssetId,
      ),
      communityPower: MiningFigureValue('${980000 - index * 115000}'),
      myContribution: const MiningFigureValue('12500'),
      rank: MiningRankPositionSettled(
        position: index + 1,
        power: '${980000 - index * 115000}',
      ),
      participants: MiningParticipantsCount(286 - index * 31),
      snapshot: snapshot,
    );
  }

  @override
  Future<MiningRules> loadRules() async => previewLaunchBaselineMiningRules();
}

/// Project material is browsable; no signing or purchase intent is manufactured.
final class MemoryPreviewLaunchGateway implements LaunchGateway {
  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.preview;
  Future<Never> _disabled() =>
      Future.error(const LaunchException(LaunchFailureKind.unavailable));
  @override
  Future<LaunchOverview> loadOverview() async => previewLaunchOverview(
    live: [previewSaleDetail().launch],
    awaitingSchedule: [],
  );
  @override
  Future<LaunchDetail> loadLaunch(String launchId) async => previewSaleDetail();
  @override
  Future<LaunchEligibility> loadEligibility(String launchId) async =>
      previewLaunchEligibility();
  @override
  Future<LaunchStake> loadStake() async => previewLaunchStake();
  @override
  Future<LaunchHolders> loadHolders(String launchId) async =>
      previewSaleHolders();
  @override
  Future<LaunchHistory> loadHistory(String launchId) async =>
      previewSaleHistory();
  @override
  Future<LaunchEconomy> loadEconomy() async => previewLaunchEconomy();
  @override
  Future<LaunchProjectPage> listProjects({
    String? status,
    String? cursor,
  }) async =>
      LaunchProjectPage(items: [previewLaunchProject()], nextCursor: null);
  @override
  Future<LaunchProject> loadProject(String projectId) async =>
      previewLaunchProject(projectId: projectId);
  @override
  Future<LaunchMilestones> loadMilestones(String projectId) async =>
      previewLaunchMilestones(items: [previewLaunchListedMilestone()]);
  @override
  Future<LaunchProject> createProject(LaunchProjectDraft draft) => _disabled();
  @override
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  }) => _disabled();
  @override
  Future<LaunchProject> submitProject(String projectId) => _disabled();
  @override
  Future<LaunchPurchasePrepared> preparePurchaseIntent({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) => _disabled();
  @override
  Future<LaunchPurchasePrepared> prepareSettlementIntent({
    required String launchId,
    required String walletId,
    required LaunchIntentKind kind,
  }) => _disabled();
  @override
  Future<LaunchPurchaseIntent> loadIntent({
    required String launchId,
    required String launchIntentId,
  }) => _disabled();
  @override
  Future<LaunchPurchaseIntent> reportPurchaseBroadcast({
    required String launchId,
    required String launchIntentId,
    required String txHash,
  }) => _disabled();
}

final class MemoryPreviewReferralGateway implements ReferralGateway {
  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.preview;
  @override
  Future<ReferralOverview> loadOverview() async =>
      previewLaunchReferral(binding: previewLaunchBoundBinding());
  @override
  Future<ReferralBinding> claim(String inviteCode) =>
      Future.error(const LaunchException(LaunchFailureKind.unavailable));
}

final class MemoryPreviewWalletGateway implements WalletReadGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;
  String _active = previewChainWalletId;
  @override
  Future<LoopWalletDirectory> loadWallets() async =>
      previewChainDirectory(activeWalletId: _active);
  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) async {
    if (expectedActiveWalletId != _active ||
        ![previewChainWalletId, previewChainOtherWalletId].contains(walletId)) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    _active = walletId;
    return loadWallets();
  }

  void _check(String id) {
    if (![previewChainWalletId, previewChainOtherWalletId].contains(id)) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
  }

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) async {
    _check(walletId);
    return previewChainBalances(walletId: walletId);
  }

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) async {
    _check(walletId);
    return previewChainActivity(walletId: walletId);
  }

  // Receiving funds is deliberately unavailable: sample addresses must never
  // become a scannable deposit destination.
  @override
  Future<LoopWalletReceive> loadReceive(String walletId) =>
      Future.error(const LoopChainException(LoopChainFailureKind.unavailable));
}
