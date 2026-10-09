import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/intel/intel_rank_controller.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart'
    show LoopProfileAvatar;
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The chip label of each board, in the order they are drawn.
String intelRankScopeLabel(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => '社区',
  MiningRankScope.users => '用户',
  MiningRankScope.referrals => '推广',
};

/// The height of one board row.
const double intelRankRowHeight = 60;

/// 情报 · 算力榜 (decision 0118).
///
/// Three boards behind chips — 社区 / 用户 / 推广 — each opened on the
/// reader's own place and then the board itself, a row per place: position,
/// face, name, figure. The board reads on as the reader scrolls and ends on
/// 「没有更多」. What the figures are and when they were computed is one weak
/// line at the foot, which opens the display rules that used to be two cards.
class IntelRankBoard extends ConsumerStatefulWidget {
  const IntelRankBoard({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<IntelRankBoard> createState() => _IntelRankBoardState();
}

class _IntelRankBoardState extends ConsumerState<IntelRankBoard> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(intelRankBoardControllerProvider);
    final controller = ref.read(intelRankBoardControllerProvider.notifier);
    if (!blocked &&
        state.phase == LaunchViewPhase.loading &&
        state.rank == null) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rank = state.rank;
    const scopes = IntelRankBoardController.scopes;

    return LoopDashboardPage(
      key: const ValueKey<String>('intel-rank-board'),
      archetype: LoopPageArchetype.listing,
      title: '算力榜',
      embedded: true,
      tabPage: true,
      onRefresh: controller.reload,
      updating: state.refreshing,
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('intel-rank-capability-block'),
              title: '算力榜当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        LoopSegBar(
          key: const ValueKey<String>('intel-rank-scope'),
          labels: <String>[
            for (final scope in scopes) intelRankScopeLabel(scope),
          ],
          selectedIndex: scopes.indexOf(state.scope),
          onSelected: (index) => unawaited(controller.select(scopes[index])),
        ),
        if (rank == null)
          LaunchStateBlock(
            prefix: 'intel-rank',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.record,
            rows: 6,
            emptyMessage: '没有读到算力榜',
            emptyReason: '暂时读不到排行数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          IntelRankMeCard(rank: rank),
          MiningStaleNotice(slug: 'intel-rank', snapshot: rank.snapshot),
          ..._rows(rank),
          if (_hasRows(rank.ranking)) ...<Widget>[
            if (state.appendFailed && !state.loadingMore)
              LoopInlineUnavailable(
                key: const ValueKey<String>('intel-rank-more-failed'),
                message: '下一页没有读到',
                onRetry: () => unawaited(controller.loadMore()),
              )
            else if (rank.nextCursor case final String cursor) ...<Widget>[
              LoopLoadMoreSentinel(
                key: const ValueKey<String>('intel-rank-load-more'),
                cursor: cursor,
                onLoadMore: () => unawaited(controller.loadMore()),
              ),
              if (state.loadingMore)
                const LoopSkeleton(
                  key: ValueKey<String>('intel-rank-loading-more'),
                  type: LoopSkeletonType.record,
                  rows: 2,
                ),
            ] else
              Padding(
                key: const ValueKey<String>('intel-rank-end'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  '没有更多',
                  textAlign: TextAlign.center,
                  style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                ),
              ),
          ],
          _provenance(rank),
        ],
      ],
    );
  }

  static bool _hasRows(MiningRanking ranking) => switch (ranking) {
    MiningRankingUsers(:final items) => items.isNotEmpty,
    MiningRankingCommunities(:final items) => items.isNotEmpty,
    MiningRankingReferrals(:final items) => items.isNotEmpty,
    MiningRankingUnavailable() => false,
  };

  List<Widget> _rows(MiningRank rank) {
    final ranking = rank.ranking;
    switch (ranking) {
      case MiningRankingUnavailable(:final reasonCode):
        return <Widget>[
          LoopInlineUnavailable(
            key: const ValueKey<String>('intel-rank-unavailable'),
            message: '榜单暂时读不到 · ${launchReasonCodeText(reasonCode)}',
            onRetry: () => unawaited(
              ref.read(intelRankBoardControllerProvider.notifier).reload(),
            ),
          ),
        ];
      case MiningRankingUsers(:final items) when items.isEmpty:
      case MiningRankingCommunities(:final items) when items.isEmpty:
      case MiningRankingReferrals(:final items) when items.isEmpty:
        return <Widget>[
          LoopEmpty(
            key: const ValueKey<String>('intel-rank-empty'),
            icon: 'info',
            message: rank.scope == MiningRankScope.referrals
                ? '还没有人邀请到好友'
                : '这一次还没有条目上榜',
            reason: rank.scope == MiningRankScope.referrals
                ? '邀请到第一位好友后，这里会按直接邀请人数排名。'
                : '最近一次算力快照里没有可以上榜的条目。',
          ),
        ];
      case MiningRankingUsers(:final items):
        return <Widget>[
          for (var index = 0; index < items.length; index += 1)
            _userRow(items[index], index),
        ];
      case MiningRankingCommunities(:final items):
        return <Widget>[
          for (final row in items)
            IntelRankRow(
              key: ValueKey<String>(
                'intel-rank-community-${row.community.communityId}',
              ),
              position: row.position,
              leading: CommunityLogo(
                identity: row.community.communityId,
                name: row.community.name,
                size: 36,
              ),
              name: row.community.name,
              caption: '${row.participants} 人有算力 · 权重 ${row.weight}',
              figure: loopGroupedFigure(row.power),
              figureCaption: '算力',
              onTap: () => widget.onNavigate(
                '/community/profile?id='
                '${Uri.encodeQueryComponent(row.community.communityId)}',
              ),
            ),
        ];
      case MiningRankingReferrals(:final items):
        return <Widget>[
          for (var index = 0; index < items.length; index += 1)
            IntelRankRow(
              key: ValueKey<String>('intel-rank-referral-$index'),
              position: items[index].position,
              leading: _identityAvatar(items[index].display, rank),
              name: _identityName(items[index].display, rank),
              isSelf: items[index].isSelf,
              figure: '${items[index].invitedCount}',
              figureCaption: '邀请人数',
            ),
        ];
    }
  }

  Widget _userRow(MiningRankUserRow row, int index) {
    final rank = ref.read(intelRankBoardControllerProvider).rank!;
    final anonymousToOthers =
        row.isSelf &&
        row.display is MiningRankAlias &&
        (row.display as MiningRankAlias).audience == MiningRankAudience.self;
    return IntelRankRow(
      key: ValueKey<String>('intel-rank-user-$index'),
      position: row.position,
      leading: _identityAvatar(row.display, rank),
      name: _identityName(row.display, rank),
      caption: anonymousToOthers ? '其他人看到的是匿名成员' : null,
      isSelf: row.isSelf,
      // A number its owner keeps to themselves is withheld, not unread.
      figure: row.power == null ? '仅本人可见' : loopGroupedFigure(row.power!),
      figureCaption: row.power == null ? null : '算力',
    );
  }

  static String _identityName(MiningRankIdentity identity, MiningRank rank) =>
      switch (identity) {
        MiningRankAlias(:final alias) => alias,
        // B7: an anonymous member stays anonymous; the label is the server's.
        MiningRankAnonymous(:final labelKey) => miningRuleKeyText(labelKey),
      };

  static Widget _identityAvatar(MiningRankIdentity identity, MiningRank rank) =>
      switch (identity) {
        MiningRankAlias(:final alias, :final avatarRef) => LoopProfileAvatar(
          avatarRef: avatarRef,
          alias: alias,
          size: 36,
        ),
        MiningRankAnonymous() => const LoopProfileAvatar(
          avatarRef: null,
          alias: '匿名',
          size: 36,
        ),
      };

  Widget _provenance(MiningRank rank) {
    final snapshot = rank.snapshot;
    final formula = rank.formula;
    final referrals = rank.scope == MiningRankScope.referrals;
    return LoopProvenanceLine(
      key: const ValueKey<String>('intel-rank-provenance'),
      // The version identifier itself stays off the line (copy glossary):
      // the line says which kind of rule ranked the board.
      prefix: referrals
          ? '按直接邀请人数'
          : switch (formula) {
              MiningFormulaEffective() => '按当前生效的算力公式',
              MiningFormulaPending() => '算力公式待生效',
            },
      sources: <String>[referrals ? 'LOOP 邀请关系' : 'LOOP 算力快照'],
      observedAt: referrals
          ? null
          : switch (snapshot) {
              MiningSnapshotComputed(:final computedAt) => computedAt,
              MiningSnapshotUnavailable() => null,
            },
      detail: <String>[
        if (referrals)
          '推广榜按当前有效的直接邀请人数排名，人数相同名次相同；邀请关系实时读取，不等待算力快照。'
        else
          '名次来自最近一次算力快照，其他账号或社区的算力变化会改变名次；不会在这台设备上计算。',
        '${miningRuleKeyText(rank.display.ruleKey)}'
            '匿名时显示「${miningRuleKeyText(rank.display.anonymousMemberKey)}」。',
        miningRuleKeyText(rank.display.powerRuleKey),
      ].join('\n'),
    );
  }
}

/// 「我的名次」 at the head of a board: the reader's own place and figure on
/// the board that is open, or a plain 「还没有名次」.
class IntelRankMeCard extends StatelessWidget {
  const IntelRankMeCard({required this.rank, super.key});

  final MiningRank rank;

  @override
  Widget build(BuildContext context) {
    final me = rank.me;
    final referrals = rank.scope == MiningRankScope.referrals;
    final communities = rank.scope == MiningRankScope.communities;
    String? communityName;
    final mine = me?.communityId;
    final ranking = rank.ranking;
    if (mine != null && ranking is MiningRankingCommunities) {
      for (final row in ranking.items) {
        if (row.community.communityId == mine) {
          communityName = row.community.name;
        }
      }
    }
    final heading = me == null ? '还没有名次' : '第 ${me.rank} 名';
    final caption = me == null
        ? switch (rank.scope) {
            MiningRankScope.referrals => '邀请到好友后会出现在推广榜上。',
            MiningRankScope.communities => '加入的社区上榜后会显示在这里。',
            MiningRankScope.users => '持有计入算力的资产后会出现在用户榜上。',
          }
        : communities
        ? (communityName == null ? '我所在的社区' : '我所在的社区 · $communityName')
        : (referrals ? '直接邀请人数' : '我的算力');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        key: const ValueKey<String>('intel-rank-me'),
        decoration: BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.card,
          border: Border.all(color: LoopColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '我的名次',
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      heading,
                      key: const ValueKey<String>('intel-rank-me-heading'),
                      style: me == null
                          ? LoopType.headingSm
                          : LoopType.figureLg,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.captionSm.copyWith(
                        color: LoopColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              if (me != null)
                Text(
                  referrals ? '${me.value} 人' : loopGroupedFigure(me.value),
                  key: const ValueKey<String>('intel-rank-me-value'),
                  style: LoopType.figureMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One place on a board: position · face · name · figure. No card; a
/// hairline under it.
class IntelRankRow extends StatelessWidget {
  const IntelRankRow({
    required this.position,
    required this.leading,
    required this.name,
    required this.figure,
    super.key,
    this.caption,
    this.figureCaption,
    this.isSelf = false,
    this.onTap,
  });

  /// `null` on a zero power: in the snapshot, not on the board.
  final int? position;
  final Widget leading;
  final String name;
  final String? caption;
  final String figure;
  final String? figureCaption;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final place = position;
    final top = place != null && place <= 3;
    final content = Container(
      height: intelRankRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      decoration: BoxDecoration(
        color: isSelf ? LoopColors.card : null,
        border: const Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              place == null ? '未上榜' : '$place',
              maxLines: 1,
              style: place == null
                  ? LoopType.captionSm.copyWith(color: LoopColors.text3)
                  : LoopType.figureMd.copyWith(
                      color: top ? LoopColors.lime : LoopColors.text2,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.title,
                      ),
                    ),
                    if (isSelf) ...<Widget>[
                      const SizedBox(width: 6),
                      const LoopBadge('我'),
                    ],
                  ],
                ),
                if (caption != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(figure, maxLines: 1, style: LoopType.figure),
              if (figureCaption != null)
                Text(
                  figureCaption!,
                  style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                ),
            ],
          ),
        ],
      ),
    );
    final spoken = <String>[
      if (place == null) '未上榜' else '第 $place 名',
      name,
      if (isSelf) '我',
      ?caption,
      <String>[?figureCaption, figure].join(' '),
    ].join('，');
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: spoken,
      excludeSemantics: true,
      child: tap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: tap, child: content),
            ),
    );
  }
}
