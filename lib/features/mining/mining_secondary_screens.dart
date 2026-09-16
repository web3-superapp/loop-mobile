import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The capability gate copy shared by the five secondary mining pages.
/// The whole-page block a closed mining gate renders. It carries the reason
/// the server published instead of a sentence the client invented, and says so
/// plainly when the capability document was never read at all.
Widget _miningCapabilityBlock(
  String key,
  String subject,
  LoopCapabilityProjection capability,
) => LoopCapabilityPageBlock.of(
  key: ValueKey<String>(key),
  title: '$subject当前不可用',
  capability: capability,
);

/// `mining-assets` · the per-asset power breakdown.
class MiningAssetsScreen extends ConsumerStatefulWidget {
  const MiningAssetsScreen({
    super.key,
    this.onBack,
    this.onOpenRules,
    this.onOpenCommunities,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenRules;

  /// The community directory, from which one community's mining panel is
  /// reachable. There is no weighted-community list to link to directly: the
  /// weights themselves are still under review.
  final VoidCallback? onOpenCommunities;

  @override
  ConsumerState<MiningAssetsScreen> createState() => _MiningAssetsScreenState();
}

class _MiningAssetsScreenState extends ConsumerState<MiningAssetsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningAssetsControllerProvider);
    final controller = ref.read(miningAssetsControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final assets = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-assets-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '算力明细',
      kicker: 'POWER FORMULA',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-assets-rules-action'),
          icon: 'info',
          label: '查看规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: _assetsHero(assets, state.phase),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-assets-capability-unavailable',
              '算力明细',
              capability,
            )
          : null,
      sections: <Widget>[
        if (assets == null)
          LaunchStateBlock(
            prefix: 'mining-assets',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到算力明细',
            emptyReason: '暂时读不到资产数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('我的总算力'),
          _AssetsTotal(
            totalPower: assets.totalPower,
            baseline: miningGateIsBaseline(assets.formula),
          ),
          const LoopLabel('计入的资产'),
          if (assets.isUnsettled)
            const LoopNotice(
              key: ValueKey<String>('mining-assets-empty-notice'),
              icon: 'info',
              title: '空列表是正常结果',
              body: '计入与排除列表都是空的。这不代表你的钱包没有持仓，也不代表某个资产被排除。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            )
          else if (assets.included.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('mining-assets-included-empty'),
              icon: 'info',
              message: '这次快照没有计入任何资产',
              reason: '你的持仓里没有可以计入的资产。',
            )
          else
            LoopRecordGroup(
              key: const ValueKey<String>('mining-assets-included'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < assets.included.length; index += 1)
                  _includedRow(
                    assets.included[index],
                    launchRowPosition(index, assets.included.length),
                    _assetSymbols(assets),
                  ),
              ],
            ),
          if (!assets.isUnsettled) ...<Widget>[
            const LoopLabel('未计入的资产'),
            if (assets.excluded.isEmpty)
              const LoopEmpty(
                key: ValueKey<String>('mining-assets-excluded-empty'),
                icon: 'info',
                message: '没有被排除的资产',
                reason: '你持有的资产这次都计入了。',
              )
            else
              LoopRecordGroup(
                key: const ValueKey<String>('mining-assets-excluded'),
                rows: <LoopRecordRow>[
                  for (
                    var index = 0;
                    index < assets.excluded.length;
                    index += 1
                  )
                    _excludedRow(
                      assets.excluded[index],
                      launchRowPosition(index, assets.excluded.length),
                    ),
                ],
              ),
          ],
          const LoopLabel('公式版本'),
          MiningFormulaBlock(formula: assets.formula),
          const LoopLabel(miningSnapshotSectionLabel),
          _AssetsSourceBlock(source: assets.source),
          const LoopLabel('社区权重'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-assets-open-communities'),
                title: '查看社区挖矿面板',
                subtitle: '每个社区的权重按审核结果授予',
                onTap: widget.onOpenCommunities,
              ),
            ],
          ),
          const LoopLabel('参考价'),
          _ReferencePriceBlock(referencePrice: assets.referencePrice),
          LoopNotice(
            key: const ValueKey<String>('mining-assets-price-notice'),
            icon: 'shield',
            title: '参考价不是瞬时成交价',
            body: assets.included.any((row) => row.isProxiedPrice)
                ? '参考价由多个渠道的价格计算得出。有的资产没有自己的交易对，'
                      '用的是另一个已登记代币的价格，这里已经逐行标出。'
                : '参考价由多个渠道的价格计算得出，不是某一笔成交的价格。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The hero. A settled total prints the server's own decimal; without a
/// settlement the page says the absence in words rather than a 29px dash — and
/// in words, not in a state name: the stamp is a settled reading or nothing.
///
/// Which words is the server's to decide. The caption used to name the formula
/// as the thing being waited on, in the same frame as a read that had not
/// landed and in the frame after one that landed under a formula already in
/// effect. A frame that has read nothing says only that it is reading, and a
/// total with no figure carries the reason the total itself came with.
LoopFolioPrimary _assetsHero(MiningAssets? assets, LaunchViewPhase phase) {
  final (String heading, String caption) = switch (assets?.totalPower) {
    MiningFigureValue(:final value) => (value, '持有量、参考价与权重都来自最近一次算力快照，不是收益。'),
    MiningFigureUnavailable(:final reasonCode) => (
      launchMissingHeading,
      launchReasonCodeText(reasonCode),
    ),
    null when phase == LaunchViewPhase.loading => ('正在读取', '总算力读到之后显示在这里。'),
    null => (launchMissingHeading, '这一页还没有读到算力明细。'),
  };
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'POWER FORMULA',
    heading: heading,
    caption: caption,
  );
}

/// Every symbol this page was given, by asset id. A proxied row names the
/// token its price came from, and that token is usually a row of its own: the
/// index lets the note use the registry's name instead of an address the
/// reader would have to match by eye.
Map<String, String> _assetSymbols(MiningAssets assets) => <String, String>{
  for (final row in assets.included)
    if (row.symbol != null) row.assetId: row.symbol!,
  for (final row in assets.excluded)
    if (row.symbol != null) row.assetId: row.symbol!,
};

/// One weighted asset. The row is headed by the registry's own symbol, with
/// the id it stands for kept beside the inputs; the three inputs stay beside
/// the figure they produced, and a price taken from another token says so on
/// the row itself.
LoopRecordRow _includedRow(
  MiningAssetRow row,
  LoopRowPosition position,
  Map<String, String> symbols,
) {
  final label = miningAssetTitle(symbol: row.symbol, assetId: row.assetId);
  final proxy = row.referencePriceProxyAssetId;
  final proxyLabel = proxy == null
      ? ''
      : miningAssetTitle(symbol: symbols[proxy], assetId: proxy);
  final priceNote = proxy == null ? '' : '（代理价，来自 $proxyLabel）';
  // A named row still says which asset it is: the id is the identity, the
  // symbol is only how the registry writes it.
  final identity = row.symbol == null
      ? ''
      : '${miningAssetLabel(row.assetId)} · ';
  return LoopRecordRow(
    key: ValueKey<String>('mining-assets-row-${row.assetId}'),
    title: label,
    subtitle:
        '$identity持有 ${row.holding} · 参考价 ${row.referencePriceUsd} 美元$priceNote',
    subtitleMaxLines: 2,
    trailing: row.power,
    trailingCaption: '权重 ${row.weight}',
    semanticLabel: proxy == null
        ? '$label，算力 ${row.power}'
        : '$label，算力 ${row.power}，参考价来自另一个代币的代理价',
    position: position,
  );
}

/// One asset the settlement skipped, with the server's own reason in words.
LoopRecordRow _excludedRow(MiningExcludedAsset row, LoopRowPosition position) =>
    LoopRecordRow(
      key: ValueKey<String>('mining-assets-excluded-${row.assetId}'),
      title: miningAssetTitle(symbol: row.symbol, assetId: row.assetId),
      subtitle: row.symbol == null
          ? launchReasonCodeText(row.reasonCode)
          : '${miningAssetLabel(row.assetId)} · '
                '${launchReasonCodeText(row.reasonCode)}',
      subtitleMaxLines: 2,
      trailingBadge: const LoopBadge('未计入'),
      position: position,
    );

/// 我的总算力. A settled figure prints; an unsettled one keeps the em dash and
/// the server's own reason, and never becomes a zero. A figure the development
/// baseline produced says so beside itself, exactly as the summary's does.
///
/// The reason is the folio's to say: it heads this same figure, three
/// centimetres up the page, with the same sentence. It stays in this cell's
/// semantic label, where a screen reader reads it on the figure it belongs to.
class _AssetsTotal extends StatelessWidget {
  const _AssetsTotal({required this.totalPower, required this.baseline});

  final MiningFigure totalPower;
  final bool baseline;

  @override
  Widget build(BuildContext context) {
    return switch (totalPower) {
      MiningFigureUnavailable(:final reasonCode) => LaunchEmptyMetric(
        key: const ValueKey<String>('mining-assets-total'),
        label: '我的总算力',
        reasonCode: reasonCode,
        showReason: false,
      ),
      MiningFigureValue(:final value) => LoopRecordGroup(
        key: const ValueKey<String>('mining-assets-total'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('mining-assets-total-row'),
            title: '我的总算力',
            subtitle: '计入的资产加总',
            trailing: value,
            trailingCaption: baseline ? miningBaselineLabel : null,
            semanticLabel: baseline
                ? '我的总算力，$value，$miningBaselineLabel'
                : '我的总算力，$value',
          ),
        ],
      ),
    };
  }
}

/// Which settlement these rows came from. The identifiers it carries are
/// backend strings, so only the block height and the time reach the row.
class _AssetsSourceBlock extends StatelessWidget {
  const _AssetsSourceBlock({required this.source});

  final MiningSnapshotRef source;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      MiningSnapshotUnavailable(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('mining-assets-source-unavailable'),
        icon: 'clock',
        message: miningSnapshotAbsenceMessage(reasonCode),
        reason: miningSnapshotAbsenceReason(reasonCode),
      ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-assets-source'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-assets-source-row'),
              title: miningSnapshotRowTitle,
              subtitle:
                  '区块 $blockNumber · ${launchTimestampLabel(computedAt)} · '
                  '这是算出算力的时间',
              subtitleMaxLines: 2,
            ),
          ],
        ),
    };
  }
}

/// The price version every row was priced against. The version string is a
/// backend identifier and stays inside the collapsed 详情.
class _ReferencePriceBlock extends StatelessWidget {
  const _ReferencePriceBlock({required this.referencePrice});

  final MiningReferencePrice referencePrice;

  @override
  Widget build(BuildContext context) {
    return switch (referencePrice) {
      MiningReferencePriceUnavailable(:final reasonCode) =>
        LaunchUnavailableCard(
          label: '挖矿参考价',
          fact: LaunchUnavailable(reasonCode),
        ),
      MiningReferencePriceSettled(:final priceVersion) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const LoopRecordGroup(
            key: ValueKey<String>('mining-assets-price'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: ValueKey<String>('mining-assets-price-row'),
                title: '挖矿参考价',
                subtitle: '这一批价格用于上面每一行',
              ),
            ],
          ),
          LoopDisclosure(
            key: const ValueKey<String>('mining-assets-price-details'),
            summary: '详情',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                '参考价版本 $priceVersion',
                key: const ValueKey<String>('mining-assets-price-version'),
                style: LoopTypography.caption(11, color: LoopColors.text3),
              ),
            ),
          ),
        ],
      ),
    };
  }
}

/// `mining-rewards` · settled rewards and the claim entry point.
class MiningRewardsScreen extends ConsumerStatefulWidget {
  const MiningRewardsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<MiningRewardsScreen> createState() =>
      _MiningRewardsScreenState();
}

class _MiningRewardsScreenState extends ConsumerState<MiningRewardsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRewardsControllerProvider);
    final controller = ref.read(miningRewardsControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rewards = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rewards-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '奖励与领取',
      kicker: 'CLAIMABLE REWARD',
      onBack: widget.onBack,
      primary: _rewardsHero(rewards, state.phase),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-rewards-capability-unavailable',
              '奖励与领取',
              capability,
            )
          : null,
      sections: <Widget>[
        if (rewards == null)
          LaunchStateBlock(
            prefix: 'mining-rewards',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到奖励记录',
            emptyReason: '暂时读不到奖励数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('奖励规则'),
          // 今日预估 is the one slot an effective version can settle. When it
          // is settled it is a figure, said exactly as 算力与产出 says it; the
          // two that the reward authority closes stay in the grid, and the
          // folio above still speaks their reason once.
          if (rewards.estimatedToday
              case final MiningDailyOutputEstimate estimate) ...<Widget>[
            MiningMetricRow(
              slug: 'estimated-today',
              label: '今日预估',
              figure: MiningFigureValue(estimate.value),
              baseline: estimate.scope.isBaseline,
              note: estimate.isPlaceholderBudget ? '按占位产量估算，奖励代币还没有确定。' : null,
            ),
            LaunchEmptyMetricGrid(
              key: const ValueKey<String>('mining-rewards-metrics'),
              metrics: <(String, String)>[
                ('待领取', rewards.claimable.reasonCode),
                ('累计已挖', rewards.accumulated.reasonCode),
              ],
              spokenReason: launchReasonCodeText(rewards.claimable.reasonCode),
            ),
          ] else
            LaunchEmptyMetricGrid(
              key: const ValueKey<String>('mining-rewards-metrics'),
              metrics: <(String, String)>[
                ('待领取', rewards.claimable.reasonCode),
                (
                  '今日预估',
                  (rewards.estimatedToday as MiningDailyOutputUnavailable)
                      .reasonCode,
                ),
                ('累计已挖', rewards.accumulated.reasonCode),
              ],
              // 待领取 and 累计已挖 are usually closed by the same thing, and the
              // folio above already said what it is. The cells keep the em dash.
              spokenReason: launchReasonCodeText(rewards.claimable.reasonCode),
            ),
          const LoopLabel('领取'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopButton(
              key: const ValueKey<String>('mining-rewards-claim'),
              label: '领取到钱包',
              primary: true,
              block: true,
              // Disabled by the server's own `claimExecutable: false`.
              onPressed: rewards.claimExecutable ? () {} : null,
              semanticLabel: '领取到钱包，当前不可执行',
            ),
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-rewards-claim-notice'),
            icon: 'lock',
            tone: LoopNoticeTone.warn,
            title: '领取入口不可执行',
            // The reason is the folio's, once. This says what the control does,
            // which is the thing the folio does not say.
            body: '可以领取时，这个按钮会变为可用；现在它不会提交任何操作。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopLabel('结算记录'),
          _RewardsLedgerBlock(
            source: rewards.source,
            claimable: rewards.claimable,
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-rewards-ledger-notice'),
            icon: 'info',
            title: '没有条目不等于没有产出',
            body: '这里只列奖励账本的条目。算力，以及每一次算力快照的区块与时间，在算力明细里。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The reward ledger's own line.
///
/// `source` and `claimable` are two slots that are usually closed by one fact,
/// and when they are, the page says that fact once — in the folio — and this
/// block states what the section itself shows: no entry to check yet. When the
/// two differ, the ledger keeps the server's own reason for its own slot.
class _RewardsLedgerBlock extends StatelessWidget {
  const _RewardsLedgerBlock({required this.source, required this.claimable});

  final LaunchUnavailable source;
  final LaunchUnavailable claimable;

  @override
  Widget build(BuildContext context) {
    final reason = launchReasonCodeText(source.reasonCode);
    final spoken = reason == launchReasonCodeText(claimable.reasonCode);
    return LoopEmpty(
      key: const ValueKey<String>('mining-rewards-ledger'),
      icon: 'clock',
      message: '结算与领取记录',
      reason: spoken ? '还没有可以核对的条目。' : reason,
    );
  }
}

/// The hero. What this page may say about a claim comes from `claimable`'s own
/// reason, never from a constant: 「还没有发生过结算」 was written before the
/// first settlement existed and stayed on the screen after it happened, while
/// the reward authority — a different fact entirely — was what actually kept
/// the claim closed.
///
/// A read that has not landed says only that it is reading. The absence of a
/// figure is stated once the answer is here, and its cause is the server's.
LoopFolioPrimary _rewardsHero(MiningRewards? rewards, LaunchViewPhase phase) {
  final (String heading, String caption) = switch (rewards) {
    null when phase == LaunchViewPhase.loading => ('正在读取', '待领取的数量读到之后显示在这里。'),
    null => (launchMissingHeading, '这一页还没有读到奖励数据。'),
    MiningRewards(:final claimable) => (
      launchMissingHeading,
      launchReasonCodeText(claimable.reasonCode),
    ),
  };
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'CLAIMABLE REWARD',
    heading: heading,
    caption: caption,
  );
}

/// `mining-rank` · the power leaderboard.
class MiningRankScreen extends ConsumerStatefulWidget {
  const MiningRankScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<MiningRankScreen> createState() => _MiningRankScreenState();
}

class _MiningRankScreenState extends ConsumerState<MiningRankScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRankControllerProvider);
    final controller = ref.read(miningRankControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rank = state.value;
    final scope = rank?.scope ?? controller.scope;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rank-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '算力排行榜',
      kicker: 'NETWORK POSITION',
      onBack: widget.onBack,
      primary: _rankHero(rank),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-rank-capability-unavailable',
              '排行榜',
              capability,
            )
          : null,
      sections: <Widget>[
        ...<Widget>[
          LoopSegBar(
            key: const ValueKey<String>('mining-rank-scope'),
            labels: <String>[
              miningRankScopeLabel(MiningRankScope.communities),
              miningRankScopeLabel(MiningRankScope.users),
            ],
            selectedIndex: scope == MiningRankScope.communities ? 0 : 1,
            onSelected: (index) => unawaited(
              controller.select(
                index == 0
                    ? MiningRankScope.communities
                    : MiningRankScope.users,
              ),
            ),
          ),
          if (rank == null)
            LaunchStateBlock(
              prefix: 'mining-rank',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '没有读到排行榜',
              emptyReason: '暂时读不到排行数据。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            const LoopLabel('榜单'),
            _RankingBlock(ranking: rank.ranking),
            const LoopLabel('我的名次'),
            _MyPositionBlock(myPosition: rank.myPosition),
            const LoopLabel('公式版本'),
            MiningFormulaBlock(formula: rank.formula),
            const LoopLabel('匿名显示规则'),
            LoopNotice(
              key: const ValueKey<String>('mining-rank-anonymity'),
              icon: 'shield',
              title: '排行条目如何显示身份',
              body:
                  '${miningRuleKeyText(rank.display.ruleKey)}'
                  '未满足条件时显示「${miningRuleKeyText(rank.display.anonymousMemberKey)}」。'
                  '这条规则不会因为榜单何时上线而改变。',
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
            const LoopNotice(
              key: ValueKey<String>('mining-rank-notice'),
              icon: 'info',
              title: '排名不是静态权益',
              body: '其他账号或社区的算力变化会改变名次。榜单只来自最近一次算力快照，不会在这台设备上计算。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The hero. A settled place prints as a position, never as a number the page
/// could be read as power; without one the hero says *which* absence this is.
///
/// A settlement that left this reader off the board is not a settlement that
/// has not happened, and neither is a board that does not carry personal
/// places at all — so each reason keeps its own sentence instead of one
/// 「等结算」 that the page's own block height contradicts. There is no
/// stamp: the prototype's `.folio-stamp` carries a settled reading (`50,000 H`,
/// `0.35×`), never a state name, and the heading already states the absence.
LoopFolioPrimary _rankHero(MiningRank? rank) {
  final (String heading, String caption) = switch (rank?.myPosition) {
    MiningRankPositionSettled(:final position) => (
      '第 $position 名',
      '名次来自最近一次算力快照，其他账号的算力变化会改变它。',
    ),
    // Settled, read, and off the board: the fact first, the cause after it.
    MiningRankPositionUnavailable(reasonCode: 'MINING_RANK_NOT_RANKED') => (
      _miningUnrankedLabel,
      '最近一次算力快照里你的算力为 0。',
    ),
    MiningRankPositionUnavailable(:final reasonCode) => (
      launchMissingHeading,
      launchReasonCodeText(reasonCode),
    ),
    // Nothing was read yet: the page states no cause it does not have.
    null => (launchMissingHeading, '排行榜读到之后在这里显示名次。'),
  };
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'NETWORK POSITION',
    heading: heading,
    caption: caption,
  );
}

/// The board. A row whose power is zero has no place on it, and says so
/// instead of printing a position the settlement never gave.
class _RankingBlock extends StatelessWidget {
  const _RankingBlock({required this.ranking});

  final MiningRanking ranking;

  @override
  Widget build(BuildContext context) {
    return switch (ranking) {
      MiningRankingUnavailable(:final reasonCode) => LaunchUnavailableCard(
        label: '排行榜条目',
        fact: LaunchUnavailable(reasonCode),
      ),
      MiningRankingUsers(:final items, :final participants)
          when items.isEmpty =>
        _emptyBoard(participants),
      MiningRankingCommunities(:final items, :final participants)
          when items.isEmpty =>
        _emptyBoard(participants),
      MiningRankingUsers(:final items, :final participants) => _board(
        participants: participants,
        rows: <LoopRecordRow>[
          for (var index = 0; index < items.length; index += 1)
            _userRow(items[index], launchRowPosition(index, items.length)),
        ],
      ),
      MiningRankingCommunities(:final items, :final participants) => _board(
        participants: participants,
        rows: <LoopRecordRow>[
          for (var index = 0; index < items.length; index += 1)
            _communityRow(items[index], launchRowPosition(index, items.length)),
        ],
      ),
    };
  }

  static Widget _emptyBoard(int participants) => LoopEmpty(
    key: const ValueKey<String>('mining-rank-empty'),
    icon: 'info',
    message: '最近一次算力快照里没有可以上榜的条目',
    reason: _participantsLine(participants),
  );

  static Widget _board({
    required int participants,
    required List<LoopRecordRow> rows,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopRecordGroup(
        key: const ValueKey<String>('mining-rank-items'),
        rows: rows,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          _participantsLine(participants),
          key: const ValueKey<String>('mining-rank-participants'),
          style: LoopTypography.caption(11, color: LoopColors.text3),
        ),
      ),
    ],
  );

  static String _participantsLine(int participants) =>
      '最近一次算力快照里有 $participants 个条目算出了算力。';
}

/// 未上榜, not the position 0: a zero power is a settled reading, and the
/// board simply has no place for it.
const String _miningUnrankedLabel = '未上榜';

LoopRecordRow _userRow(MiningRankUserRow row, LoopRowPosition position) {
  final name = switch (row.display) {
    MiningRankAlias(:final alias) => alias,
    MiningRankAnonymous(:final labelKey) => miningRuleKeyText(labelKey),
  };
  return LoopRecordRow(
    key: ValueKey<String>('mining-rank-user-${row.power}-$name'),
    title: name,
    subtitle: row.isRanked
        ? '第 ${row.position} 名'
        : '$_miningUnrankedLabel · 算力为 0',
    trailing: row.power,
    trailingBadge: row.isSelf ? const LoopBadge('我') : null,
    semanticLabel: row.isRanked
        ? '$name，第 ${row.position} 名，算力 ${row.power}'
        : '$name，$_miningUnrankedLabel',
    position: position,
  );
}

LoopRecordRow _communityRow(
  MiningRankCommunityRow row,
  LoopRowPosition position,
) => LoopRecordRow(
  key: ValueKey<String>('mining-rank-community-${row.community.communityId}'),
  title: row.community.name,
  subtitle: row.isRanked
      ? '第 ${row.position} 名 · ${row.participants} 人有算力'
      : '$_miningUnrankedLabel · ${row.participants} 人有算力',
  subtitleMaxLines: 2,
  trailing: row.power,
  trailingCaption: '权重 ${row.weight}',
  position: position,
);

/// 我的名次. A missing place keeps the server's own reason — a zero power and
/// an account outside the settlement are different facts.
class _MyPositionBlock extends StatelessWidget {
  const _MyPositionBlock({required this.myPosition});

  final MiningRankPosition myPosition;

  @override
  Widget build(BuildContext context) {
    return switch (myPosition) {
      MiningRankPositionUnavailable(:final reasonCode) => LaunchUnavailableCard(
        label: '我的名次',
        fact: LaunchUnavailable(reasonCode),
      ),
      MiningRankPositionSettled(:final position, :final power) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-rank-my-position'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-rank-my-position-row'),
              title: '我的名次',
              subtitle: '算力 $power',
              trailing: '第 $position 名',
            ),
          ],
        ),
    };
  }
}

/// `mining-community` · one community's mining panel.
class MiningCommunityScreen extends ConsumerStatefulWidget {
  const MiningCommunityScreen({super.key, this.communityId, this.onBack});

  final String? communityId;
  final VoidCallback? onBack;

  @override
  ConsumerState<MiningCommunityScreen> createState() =>
      _MiningCommunityScreenState();
}

class _MiningCommunityScreenState extends ConsumerState<MiningCommunityScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningCommunityControllerProvider);
    final controller = ref.read(miningCommunityControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.communityId));
      });
    }
    final community = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-community-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: community?.community.name ?? '社区挖矿面板',
      kicker: 'COMMUNITY POWER',
      onBack: widget.onBack,
      primary: _communityHero(community, state.phase),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-community-capability-unavailable',
              '社区挖矿面板',
              capability,
            )
          : null,
      sections: <Widget>[
        if (community == null)
          LaunchStateBlock(
            prefix: 'mining-community',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到这个社区',
            emptyReason: '社区可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('社区权重'),
          _WeightBlock(weight: community.weight),
          const LoopLabel('算力规则'),
          _CommunityMetrics(community: community),
          const LoopLabel(miningSnapshotSectionLabel),
          _CommunitySnapshotBlock(snapshot: community.snapshot),
          const LoopLabel('绑定资产'),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-community-asset'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-community-asset-row'),
                title: '绑定资产',
                subtitle: community.community.boundAssetId == null
                    ? '这个社区还没有绑定资产'
                    : community.community.boundAssetId!,
                trailing: community.community.boundAssetId == null
                    ? launchMissingFigure
                    : '已绑定',
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-community-notice'),
            icon: 'shield',
            title: '权重由平台综合评定',
            body: '权重按审核结果给出，评审因子公开、具体分值不公开。未通过审核的社区没有权重，也不会有算力。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _WeightBlock extends StatelessWidget {
  const _WeightBlock({required this.weight});

  final MiningCommunityWeight weight;

  @override
  Widget build(BuildContext context) {
    return switch (weight) {
      // The version is bound under a neutral name: it is an identifier the
      // 详情 may hold, never a value a sentence names.
      MiningCommunityWeightApproved(
        :final value,
        :final reviewedAt,
        configVersion: final identifier,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopRecordGroup(
              key: const ValueKey<String>('mining-community-weight-approved'),
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('mining-community-weight-row'),
                  title: '已授予权重',
                  subtitle: '审核于 ${launchTimestampLabel(reviewedAt)}',
                  trailing: value,
                ),
              ],
            ),
            LoopDisclosure(
              key: const ValueKey<String>('mining-community-weight-details'),
              summary: '详情',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  '已生效的公式版本 $identifier',
                  key: const ValueKey<String>(
                    'mining-community-weight-version',
                  ),
                  style: LoopTypography.caption(11, color: LoopColors.text3),
                ),
              ),
            ),
          ],
        ),
      // A review that is happening and a review that will never happen are
      // different facts, and the block says which one this is.
      MiningCommunityWeightPending(
        :final reasonCode,
        reviewStatus: MiningWeightReviewStatus.pendingReview,
      ) =>
        LoopEmpty(
          key: const ValueKey<String>('mining-community-weight-pending'),
          icon: 'clock',
          message: '权重审核中',
          reason: launchReasonCodeText(reasonCode),
        ),
      MiningCommunityWeightPending(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('mining-community-weight-not-applicable'),
        icon: 'info',
        message: '没有可审的权重',
        reason: launchReasonCodeText(reasonCode),
      ),
    };
  }
}

/// The hero. A settled community power prints the server's own decimal; the
/// weight that produced it is already in the number.
///
/// When there is no decimal, the reason is the server's: the caption used to
/// name the formula as the thing being waited on, which was printed on the
/// skeleton frame of every cold start and stayed wrong after a formula version
/// took effect — a community with no bound asset has no power for a reason of
/// its own.
LoopFolioPrimary _communityHero(
  MiningCommunity? community,
  LaunchViewPhase phase,
) {
  final (String heading, String caption) = switch (community?.communityPower) {
    MiningFigureValue(:final value) => (value, '成员在绑定资产上的算力之和，权重已经算在里面。'),
    MiningFigureUnavailable(:final reasonCode) => (
      launchMissingHeading,
      launchReasonCodeText(reasonCode),
    ),
    null when phase == LaunchViewPhase.loading => ('正在读取', '社区总算力读到之后显示在这里。'),
    null => (launchMissingHeading, '这一页还没有读到这个社区的算力。'),
  };
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'COMMUNITY POWER',
    heading: heading,
    caption: caption,
  );
}

/// 算力规则. While nothing was settled the four figures share one sentence;
/// once they are settled each one prints, and a zero says which reading it is
/// rather than becoming an em dash.
class _CommunityMetrics extends StatelessWidget {
  const _CommunityMetrics({required this.community});

  final MiningCommunity community;

  @override
  Widget build(BuildContext context) {
    final power = community.communityPower;
    final contribution = community.myContribution;
    final rank = community.rank;
    final participants = community.participants;
    if (power is MiningFigureUnavailable &&
        contribution is MiningFigureUnavailable &&
        rank is MiningRankPositionUnavailable &&
        participants is MiningParticipantsUnavailable) {
      return LaunchEmptyMetricGrid(
        key: const ValueKey<String>('mining-community-metrics'),
        metrics: <(String, String)>[
          ('社区总算力', power.reasonCode),
          ('我的贡献', contribution.reasonCode),
          ('社区排名', rank.reasonCode),
          ('参与人数', participants.reasonCode),
        ],
        // The folio heads 社区总算力 and already carries its reason.
        spokenReason: launchReasonCodeText(power.reasonCode),
      );
    }
    return LoopRecordGroup(
      key: const ValueKey<String>('mining-community-metrics'),
      rows: <LoopRecordRow>[
        _figureRow(
          slug: 'power',
          label: '社区总算力',
          figure: power,
          position: LoopRowPosition.first,
          // Same figure as the folio heading, so the same sentence is not
          // written twice on one screen.
          reasonSaidAbove: true,
        ),
        _figureRow(
          slug: 'contribution',
          label: '我的贡献',
          figure: contribution,
          position: LoopRowPosition.middle,
        ),
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-rank'),
          title: '社区排名',
          subtitle: switch (rank) {
            MiningRankPositionUnavailable(:final reasonCode) =>
              launchReasonCodeText(reasonCode),
            MiningRankPositionSettled(:final power) => '算力 $power',
          },
          subtitleMaxLines: 2,
          trailing: switch (rank) {
            MiningRankPositionUnavailable() => launchMissingFigure,
            MiningRankPositionSettled(:final position) => '第 $position 名',
          },
          position: LoopRowPosition.middle,
        ),
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-participants'),
          title: '参与人数',
          subtitle: switch (participants) {
            MiningParticipantsUnavailable(:final reasonCode) =>
              launchReasonCodeText(reasonCode),
            MiningParticipantsCount() => '算出了算力的成员',
          },
          subtitleMaxLines: 2,
          trailing: switch (participants) {
            MiningParticipantsUnavailable() => launchMissingFigure,
            MiningParticipantsCount(:final count) => '$count',
          },
          position: LoopRowPosition.last,
        ),
      ],
    );
  }

  static LoopRecordRow _figureRow({
    required String slug,
    required String label,
    required MiningFigure figure,
    required LoopRowPosition position,
    bool reasonSaidAbove = false,
  }) => LoopRecordRow(
    key: ValueKey<String>('mining-community-metric-$slug'),
    title: label,
    subtitle: switch (figure) {
      MiningFigureUnavailable() when reasonSaidAbove => null,
      MiningFigureUnavailable(:final reasonCode) => launchReasonCodeText(
        reasonCode,
      ),
      MiningFigureValue() => '来自最近一次算力快照',
    },
    subtitleMaxLines: 2,
    trailing: switch (figure) {
      MiningFigureUnavailable() => launchMissingFigure,
      MiningFigureValue(:final value) => value,
    },
    position: position,
  );
}

/// Which settlement this panel read. The identifiers it carries are backend
/// strings, so only the block height and the time reach the row.
class _CommunitySnapshotBlock extends StatelessWidget {
  const _CommunitySnapshotBlock({required this.snapshot});

  final MiningSnapshotRef snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot) {
      MiningSnapshotUnavailable(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('mining-community-snapshot-unavailable'),
        icon: 'clock',
        message: miningSnapshotAbsenceMessage(reasonCode),
        reason: miningSnapshotAbsenceReason(reasonCode),
      ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-community-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-community-snapshot-row'),
              title: miningSnapshotRowTitle,
              subtitle:
                  '区块 $blockNumber · ${launchTimestampLabel(computedAt)} · '
                  '这是算出算力的时间',
              subtitleMaxLines: 2,
            ),
          ],
        ),
    };
  }
}

/// `mining-rules` · the weight and price-guard rules.
///
/// It shows the version that is waiting for approval and labels it as such;
/// it never fills in a ratio, a band or a threshold of its own.
class MiningRulesScreen extends ConsumerStatefulWidget {
  const MiningRulesScreen({super.key, this.onBack, this.onOpenReferral});

  final VoidCallback? onBack;
  final VoidCallback? onOpenReferral;

  @override
  ConsumerState<MiningRulesScreen> createState() => _MiningRulesScreenState();
}

class _MiningRulesScreenState extends ConsumerState<MiningRulesScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRulesControllerProvider);
    final controller = ref.read(miningRulesControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rules = state.value;
    final draft = rules == null || rules.pendingApproval.isEmpty
        ? null
        : rules.pendingApproval.first;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rules-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '权重与价格保护',
      kicker: 'POWER RULES',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'POWER RULES',
        heading: draft == null
            ? launchMissingHeading
            : miningRuleKeyText(draft.expressionKey),
        caption: '规则以已批准的公式为准。下面是还没批准的草案。',
        stamp: draft == null ? null : '待批准',
      ),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-rules-capability-unavailable',
              '挖矿规则',
              capability,
            )
          : null,
      sections: <Widget>[
        if (rules == null)
          LaunchStateBlock(
            prefix: 'mining-rules',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到规则',
            emptyReason: '暂时读不到公式版本。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('已批准的版本'),
          // The version in force, said the way every other mining page says
          // it. Without one, the block keeps the server's own reason.
          switch (rules.baseline) {
            MiningFormulaEffective() => MiningFormulaBlock(
              formula: rules.baseline,
            ),
            MiningFormulaPending(:final reasonCode) => LaunchUnavailableCard(
              label: '已批准的公式版本',
              fact: LaunchUnavailable(reasonCode),
            ),
          },
          if (rules.approved != null)
            _FormulaVersionBlock(
              version: rules.approved!,
              keyPrefix: 'mining-rules-approved',
            ),
          if (rules.approved?.scope.isBaseline ?? false)
            const LoopNotice(
              key: ValueKey<String>('mining-rules-baseline-notice'),
              icon: 'info',
              title: '开发基线的数值只用于开发验证',
              body: '这一版把每个资产的权重都定为 1，当日产量是占位预算，奖励代币还没有确定。它不是产品规则。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          const LoopLabel('待批准的版本'),
          if (rules.pendingApproval.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('mining-rules-no-pending'),
              icon: 'info',
              message: '没有待批准的版本',
              reason: '目前没有草案版本。',
            )
          else
            for (final version in rules.pendingApproval)
              _FormulaVersionBlock(
                version: version,
                keyPrefix: 'mining-rules-pending-${version.configVersion}',
              ),
          const LoopLabel('邀请关系规则'),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-rules-referral'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < rules.referral.levels.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    'mining-rules-referral-l'
                    '${rules.referral.levels[index].level}',
                  ),
                  title: 'L${rules.referral.levels[index].level}',
                  subtitle:
                      '生效于 '
                      '${launchTimestampLabel(rules.referral.effectiveAt)}',
                  trailing: '${rules.referral.levels[index].boostPercent}%',
                  position: launchRowPosition(
                    index,
                    rules.referral.levels.length,
                  ),
                ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('mining-rules-open-referral'),
                label: '查看我的邀请关系',
                onPressed: widget.onOpenReferral,
              ),
            ],
          ),
          // Only while nothing is in force. Once a version is approved the
          // page above it prints a pinned range and a budget, and this
          // sentence would be the same screen calling those numbers absent.
          // What the approved version is, the baseline notice already says.
          if (rules.approved == null)
            const LoopNotice(
              key: ValueKey<String>('mining-rules-notice'),
              icon: 'shield',
              title: '草案不是生效规则',
              body: '待批准的版本不会参与任何计算。权重区间与价格保护阈值只有规则条目，没有数值；批准之后才会公布。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _FormulaVersionBlock extends StatelessWidget {
  const _FormulaVersionBlock({required this.version, required this.keyPrefix});

  final MiningFormulaVersion version;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final rows = <LoopRecordRow>[
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-expression'),
        title: '算力公式',
        subtitle: miningRuleKeyText(version.expressionKey),
        trailingBadge: LoopBadge(
          miningFormulaStatusLabel(version.status),
          kind: version.status == MiningFormulaStatus.approved
              ? LoopBadgeKind.mining
              : LoopBadgeKind.mute,
        ),
        position: LoopRowPosition.first,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-daily-output'),
        title: '每日产出',
        subtitle: miningRuleKeyText(version.dailyOutputKey),
        // The budget is published with its own status, so it is printed with
        // it: a placeholder number never stands on the page by itself.
        trailing: version.dailyOutput?.budget,
        trailingCaption: version.dailyOutput == null
            ? null
            : (version.dailyOutput!.isPlaceholder ? '占位产量' : '当日产量'),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-loop'),
        title: 'LOOP 权重',
        subtitle: miningRuleKeyText(version.weightRange.loop.descriptionKey),
        trailing: launchMissingFigure,
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.loop.status,
        ),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-community'),
        title: '社区币权重',
        subtitle: miningRuleKeyText(
          version.weightRange.community.descriptionKey,
        ),
        // The bounds print only once the version pinned them; until then the
        // band is a rule with no numbers and keeps the em dash.
        trailing: switch (version.weightRange.community.range) {
          null => launchMissingFigure,
          MiningWeightBounds(:final min, :final max) => '$min–$max',
        },
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.community.status,
        ),
        position: LoopRowPosition.middle,
      ),
      for (final guard in version.priceGuardRules)
        LoopRecordRow(
          key: ValueKey<String>('$keyPrefix-guard-${guard.ruleKey}'),
          title: '价格保护',
          subtitle: miningRuleKeyText(guard.ruleKey),
          trailingCaption: miningFormulaStatusLabel(guard.status),
          position: LoopRowPosition.middle,
        ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-referral-boost'),
        title: '邀请加成',
        subtitle: '加成只计入 Mining Power',
        trailingCaption: miningFormulaStatusLabel(version.referralBoostStatus),
        position: LoopRowPosition.last,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(key: ValueKey<String>('$keyPrefix-rows'), rows: rows),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            <String>[
              miningFormulaStatusLabel(version.status),
              // The scope the version declares about itself, wherever the
              // version is printed.
              if (version.scope.isBaseline) miningBaselineLabel,
              if (version.approvedAt != null)
                '批准于 ${launchTimestampLabel(version.approvedAt!)}',
            ].join(' · '),
            key: ValueKey<String>('$keyPrefix-status'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        if (version.assetWeights.isNotEmpty) ...<Widget>[
          const LoopLabel('资产权重'),
          LoopRecordGroup(
            key: ValueKey<String>('$keyPrefix-asset-weights'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < version.assetWeights.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    '$keyPrefix-asset-weight-'
                    '${version.assetWeights.keys.elementAt(index)}',
                  ),
                  title: miningAssetLabel(
                    version.assetWeights.keys.elementAt(index),
                  ),
                  subtitle: version.assetWeights.keys.elementAt(index),
                  trailing: version.assetWeights.values.elementAt(index),
                  position: launchRowPosition(
                    index,
                    version.assetWeights.length,
                  ),
                ),
            ],
          ),
        ],
        const LoopLabel('评审因子'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final factor in version.weightRange.reviewFactorKeys)
                Padding(
                  key: ValueKey<String>('$keyPrefix-factor-$factor'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${miningRuleKeyText(factor)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
