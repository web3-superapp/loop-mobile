import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_home_widgets.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

typedef CommunityNavigation = void Function(String location);

/// `community` · the reader's own index of communities.
///
/// Every figure on this page comes from `GET /v2/community/home`. Since
/// decision 0110 it is no longer a tab: 聊天 is the post-login home and owns
/// conversations, unread counts and stranger requests, and 「＋」 there owns
/// search, so the old search and message panels were retired with the tab.
/// The page stays mounted at `/community` and is opened as a child page.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.onNavigate, this.onBack});

  final CommunityNavigation? onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  /// Whether this page drew the index as a skeleton. Only then do the groups
  /// fade in when they land (decision 0095).
  bool _sawSkeleton = false;

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityHomeControllerProvider);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(communityHomeControllerProvider.notifier).load());
        }
      });
    }

    final home = state.value;
    final loading = state.phase == CommunityViewPhase.loading;
    if (home == null && loading) _sawSkeleton = true;
    final controller = ref.read(communityHomeControllerProvider.notifier);
    // Since backend decision 0073 the aggregate answers in two groups, and a
    // community the reader owns is no longer inside `joined`. This page is
    // the reader's own index of the communities they belong to, and they
    // belong to the ones they founded most of all: the two groups are read
    // together here, or an owner's own community would vanish from the tab
    // the moment the server started answering in two. Which group a row came
    // from is a question for 我的 → 我的社区, not for this page.
    final joined = <JoinedCommunity>[
      ...?home?.joined,
      for (final entry in home?.owned ?? const <OwnedCommunity>[])
        JoinedCommunity(
          community: entry.community,
          membership: entry.membership,
        ),
    ];
    // The prototype's own heading: how many of the reader's communities are
    // bound to an asset, which is the whole of what 「在挖矿」 means here. The
    // aggregate carries the binding on every joined row, so this is a reading
    // and not a second request.
    final miningCount = joined
        .where((entry) => entry.community.hasBoundAsset)
        .length;
    final mining = <JoinedCommunity>[
      for (final entry in joined)
        if (entry.community.hasBoundAsset) entry,
    ];
    final others = <JoinedCommunity>[
      for (final entry in joined)
        if (!entry.community.hasBoundAsset) entry,
    ];
    // Ranking the reader's communities by discussion, counting live rooms and
    // totalling unread all need a Stream reading this page does not have: the
    // aggregate publishes both as unavailable facts and carries no unread per
    // joined community. So every clause is absent, and the folio says why
    // instead of printing a sentence with the numbers cut out of it.
    final activity = communityActivityCaption();
    return LoopDashboardPage(
      key: const ValueKey<String>('community-screen'),
      archetype: LoopPageArchetype.listing,
      title: '社区',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The discover hero sits above the index card, as in the
          // frozen prototype.
          if (home != null)
            CommunityDiscoverHero(
              key: const ValueKey<String>('community-discover-hero'),
              // `discover` is a preview the server cut to a handful,
              // so its length is not a count of verified communities
              // and the kicker never prints it as one.
              onTap: () => _open('/community/discover'),
            ),
          LoopFolioPrimary(
            key: const ValueKey<String>('community-folio'),
            variant: LoopFolioVariant.lime,
            archetype: LoopFolioArchetype.listing,
            kicker: 'COMMUNITY INDEX',
            // A read that is still running is not a read that failed.
            // The skeleton below was already saying 「正在读取」 while
            // this hero said 「暂无数值 / 社区数据暂时读不到」 for the
            // first seconds of every cold start.
            heading: home == null
                ? (loading ? '正在读取' : communityMissingHeading)
                : '$miningCount 个社区在挖矿',
            // Decision 0095: the count is drawn as a skeleton of its
            // own height until it is read.
            headingLoading: home == null && loading,
            caption: home == null
                ? loading
                      ? '已加入的社区数量读到之后显示在这里。'
                      : '社区数据暂时读不到，这一页不显示任何数字。'
                : activity ?? '讨论热度与语音房活动还没有开放。',
            // `.folio-stamp` is 「N LIVE」 in the prototype. Nothing
            // here counts live rooms, so the corner stays empty; it
            // is not a slot for the word DATABASE.
          ),
        ],
      ),
      block: communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>('community-capability-unavailable'),
              capability: capability,
              title: '社区模块当前不可用',
              deferredMessage: '社区还没有开放。',
              unknownMessage: '社区还没有准备好，请稍后再试。',
            )
          : null,
      onRefresh: () =>
          ref.read(communityHomeControllerProvider.notifier).reload(),
      updating: state.refreshing,
      sections: <Widget>[
        LoopFreshnessStrip(
          key: const ValueKey<String>('community-freshness'),
          restoredAt: controller.restoredObservedAt,
          readAt: controller.valueObservedAt,
          refreshing: state.refreshing,
          refreshFailed: home != null && state.failureKind != null,
          onRetry: () => unawaited(controller.reload()),
        ),
        CommunityPreviewNotice(mode: mode, resource: '社区数据'),
        if (state.phase != CommunityViewPhase.ready || home == null)
          CommunityStateBlock(
            // Rows of the index's own height (decision 0095).
            skeleton: LoopSkeletonType.record,
            rows: 4,
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有加入任何社区',
            emptyReason: '加入社区后，这里会列出你的社区。',
            onRetry: () => unawaited(
              ref.read(communityHomeControllerProvider.notifier).reload(),
            ),
          )
        else ...<Widget>[
          if (joined.isEmpty) ...<Widget>[
            const LoopLabel('已加入的社区'),
            const LoopEmpty(
              key: ValueKey<String>('community-joined-empty'),
              message: '还没有加入任何社区',
              reason: '从"发现社区"开始，加入后这里会显示你的社区。',
            ),
          ],
          // Two groups, in the prototype's order: the communities that
          // bound an asset — the ones a reader is here to mine — and
          // then everything else.
          if (mining.isNotEmpty) ...<Widget>[
            // `<p class="label" style="padding-top:0">` — the first
            // label on this page sits against the folio.
            const LoopLabel('带币社区 · 可挖矿', tight: true),
            LoopContentArrival(
              animate: _sawSkeleton,
              child: LoopRecordGroup(
                key: const ValueKey<String>('community-mining-group'),
                rows: <LoopRecordRow>[
                  for (final entry in mining) _joinedRow(entry),
                ],
              ),
            ),
          ],
          if (others.isNotEmpty) ...<Widget>[
            LoopLabel(
              '其他社区',
              followsLabel: mining.isNotEmpty,
              tight: mining.isEmpty,
            ),
            LoopContentArrival(
              animate: _sawSkeleton,
              child: LoopRecordGroup(
                key: const ValueKey<String>('community-other-group'),
                rows: <LoopRecordRow>[
                  for (final entry in others) _joinedRow(entry),
                ],
              ),
            ),
          ],
          if (home.joinedTruncated || home.ownedTruncated)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LoopButton(
                key: const ValueKey<String>('community-view-all-joined'),
                label: '查看全部已加入的社区',
                block: true,
                onPressed: () => _open('/community/discover?membership=joined'),
              ),
            ),
          LoopNotice(
            key: const ValueKey<String>('community-recommendation-rule'),
            icon: 'info',
            title: '推荐依据',
            body:
                '推荐只按成员数与创建时间排列，'
                '不是个性化算法推荐。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          CommunityObservedFootnote(
            key: const ValueKey<String>('community-observed-at'),
            observedAt: home.observedAt,
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  /// One joined community, in the prototype's own row.
  ///
  /// The second line is `48,120 成员 · <accent>`: the head count in mono, and
  /// then the one fact that decides whether this community mines. The
  /// community's approved weight lives behind a per-community mining read this
  /// page does not issue, so the accent carries the community's verification
  /// state when the operator has not verified it — and nothing at all when it
  /// is verified and the weight is simply not on this page.
  LoopRecordRow _joinedRow(JoinedCommunity entry) {
    final community = entry.community;
    final unverified =
        community.verificationStatus != CommunityVerification.verified
        ? communityVerificationLabel(community.verificationStatus)
        : null;
    // A muted or banned membership is the reader's own standing and outranks
    // everything else on the line; a plain 「成员」 told a reader nothing the
    // row did not already say.
    final standing = entry.membership.status == CommunityMemberStatus.active
        ? null
        : communityMembershipLabel(entry.membership);
    final accent = standing ?? unverified;
    final members = communityMemberCountLabel(community.memberCount);
    return LoopRecordRow(
      key: ValueKey<String>('community-joined-${community.communityId}'),
      leading: CommunityLogo(
        identity: community.communityId,
        name: community.name,
        logoRef: community.logoRef,
      ),
      title: community.name,
      subtitle: accent == null ? members : '$members · $accent',
      subtitleSpans: <InlineSpan>[
        TextSpan(text: members, style: LoopMono.stamp),
        if (accent != null) ...<InlineSpan>[
          const TextSpan(text: ' · '),
          TextSpan(
            text: accent,
            style: LoopTypography.figure(
              13,
              weight: FontWeight.w700,
              color: LoopColors.lime,
            ),
          ),
        ],
      ],
      // `.badge.badge-up` on the right of the row. LOOP publishes no unread
      // count per community in this version, so no row carries one; a zero is
      // never drawn.
      onTap: () => _open('/community/profile?id=${community.communityId}'),
      semanticLabel:
          '${community.name}，$members'
          '${accent == null ? '' : '，$accent'}',
    );
  }
}
