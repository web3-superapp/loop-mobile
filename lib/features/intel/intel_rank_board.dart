import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// The chip label of each board, in the order they are drawn.
String intelRankScopeLabel(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => LoopL10n.current.common_community,
  MiningRankScope.users => LoopL10n.current.common_user,
  MiningRankScope.referrals => LoopL10n.current.intel_rankBoardReferrals,
};

/// The face on a board row (docs/35 `.rank-row .face`).
const double intelRankRowFaceSize = 36;

/// A row's height (docs/58 §5.16, §9.4): 51.
const double intelRankRowHeight = 51;

/// The place column's width (docs/58 §5.16).
const double intelRankPlaceColumn = 34;

/// 情报 · 算力榜 (decisions 0118, 0122, 0182).
///
/// The reader's own place is the page.s one ledger card; the three
/// boards sit behind chips under it — 社区 / 用户 / 推广 — then the first
/// three on a podium and every later place as a row with its figure
/// (S325 · decision 0255, UX-018: no share bar). The board reads on as the reader scrolls. What the
/// figures are and when they were computed is one weak line at the foot,
/// which opens the display rules.
///
/// Decision 0272 (S344): 算力榜 is the second-level page behind 情报 · 算力's
/// network card (the `mining-rank` route): 社区 / 用户 / 邀请, the invite
/// center itself living in the 邀请 tab of 算力.
class IntelRankBoard extends ConsumerStatefulWidget {
  const IntelRankBoard({required this.onNavigate, super.key, this.onBack});

  final ValueChanged<String> onNavigate;

  /// Set when the board is its own page; null draws it as an embedded body.
  final VoidCallback? onBack;

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
        ? LoopFolioPrimary(
            key: ValueKey<String>('intel-rank-me-loading'),
            // S241b: the flat dark ledger; the place reads in yellow.
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            ring: false,
            kicker: intelRankLedgerKickerBase,
            heading: context.l10n.intel_rankBoardIntelRankMeLoadingHeading,
            headingLoading: true,
          )
        : null;

    // S353b · decision 0279 (docs/58 §5.2): the boards are the Figma's
    // first-level tab strip — white words over a full-cell Yellow line.
    final scopeBar = Padding(
      padding: const EdgeInsets.only(bottom: LoopSpacing.segmentGap),
      child: LoopTabStrip(
        key: const ValueKey<String>('intel-rank-scope'),
        labels: <String>[
          for (final scope in scopes) intelRankScopeLabel(scope),
        ],
        selectedIndex: scopes.indexOf(state.scope),
        onSelected: (index) => unawaited(controller.select(scopes[index])),
        scaleDownLabels: true,
      ),
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
        title: context.l10n.intel_rankBoardIntelRankBoardTitle,
        onBack: widget.onBack,
        embedded: widget.onBack == null,
        tabPage: widget.onBack == null,
        // As its own page the board keeps 情报's wall (decision 0221), so
        // the podium and the chrome ledger stand where they always stood.
        backdrop: widget.onBack == null
            ? null
            : const LoopWallBackdrop(
                key: ValueKey<String>('intel-rank-atmo-backdrop'),
                fog: LoopWallFog.intel,
                keyPrefix: 'intel-rank-atmo',
              ),
        onRefresh: controller.reload,
        updating: state.refreshing,
        block: blocked
            ? LoopCapabilityPageBlock.of(
                key: const ValueKey<String>('intel-rank-capability-block'),
                title:
                    context.l10n.intel_rankBoardIntelRankCapabilityBlockTitle,
                capability: capability,
              )
            : null,
        primary: ledger,
        sections: <Widget>[
          scopeBar,
          if (rank == null)
            LaunchStateBlock(
              prefix: 'intel-rank',
              phase: state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.record,
              rows: 6,
              emptyMessage: context.l10n.intel_rankBoardEmptyMessage,
              emptyReason: context.l10n.intel_rankBoardEmptyReason,
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            MiningStaleNotice(slug: 'intel-rank', snapshot: rank.snapshot),
            ..._rows(rank, faces),
            if (_hasRows(rank.ranking)) ...<Widget>[
              if (state.appendFailed && !state.loadingMore)
                LoopInlineUnavailable(
                  key: const ValueKey<String>('intel-rank-more-failed'),
                  message: context.l10n.common_nextPageFailed,
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
            message: LoopL10n.current
                .intel_rankBoardIntelRankUnavailableMessage(
                  launchReasonCodeText(reasonCode),
                ),
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
            title: referrals
                ? LoopL10n.current.intel_rankBoardIntelRankEmptyTitle
                : LoopL10n.current.intel_rankBoardIntelRankEmptyTitle2,
            message: referrals
                ? LoopL10n.current.intel_rankBoardIntelRankEmptyMessage
                : LoopL10n.current.intel_rankBoardIntelRankEmptyMessage2,
            // The ledger card is this page.s one ledger card (decision 0182; flat since S241b).
            action: referrals
                ? LoopButton(
                    key: const ValueKey<String>('intel-rank-empty-invite'),
                    label: LoopL10n
                        .current
                        .intel_rankBoardIntelRankEmptyInviteLabel,
                    icon: 'users',
                    onPressed: () => widget.onNavigate(referralCenterPath),
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
              caption: LoopL10n.current.intel_rankBoardCaption(
                row.participants,
              ),
              amount: Decimal.tryParse(row.power),
              isSelf: mine != null && mine == row.community.communityId,
              figure: loopPowerFigure(row.power),
              spoken: LoopL10n.current.common_power,
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
              caption: LoopL10n.current.intel_rankBoardCaption2,
              isSelf: items[index].isSelf,
              amount: Decimal.fromInt(items[index].invitedCount),
              figure: '${items[index].invitedCount}',
              spoken: LoopL10n.current.intel_rankBoardSpoken,
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
    final me = rank.me;
    final selfMissing = me != null && !entries.any((entry) => entry.isSelf);
    final rows = entries.skip(podium).toList();
    return <Widget>[
      if (podium > 0) ...<Widget>[
        IntelRankSectionHeading(live: rank.scope != MiningRankScope.referrals),
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
          spoken: entry.spoken,
          onTap: entry.onTap,
        ),
      if (selfMissing)
        IntelRankSelfRow(
          key: const ValueKey<String>('intel-rank-self-row'),
          rank: rank,
          me: me,
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
      caption: anonymousToOthers
          ? LoopL10n.current.intel_rankBoardCaption3
          : null,
      isSelf: row.isSelf,
      amount: row.power == null ? null : Decimal.tryParse(row.power!),
      // A number its owner keeps to themselves is withheld, not unread.
      figure: row.power == null
          ? LoopL10n.current.intel_rankBoardFigure
          : loopPowerFigure(row.power!),
      spoken: row.power == null ? null : LoopL10n.current.common_power,
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
    if (location == null) return null;
    // S347 · N1: 我 is a tab — switched to, never pushed over this page.
    if (isSelf) return () => LoopProfileFaceLink.push(context, location);
    return () => widget.onNavigate(location);
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
      alias: LoopL10n.current.intel_rankBoardAlias,
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
          ? LoopL10n.current.intel_rankBoardIntelRankProvenancePrefix
          : switch (formula) {
              MiningFormulaEffective() =>
                LoopL10n.current.intel_rankBoardMiningFormulaEffective,
              MiningFormulaPending() =>
                LoopL10n.current.intel_rankBoardMiningFormulaPending,
            },
      sources: <String>[
        referrals
            ? LoopL10n.current.intel_rankBoardLoopProvenanceLine
            : LoopL10n.current.intel_rankBoardS,
      ],
      observedAt: referrals
          ? null
          : switch (snapshot) {
              MiningSnapshotComputed(:final computedAt) => computedAt,
              MiningSnapshotUnavailable() => null,
            },
      detail: <String>[
        if (referrals)
          LoopL10n.current.intel_rankBoardLoopProvenanceLine2
        else
          LoopL10n.current.intel_rankBoardLoopProvenanceLine3,
        LoopL10n.current.intel_rankBoardLoopProvenanceLine4(
          miningRuleKeyText(rank.display.ruleKey),
          miningRuleKeyText(rank.display.anonymousMemberKey),
        ),
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
  return LoopL10n.current.intel_rankBoardIf(
    <String>[
      for (final row in ranking.items)
        LoopL10n.current.intel_rankBoardParticipantEntry(
          row.participants,
          row.community.name,
        ),
    ].join(LoopL10n.current.widgets_enumerationSeparator),
  );
}

// ---------------------------------------------------------------------------
// The ledger card (decision 0182)
// ---------------------------------------------------------------------------

/// The kicker every board's ledger card opens with.
String get intelRankLedgerKickerBase =>
    LoopL10n.current.intel_rankBoardIntelRankBoardTitle;

/// 「算力榜，快照 10-15 04:00」 on the two power boards (the snapshot's own
/// computation time, local), 「算力榜 · 实时」 on 推广, which reads the invite
/// relation live (「算力榜，实时」), and the bare 「算力榜」 when no snapshot was computed.
String intelRankLedgerKicker(MiningRank rank) {
  if (rank.scope == MiningRankScope.referrals) {
    return LoopL10n.current.intel_rankBoardIf2(intelRankLedgerKickerBase);
  }
  return switch (rank.snapshot) {
    MiningSnapshotComputed(:final computedAt) =>
      LoopL10n.current.intel_rankBoardMiningSnapshotComputed(
        intelRankLedgerKickerBase,
        intelRankMonthDayClock(computedAt),
      ),
    MiningSnapshotUnavailable() => intelRankLedgerKickerBase,
  };
}

/// "MM-dd HH:mm" in the device's local time.
String intelRankMonthDayClock(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${loopClockLabel(local)}';
}

/// [sentence] (「第 12 名」 / "Rank #12") cut around [place], so the figure
/// can wear the plate's style: the words before it, the figure, the words
/// after it. The words come from the translation, never from this file.
List<String> intelRankPlaceParts(String sentence, int place) {
  final figure = '$place';
  final at = sentence.indexOf(figure);
  if (at < 0) return <String>[sentence, '', ''];
  return <String>[
    sentence.substring(0, at),
    figure,
    sentence.substring(at + figure.length),
  ];
}

/// 「我的名次\n第 12 名」, or 「我的名次\n还没有名次」.
String intelRankLedgerHeading(MiningRank rank) {
  final me = rank.me;
  return me == null
      ? LoopL10n.current.intel_rankBoardIntelRankLedgerHeading
      : LoopL10n.current.intel_rankBoardS2(me.rank);
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
    // Decision 0252: the gap between the two whole figures on screen.
    final gap = value.floor().toBigInt() - mine.floor().toBigInt();
    if (gap <= BigInt.zero) return null;
    final figure = loopPowerFigureOf(gap);
    return rank.scope == MiningRankScope.referrals
        ? LoopL10n.current.intel_rankBoardIntelRankGapToNext(above, figure)
        : LoopL10n.current.intel_rankBoardS3(above, figure);
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
        return LoopL10n.current.intel_rankBoardIf3(
          row.community.name,
          row.weight,
        );
      }
    }
  }
  final name = faces[mine]?.name;
  return name == null || name.isEmpty
      ? null
      : LoopL10n.current.intel_rankBoardNull(name);
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
    return referrals
        ? LoopL10n.current.intel_rankBoardIf4
        : LoopL10n.current.intel_rankBoardS4;
  }
  return <String>[
    if (referrals)
      LoopL10n.current.intel_rankBoardIf5(me.value)
    else
      LoopL10n.current.intel_rankBoardIf6(loopPowerFigure(me.value)),
    ?intelRankGapToNext(rank),
    ?intelRankLedgerCommunity(rank, faces),
    // v3 (decision 0229): a comma, never a centre-dot chain.
  ].join(LoopL10n.current.common_listSeparator);
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
      label: <String>[
        if (rank.scope == MiningRankScope.referrals)
          '$intelReferralLedgerTitle${context.l10n.common_listSeparator}'
              '${rank.me == null ? context.l10n.intel_rankBoardBuild : context.l10n.intel_rankBoardText4(rank.me!.rank)}'
        else
          heading.replaceAll('\n', context.l10n.common_listSeparator),
        caption,
        ?stamp,
      ].join(context.l10n.common_listSeparator),
      excludeSemantics: true,
      // Decisions 0221, 0224: 「我的名次」 is a chrome plate — a bevelled
      // chrome edge around a brushed dark face — with the place in Inter Bold 40
      // Yellow and the faded crown in its corner.
      // S353b · decision 0279 (docs/58 §5.14): the power card — a 12
      // corner, the gradient #14151a → #1b1028 and the doodle wall at 30 %.
      child: IntelPowerCard(
        key: const ValueKey<String>('intel-rank-me-plate'),
        // v3 (decision 0229): 28 from the plate to the next block.
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          8,
          LoopSpacing.page,
          LoopSpacing.bannerGap - 8,
        ),
        child: rank.scope == MiningRankScope.referrals
            ? _IntelReferralLedgerBody(
                rank: rank,
                caption: caption,
                stamp: stamp,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    intelRankLedgerKicker(rank),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.eyebrow.copyWith(color: LoopColors.text2),
                  ),
                  const SizedBox(height: 8),
                  _IntelRankHeading(heading: heading, place: rank.me?.rank),
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
                          style: LoopType.caption.copyWith(
                            color: LoopColors.text2,
                          ),
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

/// The Figma's power card (docs/58 §5.14) as the ground of 算力榜's
/// 「我的名次」: a 12 corner, the 107° gradient #14151a → #1b1028, the doodle
/// wall at 30 % over it, 16 / 14 inside.
class IntelPowerCard extends StatelessWidget {
  const IntelPowerCard({required this.child, super.key, this.margin});

  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      gradient: LoopColors.powerCardGradient,
      borderRadius: LoopRadius.card,
    ),
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.3,
              child: loopAtmoArt(LoopAtmoAssets.wall, fit: BoxFit.cover),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 14, 16, 16),
          child: child,
        ),
      ],
    ),
  );
}

/// The title of the 邀请中心 board's plate (UX-012, decision 0257).
String get intelReferralLedgerTitle =>
    LoopL10n.current.intel_rankBoardIntelReferralLedgerTitle;

/// 邀请中心's plate (UX-012, decision 0257), in four aligned lines: the
/// title, the place (「第 N 名」, or the 「暂未上榜」 chip), one sentence, and
/// the 「榜单实时更新」 status dot — the board reads the invite relation live.
class _IntelReferralLedgerBody extends StatelessWidget {
  const _IntelReferralLedgerBody({
    required this.rank,
    required this.caption,
    required this.stamp,
  });

  final MiningRank rank;
  final String caption;
  final String? stamp;

  @override
  Widget build(BuildContext context) {
    final me = rank.me;
    final unit = LoopType.body.copyWith(color: LoopColors.text2);
    return Column(
      key: const ValueKey<String>('intel-referral-ledger'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          intelReferralLedgerTitle,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: Row(
            children: <Widget>[
              if (me == null)
                Container(
                  key: const ValueKey<String>('intel-referral-ledger-chip'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LoopColors.card2,
                    borderRadius: LoopRadius.pill,
                    border: Border.all(color: LoopColors.line2),
                  ),
                  child: Text(
                    context.l10n.intel_rankBoardBuild,
                    style: LoopTypography.withWeight(
                      LoopType.body,
                      FontWeight.w600,
                    ).copyWith(color: LoopColors.chalk),
                  ),
                )
              else
                Text.rich(
                  key: const ValueKey<String>('intel-referral-ledger-place'),
                  TextSpan(
                    children: <InlineSpan>[
                      for (final (index, part) in intelRankPlaceParts(
                        context.l10n.intel_rankBoardText4(me.rank),
                        me.rank,
                      ).indexed)
                        if (part.isNotEmpty)
                          TextSpan(
                            text: part,
                            style: index == 1
                                ? LoopType.heroFigure.copyWith(
                                    color: MiningRankEntry.placeColor(me.rank),
                                    height: 1,
                                  )
                                : unit,
                          ),
                    ],
                  ),
                  maxLines: 1,
                ),
              const Spacer(),
              if (stamp case final String value)
                LoopFolioStamp(value, color: LoopColors.text2),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          key: const ValueKey<String>('intel-rank-me-caption'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        ),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey<String>('intel-referral-ledger-live'),
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: LoopColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.intel_rankBoardBuild2,
              style: LoopType.captionSm.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntelRankHeading extends StatelessWidget {
  const _IntelRankHeading({required this.heading, this.place});

  final String heading;

  /// The reader's place, when there is one; [heading] says it in words.
  final int? place;

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
    // 「第 12 名」: the place is the plate's figure (decision 0224) — Inter Bold 40
    // Yellow between two Inter 14 Text2 words.
    final place = rest == null ? null : this.place;
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
            for (final (index, part) in intelRankPlaceParts(
              rest,
              place,
            ).indexed)
              if (part.isNotEmpty)
                TextSpan(
                  text: part,
                  // docs/58 §5.14: the card's value at 30 / 700 — Yellow
                  // for the first place, bronze for the third.
                  style: index == 1
                      ? LoopType.heroFigure.copyWith(
                          color: MiningRankEntry.placeColor(place),
                        )
                      : unit,
                ),
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

  /// The figure as a number; `null` when the figure is withheld.
  final Decimal? amount;
  final bool isSelf;
  final VoidCallback? onTap;

  String spokenLabel() => <String>[
    if (position == null)
      LoopL10n.current.intel_rankBoardText3
    else
      LoopL10n.current.intel_rankBoardText4(position),
    name,
    if (isSelf) LoopL10n.current.common_me,
    ?caption,
    if (weight != null) LoopL10n.current.intel_rankBoardText5(weight),
    <String>[?spoken, figure].join(' '),
  ].join(LoopL10n.current.common_listSeparator);
}

/// The heading over the podium (S353b · decision 0279, docs/58 §5.14): the
/// section word at 19 / 700 and, at the right end, 「ⓘ 榜单实时更新」 at
/// 10 / 400 textSecondary — 24 under the card above.
class IntelRankSectionHeading extends StatelessWidget {
  const IntelRankSectionHeading({
    super.key = const ValueKey<String>('intel-rank-podium-label'),
    this.live = true,
  });

  /// Whether 「ⓘ 榜单实时更新」 stands at the right end (off on 邀请中心,
  /// whose card already says it).
  final bool live;

  @override
  Widget build(BuildContext context) {
    final note = LoopType.metaSm.copyWith(color: LoopColors.text2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        LoopSpacing.section - LoopSpacing.segmentGap + 8,
        LoopSpacing.page,
        LoopSpacing.headingGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              LoopL10n.current.intel_rankBoardIntelRankPodiumLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.headline,
            ),
          ),
          if (live) ...<Widget>[
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Row(
                key: const ValueKey<String>('intel-rank-live-note'),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const LoopIcon('info', size: 10, color: LoopColors.text2),
                  const SizedBox(width: 4),
                  Text(context.l10n.intel_rankBoardBuild2, style: note),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The first three places as a podium (decision 0224, replacing the three
/// record cards of decisions 0122 / 0123 / 0182). S353b · decision 0279
/// (docs/58 §5.15): the Figma's podium — a 270 × 85 Purple `#8e22ff` glow
/// behind the faces, three dark blocks (#1a1b20, a 12 corner; the middle
/// one 17 higher) the faces stand on, the winner's 62 face in a Yellow ring
/// under the Yellow line crown, second and third 54 in Purple rings. Each
/// block reads the place 「01 / 02 / 03」 at 17 / 700 (Yellow for the first),
/// the name 14 / 600 and the figure 13 / 600; the reader's own place wears
/// the 「我」 tag. An empty place is a 52 ring with a grey crown and
/// 「虚位以待」.
class IntelRankPodium extends StatelessWidget {
  const IntelRankPodium({required this.entries, super.key})
    : assert(entries.length >= 1 && entries.length <= 3);

  final List<IntelRankEntry> entries;

  /// The Figma's crown over the winner (2001:949).
  static const String crownAsset = 'assets/figma/crown-vector.svg';

  /// The blocks' heights: the winner's, then the others'.
  static const double firstBlock = 72;
  static const double otherBlock = 55;

  @override
  Widget build(BuildContext context) {
    IntelRankEntry? at(int place) =>
        place <= entries.length ? entries[place - 1] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Decision 0252: the three figures share one size; the longest sets
        // it for all three.
        final style = intelPodiumFigureStyle(
          figures: <String>[for (final entry in entries) entry.figure],
          slotWidth: (constraints.maxWidth - 32 - 12) / 3 - 12,
          textScaler: MediaQuery.textScalerOf(context),
        );
        Widget slot(int place) {
          final entry = at(place);
          return entry == null
              ? _PodiumEmpty(place: place)
              : _PodiumPlace(entry: entry, place: place, figureStyle: style);
        }

        return _podium(slot);
      },
    );
  }

  Widget _podium(Widget Function(int place) slot) {
    return Padding(
      key: const ValueKey<String>('intel-rank-podium'),
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(child: _PodiumGround()),
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                // Second, first, third — the podium's own order.
                Expanded(child: slot(2)),
                const SizedBox(width: 2),
                Expanded(child: slot(1)),
                const SizedBox(width: 2),
                Expanded(child: slot(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The podium's light (docs/58 §5.15): a 270 × 85 ellipse of `#8e22ff` at
/// 55 % fading out, behind the faces.
class _PodiumGround extends StatelessWidget {
  const _PodiumGround();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      key: const ValueKey<String>('intel-rank-podium-ground'),
      alignment: const Alignment(0, -0.55),
      child: SizedBox(
        key: const ValueKey<String>('intel-rank-podium-wall'),
        width: 270,
        height: 85,
        child: Transform.scale(
          scaleY: 85 / 270,
          child: OverflowBox(
            maxHeight: 270,
            minHeight: 270,
            child: DecoratedBox(
              key: const ValueKey<String>('intel-rank-podium-fog'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    LoopColors.podiumGlow.withValues(alpha: 0.55),
                    LoopColors.podiumGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The one style the podium's figures share: [LoopType.figureXs] (13 / 600,
/// docs/58 §5.15), scaled down together until the widest of [figures] fits
/// [slotWidth].
TextStyle intelPodiumFigureStyle({
  required List<String> figures,
  required double slotWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final base = LoopType.figureXs;
  var widest = 0.0;
  for (final figure in figures) {
    final painter = TextPainter(
      text: TextSpan(text: figure, style: base),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  final size = base.fontSize;
  if (size == null || widest <= slotWidth || slotWidth <= 0) return base;
  // A hair under the exact ratio, so the shared size never trips the
  // per-figure shrink below.
  return base.copyWith(fontSize: size * slotWidth / widest * 0.98);
}

/// The face size on the podium (docs/58 §5.15): the winner 62, second and
/// third 54.
double intelPodiumFaceSize(int place) => place == 1 ? 62 : 54;

/// The width of the ring around a podium face.
const double intelPodiumRing = 2;

/// A podium block: the dark ground the face stands on, holding the place,
/// the name and the figure.
class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(minHeight: height),
    // The winner's block stands the Figma's 17 higher than the others.
    padding: EdgeInsets.fromLTRB(
      6,
      14,
      6,
      8 + (height - IntelRankPodium.otherBlock),
    ),
    decoration: const BoxDecoration(
      color: LoopColors.surfaceElevated,
      borderRadius: LoopRadius.card,
    ),
    child: child,
  );
}

/// The place word over a block: 17 / 700, Yellow for the first.
TextStyle _podiumIndexStyle(int place) => LoopType.emptyTitle.copyWith(
  color: place == 1 ? LoopColors.yellow : LoopColors.text2,
  height: 1.2,
);

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.place,
    required this.figureStyle,
  });

  final IntelRankEntry entry;

  /// The size all three figures share ([intelPodiumFigureStyle]).
  final TextStyle figureStyle;

  /// 1, 2 or 3 — the podium slot.
  final int place;

  @override
  Widget build(BuildContext context) {
    final first = place == 1;
    final size = intelPodiumFaceSize(place);
    final face = Container(
      key: first ? const ValueKey<String>('intel-rank-ring-1') : null,
      padding: const EdgeInsets.all(intelPodiumRing),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: first ? LoopColors.yellow : LoopColors.purple,
          width: intelPodiumRing,
        ),
      ),
      child: SizedBox.square(
        key: ValueKey<String>('intel-rank-face-$place'),
        dimension: size,
        child: ClipOval(child: entry.leading(size, chromeFallback: true)),
      ),
    );
    final index = (entry.position ?? place).toString().padLeft(2, '0');
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (first)
          IgnorePointer(
            child: SvgPicture.asset(
              IntelRankPodium.crownAsset,
              key: const ValueKey<String>('intel-rank-crown-1'),
              width: 27,
              height: 27,
              excludeFromSemantics: true,
            ),
          ),
        if (first) const SizedBox(height: 4),
        face,
        // The block starts under the face's lower half.
        Transform.translate(
          offset: Offset(0, -size / 4),
          child: _PodiumBlock(
            height: first
                ? IntelRankPodium.firstBlock
                : IntelRankPodium.otherBlock,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  index,
                  key: ValueKey<String>('intel-rank-index-$place'),
                  maxLines: 1,
                  style: _podiumIndexStyle(place),
                ),
                Text(
                  entry.name,
                  key: ValueKey<String>('intel-rank-name-$place'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: LoopType.figureSm.copyWith(
                    color: LoopColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    entry.figure,
                    key: ValueKey<String>('intel-rank-figure-$place'),
                    maxLines: 1,
                    style: figureStyle.copyWith(color: LoopColors.text2),
                  ),
                ),
                if (entry.weight != null && !entry.isSelf) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.intel_rankBoardText5(entry.weight!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.progress,
                  ),
                ],
                if (entry.isSelf) ...<Widget>[
                  const SizedBox(height: 4),
                  LoopBadge(context.l10n.common_me),
                ],
              ],
            ),
          ),
        ),
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

/// An empty place on the podium (docs/58 §5.15): a 52 ring (#1b1c22, a 1 px
/// grey edge) with the grey crown inside, on its block, and 「虚位以待」.
class _PodiumEmpty extends StatelessWidget {
  const _PodiumEmpty({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.intel_rankBoardLabel(place),
    excludeSemantics: true,
    child: Column(
      key: ValueKey<String>('intel-rank-empty-slot-$place'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LoopColors.surfaceElevated,
            border: Border.all(color: LoopColors.text3),
          ),
          child: Opacity(
            opacity: 0.6,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(loopGreyMatrix),
              child: SvgPicture.asset(
                IntelRankPodium.crownAsset,
                width: 23,
                height: 23,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -13),
          child: _PodiumBlock(
            height: IntelRankPodium.otherBlock,
            child: Center(
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.intel_rankBoardText6,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.meta.copyWith(color: LoopColors.text2),
                ),
              ),
            ),
          ),
        ),
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
    MiningRankScope.communities => LoopL10n.current.common_community,
    MiningRankScope.users => LoopL10n.current.common_user,
    MiningRankScope.referrals => LoopL10n.current.common_user,
  };

  static String rightOf(MiningRankScope scope) => switch (scope) {
    MiningRankScope.referrals => LoopL10n.current.intel_rankBoardCaption2,
    _ => LoopL10n.current.common_power,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('intel-rank-list-head'),
      // S350b · decision 0275: 16 from the podium, so the head reads as the
      // list's own and not the podium's foot.
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        LoopSpacing.segmentGap,
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
                style: LoopType.caption.copyWith(color: LoopColors.text3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              rightOf(scope),
              style: LoopType.caption.copyWith(color: LoopColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// One place from the fourth on (docs/35 定稿 · B row): position · face 40 ·
/// name with its badge over a second line · the figure, alone (S325 ·
/// decision 0255, UX-018: the share bar under it said nothing the figure did
/// not, and read as noise when every row was 1). No card; a hairline under it. The reader's own row is
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
    final accent = isSelf ? LoopColors.yellow : null;
    // v3 (decision 0229): rows of 72 (80 with a second line) told apart by
    // space, no hairline; the weight joins the second line instead of
    // standing as a badge beside the name.
    final second = <String>[
      if (weight != null) context.l10n.intel_rankBoardText5(weight),
      ?caption,
    ];
    // S353b · decision 0279 (docs/58 §5.16, §9.4): 51 high, 6 above and
    // below, no line.
    final content = Container(
      constraints: const BoxConstraints(minHeight: intelRankRowHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        // S241b: the reader's own row is a selected row — purple 9 %.
        color: isSelf ? LoopColors.purpleSoft : null,
      ),
      child: Row(
        children: <Widget>[
          // docs/58 §5.16: the place in a 34 column, 13 / 600 textSecondary.
          SizedBox(
            width: intelRankPlaceColumn,
            child: Text(
              place == null ? context.l10n.intel_rankBoardText3 : '$place',
              key: const ValueKey<String>('intel-rank-row-position'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: place == null
                  ? LoopType.progress
                  : LoopType.figureXs.copyWith(
                      color: accent ?? LoopColors.text2,
                    ),
            ),
          ),
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
                if (second.isNotEmpty)
                  Text(
                    second.join(LoopL10n.current.common_listSeparator),
                    key: const ValueKey<String>('intel-rank-row-caption'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.progress,
                  ),
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
                style: LoopType.figureXs.copyWith(
                  color: accent ?? LoopColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final label = <String>[
      if (place == null)
        context.l10n.intel_rankBoardText3
      else
        context.l10n.intel_rankBoardText4(place),
      name,
      if (isSelf) context.l10n.common_me,
      ?caption,
      if (weight != null) context.l10n.intel_rankBoardText5(weight),
      <String>[?spoken, figure].join(' '),
    ].join(LoopL10n.current.common_listSeparator);
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
    required this.faces,
    super.key,
  });

  final MiningRank rank;
  final MiningRankMe me;
  final Map<String, CommunityFace> faces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = rank.scope == MiningRankScope.referrals;
    final Widget face;
    final String name;
    final community = me.communityId;
    if (rank.scope == MiningRankScope.communities && community != null) {
      name = faces[community]?.name ?? context.l10n.intel_rankBoardIf7;
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
      name = profile?.alias ?? context.l10n.common_me;
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
      caption: referrals ? context.l10n.intel_rankBoardCaption2 : null,
      isSelf: true,
      figure: referrals ? me.value : loopPowerFigure(me.value),
      spoken: referrals
          ? context.l10n.intel_rankBoardSpoken
          : context.l10n.common_power,
    );
  }
}
