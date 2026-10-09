import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/intel/intel_rank_controller.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart'
    show LoopProfileAvatar;
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

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
    // The board names a community by id; its logo comes from the summaries
    // this account already read (decision 0122).
    final faces = ref.watch(communityFacesProvider);
    if (state.scope == MiningRankScope.communities) {
      final home = ref.watch(communityHomeControllerProvider);
      if (home.phase == CommunityViewPhase.loading && home.value == null) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(communityHomeControllerProvider.notifier).load(),
            );
          }
        });
      }
    }

    // The three boards follow a sideways swipe as well as a tap on their
    // chips (S123 m7); past the first or last board the swipe moves 情报's
    // own segments.
    return LoopSegmentSwipe(
      key: const ValueKey<String>('intel-rank-swipe'),
      index: scopes.indexOf(state.scope),
      count: scopes.length,
      onSelect: (index) => unawaited(controller.select(scopes[index])),
      child: LoopDashboardPage(
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
            icons: <String>[
              for (final scope in scopes) intelRankScopeIcon(scope),
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
            IntelRankMePill(rank: rank, faces: faces),
            MiningStaleNotice(slug: 'intel-rank', snapshot: rank.snapshot),
            ..._rows(rank, faces),
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
                // A board that has reached its end draws nothing more
                // (decision 0122, OKX rule 10).
                const SizedBox(
                  key: ValueKey<String>('intel-rank-end'),
                  height: 12,
                ),
            ],
            _provenance(rank),
          ],
        ],
      ),
    );
  }

  static bool _hasRows(MiningRanking ranking) => switch (ranking) {
    MiningRankingUsers(:final items) => items.isNotEmpty,
    MiningRankingCommunities(:final items) => items.isNotEmpty,
    MiningRankingReferrals(:final items) => items.isNotEmpty,
    MiningRankingUnavailable() => false,
  };

  List<Widget> _rows(MiningRank rank, Map<String, CommunityFace> faces) {
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
        final referrals = rank.scope == MiningRankScope.referrals;
        return <Widget>[
          LoopEmptyState(
            key: const ValueKey<String>('intel-rank-empty'),
            illustration: LoopIllustration.rank,
            title: referrals ? '还没有人邀请到好友' : '这一次还没有条目上榜',
            message: referrals ? '邀请到第一位好友后，这里按直接邀请人数排名' : '下一次算力快照后再来看看',
            action: referrals
                ? LoopButton(
                    key: const ValueKey<String>('intel-rank-empty-invite'),
                    label: '去邀请',
                    icon: 'users',
                    primary: true,
                    onPressed: () => widget.onNavigate('/profile/referral'),
                  )
                : null,
          ),
        ];
      case MiningRankingUsers(:final items):
        return _board(<IntelRankEntry>[
          for (var index = 0; index < items.length; index += 1)
            _userEntry(items[index], index, rank),
        ]);
      case MiningRankingCommunities(:final items):
        return _board(<IntelRankEntry>[
          for (final row in items)
            IntelRankEntry(
              id: 'community-${row.community.communityId}',
              position: row.position,
              leading: (size) => CommunityLogo(
                identity: row.community.communityId,
                name: row.community.name,
                logoRef: faces[row.community.communityId]?.logoRef,
                size: size,
                radius: size >= 48 ? 16 : LoopRadius.innerValue,
              ),
              name: row.community.name,
              weight: row.weight,
              figure: loopGroupedFigure(row.power),
              spoken: '${row.participants} 人有算力，算力',
              onTap: () => widget.onNavigate(
                '/community/profile?id='
                '${Uri.encodeQueryComponent(row.community.communityId)}',
              ),
            ),
        ]);
      case MiningRankingReferrals(:final items):
        return _board(<IntelRankEntry>[
          for (var index = 0; index < items.length; index += 1)
            IntelRankEntry(
              id: 'referral-$index',
              position: items[index].position,
              leading: (size) => _identityAvatar(items[index].display, size),
              name: _identityName(items[index].display, rank),
              isSelf: items[index].isSelf,
              figure: '${items[index].invitedCount}',
              spoken: '邀请人数',
            ),
        ]);
    }
  }

  /// The first three places on the podium, every later one as a row.
  ///
  /// Only a place the server numbered 1, 2 or 3 goes up; a tie keeps the
  /// server's own number on both entries.
  List<Widget> _board(List<IntelRankEntry> entries) {
    var podium = 0;
    while (podium < entries.length &&
        podium < 3 &&
        (entries[podium].position ?? 99) <= 3) {
      podium += 1;
    }
    return <Widget>[
      if (podium > 0) IntelRankPodium(entries: entries.sublist(0, podium)),
      for (final entry in entries.skip(podium))
        IntelRankRow(
          key: ValueKey<String>('intel-rank-${entry.id}'),
          position: entry.position,
          leading: entry.leading(36),
          name: entry.name,
          caption: entry.caption,
          weight: entry.weight,
          isSelf: entry.isSelf,
          figure: entry.figure,
          spoken: entry.spoken,
          onTap: entry.onTap,
        ),
    ];
  }

  IntelRankEntry _userEntry(MiningRankUserRow row, int index, MiningRank rank) {
    final anonymousToOthers =
        row.isSelf &&
        row.display is MiningRankAlias &&
        (row.display as MiningRankAlias).audience == MiningRankAudience.self;
    return IntelRankEntry(
      id: 'user-$index',
      position: row.position,
      leading: (size) => _identityAvatar(row.display, size),
      name: _identityName(row.display, rank),
      caption: anonymousToOthers ? '其他人看到的是匿名成员' : null,
      isSelf: row.isSelf,
      // A number its owner keeps to themselves is withheld, not unread.
      figure: row.power == null ? '仅本人可见' : loopGroupedFigure(row.power!),
      spoken: row.power == null ? null : '算力',
    );
  }

  static String _identityName(MiningRankIdentity identity, MiningRank rank) =>
      switch (identity) {
        MiningRankAlias(:final alias) => alias,
        // B7: an anonymous member stays anonymous; the label is the server's.
        MiningRankAnonymous(:final labelKey) => miningRuleKeyText(labelKey),
      };

  static Widget _identityAvatar(MiningRankIdentity identity, double size) =>
      switch (identity) {
        MiningRankAlias(:final alias, :final avatarRef) => LoopProfileAvatar(
          avatarRef: avatarRef,
          alias: alias,
          size: size,
        ),
        MiningRankAnonymous() => LoopProfileAvatar(
          avatarRef: null,
          alias: '匿名',
          size: size,
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
        ?intelRankParticipantsDetail(rank),
        ?miningProvenanceDetail(snapshot, formula: formula),
      ].join('\n'),
    );
  }
}

/// The chip glyph of each board (decision 0122).
String intelRankScopeIcon(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => 'community',
  MiningRankScope.users => 'user',
  MiningRankScope.referrals => 'users',
};

/// How many members hold power in each ranked community — the figure the
/// rows used to print as 「N 人有算力 ·」 (decision 0122 moved it here).
String? intelRankParticipantsDetail(MiningRank rank) {
  final ranking = rank.ranking;
  if (ranking is! MiningRankingCommunities || ranking.items.isEmpty) {
    return null;
  }
  return '有算力的成员：${<String>[for (final row in ranking.items) '${row.community.name} ${row.participants} 人'].join('、')}。';
}

/// One place on a board, before it is drawn on the podium or as a row.
@immutable
final class IntelRankEntry {
  const IntelRankEntry({
    required this.id,
    required this.position,
    required this.leading,
    required this.name,
    required this.figure,
    this.caption,
    this.weight,
    this.spoken,
    this.isSelf = false,
    this.onTap,
  });

  /// Stable key suffix: `community-<id>`, `user-<index>`, `referral-<index>`.
  final String id;

  /// `null` on a zero power: in the snapshot, not on the board.
  final int? position;
  final Widget Function(double size) leading;
  final String name;
  final String figure;
  final String? caption;

  /// The community's approved weight, drawn as a small 「权重 x」 tag.
  final String? weight;

  /// What the figure is, said aloud only (「算力」, 「邀请人数」).
  final String? spoken;
  final bool isSelf;
  final VoidCallback? onTap;

  String spokenLabel() => <String>[
    if (position == null) '未上榜' else '第 $position 名',
    name,
    if (isSelf) '我',
    ?caption,
    if (weight != null) '权重 $weight',
    <String>[?spoken, figure].join(' '),
  ].join('，');
}

/// The colour of a medal: first Lime, second brass, third copper.
Color intelRankMedalColour(int place) => switch (place) {
  1 => LoopColors.lime,
  2 => LoopColors.brass,
  _ => LoopColors.copper,
};

/// 「我的名次」 as one capsule under the chips (decision 0122): the reader's
/// face, 「第 2 名」 and the figure — or 「还没有名次」.
class IntelRankMePill extends ConsumerWidget {
  const IntelRankMePill({required this.rank, required this.faces, super.key});

  final MiningRank rank;
  final Map<String, CommunityFace> faces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = rank.me;
    final referrals = rank.scope == MiningRankScope.referrals;
    final mine = me?.communityId;
    final Widget face;
    if (rank.scope == MiningRankScope.communities && mine != null) {
      String name = faces[mine]?.name ?? '';
      final ranking = rank.ranking;
      if (ranking is MiningRankingCommunities) {
        for (final row in ranking.items) {
          if (row.community.communityId == mine) name = row.community.name;
        }
      }
      face = CommunityLogo(
        identity: mine,
        name: name,
        logoRef: faces[mine]?.logoRef,
        size: 26,
        radius: 8,
      );
    } else {
      final state = ref.watch(profileControllerProvider);
      if (state.phase == ProfilePhase.initial) {
        scheduleMicrotask(() {
          if (context.mounted) {
            unawaited(ref.read(profileControllerProvider.notifier).load());
          }
        });
      }
      final profile = state.resource?.values;
      face = LoopProfileAvatar(
        avatarRef: profile?.avatarRef,
        alias: profile?.alias,
        size: 26,
      );
    }
    final value = me == null
        ? null
        : (referrals ? '${me.value} 人' : loopGroupedFigure(me.value));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: me == null ? '我的名次，还没有名次' : '我的名次，第 ${me.rank} 名，$value',
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey<String>('intel-rank-me'),
              height: 36,
              padding: const EdgeInsets.fromLTRB(5, 0, 14, 0),
              decoration: const BoxDecoration(
                color: LoopColors.card,
                borderRadius: LoopRadius.pill,
                border: Border.fromBorderSide(
                  BorderSide(color: LoopColors.line),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  face,
                  const SizedBox(width: 8),
                  Text(
                    me == null ? '还没有名次' : '第 ${me.rank} 名',
                    key: const ValueKey<String>('intel-rank-me-heading'),
                    style: LoopTypography.title(
                      13,
                      color: me == null ? LoopColors.text2 : LoopColors.chalk,
                    ),
                  ),
                  if (value != null) ...<Widget>[
                    Text(
                      '  ·  ',
                      style: LoopType.caption.copyWith(color: LoopColors.text3),
                    ),
                    Flexible(
                      child: Text(
                        value,
                        key: const ValueKey<String>('intel-rank-me-value'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopTypography.figure(
                          13,
                          weight: FontWeight.w600,
                          color: LoopColors.text2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first three places (decision 0122): three cards side by side, the
/// winner in the middle with a crown and a 56 face, second and third with 48
/// faces, all three one height (decision 0123), each with a medal in its
/// place colour.
class IntelRankPodium extends StatelessWidget {
  const IntelRankPodium({required this.entries, super.key})
    : assert(entries.length >= 1 && entries.length <= 3);

  final List<IntelRankEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Second, first, third — the podium's own order.
    final order = <int>[
      if (entries.length > 1) 1,
      0,
      if (entries.length > 2) 2,
    ];
    return Padding(
      key: const ValueKey<String>('intel-rank-podium'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      // Decision 0123: the three cards share one height, so a two-line name
      // never makes one card taller than its neighbours.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var slot = 0; slot < order.length; slot += 1) ...<Widget>[
              if (slot > 0) const SizedBox(width: 8),
              Expanded(
                child: _PodiumCard(
                  entry: entries[order[slot]],
                  place: order[slot] + 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The face size on the podium: the winner 56, second and third 48.
double intelPodiumFaceSize(int place) => place == 1 ? 56 : 48;

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, required this.place});

  final IntelRankEntry entry;

  /// 1, 2 or 3 — the podium slot, which is also the medal's colour.
  final int place;

  @override
  Widget build(BuildContext context) {
    final medal = intelRankMedalColour(place);
    final first = place == 1;
    final number = entry.position ?? place;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        // OKX card: a flat face, no edge; the winner is one step lighter
        // and one crown taller (decision 0122).
        color: first ? LoopColors.card2 : LoopColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        children: <Widget>[
          if (first) ...<Widget>[
            const LoopIcon('crown', size: 18, color: LoopColors.lime),
            const SizedBox(height: 6),
          ] else
            // Second and third stand lower than the winner: the spare height
            // of the equal cards goes above their faces, not between the
            // name and the figure (decision 0123).
            const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              SizedBox.square(
                key: ValueKey<String>('intel-rank-face-$place'),
                dimension: intelPodiumFaceSize(place),
                child: entry.leading(intelPodiumFaceSize(place)),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  key: ValueKey<String>('intel-rank-medal-$place'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: medal,
                    shape: BoxShape.circle,
                    border: Border.all(color: LoopColors.ink, width: 2),
                  ),
                  child: Text(
                    '$number',
                    style: LoopTypography.figure(
                      11,
                      weight: FontWeight.w800,
                      color: LoopColors.ink,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.name,
            key: ValueKey<String>('intel-rank-name-$place'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LoopTypography.title(14),
          ),
          // The figures sit on one line across the three cards.
          if (first) const Spacer(),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry.figure,
              maxLines: 1,
              style: LoopTypography.figure(
                15,
                weight: FontWeight.w700,
                color: LoopColors.chalk,
              ),
            ),
          ),
          if (entry.weight != null || entry.isSelf) ...<Widget>[
            const SizedBox(height: 6),
            entry.isSelf
                ? const LoopBadge('我')
                : _WeightTag(weight: entry.weight!),
          ],
        ],
      ),
    );
    final tap = entry.onTap;
    return Semantics(
      button: tap != null,
      label: entry.spokenLabel(),
      excludeSemantics: true,
      child: tap == null
          ? KeyedSubtree(
              key: ValueKey<String>('intel-rank-${entry.id}'),
              child: card,
            )
          : GestureDetector(
              key: ValueKey<String>('intel-rank-${entry.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: card,
            ),
    );
  }
}

/// 「权重 1.5」 as a hairline capsule.
class _WeightTag extends StatelessWidget {
  const _WeightTag({required this.weight});

  final String weight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: const BoxDecoration(
      borderRadius: LoopRadius.pill,
      border: Border.fromBorderSide(BorderSide(color: LoopColors.line2)),
    ),
    child: Text(
      '权重 $weight',
      maxLines: 1,
      style: LoopType.captionSm.copyWith(color: LoopColors.text2),
    ),
  );
}

/// One place from the fourth on: position · face · name · figure. No card;
/// a hairline under it.
class IntelRankRow extends StatelessWidget {
  const IntelRankRow({
    required this.position,
    required this.leading,
    required this.name,
    required this.figure,
    super.key,
    this.caption,
    this.weight,
    this.spoken,
    this.isSelf = false,
    this.onTap,
  });

  /// `null` on a zero power: in the snapshot, not on the board.
  final int? position;
  final Widget leading;
  final String name;
  final String? caption;
  final String? weight;
  final String figure;

  /// What the figure is, said aloud only.
  final String? spoken;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final place = position;
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
            width: 30,
            child: Text(
              place == null ? '未上榜' : '$place',
              maxLines: 1,
              style: place == null
                  ? LoopType.captionSm.copyWith(color: LoopColors.text3)
                  : LoopTypography.figure(
                      13,
                      weight: FontWeight.w600,
                      color: LoopColors.text3,
                    ),
            ),
          ),
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
                ] else if (weight != null) ...<Widget>[
                  const SizedBox(height: 3),
                  _WeightTag(weight: weight!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(figure, maxLines: 1, style: LoopType.figure),
        ],
      ),
    );
    final label = <String>[
      if (place == null) '未上榜' else '第 $place 名',
      name,
      if (isSelf) '我',
      ?caption,
      if (weight != null) '权重 $weight',
      <String>[?spoken, figure].join(' '),
    ].join('，');
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: label,
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
