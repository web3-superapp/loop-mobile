import 'dart:async';

import 'package:decimal/decimal.dart';
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
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/profile/presentation/owner_face.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart'
    show LoopProfileAvatar;
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart' show LoopProgressBar;
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// The chip label of each board, in the order they are drawn.
String intelRankScopeLabel(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => '社区',
  MiningRankScope.users => '用户',
  MiningRankScope.referrals => '邀请中心',
};

/// The face on a board row (docs/35 `.rank-row .face`).
const double intelRankRowFaceSize = 40;

/// The width of the share bar under a row's figure (`.rank-row .fig .bar`).
const double intelRankShareBarWidth = 64;

/// 情报 · 算力榜 (decisions 0118, 0122, 0182).
///
/// The reader's own place is the page.s one ledger card; the three
/// boards sit behind chips under it — 社区 / 用户 / 推广 — then the first
/// three on a podium and every later place as a row with its share of the
/// leader's figure. The board reads on as the reader scrolls. What the
/// figures are and when they were computed is one weak line at the foot,
/// which opens the display rules.
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

    // The ledger card: the board's own reading once it lands, a skeleton
    // heading while the first page of a board is on its way, nothing when the
    // board could not be read (the state block below says why).
    final Widget? ledger = rank != null
        ? IntelRankLedger(
            key: const ValueKey<String>('intel-rank-me'),
            rank: rank,
            faces: faces,
          )
        : state.phase == LaunchViewPhase.loading
        ? const LoopFolioPrimary(
            key: ValueKey<String>('intel-rank-me-loading'),
            // S241b: the flat dark ledger; the place reads in yellow.
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            ring: false,
            kicker: intelRankLedgerKickerBase,
            heading: '我的名次读取中',
            headingLoading: true,
          )
        : null;

    final scopeBar = LoopSegBar(
      key: const ValueKey<String>('intel-rank-scope'),
      labels: <String>[for (final scope in scopes) intelRankScopeLabel(scope)],
      icons: <String>[for (final scope in scopes) intelRankScopeIcon(scope)],
      selectedIndex: scopes.indexOf(state.scope),
      onSelected: (index) => unawaited(controller.select(scopes[index])),
    );

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
        primary: ledger,
        sections: <Widget>[
          scopeBar,
          // S239 · decision 0214: the third chip is 邀请中心 — my invite code
          // with copy, link and poster, 我的邀请 counts and the way into the
          // full page — over the 推广榜 it always was.
          if (state.scope == MiningRankScope.referrals)
            ReferralCenterCard(onNavigate: widget.onNavigate),
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
            // The ledger card is this page.s one ledger card (decision 0182; flat since S241b).
            action: referrals
                ? LoopButton(
                    key: const ValueKey<String>('intel-rank-empty-invite'),
                    label: '去邀请',
                    icon: 'users',
                    onPressed: () => widget.onNavigate('/profile/referral'),
                  )
                : null,
          ),
        ];
      case MiningRankingUsers(:final items):
        return _board(rank, <IntelRankEntry>[
          for (var index = 0; index < items.length; index += 1)
            _userEntry(items[index], index, rank),
        ]);
      case MiningRankingCommunities(:final items):
        final mine = rank.me?.communityId;
        return _board(rank, <IntelRankEntry>[
          for (final row in items)
            IntelRankEntry(
              id: 'community-${row.community.communityId}',
              position: row.position,
              leading: (size, {chromeFallback = false}) => _communityLogo(
                row.community.communityId,
                row.community.name,
                faces,
                size,
                chromeFallback: chromeFallback,
              ),
              name: row.community.name,
              weight: row.weight,
              caption: '${row.participants} 人有算力',
              amount: Decimal.tryParse(row.power),
              isSelf: mine != null && mine == row.community.communityId,
              figure: loopGroupedFigure(row.power),
              spoken: '算力',
              onTap: () => widget.onNavigate(
                '/community/profile?id='
                '${Uri.encodeQueryComponent(row.community.communityId)}',
              ),
            ),
        ]);
      case MiningRankingReferrals(:final items):
        return _board(rank, <IntelRankEntry>[
          for (var index = 0; index < items.length; index += 1)
            IntelRankEntry(
              id: 'referral-$index',
              position: items[index].position,
              leading: (size, {chromeFallback = false}) => _identityAvatar(
                items[index].display,
                size,
                chromeFallback: chromeFallback,
              ),
              name: _identityName(items[index].display, rank),
              caption: '直接邀请',
              isSelf: items[index].isSelf,
              amount: Decimal.fromInt(items[index].invitedCount),
              figure: '${items[index].invitedCount}',
              spoken: '邀请人数',
              onTap: _profileTap(items[index].display, items[index].isSelf),
            ),
        ]);
    }
  }

  /// The first three places on the podium, every later one as a row, and the
  /// reader's own row at the end when the pages read so far do not hold it.
  ///
  /// Only a place the server numbered 1, 2 or 3 goes up; a tie keeps the
  /// server's own number on both entries.
  List<Widget> _board(MiningRank rank, List<IntelRankEntry> entries) {
    var podium = 0;
    while (podium < entries.length &&
        podium < 3 &&
        (entries[podium].position ?? 99) <= 3) {
      podium += 1;
    }
    final leader = intelRankLeaderAmount(entries);
    final me = rank.me;
    final selfMissing = me != null && !entries.any((entry) => entry.isSelf);
    final rows = entries.skip(podium).toList();
    return <Widget>[
      if (podium > 0) ...<Widget>[
        const LoopLabel(
          '前三名',
          key: ValueKey<String>('intel-rank-podium-label'),
        ),
        IntelRankPodium(entries: entries.sublist(0, podium)),
      ],
      if (rows.isNotEmpty || selfMissing) IntelRankListHead(scope: rank.scope),
      for (final entry in rows)
        IntelRankRow(
          key: ValueKey<String>('intel-rank-${entry.id}'),
          position: entry.position,
          leading: entry.leading(intelRankRowFaceSize),
          name: entry.name,
          caption: entry.caption,
          weight: entry.weight,
          isSelf: entry.isSelf,
          figure: entry.figure,
          share: intelRankShare(entry.amount, leader),
          spoken: entry.spoken,
          onTap: entry.onTap,
        ),
      if (selfMissing)
        IntelRankSelfRow(
          key: const ValueKey<String>('intel-rank-self-row'),
          rank: rank,
          me: me,
          leader: leader,
          faces: ref.watch(communityFacesProvider),
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
      leading: (size, {chromeFallback = false}) =>
          _identityAvatar(row.display, size, chromeFallback: chromeFallback),
      name: _identityName(row.display, rank),
      caption: anonymousToOthers ? '其他人看到的是匿名成员' : null,
      isSelf: row.isSelf,
      amount: row.power == null ? null : Decimal.tryParse(row.power!),
      // A number its owner keeps to themselves is withheld, not unread.
      figure: row.power == null ? '仅本人可见' : loopGroupedFigure(row.power!),
      spoken: row.power == null ? null : '算力',
      onTap: _profileTap(row.display, row.isSelf),
    );
  }

  /// S239: a named row opens its owner's page, the reader's own row opens
  /// 我; an anonymous row opens nothing.
  VoidCallback? _profileTap(MiningRankIdentity identity, bool isSelf) {
    final location = loopProfileFaceLocation(
      identity is MiningRankAlias ? identity.publicProfileId : null,
      isSelf: isSelf,
    );
    return location == null ? null : () => widget.onNavigate(location);
  }

  static String _identityName(MiningRankIdentity identity, MiningRank rank) =>
      switch (identity) {
        MiningRankAlias(:final alias) => alias,
        // B7: an anonymous member stays anonymous; the label is the server's.
        MiningRankAnonymous(:final labelKey) => miningRuleKeyText(labelKey),
      };

  /// A person's face; on the podium (decision 0224) a person with no
  /// picture of their own wears the chrome medal, not initials.
  static Widget _identityAvatar(
    MiningRankIdentity identity,
    double size, {
    bool chromeFallback = false,
  }) => switch (identity) {
    MiningRankAlias(avatarRef: null) ||
    MiningRankAnonymous() when chromeFallback => LoopChromeMedal(size: size),
    _ => _plainIdentityAvatar(identity, size),
  };

  static Widget _plainIdentityAvatar(
    MiningRankIdentity identity,
    double size,
  ) => switch (identity) {
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

/// A community's logo as a round face (docs/35 `.face{border-radius:50%}`).
Widget _communityLogo(
  String communityId,
  String name,
  Map<String, CommunityFace> faces,
  double size, {
  bool chromeFallback = false,
}) => CommunityLogo(
  identity: communityId,
  name: name,
  logoRef: faces[communityId]?.logoRef,
  size: size,
  radius: chromeFallback
      ? size / 2
      : size >= 48
      ? LoopRadius.controlValue
      : size / 2,
  chromeFallback: chromeFallback,
);

/// The chip glyph of each board (decision 0122).
String intelRankScopeIcon(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => 'community',
  MiningRankScope.users => 'user',
  MiningRankScope.referrals => 'users',
};

/// How many members hold power in each ranked community, for the source
/// line's detail (decision 0122).
String? intelRankParticipantsDetail(MiningRank rank) {
  final ranking = rank.ranking;
  if (ranking is! MiningRankingCommunities || ranking.items.isEmpty) {
    return null;
  }
  return '有算力的成员：${<String>[for (final row in ranking.items) '${row.community.name} ${row.participants} 人'].join('、')}。';
}

// ---------------------------------------------------------------------------
// The ledger card (decision 0182)
// ---------------------------------------------------------------------------

/// The kicker every board's ledger card opens with.
const String intelRankLedgerKickerBase = '算力榜';

/// 「算力榜，快照 10-15 04:00」 on the two power boards (the snapshot's own
/// computation time, local), 「算力榜 · 实时」 on 推广, which reads the invite
/// relation live (「算力榜，实时」), and the bare 「算力榜」 when no snapshot was computed.
String intelRankLedgerKicker(MiningRank rank) {
  if (rank.scope == MiningRankScope.referrals) {
    return '$intelRankLedgerKickerBase，实时';
  }
  return switch (rank.snapshot) {
    MiningSnapshotComputed(:final computedAt) =>
      '$intelRankLedgerKickerBase，快照 ${intelRankMonthDayClock(computedAt)}',
    MiningSnapshotUnavailable() => intelRankLedgerKickerBase,
  };
}

/// "MM-dd HH:mm" in the device's local time.
String intelRankMonthDayClock(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${loopClockLabel(local)}';
}

/// 「我的名次\n第 12 名」, or 「我的名次\n还没有名次」.
String intelRankLedgerHeading(MiningRank rank) {
  final me = rank.me;
  return me == null ? '我的名次\n还没有名次' : '我的名次\n第 ${me.rank} 名';
}

/// Every board place the pages read so far hold, with its figure: power on
/// the two power boards, direct invitees on 推广. A withheld power has none.
List<(int, Decimal)> _placedAmounts(MiningRanking ranking) => switch (ranking) {
  MiningRankingUsers(:final items) => <(int, Decimal)>[
    for (final row in items)
      if (row.position case final int place)
        if (row.power case final String power)
          if (Decimal.tryParse(power) case final Decimal value) (place, value),
  ],
  MiningRankingCommunities(:final items) => <(int, Decimal)>[
    for (final row in items)
      if (row.position case final int place)
        if (Decimal.tryParse(row.power) case final Decimal value)
          (place, value),
  ],
  MiningRankingReferrals(:final items) => <(int, Decimal)>[
    for (final row in items) (row.position, Decimal.fromInt(row.invitedCount)),
  ],
  MiningRankingUnavailable() => const <(int, Decimal)>[],
};

/// 「距第 11 名还差 80」 — only when the rows read so far hold the place
/// right above the reader's with a figure larger than the reader's own.
String? intelRankGapToNext(MiningRank rank) {
  final me = rank.me;
  if (me == null || me.rank <= 1) return null;
  final mine = Decimal.tryParse(me.value);
  if (mine == null) return null;
  final above = me.rank - 1;
  for (final (place, value) in _placedAmounts(rank.ranking)) {
    if (place != above) continue;
    final gap = value - mine;
    if (gap <= Decimal.zero) return null;
    final figure = loopGroupedFigure(gap.toString());
    return rank.scope == MiningRankScope.referrals
        ? '距第 $above 名还差 $figure 人'
        : '距第 $above 名还差 $figure';
  }
  return null;
}

/// 「社区 S137 Testnet 权重 1.0」: the reader's best-ranked community on the
/// community board, its weight only when its row has been read.
String? intelRankLedgerCommunity(
  MiningRank rank,
  Map<String, CommunityFace> faces,
) {
  final mine = rank.me?.communityId;
  if (rank.scope != MiningRankScope.communities || mine == null) return null;
  final ranking = rank.ranking;
  if (ranking is MiningRankingCommunities) {
    for (final row in ranking.items) {
      if (row.community.communityId == mine) {
        return '社区 ${row.community.name} 权重 ${row.weight}';
      }
    }
  }
  final name = faces[mine]?.name;
  return name == null || name.isEmpty ? null : '社区 $name';
}

/// The ledger card's caption: the reader's figure, the gap to the place
/// above when it can be read, and the reader's community on the community
/// board. A reader without a place is told how a place is earned.
String intelRankLedgerCaption(
  MiningRank rank,
  Map<String, CommunityFace> faces,
) {
  final me = rank.me;
  final referrals = rank.scope == MiningRankScope.referrals;
  if (me == null) {
    return referrals ? '邀请到第一位好友后上榜' : '有算力后，下一次算力快照上榜';
  }
  return <String>[
    if (referrals)
      '直接邀请 ${me.value} 人'
    else
      '算力 ${loopGroupedFigure(me.value)}',
    ?intelRankGapToNext(rank),
    ?intelRankLedgerCommunity(rank, faces),
    // v3 (decision 0229): a comma, never a centre-dot chain.
  ].join('，');
}

/// How many places the board has, when the server said so.
int? intelRankBoardSize(MiningRanking ranking) => switch (ranking) {
  MiningRankingUsers(:final participants) => participants,
  MiningRankingCommunities(:final participants) => participants,
  MiningRankingReferrals(:final participants) => participants,
  MiningRankingUnavailable() => null,
};

/// 「TOP 8%」 = the reader's place ÷ the board's size, rounded up and held
/// to 1–100. No place or no size draws no stamp.
String? intelRankTopShare(MiningRank rank) {
  final me = rank.me;
  final size = intelRankBoardSize(rank.ranking);
  if (me == null || size == null || size <= 0 || me.rank <= 0) return null;
  final percent = ((me.rank * 100 + size - 1) ~/ size).clamp(1, 100);
  return 'TOP $percent%';
}

/// 「我的名次」 as the page.s ledger card (decision 0182): kicker
/// 「POWER BOARD · 快照 …」, heading 「我的名次 / 第 N 名」, a caption with the
/// figure and what can be read around it, and 「TOP x%」 when the board's
/// size is known.
class IntelRankLedger extends StatelessWidget {
  const IntelRankLedger({required this.rank, required this.faces, super.key});

  final MiningRank rank;
  final Map<String, CommunityFace> faces;

  @override
  Widget build(BuildContext context) {
    final heading = intelRankLedgerHeading(rank);
    final caption = intelRankLedgerCaption(rank, faces);
    final stamp = intelRankTopShare(rank);
    return Semantics(
      container: true,
      label: <String>[heading.replaceAll('\n', '，'), caption, ?stamp].join('，'),
      excludeSemantics: true,
      // Decisions 0221, 0224: 「我的名次」 is a chrome plate — a bevelled
      // chrome edge around a brushed dark face — with the place in Anton 40
      // Yellow and the faded crown in its corner.
      child: LoopChromePlate(
        key: const ValueKey<String>('intel-rank-me-plate'),
        mark: LoopChromePlateMark.crown,
        // v3 (decision 0229): 28 from the plate to the next block.
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          8,
          LoopSpacing.page,
          LoopSpacing.bannerGap - 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LoopKicker(intelRankLedgerKicker(rank)),
            const SizedBox(height: 8),
            _IntelRankHeading(heading: heading),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    caption,
                    key: const ValueKey<String>('intel-rank-me-caption'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ),
                if (stamp != null) ...<Widget>[
                  const SizedBox(width: 12),
                  LoopFolioStamp(stamp, color: LoopColors.text2),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntelRankHeading extends StatelessWidget {
  const _IntelRankHeading({required this.heading});

  final String heading;

  @override
  Widget build(BuildContext context) {
    final cut = heading.indexOf('\n');
    final first = cut < 0 ? heading : heading.substring(0, cut);
    final rest = cut < 0 ? null : heading.substring(cut + 1);
    final label = TextSpan(
      text: first,
      style: LoopType.caption.copyWith(color: LoopColors.text2),
    );
    final unit = LoopType.body.copyWith(color: LoopColors.text2);
    // 「第 12 名」: the place is the plate's figure (decision 0224) — Anton 40
    // Yellow between two Arimo 14 Text2 words.
    final place = rest == null
        ? null
        : RegExp(r'^第 (\d+) 名$').firstMatch(rest)?.group(1);
    if (rest != null && place == null) {
      // 「还没有名次」: a sentence, not a number — the grey crown line drawing
      // where the figure would be, and the sentence at 18 / 700.
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            label,
            const TextSpan(text: '\n'),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 6),
                child: Opacity(
                  opacity: 0.45,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(loopGreyMatrix),
                    child: loopAtmoArt(
                      LoopAtmoAssets.crownFlat,
                      key: const ValueKey<String>('intel-rank-me-empty-crown'),
                      width: 40,
                      height: 30,
                    ),
                  ),
                ),
              ),
            ),
            TextSpan(
              text: rest,
              style: LoopType.headline.copyWith(color: LoopColors.chalk),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          label,
          if (rest != null && place != null) ...<InlineSpan>[
            const TextSpan(text: '\n'),
            TextSpan(text: '第 ', style: unit),
            TextSpan(
              text: place,
              style: LoopType.plateFigure.copyWith(color: LoopColors.yellow),
            ),
            TextSpan(text: ' 名', style: unit),
          ],
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Entries, podium and rows
// ---------------------------------------------------------------------------

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
    this.amount,
    this.isSelf = false,
    this.onTap,
  });

  /// Stable key suffix: `community-<id>`, `user-<index>`, `referral-<index>`.
  final String id;

  /// `null` on a zero power: in the snapshot, not on the board.
  final int? position;

  /// The face at [size]; `chromeFallback` (the podium) draws the chrome
  /// medal for a face with no picture (decision 0224).
  final Widget Function(double size, {bool chromeFallback}) leading;
  final String name;
  final String figure;

  /// The row's second line (「31 人有算力」, 「直接邀请」).
  final String? caption;

  /// The community's approved weight, drawn as a 「权重 x」 badge.
  final String? weight;

  /// What the figure is, said aloud only (「算力」, 「邀请人数」).
  final String? spoken;

  /// The figure as a number, for the share of the leader's; `null` when the
  /// figure is withheld.
  final Decimal? amount;
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

/// The leader's figure: the entry the server numbered 1. `null` when the
/// board has none or its figure is withheld or zero.
Decimal? intelRankLeaderAmount(List<IntelRankEntry> entries) {
  for (final entry in entries) {
    if (entry.position != 1) continue;
    final amount = entry.amount;
    if (amount != null && amount > Decimal.zero) return amount;
  }
  return null;
}

/// A row's share of the leader's figure, 0–1, for its 6 px bar. Computed on
/// the device from the two figures on screen; `null` draws no bar.
double? intelRankShare(Decimal? amount, Decimal? leader) {
  if (amount == null || leader == null || leader <= Decimal.zero) return null;
  final share = (amount / leader).toDouble();
  return share.clamp(0, 1).toDouble();
}

/// The first three places as a podium (decision 0224, replacing the three
/// record cards of decisions 0122 / 0123 / 0182). A brand piece: the wall at
/// 90 % under a Purple fog at 55 %, as on the banner. The winner stands in
/// the middle — a 72 face in a 2 px chrome ring under the Yellow drip crown
/// — second and third at the sides with 56 faces under grey crowns. Each
/// place reads 「01 / 02 / 03」 in the section index's Anton Yellow with its
/// splat; a face with no picture is the chrome medal. Fewer than three
/// places leave the empty ones as 「虚位以待」 under a grey crown line.
class IntelRankPodium extends StatelessWidget {
  const IntelRankPodium({required this.entries, super.key})
    : assert(entries.length >= 1 && entries.length <= 3);

  final List<IntelRankEntry> entries;

  @override
  Widget build(BuildContext context) {
    IntelRankEntry? at(int place) =>
        place <= entries.length ? entries[place - 1] : null;
    Widget slot(int place) {
      final entry = at(place);
      return entry == null
          ? _PodiumEmpty(place: place)
          : _PodiumPlace(entry: entry, place: place);
    }

    return Padding(
      key: const ValueKey<String>('intel-rank-podium'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: LoopRadius.card,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _PodiumGround()),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 30, 8, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // Second, first, third — the podium's own order.
                  Expanded(child: slot(2)),
                  const SizedBox(width: 6),
                  Expanded(child: slot(1)),
                  const SizedBox(width: 6),
                  Expanded(child: slot(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The podium's ground: the wall at 90 % under the Purple fog at 55 % and a
/// downward Ink wash, as on the banner (decision 0220 §4).
class _PodiumGround extends StatelessWidget {
  const _PodiumGround();

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey<String>('intel-rank-podium-ground'),
    fit: StackFit.expand,
    children: <Widget>[
      const ColoredBox(color: Color(0xFF0E0D12)),
      const DecoratedBox(
        key: ValueKey<String>('intel-rank-podium-wall'),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(LoopAtmoAssets.wall),
            fit: BoxFit.cover,
            opacity: 0.9,
          ),
        ),
      ),
      Positioned(
        left: -40,
        top: -140,
        width: 420,
        height: 420,
        child: Opacity(
          opacity: 0.55,
          child: loopAtmoArt(
            LoopAtmoAssets.sprayPurple,
            key: const ValueKey<String>('intel-rank-podium-fog'),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x0009090B), Color(0x9909090B)],
          ),
        ),
      ),
    ],
  );
}

/// The face size on the podium: the winner 72, second and third 56.
double intelPodiumFaceSize(int place) => place == 1 ? 72 : 56;

/// The width of the chrome ring around the winner's face.
const double intelPodiumRing = 2;

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.entry, required this.place});

  final IntelRankEntry entry;

  /// 1, 2 or 3 — the podium slot.
  final int place;

  @override
  Widget build(BuildContext context) {
    final first = place == 1;
    final size = intelPodiumFaceSize(place);
    Widget face = SizedBox.square(
      key: ValueKey<String>('intel-rank-face-$place'),
      dimension: size,
      child: ClipOval(child: entry.leading(size, chromeFallback: true)),
    );
    if (first) {
      face = Container(
        key: const ValueKey<String>('intel-rank-ring-1'),
        padding: const EdgeInsets.all(intelPodiumRing),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: loopChromeGradient,
        ),
        child: face,
      );
    }
    final crownWidth = first ? size * 0.7 : 30.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            face,
            // The crown sits on the face's top edge.
            Positioned(
              top: -crownWidth * (first ? 0.5 : 0.55),
              width: crownWidth,
              child: first
                  ? IgnorePointer(
                      child: loopAtmoArt(
                        LoopAtmoAssets.crownYellow,
                        key: const ValueKey<String>('intel-rank-crown-1'),
                        width: crownWidth,
                        height: crownWidth * 0.75,
                      ),
                    )
                  : LoopRankCrown(
                      key: ValueKey<String>('intel-rank-crown-$place'),
                      place: place,
                      width: crownWidth,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: ValueKey<String>('intel-rank-index-$place'),
          child: LoopSprayIndex(index: entry.position ?? place),
        ),
        const SizedBox(height: 4),
        Text(
          entry.name,
          key: ValueKey<String>('intel-rank-name-$place'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: LoopTypography.withWeight(LoopType.body2, FontWeight.w600),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            entry.figure,
            key: ValueKey<String>('intel-rank-figure-$place'),
            maxLines: 1,
            style: LoopType.figureLg.copyWith(
              color: first ? LoopColors.yellow : LoopColors.chalk,
            ),
          ),
        ),
        if (entry.weight != null || entry.isSelf) ...<Widget>[
          const SizedBox(height: 6),
          // v3 (decision 0229): the weight is a caption, not a third badge.
          entry.isSelf
              ? const LoopBadge('我')
              : Text('权重 ${entry.weight!}', style: LoopType.caption),
        ],
      ],
    );
    final tap = entry.onTap;
    return Semantics(
      button: tap != null,
      label: entry.spokenLabel(),
      excludeSemantics: true,
      child: KeyedSubtree(
        key: ValueKey<String>('intel-rank-${entry.id}'),
        child: LoopPressable(onTap: tap, scale: false, child: content),
      ),
    );
  }
}

/// An empty place on the podium: a grey crown line and 「虚位以待」.
class _PodiumEmpty extends StatelessWidget {
  const _PodiumEmpty({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '第 $place 名，虚位以待',
    excludeSemantics: true,
    child: Column(
      key: ValueKey<String>('intel-rank-empty-slot-$place'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: 0.45,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(loopGreyMatrix),
            child: loopAtmoArt(LoopAtmoAssets.crownFlat, width: 48, height: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text('虚位以待', style: LoopType.caption.copyWith(color: LoopColors.text2)),
      ],
    ),
  );
}

/// The head over the rows (`.rank-list-head`): what the left and the right
/// columns are, mono and uppercase like a `.label`.
class IntelRankListHead extends StatelessWidget {
  const IntelRankListHead({required this.scope, super.key});

  final MiningRankScope scope;

  // v3 (decision 0229): one word per column, no centre-dot chain; the bar
  // under each figure already says it is a share of the first place.
  static String leftOf(MiningRankScope scope) => switch (scope) {
    MiningRankScope.communities => '社区',
    MiningRankScope.users => '用户',
    MiningRankScope.referrals => '用户',
  };

  static String rightOf(MiningRankScope scope) => switch (scope) {
    MiningRankScope.referrals => '直接邀请',
    _ => '算力',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('intel-rank-list-head'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        LoopSpacing.tight,
        LoopSpacing.page,
        LoopSpacing.tight,
      ),
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftOf(scope),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption,
              ),
            ),
            const SizedBox(width: 12),
            Text(rightOf(scope), style: LoopType.caption),
          ],
        ),
      ),
    );
  }
}

/// One place from the fourth on (docs/35 定稿 · B row): position · face 40 ·
/// name with its badge over a second line · the figure over its share of the
/// leader's. No card; a hairline under it. The reader's own row is
/// purpleSoft with a yellow position and figure.
class IntelRankRow extends StatelessWidget {
  const IntelRankRow({
    required this.position,
    required this.leading,
    required this.name,
    required this.figure,
    super.key,
    this.caption,
    this.weight,
    this.share,
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

  /// The figure's share of the leader's, 0–1; `null` draws no bar.
  final double? share;

  /// What the figure is, said aloud only.
  final String? spoken;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final place = position;
    final accent = isSelf ? LoopColors.yellow : null;
    // v3 (decision 0229): rows of 72 (80 with a second line) told apart by
    // space, no hairline; the weight joins the second line instead of
    // standing as a badge beside the name.
    final second = <String>[if (weight != null) '权重 $weight', ?caption];
    final content = Container(
      constraints: BoxConstraints(
        minHeight: second.isEmpty
            ? LoopSpacing.rowMin
            : LoopSpacing.rowMinWithSub,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        // S241b: the reader's own row is a selected row — purple 9 %.
        color: isSelf ? LoopColors.purpleSoft : null,
      ),
      child: Row(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 22),
            child: Text(
              place == null ? '未上榜' : '$place',
              key: const ValueKey<String>('intel-rank-row-position'),
              maxLines: 1,
              textAlign: TextAlign.right,
              style: place == null
                  ? LoopType.caption
                  : LoopTypography.withWeight(
                      LoopType.figureBody,
                      FontWeight.w700,
                    ).copyWith(color: accent ?? LoopColors.text3),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(dimension: intelRankRowFaceSize, child: leading),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.body1,
                ),
                if (second.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    second.join('，'),
                    key: const ValueKey<String>('intel-rank-row-caption'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.caption,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                figure,
                key: const ValueKey<String>('intel-rank-row-figure'),
                maxLines: 1,
                style: LoopType.figure.copyWith(
                  color: accent ?? LoopColors.chalk,
                ),
              ),
              if (share case final double fraction) ...<Widget>[
                const SizedBox(height: 6),
                SizedBox(
                  width: intelRankShareBarWidth,
                  child: LoopProgressBar(
                    key: const ValueKey<String>('intel-rank-row-share'),
                    value: fraction,
                    semanticLabel: '占第一名 ${(fraction * 100).round()}%',
                  ),
                ),
              ],
            ],
          ),
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

/// The reader's own row at the end of the rows read so far, when none of
/// them is the reader's (decision 0182): the place and figure come from the
/// board's own `me`, the face and name from the reader's profile — or, on
/// the community board, the reader's best-ranked community.
class IntelRankSelfRow extends ConsumerWidget {
  const IntelRankSelfRow({
    required this.rank,
    required this.me,
    required this.leader,
    required this.faces,
    super.key,
  });

  final MiningRank rank;
  final MiningRankMe me;
  final Decimal? leader;
  final Map<String, CommunityFace> faces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = rank.scope == MiningRankScope.referrals;
    final Widget face;
    final String name;
    final community = me.communityId;
    if (rank.scope == MiningRankScope.communities && community != null) {
      name = faces[community]?.name ?? '我的社区';
      face = _communityLogo(community, name, faces, intelRankRowFaceSize);
    } else {
      final state = ref.watch(profileControllerProvider);
      if (state.phase == ProfilePhase.initial) {
        scheduleMicrotask(() {
          if (context.mounted) {
            unawaited(ref.read(profileControllerProvider.notifier).load());
          }
        });
      }
      // Decision 0132: the same face 聊天's head draws, stored or live.
      final profile = ref.watch(ownerFaceProvider);
      name = profile?.alias ?? '我';
      face = LoopProfileAvatar(
        avatarRef: profile?.avatarRef,
        alias: profile?.alias,
        size: intelRankRowFaceSize,
      );
    }
    final selfTap =
        rank.scope == MiningRankScope.communities && community != null
        ? null
        : () => LoopProfileFaceLink.push(context, loopOwnProfileLocation);
    return IntelRankRow(
      position: me.rank,
      leading: face,
      name: name,
      onTap: selfTap,
      caption: referrals ? '直接邀请' : null,
      isSelf: true,
      figure: referrals ? me.value : loopGroupedFigure(me.value),
      share: intelRankShare(Decimal.tryParse(me.value), leader),
      spoken: referrals ? '邀请人数' : '算力',
    );
  }
}
