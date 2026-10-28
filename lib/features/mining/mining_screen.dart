import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `mining` · the Mining destination.
///
/// The mining formula is backend delivery D19 and no version is approved yet,
/// so every figure on this page is the em dash plus the server's own reason,
/// and the hero says the absence in words rather than printing a 29px dash.
/// The client never estimates power, output, accumulation or a claim.
///
/// Its shape is the prototype's composite dashboard: one Lime card carrying
/// the rank, the power, three metrics and the two next steps, then the
/// composition that produced the power. The page used to spread the same
/// facts over five stacked key-value blocks and a menu of four links, which
/// put 领取奖励 three screens below the fold (visual audit 2026-09-21 §I.2).
class MiningScreen extends ConsumerStatefulWidget {
  const MiningScreen({
    super.key,
    this.onOpenAssets,
    this.onOpenRewards,
    this.onOpenRank,
    this.onOpenRules,
    this.onOpenReferral,
    this.onOpenMarket,
    this.onBack,
  });

  /// Set when 挖矿 is opened as a page (from 我) rather than as a tab.
  final VoidCallback? onBack;

  final VoidCallback? onOpenAssets;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenRank;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenReferral;

  /// 行情, where the weighted community tokens are discovered.
  final VoidCallback? onOpenMarket;

  @override
  ConsumerState<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends ConsumerState<MiningScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningSummaryControllerProvider);
    final controller = ref.read(miningSummaryControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final summary = state.value;

    // The composition that produced the figure in the hero, and the place on
    // the board it earned. Both are reads this module already makes for its
    // own pages — 算力明细 and 算力排行榜 — and the two pages share the
    // provider, so opening either one from here costs no second request.
    final assetsState = ref.watch(miningAssetsControllerProvider);
    if (!blocked && assetsState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningAssetsControllerProvider.notifier).load());
        }
      });
    }
    final rankState = ref.watch(miningRankControllerProvider);
    if (!blocked && rankState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningRankControllerProvider.notifier).load());
        }
      });
    }

    // Decision 0184: whether the LOOP token is live is the rewards resource's
    // to say (`hourly.claim`, the claim contract). It is the same provider
    // 挖矿奖励 reads, so opening that page from here costs no second request.
    // Until it answers — and whenever it does not say — the page counts
    // power only.
    final rewardsState = ref.watch(miningRewardsViewControllerProvider);
    if (!blocked && rewardsState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(miningRewardsViewControllerProvider.notifier).load(),
          );
        }
      });
    }
    final rewards = rewardsState.value;
    final live = miningTokenLive(rewards);

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的挖矿',
      onBack: widget.onBack,
      tabPage: widget.onBack == null,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-rules-action'),
          icon: 'info',
          label: '挖矿说明',
          onPressed: () => unawaited(_openInfo(summary)),
        ),
      ],
      primary: summary == null
          ? _hero(summary, state.phase)
          : MiningSummaryHero(
              heading: _heroHeading(summary),
              unit: _heroUnit(summary),
              caption: _heroCaption(summary),
              stamp: _heroStamp(summary),
              rank: _rankBadge(rankState.value),
              metrics: live
                  ? <MiningHeroMetric>[
                      _dailyMetric(summary.estimatedToday),
                      MiningHeroMetric(
                        slug: 'accumulated',
                        label: '累计已挖',
                        value: launchMissingFigure,
                        spoken: launchReasonCodeText(
                          summary.accumulated.reasonCode,
                        ),
                      ),
                      MiningHeroMetric(
                        slug: 'claimable',
                        label: '待领取',
                        value: launchMissingFigure,
                        spoken: launchReasonCodeText(
                          summary.claimable.reasonCode,
                        ),
                      ),
                    ]
                  : _powerMetrics(summary, rewards),
              // The claim itself lives on 奖励与领取, which states whether it
              // can be executed; this button is how the reader gets there.
              onClaim: widget.onOpenRewards,
              claimSemanticLabel: '领取奖励，打开奖励与领取',
              onOpenAssets: widget.onOpenAssets,
              powerOnly: !live,
              split: miningPoolSplitMetrics(rewards),
            ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('mining-capability-unavailable'),
              title: '挖矿当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (summary == null)
          LaunchStateBlock(
            prefix: 'mining',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '暂无算力数据',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // S315 (需求方 2026-10-27): 总算力 → 算力构成 → 社区, and no
          // sentence between them. The snapshot time is the hero's one line;
          // why a figure is a dash is the (i)'s, not the page's. The quiet
          // 「(i) 来源」 stays under the hero (decision 0121).
          MiningSnapshotProvenanceLine(
            slug: 'summary',
            snapshot: summary.snapshot,
            formula: summary.formula,
            markStale: true,
          ),
          const LoopLabel('算力构成'),
          _CompositionBlock(
            rewards: rewards,
            phase: rewardsState.phase,
            failureKind: rewardsState.failureKind,
            assets: assetsState.value,
          ),
          const LoopLabel('社区'),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-community-entries'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-market'),
                leading: const LoopRowIcon(icon: 'search'),
                title: '有权重的社区币',
                onTap: widget.onOpenMarket,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-rank'),
                leading: const LoopRowIcon(icon: 'chart'),
                title: '算力排行榜',
                trailing: _rankTrailing(rankState.value),
                onTap: widget.onOpenRank,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-referral'),
                leading: const LoopRowIcon(icon: 'users'),
                title: '邀请加成',
                onTap: widget.onOpenReferral,
                semanticLabel:
                    '邀请加成，${launchReasonCodeText(summary.referralBoost.reasonCode)}',
                position: LoopRowPosition.last,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// The (i) in the header (decision 0243, 需求方 2026-10-23 #04): the
  /// formula version, the snapshot the figures came from and the no-local-
  /// estimate rule — where the numbers come from, said once here instead of
  /// three blocks under 增加算力 — and the way on to 挖矿规则.
  Future<void> _openInfo(MiningSummary? summary) => showLoopInfoSheet(
    context,
    title: '挖矿说明',
    notes: miningInfoNotes(summary),
    sheetKey: 'mining-info-sheet',
    footer: widget.onOpenRules == null
        ? null
        : (sheetContext) => LoopButton(
            key: const ValueKey<String>('mining-info-open-rules'),
            label: '查看挖矿规则',
            block: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              widget.onOpenRules?.call();
            },
          ),
  );
}

/// 公式版本 in the (i): the state in words, then — on its own line, the way
/// the 详情 disclosure it replaces printed it — the version identifier, which
/// is only ever shown behind a tap.
String _formulaInfoBody(MiningFormulaGate? formula) {
  final (
    String sentence,
    String? label,
    String? identifier,
  ) = switch (formula) {
    null => ('还没有读到挖矿摘要，公式版本读到之后显示在这里。', null, null),
    MiningFormulaPending(:final reasonCode, pendingVersion: null) => (
      '挖矿公式还没有批准的版本：${launchReasonCodeText(reasonCode)}',
      null,
      null,
    ),
    MiningFormulaPending(:final pendingVersion) => (
      '挖矿公式待批准。批准后，页面上的数字才会有来源。',
      '待批准的公式版本',
      pendingVersion,
    ),
    MiningFormulaEffective(
      :final effectiveAt,
      :final scope,
      :final configVersion,
    ) =>
      (
        '挖矿公式已生效${scope.isBaseline ? '（$miningBaselineLabel）' : ''}'
            ' · 生效于 ${launchTimestampLabel(effectiveAt)}',
        '已生效的公式版本',
        configVersion,
      ),
  };
  return label == null || identifier == null
      ? sentence
      : '$sentence\n$label $identifier';
}

/// What 我的挖矿's (i) says (decision 0243). It reads the same summary the
/// page draws; without one it says the figures have not been read, never a
/// version or a block it does not have.
List<LoopInfoNote> miningInfoNotes(MiningSummary? summary) {
  final formula = summary?.formula;
  final snapshot = summary?.snapshot;
  return <LoopInfoNote>[
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-formula'),
      title: '公式版本',
      body: _formulaInfoBody(formula),
    ),
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-snapshot'),
      title: miningSnapshotRowTitle,
      body: switch (snapshot) {
        null => '还没有读到算力快照。',
        MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
          '${miningSnapshotAbsenceMessage(reasonCode)}。'
              '${miningSnapshotAbsenceReason(reasonCode, attempt: latestAttempt)}',
        MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
          '区块 ${loopGroupedFigure(blockNumber)} · '
              '${launchTimestampLabel(computedAt)} · '
              '这是算出算力的时间',
      },
    ),
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-truth'),
      title: '不做本地估算',
      body: switch (formula) {
        MiningFormulaEffective() => 'LOOP 不会在这台设备上累计积分或估算收益，页面上的数字都来自最近一次算力快照。',
        _ => 'LOOP 不会在这台设备上累计积分或估算收益。读不到不等于「算力为零」。',
      },
    ),
    // Decision 0183 (需求方 2026-10-25): what a holding needs before it
    // counts, one condition per line.
    const LoopInfoNote(
      key: ValueKey<String>('mining-info-conditions'),
      title: '哪些持仓计入算力',
      body:
          '持币算力 = 持有数量 × 资产权重，不乘价格；NFT 按所属社区系数计。\n'
          '$miningConditionVerified\n'
          '$miningConditionMember\n'
          '$miningConditionEmbedded',
    ),
  ];
}

/// The hero heading: the power itself, or the words for its absence.
String _heroHeading(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending() => launchMissingHeading,
  MiningFormulaEffective() => switch (summary.power) {
    MiningFigureValue(:final value) => loopPowerFigure(value),
    MiningFigureUnavailable() => launchMissingHeading,
  },
};

/// `.mining-power-value small` — the unit only a settled figure carries.
String? _heroUnit(MiningSummary summary) =>
    _heroHeading(summary) == launchMissingHeading ? null : 'H';

/// The hero's one line under the figure: when the snapshot behind it was
/// computed, and 未更新 when a later run overtook it (decision 0057). S315: no
/// sentence about formulas or promises; the (i) carries those.
String _heroCaption(MiningSummary summary) => switch (summary.snapshot) {
  MiningSnapshotComputed(:final computedAt, :final stale) =>
    '快照 · ${launchTimestampLabel(computedAt)}${stale ? ' · 未更新' : ''}',
  _ => '快照 · $launchMissingFigure',
};

String? _heroStamp(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending(:final pendingVersion) =>
    pendingVersion != null ? '待批准' : null,
  MiningFormulaEffective(:final scope) =>
    scope.isBaseline ? miningBaselineLabel : null,
};

/// The three cells while the LOOP token is not live (decision 0184): the
/// network's power, the account's last settled hour and its counted
/// invites. None of them is a LOOP amount.
List<MiningHeroMetric> _powerMetrics(
  MiningSummary summary,
  MiningRewardsView? rewards,
) {
  final hour = miningLastHourPower(rewards);
  final invites = rewards?.invites?.total.activeMembers;
  return <MiningHeroMetric>[
    switch (summary.networkPower) {
      MiningFigureValue(:final value) => MiningHeroMetric(
        slug: 'network-power',
        label: '全网算力',
        value: loopPowerFigure(value),
        spoken: loopPowerFigure(value),
      ),
      MiningFigureUnavailable(:final reasonCode) => MiningHeroMetric(
        slug: 'network-power',
        label: '全网算力',
        value: launchMissingFigure,
        spoken: launchReasonCodeText(reasonCode),
      ),
    },
    MiningHeroMetric(
      slug: 'last-hour-power',
      label: '上一小时算力',
      value: hour == null ? launchMissingFigure : miningPowerFigure(hour),
      spoken: hour == null ? '还没有结算的小时' : miningPowerFigure(hour),
    ),
    MiningHeroMetric(
      slug: 'active-invites',
      label: '有效邀请',
      value: invites == null ? launchMissingFigure : '$invites 人',
      spoken: invites == null ? '还没有读到' : '$invites 人',
    ),
  ];
}

MiningHeroMetric _dailyMetric(MiningDailyOutput output) => switch (output) {
  MiningDailyOutputEstimate(:final value) => MiningHeroMetric(
    slug: 'estimated-today',
    label: '今日预估',
    value: loopGroupedFigure(value),
    spoken: loopGroupedFigure(value),
  ),
  MiningDailyOutputUnavailable(:final reasonCode) => MiningHeroMetric(
    slug: 'estimated-today',
    label: '今日预估',
    value: launchMissingFigure,
    spoken: launchReasonCodeText(reasonCode),
  ),
};

/// 第 1,284 名. It prints only a place the server settled; a board this
/// reader is not on, and a board that did not load, both leave it out.
String? _rankBadge(MiningRank? rank) => switch (rank?.myPosition) {
  MiningRankPositionSettled(:final position) => '第 $position 名',
  _ => null,
};

String? _rankTrailing(MiningRank? rank) => switch (rank?.myPosition) {
  MiningRankPositionSettled(:final position) => '第 $position 名',
  _ => null,
};

/// The hero, before anything was read. A read that has not landed says only
/// that it is reading, and the reason a read failed stays with the state block
/// that owns it.
LoopFolioPrimary _hero(MiningSummary? summary, LaunchViewPhase phase) {
  final loading = phase == LaunchViewPhase.loading;
  return LoopFolioPrimary(
    ring: false,
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: '总算力',
    heading: loading ? '正在读取' : launchMissingHeading,
  );
}

/// 代币算力 and NFT 算力 (decision 0253): the two pools of the last settled
/// hour, `tracks.asset.totalPower` and `tracks.nft.totalPower` as the server
/// settled them. The snapshot behind 总算力 does not split them.
List<MiningHeroMetric> miningPoolSplitMetrics(MiningRewardsView? rewards) {
  MiningHeroMetric cell(String slug, String label, Decimal? value) =>
      MiningHeroMetric(
        slug: slug,
        label: label,
        value: value == null ? launchMissingFigure : miningPowerFigure(value),
        spoken: value == null ? '还没有结算的小时' : miningPowerFigure(value),
      );
  return <MiningHeroMetric>[
    cell('token-power', '代币算力', rewards?.asset?.totalPower),
    cell('nft-power', 'NFT 算力', rewards?.nft?.totalPower),
  ];
}

/// 算力构成 (decision 0253) — two groups, 代币 and NFT, each headed by its
/// pool's subtotal. The rows are the last settled hour's: one per counted
/// asset and one for the NFTs held, plus 邀请加成 when the invites added
/// power to that pool. The snapshot rows lend an asset its symbol and logo
/// only; their power folds NFT power into the MEME row, so it is not used here.
class _CompositionBlock extends ConsumerWidget {
  const _CompositionBlock({
    required this.rewards,
    required this.phase,
    required this.failureKind,
    required this.assets,
  });

  final MiningRewardsView? rewards;
  final LoopChainViewPhase phase;
  final LoopChainFailureKind? failureKind;
  final MiningAssets? assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = rewards;
    if (view == null) {
      return LoopChainStateBlock(
        keyPrefix: 'mining-composition',
        phase: phase,
        failureKind: failureKind,
        rows: 2,
        emptyMessage: '暂无算力构成',
        onRetry: () => unawaited(
          ref.read(miningRewardsViewControllerProvider.notifier).reload(),
        ),
      );
    }
    final snapshotRows = <String, MiningAssetRow>{
      for (final row in assets?.included ?? const <MiningAssetRow>[])
        row.assetId: row,
    };
    final asset = view.asset;
    final nft = view.nft;
    final tokenRows = <_HourRow>[
      for (final holding in asset?.assets ?? const <MiningTrackAsset>[])
        _HourRow.asset(holding, snapshotRows[holding.assetId]),
      if (asset != null && asset.invitePower > Decimal.zero)
        _HourRow.invite('token', asset.invitePower),
    ];
    final nftRows = <_HourRow>[
      if (nft != null &&
          (nft.realCount > BigInt.zero || nft.ownPower > Decimal.zero))
        _HourRow.nft(nft),
      if (nft != null && nft.invitePower > Decimal.zero)
        _HourRow.invite('nft', nft.invitePower),
    ];
    return Column(
      key: const ValueKey<String>('mining-composition'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ..._group(
          slug: 'token',
          title: '代币',
          subtotal: asset?.totalPower,
          rows: tokenRows,
          emptyTitle: '暂无代币算力',
        ),
        ..._group(
          slug: 'nft',
          title: 'NFT',
          subtotal: nft?.totalPower,
          rows: nftRows,
          emptyTitle: '暂无 NFT 算力',
        ),
      ],
    );
  }

  static List<Widget> _group({
    required String slug,
    required String title,
    required Decimal? subtotal,
    required List<_HourRow> rows,
    required String emptyTitle,
  }) => <Widget>[
    MiningCompositionGroupHeading(
      slug: slug,
      title: title,
      subtotal: subtotal == null
          ? launchMissingFigure
          : miningPowerFigure(subtotal),
      spoken: subtotal == null ? '还没有结算的小时' : miningPowerFigure(subtotal),
    ),
    if (rows.isEmpty)
      LoopEmptyState(
        key: ValueKey<String>('mining-composition-$slug-empty'),
        illustration: LoopIllustration.holders,
        title: emptyTitle,
        compact: true,
      )
    else
      LoopRecordGroup(
        key: ValueKey<String>('mining-composition-$slug'),
        rows: <LoopRecordRow>[
          for (var index = 0; index < rows.length; index += 1)
            rows[index].build(launchRowPosition(index, rows.length)),
        ],
      ),
  ];
}

/// One row of the hour's composition.
final class _HourRow {
  _HourRow.asset(MiningTrackAsset holding, MiningAssetRow? snapshot)
    : key = 'mining-composition-token-${holding.assetId}',
      title = miningAssetTitle(
        symbol: snapshot?.symbol,
        assetId: holding.assetId,
      ),
      // A named row still says which asset it is (S321 row).
      subtitle = snapshot?.symbol == null
          ? null
          : miningAssetLabel(holding.assetId),
      power = holding.power,
      leading = LoopTokenLogo(
        assetSymbol:
            snapshot?.symbol ??
            miningAssetTitle(symbol: null, assetId: holding.assetId),
        logoUrl: snapshot?.logoUrl,
        size: 44,
        semanticLabel: miningAssetTitle(
          symbol: snapshot?.symbol,
          assetId: holding.assetId,
        ),
      );

  _HourRow.nft(MiningNftTrack track)
    : key = 'mining-composition-nft-held',
      title = 'NFT',
      subtitle = '持有 ${loopGroupedFigure(track.realCount.toString())} 个',
      power = track.ownPower,
      leading = const LoopRowIcon(icon: 'star');

  _HourRow.invite(String slug, this.power)
    : key = 'mining-composition-$slug-invite',
      title = '邀请加成',
      subtitle = null,
      leading = const LoopRowIcon(icon: 'users');

  final String key;
  final String title;
  final String? subtitle;
  final Decimal power;
  final Widget leading;

  LoopRecordRow build(LoopRowPosition position) => LoopRecordRow(
    key: ValueKey<String>(key),
    leading: leading,
    title: title,
    subtitle: subtitle,
    trailing: miningPowerFigure(power),
    trailingCaption: '算力',
    semanticLabel: <String>[
      title,
      ?subtitle,
      '算力 ${miningPowerFigure(power)}',
    ].join('，'),
    position: position,
  );
}
