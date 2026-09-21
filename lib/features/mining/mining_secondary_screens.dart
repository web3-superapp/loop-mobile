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
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
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
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-assets-rules-action'),
          icon: 'info',
          label: '查看规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: MiningCompositePrimary(
        primary: _assetsHero(assets, state.phase),
        detail: <Widget>[
          MiningDetailRow(
            key: const ValueKey<String>('mining-assets-total'),
            label: '我的总算力',
            value: switch (assets?.totalPower) {
              MiningFigureValue(:final value) => loopGroupedFigure(value),
              _ => launchMissingFigure,
            },
            spoken: switch (assets?.totalPower) {
              MiningFigureValue(:final value) => loopGroupedFigure(value),
              MiningFigureUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => '还没有读到',
            },
          ),
          if (assets != null && miningGateIsBaseline(assets.formula))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                miningBaselineLabel,
                key: const ValueKey<String>('mining-assets-total-baseline'),
                style: LoopTypography.caption(11, color: LoopColors.text2),
              ),
            ),
        ],
      ),
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
          MiningStaleNotice(
            slug: 'assets',
            snapshot: assets.source,
            symbols: _assetSymbols(assets),
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-assets-open-communities'),
                leading: const LoopRowIcon(icon: 'clock'),
                title: '查看社区挖矿面板',
                subtitle: '每个社区的权重按审核结果授予',
                onTap: widget.onOpenCommunities,
              ),
            ],
          ),
          const LoopLabel('Included Assets'),
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
                  miningCompositionRow(
                    assets.included[index],
                    launchRowPosition(index, assets.included.length),
                    symbols: _assetSymbols(assets),
                  ),
              ],
            ),
          if (!assets.isUnsettled) ...<Widget>[
            const LoopLabel('Excluded Assets'),
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
          const LoopLabel('Reference Price'),
          _ReferencePriceBlock(referencePrice: assets.referencePrice),
          const LoopLabel('公式版本'),
          MiningFormulaBlock(formula: assets.formula),
          const LoopLabel(miningSnapshotSectionLabel),
          _AssetsSourceBlock(
            source: assets.source,
            symbols: _assetSymbols(assets),
          ),
          LoopNotice(
            key: const ValueKey<String>('mining-assets-price-notice'),
            icon: 'shield',
            title: '参考价不是瞬时成交价',
            body: switch ((
              assets.included.any((row) => row.isProxiedPrice),
              assets.included.any((row) => row.isDerivedPrice),
            )) {
              (true, _) =>
                '参考价由多个渠道的价格计算得出。有的资产没有自己的交易对，'
                    '用的是另一个已登记代币的价格，这里已经逐行标出。',
              (false, true) =>
                '参考价由多个渠道的价格计算得出。有的资产只出现在别的代币的报价对里，'
                    '价格由那个报价对推导得出，并且必须落在公式版本声明的区间内，这里已经逐行标出。',
              (false, false) => '参考价由多个渠道的价格计算得出，不是某一笔成交的价格。',
            },
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The hero.
///
/// The prototype heads this page with the expression itself — `持有量 ×
/// 参考价 × 权重` — because the page *is* that expression, asset by asset;
/// the total it produces is the reading welded under the card. The App used
/// to print the total here and the formula nowhere, which left the heading
/// saying 暂无数值 over a page whose subject is how a number is made (visual
/// audit §I.3).
///
/// The caption is the only part that moves: a frame that has read nothing
/// says so, and an answer with no total carries the reason the total came
/// with.
LoopFolioPrimary _assetsHero(MiningAssets? assets, LaunchViewPhase phase) {
  final caption = switch (assets?.totalPower) {
    MiningFigureValue() => '每个资产的贡献、排除状态与数据来源分别列明。',
    MiningFigureUnavailable(:final reasonCode) => launchReasonCodeText(
      reasonCode,
    ),
    null when phase == LaunchViewPhase.loading => '每个资产的贡献与排除状态读到之后显示在这里。',
    null => '这一页还没有读到算力明细。',
  };
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'POWER FORMULA',
    heading: miningPowerFormulaHeading,
    caption: caption,
    margin: EdgeInsets.zero,
    squareBottom: true,
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

/// Which settlement these rows came from. The identifiers it carries are
/// backend strings, so only the block height and the time reach the row.
class _AssetsSourceBlock extends StatelessWidget {
  const _AssetsSourceBlock({required this.source, this.symbols = const {}});

  final MiningSnapshotRef source;

  /// Registry symbols by asset id, so an unread holding is named the way the
  /// rows above name it.
  final Map<String, String> symbols;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
        LoopEmpty(
          key: const ValueKey<String>('mining-assets-source-unavailable'),
          icon: 'clock',
          message: miningSnapshotAbsenceMessage(reasonCode),
          reason: miningSnapshotAbsenceReason(
            reasonCode,
            attempt: latestAttempt,
            symbols: symbols,
          ),
        ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-assets-source'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-assets-source-row'),
              title: miningSnapshotRowTitle,
              subtitle:
                  '区块 ${loopGroupedFigure(blockNumber)} · '
                  '${launchTimestampLabel(computedAt)} · '
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
      onBack: widget.onBack,
      primary: MiningCompositePrimary(
        primary: _rewardsHero(rewards, state.phase),
        detail: <Widget>[
          Text(
            '待领取 LOOP · 每日 00:00 UTC 结算',
            key: const ValueKey<String>('mining-rewards-cadence'),
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
          const MiningDetailRule(),
          MiningDetailRow(
            key: const ValueKey<String>('mining-rewards-readings'),
            label: '今日预估',
            value: switch (rewards?.estimatedToday) {
              MiningDailyOutputEstimate(:final value) => loopGroupedFigure(
                value,
              ),
              _ => launchMissingFigure,
            },
            spoken: switch (rewards?.estimatedToday) {
              MiningDailyOutputEstimate(:final value) => loopGroupedFigure(
                value,
              ),
              MiningDailyOutputUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => '还没有读到',
            },
            trailingLabel: '累计已挖',
            trailingValue: launchMissingFigure,
          ),
          if (rewards?.estimatedToday case final MiningDailyOutputEstimate e)
            if (e.isPlaceholderBudget)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  <String>[
                    if (e.scope.isBaseline) miningBaselineLabel,
                    '按占位产量估算，奖励代币还没有确定。',
                  ].join(' · '),
                  key: const ValueKey<String>('mining-rewards-budget-note'),
                  style: LoopTypography.caption(11, color: LoopColors.text2),
                ),
              ),
        ],
      ),
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
          MiningDashReasons(
            slug: 'mining-rewards',
            // 待领取 is the heading itself, and the caption under it is the
            // claim's own reason; it is not written twice.
            said: <String>{launchReasonCodeText(rewards.claimable.reasonCode)},
            entries: <(String, String)>[
              if (rewards.estimatedToday case MiningDailyOutputUnavailable(
                :final reasonCode,
              ))
                ('今日预估', launchReasonCodeText(reasonCode)),
              ('累计已挖', launchReasonCodeText(rewards.accumulated.reasonCode)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
          const LoopLabel('Claim Records'),
          _RewardsLedgerBlock(
            source: rewards.source,
            claimable: rewards.claimable,
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-rewards-ledger-notice'),
            icon: 'chart',
            title: '结算公式',
            body:
                '我的算力 ÷ 全网算力 × 当日产量。预估会随全网算力变化，最终以服务端结算状态为准；'
                '这里只列奖励账本的条目，算力在算力明细里。',
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
    // `#scr-mining-rewards .ledger-card.folio-primary` carries no
    // `.ledger-quiet`: this is one of the two saturated Lime heroes in the
    // module, and the App had painted both of them the quiet green.
    variant: LoopFolioVariant.lime,
    archetype: LoopFolioArchetype.record,
    kicker: 'CLAIMABLE REWARD',
    heading: heading,
    caption: caption,
    // `.folio-stamp` states a reading, never a state name: it appears only
    // when the server says the claim can actually be executed.
    stamp: (rewards?.claimExecutable ?? false) ? 'CLAIMABLE' : null,
    ring: false,
    margin: EdgeInsets.zero,
    squareBottom: true,
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
      onBack: widget.onBack,
      primary: MiningCompositePrimary(
        primary: _rankHero(rank),
        detail: <Widget>[
          MiningDetailRow(
            key: const ValueKey<String>('mining-rank-reading'),
            label: '我的名次',
            value: switch (rank?.myPosition) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              _ => launchMissingFigure,
            },
            spoken: switch (rank?.myPosition) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              MiningRankPositionUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => '还没有读到',
            },
            trailingLabel: '已确认算力',
            trailingValue: switch (rank?.myPosition) {
              MiningRankPositionSettled(:final power) => loopGroupedFigure(
                power,
              ),
              _ => launchMissingFigure,
            },
          ),
          const MiningDetailRule(),
          Text(
            '榜单按服务端已确认算力快照排序',
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
        ],
      ),
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
            MiningStaleNotice(slug: 'rank', snapshot: rank.snapshot),
            LoopLabel(
              scope == MiningRankScope.communities
                  ? 'Community Ranking'
                  : 'User Ranking',
            ),
            _RankingBlock(ranking: rank.ranking),
            const LoopLabel('公式版本'),
            MiningFormulaBlock(formula: rank.formula),
            const LoopLabel('显示规则'),
            LoopNotice(
              key: const ValueKey<String>('mining-rank-anonymity'),
              icon: 'shield',
              title: '排行条目如何显示身份与算力',
              body:
                  '${miningRuleKeyText(rank.display.ruleKey)}'
                  '匿名时显示「${miningRuleKeyText(rank.display.anonymousMemberKey)}」。\n'
                  '${miningRuleKeyText(rank.display.powerRuleKey)}',
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
    // `.folio-stamp` on this page is `50,000 H` — the settled power behind the
    // place, never a state name.
    stamp: switch (rank?.myPosition) {
      MiningRankPositionSettled(:final power) =>
        '${loopGroupedFigure(power)} H',
      _ => null,
    },
    ring: false,
    margin: EdgeInsets.zero,
    squareBottom: true,
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
      MiningRankingUsers(:final items, :final participants) => _split(
        participants: participants,
        ranked: items.where((item) => item.isRanked).toList(growable: false),
        unranked: items.where((item) => !item.isRanked).toList(growable: false),
        row: _userRow,
      ),
      MiningRankingCommunities(:final items, :final participants) => _split(
        participants: participants,
        ranked: items.where((item) => item.isRanked).toList(growable: false),
        unranked: items.where((item) => !item.isRanked).toList(growable: false),
        row: _communityRow,
      ),
    };
  }

  /// An entry the settlement left off the board is not a place on it. The
  /// 榜单 group used to carry both, so a row reading 未上榜 sat between two
  /// numbered places; the two groups are now separated by a label that says
  /// which is which.
  static Widget _split<T>({
    required int participants,
    required List<T> ranked,
    required List<T> unranked,
    required LoopRecordRow Function(T, int, LoopRowPosition) row,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (ranked.isEmpty)
        const LoopEmpty(
          key: ValueKey<String>('mining-rank-none-ranked'),
          icon: 'info',
          message: '这一次没有条目上榜',
          reason: '下面的条目算力为 0，快照没有给它们名次。',
        )
      else
        LoopRecordGroup(
          key: const ValueKey<String>('mining-rank-items'),
          rows: <LoopRecordRow>[
            for (var index = 0; index < ranked.length; index += 1)
              row(
                ranked[index],
                index,
                launchRowPosition(index, ranked.length),
              ),
          ],
        ),
      if (unranked.isNotEmpty) ...<Widget>[
        const LoopLabel(_miningUnrankedLabel),
        LoopRecordGroup(
          key: const ValueKey<String>('mining-rank-unranked-items'),
          rows: <LoopRecordRow>[
            for (var index = 0; index < unranked.length; index += 1)
              row(
                unranked[index],
                ranked.length + index,
                launchRowPosition(index, unranked.length),
              ),
          ],
        ),
      ],
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

  static Widget _emptyBoard(int participants) => LoopEmpty(
    key: const ValueKey<String>('mining-rank-empty'),
    icon: 'info',
    message: '最近一次算力快照里没有可以上榜的条目',
    reason: _participantsLine(participants),
  );

  static String _participantsLine(int participants) =>
      '最近一次算力快照里有 $participants 个条目算出了算力。';
}

/// 未上榜, not the position 0: a zero power is a settled reading, and the
/// board simply has no place for it.
const String _miningUnrankedLabel = '未上榜';

/// 算力仅本人可见, not 读不到: the owner set their mining power visibility to
/// themselves, so the number was never published to this reader. The position
/// beside it is public and stays.
const String _miningPowerWithheldLabel = '算力仅本人可见';

LoopRecordRow _userRow(
  MiningRankUserRow row,
  int index,
  LoopRowPosition position,
) {
  final name = switch (row.display) {
    MiningRankAlias(:final alias) => alias,
    MiningRankAnonymous(:final labelKey) => miningRuleKeyText(labelKey),
  };
  final place = row.isRanked
      ? '第 ${row.position} 名'
      : '$_miningUnrankedLabel · 算力为 0';
  final powerNote = switch (row) {
    // Somebody else's number, withheld by its owner.
    MiningRankUserRow(power: null) => _miningPowerWithheldLabel,
    // The reader's own number, which nobody else is shown.
    MiningRankUserRow(isSelf: true, powerVisibility: MiningRankAudience.self) =>
      '算力只有你自己看得到',
    _ => null,
  };
  // The reader's own alias while anonymous mode is on: this row is not what
  // the board shows anybody else, and it says so instead of letting the
  // reader assume their alias is public.
  final anonymousToOthers =
      row.isSelf &&
      row.display is MiningRankAlias &&
      (row.display as MiningRankAlias).audience == MiningRankAudience.self;
  final subtitle = <String>[
    <String>[place, ?powerNote].join(' · '),
    if (anonymousToOthers) '其他人看到的是匿名成员',
  ].join('\n');
  return LoopRecordRow(
    // The board may carry several anonymous entries with the same power, and
    // 「power + name」 was the same string for each of them: two siblings with
    // one key is an assertion, not a board. The row's place in the answer is
    // what distinguishes them.
    key: ValueKey<String>(
      'mining-rank-user-$index-${row.power ?? 'withheld'}-$name',
    ),
    // `.row-ico` carries the place itself on the user board; an entry with no
    // place carries the dash rather than a number it was not given.
    leading: LoopRowIcon(
      monogram: row.isRanked ? '#${row.position}' : launchMissingFigure,
      tone: row.isSelf ? LoopRowIconTone.accent : LoopRowIconTone.neutral,
    ),
    title: name,
    subtitle: subtitle,
    subtitleMaxLines: 2,
    trailing: row.power,
    trailingBadge: row.isSelf ? const LoopBadge('我') : null,
    semanticLabel: <String>[
      name,
      row.isRanked ? '第 ${row.position} 名' : _miningUnrankedLabel,
      if (row.power != null) '算力 ${row.power}',
      ?powerNote,
      if (anonymousToOthers) '其他人看到的是匿名成员',
    ].join('，'),
    position: position,
  );
}

LoopRecordRow _communityRow(
  MiningRankCommunityRow row,
  int index,
  LoopRowPosition position,
) => LoopRecordRow(
  key: ValueKey<String>('mining-rank-community-${row.community.communityId}'),
  leading: LoopInitialsAvatar(label: row.community.name, size: 44),
  title: row.isRanked
      ? '#${row.position} ${row.community.name}'
      : row.community.name,
  subtitle: row.isRanked
      ? '第 ${row.position} 名 · ${row.participants} 人有算力'
      : '$_miningUnrankedLabel · ${row.participants} 人有算力',
  subtitleMaxLines: 2,
  trailing: row.power,
  trailingCaption: '权重 ${row.weight}',
  position: position,
);

/// `mining-community` · one community's mining panel.
class MiningCommunityScreen extends ConsumerStatefulWidget {
  const MiningCommunityScreen({
    super.key,
    this.communityId,
    this.onBack,
    this.onOpenRank,
  });

  final String? communityId;
  final VoidCallback? onBack;

  /// `#scr-mining-community .topbar .tool-btn`: the board this panel's place
  /// comes from.
  final VoidCallback? onOpenRank;

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
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-community-rank-action'),
          icon: 'chart',
          label: '查看排行榜',
          onPressed: widget.onOpenRank,
        ),
      ],
      primary: MiningCompositePrimary(
        primary: _communityHero(community, state.phase),
        detail: <Widget>[
          MiningDetailRow(
            key: const ValueKey<String>('mining-community-reading'),
            label: '社区排名',
            value: switch (community?.rank) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              _ => launchMissingFigure,
            },
            spoken: switch (community?.rank) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              MiningRankPositionUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => '还没有读到',
            },
            trailingLabel: '参与人数',
            trailingValue: switch (community?.participants) {
              MiningParticipantsCount(:final count) => '$count',
              _ => launchMissingFigure,
            },
          ),
        ],
      ),
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
          MiningStaleNotice(slug: 'community', snapshot: community.snapshot),
          const LoopLabel('My Contribution'),
          _MyContributionCard(community: community),
          const LoopLabel('Community Records'),
          _CommunityRecords(community: community),
          const LoopLabel('社区权重'),
          _WeightBlock(weight: community.weight),
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
    // `.folio-stamp` is `0.35×` — the weight already inside the figure above,
    // printed only once the review granted one.
    stamp: switch (community?.weight) {
      MiningCommunityWeightApproved(:final value) => '$value×',
      _ => null,
    },
    ring: false,
    margin: EdgeInsets.zero,
    squareBottom: true,
  );
}

/// `MY CONTRIBUTION` — the prototype's one Chalk card in this module.
///
/// The App had no Chalk surface on any mining page, so the six pages read as
/// one unbroken dark run (visual audit §I.1). The two cells are the two facts
/// this reader owns here: the power their holding contributes, and the weight
/// that is already inside it. Neither is computed on the device.
class _MyContributionCard extends StatelessWidget {
  const _MyContributionCard({required this.community});

  final MiningCommunity community;

  @override
  Widget build(BuildContext context) {
    final (
      String contribution,
      String spokenContribution,
    ) = switch (community.myContribution) {
      MiningFigureValue(:final value) => (
        loopGroupedFigure(value),
        loopGroupedFigure(value),
      ),
      MiningFigureUnavailable(:final reasonCode) => (
        launchMissingFigure,
        launchReasonCodeText(reasonCode),
      ),
    };
    final (String weight, String spokenWeight) = switch (community.weight) {
      MiningCommunityWeightApproved(:final value) => ('$value×', '$value×'),
      MiningCommunityWeightPending(:final reasonCode) => (
        launchMissingFigure,
        launchReasonCodeText(reasonCode),
      ),
    };
    return LoopChalkCard(
      key: const ValueKey<String>('mining-community-contribution'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Semantics(
        container: true,
        label: '我的算力，$spokenContribution。社区权重，$spokenWeight',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: _cell('我的算力', contribution)),
                  const SizedBox(width: 14),
                  Expanded(child: _cell('社区权重', weight)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Container(
                  height: 1,
                  color: LoopColors.ink.withValues(alpha: 0.14),
                ),
              ),
              Text(
                '权重由平台审核结果授予，已经算在上面的算力里。',
                style: LoopTypography.caption(
                  10,
                  color: LoopColors.ink.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _cell(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LoopTypography.figure(
          16,
          weight: FontWeight.w700,
          color: LoopColors.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: LoopTypography.caption(
          9,
          color: LoopColors.ink.withValues(alpha: 0.58),
        ),
      ),
    ],
  );
}

/// `COMMUNITY RECORDS` — the two readings the panel is a record of.
class _CommunityRecords extends StatelessWidget {
  const _CommunityRecords({required this.community});

  final MiningCommunity community;

  @override
  Widget build(BuildContext context) {
    return LoopRecordGroup(
      key: const ValueKey<String>('mining-community-metrics'),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-participants'),
          title: '参与挖矿的持有人',
          subtitle: switch (community.participants) {
            MiningParticipantsUnavailable(:final reasonCode) =>
              launchReasonCodeText(reasonCode),
            MiningParticipantsCount() => '最近一次算力快照里算出了算力的成员',
          },
          subtitleMaxLines: 2,
          trailing: switch (community.participants) {
            MiningParticipantsUnavailable() => launchMissingFigure,
            MiningParticipantsCount(:final count) => '$count',
          },
          position: LoopRowPosition.first,
        ),
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-power'),
          title: '社区总算力',
          // The folio heads this same figure and already carries its reason.
          subtitle: switch (community.communityPower) {
            MiningFigureUnavailable() => null,
            MiningFigureValue() => '成员在绑定资产上的算力之和',
          },
          subtitleMaxLines: 2,
          trailing: switch (community.communityPower) {
            MiningFigureUnavailable() => launchMissingFigure,
            MiningFigureValue(:final value) => loopGroupedFigure(value),
          },
          position: LoopRowPosition.last,
        ),
      ],
    );
  }
}

/// Which settlement this panel read. The identifiers it carries are backend
/// strings, so only the block height and the time reach the row.
class _CommunitySnapshotBlock extends StatelessWidget {
  const _CommunitySnapshotBlock({required this.snapshot});

  final MiningSnapshotRef snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot) {
      MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
        LoopEmpty(
          key: const ValueKey<String>('mining-community-snapshot-unavailable'),
          icon: 'clock',
          message: miningSnapshotAbsenceMessage(reasonCode),
          reason: miningSnapshotAbsenceReason(
            reasonCode,
            attempt: latestAttempt,
          ),
        ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-community-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-community-snapshot-row'),
              title: miningSnapshotRowTitle,
              subtitle:
                  '区块 ${loopGroupedFigure(blockNumber)} · '
                  '${launchTimestampLabel(computedAt)} · '
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
    final approved = rules?.approved;
    // 算力明细 is the read that carries a symbol for each asset id, and the
    // rule keys are asset ids. Without it 「资产权重」 can only head its rows
    // with a contract address, so this page asks for it too; the read is
    // shared with 算力明细 and is skipped when it already has a value. A read
    // that does not answer leaves the rows saying the id, never a made-up
    // name.
    final assetsState = ref.watch(miningAssetsControllerProvider);
    if (!blocked && assetsState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningAssetsControllerProvider.notifier).load());
        }
      });
    }
    final assets = assetsState.value;
    final symbols = assets == null
        ? const <String, String>{}
        : _assetSymbols(assets);

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rules-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      // The prototype's topbar says 挖矿规则 and its hero says 权重与价格保护;
      // the App had the two the other way round (visual audit §I.7).
      title: '挖矿规则',
      onBack: widget.onBack,
      primary: MiningCompositePrimary(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'POWER RULES',
          // The hero used to announce a draft over a page whose first section
          // is 「已批准的版本」 with an 已批准 badge inside it, so one screen
          // said both that the rule was pending and that it was approved. The
          // sentence now follows whether a version has been approved, and the
          // big line shows the rule in force when there is one.
          heading: '权重与价格保护',
          caption: switch ((approved, draft)) {
            (null, null) => '还没有已批准的公式，也没有待批准的草案。',
            (null, _) => '还没有已批准的公式。下面这条是等待批准的草案。',
            (_, null) => '这一版已批准，当前生效；没有待批准的草案。',
            (_, _) => '这一版已批准，当前生效。下面另有等待批准的草案。',
          },
          stamp: switch ((approved, draft)) {
            (_?, _) => '已批准',
            (null, _?) => '待批准',
            (null, null) => null,
          },
          ring: false,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[
          Text('DAILY OUTPUT', style: LoopMono.label),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '每日产出 ',
                  style: LoopTypography.caption(
                    11,
                    color: LoopColors.chalk,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: switch (approved ?? draft) {
                    final MiningFormulaVersion version => miningRuleKeyText(
                      version.dailyOutputKey,
                    ),
                    null => launchMissingFigure,
                  },
                  style: LoopTypography.caption(11, color: LoopColors.text2),
                ),
              ],
            ),
            key: const ValueKey<String>('mining-rules-daily-output'),
          ),
        ],
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
              symbols: symbols,
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
                symbols: symbols,
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
  const _FormulaVersionBlock({
    required this.version,
    required this.keyPrefix,
    this.symbols = const <String, String>{},
  });

  final MiningFormulaVersion version;
  final String keyPrefix;

  /// Registry symbols by asset id, when 算力明细 has already been read.
  ///
  /// 「资产权重」 headed three of its four rows with a contract address
  /// (`0x0e09…ce82`) and repeated the whole CAIP id underneath. The rule keys
  /// are asset ids, and the same ids carry a symbol on the 算力明细 read, so
  /// the row is headed by the symbol whenever that read has happened. Without
  /// it the row still says the id rather than inventing a name.
  final Map<String, String> symbols;

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
        // The expression itself is the composite strip's, stated once at the
        // top of the page; this row carries the budget the version pins.
        // The budget is published with its own status, so it is printed with
        // it: a placeholder number never stands on the page by itself. The
        // separators are display only and are dropped whenever they cannot be
        // added without changing what the server said.
        trailing: version.dailyOutput == null
            ? null
            : loopGroupedFigure(version.dailyOutput!.budget),
        trailingCaption: version.dailyOutput == null
            ? null
            : (version.dailyOutput!.isPlaceholder ? '占位产量' : '当日产量'),
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
    // `WEIGHT RANGE`: the prototype heads each band with its own tile, so the
    // two bands are told apart before they are read (visual audit §I.7).
    final weightRows = <LoopRecordRow>[
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-loop'),
        leading: const LoopRowIcon(
          monogram: 'LOOP',
          tone: LoopRowIconTone.accent,
        ),
        title: 'LOOP',
        subtitle: miningRuleKeyText(version.weightRange.loop.descriptionKey),
        subtitleMaxLines: 2,
        trailing: launchMissingFigure,
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.loop.status,
        ),
        position: LoopRowPosition.first,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-community'),
        leading: const LoopRowIcon(monogram: 'COMM'),
        title: '经审核的社区币',
        subtitle: miningRuleKeyText(
          version.weightRange.community.descriptionKey,
        ),
        subtitleMaxLines: 2,
        // The bounds print only once the version pinned them; until then the
        // band is a rule with no numbers and keeps the em dash.
        trailing: switch (version.weightRange.community.range) {
          null => launchMissingFigure,
          MiningWeightBounds(:final min, :final max) => '$min–$max',
        },
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.community.status,
        ),
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
                  title: miningAssetTitle(
                    symbol: symbols[version.assetWeights.keys.elementAt(index)],
                    assetId: version.assetWeights.keys.elementAt(index),
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
        const LoopLabel('Weight Range'),
        LoopRecordGroup(
          key: ValueKey<String>('$keyPrefix-weight-range'),
          rows: weightRows,
        ),
        const LoopLabel('Review Factors'),
        LoopChalkCard(
          key: ValueKey<String>('$keyPrefix-review-factors'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final factor in version.weightRange.reviewFactorKeys)
                Padding(
                  key: ValueKey<String>('$keyPrefix-factor-$factor'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    miningRuleKeyText(factor),
                    style: LoopTypography.caption(11, color: LoopColors.ink),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Container(
                  height: 1,
                  color: LoopColors.ink.withValues(alpha: 0.14),
                ),
              ),
              Text(
                '具体量化分值不公开，权重以平台综合评定结果为准。',
                style: LoopTypography.caption(
                  9,
                  color: LoopColors.ink.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        if (version.priceGuardRules.isNotEmpty) ...<Widget>[
          const LoopLabel('Reference Price Guard'),
          LoopRecordGroup(
            key: ValueKey<String>('$keyPrefix-guards'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < version.priceGuardRules.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    '$keyPrefix-guard-'
                    '${version.priceGuardRules[index].ruleKey}',
                  ),
                  leading: LoopRowIcon(
                    monogram: (index + 1).toString().padLeft(2, '0'),
                  ),
                  title: miningRuleKeyText(
                    version.priceGuardRules[index].ruleKey,
                  ),
                  subtitle: miningFormulaStatusLabel(
                    version.priceGuardRules[index].status,
                  ),
                  position: launchRowPosition(
                    index,
                    version.priceGuardRules.length,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
