import 'package:flutter/material.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// `开发预览` eyebrow for a Preview-backed S3 page. Production and unavailable
/// modes carry no kicker, so the label can never appear outside Preview.
String? communityPreviewKicker(CommunityGatewayMode mode) =>
    mode == CommunityGatewayMode.preview ? '开发预览' : null;

/// Whether the page must stop at the capability gate instead of reading.
///
/// The explicit Development Preview adapter makes no server claim and is
/// visibly labelled `演示数据`, so it is not gated by the public capability
/// document — which a Preview session never observes.
bool communityCapabilityBlocks(
  CommunityGatewayMode mode,
  LoopCapabilityProjection capability,
) => mode != CommunityGatewayMode.preview && !capability.isAvailable;

/// The whole-page block a closed community gate renders.
///
/// It keeps two answers apart that used to share one sentence: the capability
/// document was never read, so LOOP was not reached at all and the next step
/// belongs to the user's own network; or LOOP answered and closed the surface,
/// which nothing on this device can change.
class CommunityCapabilityPageBlock extends StatelessWidget {
  const CommunityCapabilityPageBlock({
    required this.capability,
    required this.title,
    super.key,
    this.deferredMessage,
    this.unknownMessage,
  });

  final LoopCapabilityProjection capability;
  final String title;

  /// What a surface that exists but has not been switched on says. Surfaces
  /// that never had their own sentence keep the neutral one.
  final String? deferredMessage;

  /// What a surface says while no capability document has been read but LOOP
  /// was never actually asked — a build with no backend, or a read still in
  /// flight. A *failed* read is not this; it gets the unreachable page.
  final String? unknownMessage;

  @override
  Widget build(BuildContext context) {
    // The read did not get through: that is the network, not a closed surface.
    if (capability.unreachable) return const LoopPageBlock.unreachable();
    return LoopPageBlock(
      title: title,
      message: switch (capability.decision) {
        LoopCapabilityDecision.unknown => unknownMessage ?? '请稍后再试。',
        LoopCapabilityDecision.deferred => deferredMessage ?? '请稍后再试。',
        _ => '请稍后再试。',
      },
    );
  }
}

/// Visible Preview truth label. Reads and writes made here stay in the
/// running Preview and never reach an account or a provider.
class CommunityPreviewNotice extends StatelessWidget {
  const CommunityPreviewNotice({
    required this.mode,
    required this.resource,
    super.key,
  });

  final CommunityGatewayMode mode;
  final String resource;

  @override
  Widget build(BuildContext context) {
    if (mode != CommunityGatewayMode.preview) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('community-preview-notice'),
      icon: 'info',
      tone: LoopNoticeTone.warn,
      title: '演示数据',
      body: '$resource只存在于这次开发预览里，不会写入账号，也不会上传。',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }
}

/// The one place the five reviewed states are rendered for an S3 page.
class CommunityStateBlock extends StatelessWidget {
  const CommunityStateBlock({
    required this.phase,
    required this.failureKind,
    super.key,
    this.onRetry,
    this.emptyMessage = '这里还没有内容',
    this.emptyReason,
    this.permissionTitle = '当前账号没有权限',
    this.skeleton = LoopSkeletonType.list,
    this.rows = 3,
    this.refreshing = false,
  });

  final CommunityViewPhase phase;
  final CommunityFailureKind? failureKind;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? emptyReason;
  final String permissionTitle;
  final LoopSkeletonType skeleton;
  final int rows;

  /// `CommunityResourceState.refreshing`: a re-read over data the page already
  /// shows. The block marks it instead of covering the data with a skeleton.
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case CommunityViewPhase.loading:
        return LoopSkeleton(
          key: const ValueKey<String>('community-state-loading'),
          type: skeleton,
          rows: rows,
        );
      case CommunityViewPhase.empty:
        return LoopEmpty(
          key: const ValueKey<String>('community-state-empty'),
          message: emptyMessage,
          reason: emptyReason,
        );
      case CommunityViewPhase.offline:
        return LoopOfflineState(
          key: const ValueKey<String>('community-state-offline'),
          onRetry: onRetry,
          pausedActions: const <String>['加入', '关注', '屏蔽', '治理'],
        );
      case CommunityViewPhase.unavailable:
        return LoopEmpty(
          key: const ValueKey<String>('community-state-unavailable'),
          icon: 'warn',
          message: '该功能当前不可用',
          reason: communityFailureReason(failureKind),
        );
      case CommunityViewPhase.permission:
        return LoopPermissionState(
          key: const ValueKey<String>('community-state-permission'),
          icon: 'shield',
          title: permissionTitle,
          purpose: communityFailureReason(failureKind),
        );
      case CommunityViewPhase.error:
        return LoopErrorState(
          key: const ValueKey<String>('community-state-error'),
          reason: communityFailureReason(failureKind),
          onRetry: onRetry,
        );
      case CommunityViewPhase.ready:
        return LoopUpdatingBadge(
          key: const ValueKey<String>('community-state-updating'),
          visible: refreshing,
        );
    }
  }
}

/// Renders one `{status: unavailable, reasonCode}` field. It never renders a
/// figure, a zero, or a fixture in place of the missing fact.
class CommunityUnavailableCard extends StatelessWidget {
  const CommunityUnavailableCard({
    required this.label,
    required this.fact,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.action,
  });

  final String label;
  final LoopUnavailableFact fact;
  final EdgeInsets margin;

  /// The one next step, when one exists.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: ValueKey<String>('community-unavailable-${fact.reasonCode}'),
      message: label,
      reason: communityUnavailableReason(fact.reasonCode),
      margin: margin,
      action: action,
    );
  }
}

/// A server-side time in UTC — a snapshot's, an observation's. The client
/// never restates it as a local wall clock or as a relative "just now".
String communitySettlementLabel(DateTime computedAt) {
  final value = computedAt.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)} UTC';
}

/// A count in the community record's own mono voice, grouped in thousands.
///
/// `128420 成员` is read digit by digit; `128,420 成员` is read at a glance,
/// which is the only thing the separator is for. It never rounds and never
/// abbreviates: the number printed is the number the server sent.
String communityCountLabel(int count) {
  final digits = count.abs().toString();
  final buffer = StringBuffer(count < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// What the 在线 figure in the identity line is, said in full.
///
/// The page prints one number beside the member count, which is where a
/// reader looks for it; this is where the number explains itself. It used to
/// be a permanent four-line notice halfway down the record, which is a
/// paragraph about a fact nobody had asked about yet.
Future<void> showCommunityPresenceMeaningSheet(
  BuildContext context, {
  required int count,
  required DateTime observedAt,
}) async {
  await showLoopSheet<void>(
    context,
    barrierLabel: '关闭在线人数说明',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('community-online-meaning-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '这里数的是连接，不是活跃',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '这是社区官方频道的成员里，此刻仍与 Stream 保持连接的人数'
            '（${communityCountLabel(count)} 人），不是「正在看这个频道」，'
            '不是「最近活跃」，也不是社区成员总数。它是一次观察，不是持续统计。',
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          const SizedBox(height: 10),
          Text(
            '观察于 ${communityObservedAtLabel(observedAt)}',
            style: LoopTypography.figure(12, color: LoopColors.text3),
          ),
          const SizedBox(height: 18),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-online-meaning-close'),
                label: '知道了',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// The community's own identity block (`#scr-community-profile .pad`): the
/// logo, the name, one mono line of counts and the community's description.
///
/// The counts line only ever carries facts the server sent. An unavailable
/// presence reading drops the 在线 segment instead of explaining itself in
/// place: the explanation belongs to the reading, and the reading is not
/// there.
class CommunityIdentityBlock extends StatelessWidget {
  const CommunityIdentityBlock({
    required this.community,
    required this.onlineCount,
    super.key,
    this.onExplainPresence,
  });

  final CommunitySummary community;
  final CommunityOnlineCount onlineCount;

  /// Opens the presence explanation. Offered only when a reading exists.
  final VoidCallback? onExplainPresence;

  @override
  Widget build(BuildContext context) {
    final observed = onlineCount is CommunityOnlineCountObserved
        ? onlineCount as CommunityOnlineCountObserved
        : null;
    final members = communityCountLabel(community.memberCount);
    final counts = <InlineSpan>[
      TextSpan(text: '$members 成员'),
      if (observed != null) ...<InlineSpan>[
        const TextSpan(text: ' · '),
        TextSpan(
          text: '${communityCountLabel(observed.count)} 在线',
          style: LoopTypography.figure(12, color: LoopColors.lime),
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CommunityLogoTile(
            key: const ValueKey<String>('community-profile-logo'),
            name: community.name,
            size: 88,
            radius: LoopRadius.controlValue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(community.name, style: LoopTypography.title(19)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: counts,
                    style: LoopTypography.figure(12, color: LoopColors.text2),
                  ),
                  key: const ValueKey<String>('community-profile-counts'),
                ),
                const SizedBox(height: 8),
                Text(
                  community.description ?? '这个社区还没有填写简介。',
                  style: LoopTypography.body(12, color: LoopColors.text2),
                ),
              ],
            ),
          ),
          if (observed != null && onExplainPresence != null)
            LoopIconButton(
              key: const ValueKey<String>('community-online-count-explain'),
              icon: 'info',
              label: '在线人数是怎么数的',
              onPressed: onExplainPresence,
            ),
        ],
      ),
    );
  }
}

/// The community record's mining block (`#scr-community-profile .card`
/// → `mining-community`): the reviewed weight, the community's own power,
/// and the three per-account columns.
///
/// The card keeps its shape whatever the server answered. A column with no
/// source prints an em dash and the line under the card says which columns
/// those are and why — replacing the whole card with a paragraph would lose
/// the two figures that *are* readable along with the way into the panel.
class CommunityMiningSummaryCard extends StatelessWidget {
  const CommunityMiningSummaryCard({
    required this.fact,
    super.key,
    this.onOpenPanel,
  });

  final LoopMiningPowerFact fact;
  final VoidCallback? onOpenPanel;

  @override
  Widget build(BuildContext context) {
    final settled = fact is LoopCommunityMiningPower
        ? fact as LoopCommunityMiningPower
        : null;
    final weight = switch (settled?.weight) {
      MiningCommunityWeightApproved(:final value) => value,
      _ => communityMissingFigure,
    };
    final power = settled?.power ?? communityMissingFigure;
    // Where the three per-account columns are read. They are one account's
    // figures across the community's asset, and this record carries none of
    // them; the panel does.
    const panel = '我的持仓、我的算力与预估收益要在社区挖矿面板里读，这张卡片不替它们估算。';
    // A later run that did not complete leaves this number the last complete
    // snapshot's (Decision 0057). The card dates it instead of withdrawing
    // it; why that run stopped is on the mining page, which this card opens.
    final dated = switch (fact) {
      LoopMiningPowerSettled(:final computedAt, stale: true) =>
        '${miningStaleLine(computedAtLabel: communityObservedAtLabel(computedAt))}。',
      LoopMiningPowerSettled(:final computedAt) =>
        '最近一次算力快照 · ${communityObservedAtLabel(computedAt)}。',
      LoopMiningPowerUnavailable() => '',
    };
    final note = switch (fact) {
      LoopMiningPowerUnavailable(:final reasonCode) =>
        '${communityUnavailableReason(reasonCode)}$panel',
      LoopCommunityMiningPower(:final weight) =>
        '$dated'
            '${switch (weight) {
              MiningCommunityWeightApproved() => '',
              MiningCommunityWeightPending(reviewStatus: MiningWeightReviewStatus.pendingReview) => '权重还在审核中，这里不显示权重数值。',
              MiningCommunityWeightPending() => '没有绑定代币，没有权重可审。',
            }}$panel',
      LoopMiningPowerSettled() => '$dated$panel',
    };
    final subtitle = settled != null && settled.isBaseline
        ? 'Mining Weight · 社区总算力 $power · $miningBaselineLabel'
        : 'Mining Weight · 社区总算力 $power';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSurfaceCard(
          key: const ValueKey<String>('community-mining-summary'),
          margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          onTap: onOpenPanel,
          semanticLabel: '社区挖矿面板，权重 $weight，社区算力 $power',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LoopIcon('mine', size: 21, color: LoopColors.lime),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          weight,
                          key: const ValueKey<String>(
                            'community-mining-weight',
                          ),
                          style: LoopTypography.figure(
                            17,
                            color: LoopColors.lime,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: LoopTypography.caption(
                            11,
                            color: LoopColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenPanel != null)
                    const LoopIcon(
                      'chevron',
                      size: 14,
                      color: LoopColors.text3,
                    ),
                ],
              ),
              const SizedBox(height: 11),
              const Divider(height: 1, thickness: 1, color: LoopColors.line),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  _MiningColumn(label: '我的持仓'),
                  SizedBox(width: 16),
                  _MiningColumn(label: '我的算力', accent: true),
                  SizedBox(width: 16),
                  _MiningColumn(label: '预估/日'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            note,
            key: const ValueKey<String>('community-mining-summary-note'),
            style: LoopTypography.caption(11, color: LoopColors.text3),
          ),
        ),
      ],
    );
  }
}

/// One column of the mining card. Every one of the three is an account-level
/// figure the community record does not carry, so each prints the dash and
/// the card's own line says where the figure lives.
class _MiningColumn extends StatelessWidget {
  const _MiningColumn({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          communityMissingFigure,
          style: LoopTypography.figure(
            13,
            color: accent ? LoopColors.lime : LoopColors.chalk,
          ),
        ),
        Text(label, style: LoopTypography.caption(11, color: LoopColors.text3)),
      ],
    );
  }
}

/// The published announcement rows (`.row` × n), or the one quiet line a
/// community with nothing published gets.
///
/// An unavailable board and an empty one are different sentences: the first
/// says the server could not answer, the second says this community has not
/// announced anything.
class CommunityAnnouncementBoard extends StatelessWidget {
  const CommunityAnnouncementBoard({
    required this.feed,
    super.key,
    this.onOpen,
  });

  final CommunityAnnouncementFeed feed;

  /// Where an announcement is read in full. Announcements live in the
  /// official group, so the row goes there; with no way in, the row states
  /// the announcement and takes no tap.
  final VoidCallback? onOpen;

  /// The glyph one kind draws. An unknown kind keeps the neutral one.
  static String glyphFor(String kind) => switch (kind) {
    'pinned' || 'pin' => 'pin',
    'voiceRoom' || 'ama' => 'mic',
    'update' || 'release' => 'news',
    _ => 'news',
  };

  @override
  Widget build(BuildContext context) {
    switch (feed) {
      case CommunityAnnouncementFeedUnavailable(:final reasonCode):
        // A board that could not be read is still a board with nothing on
        // it, so the line reads the same way as an empty one — and then says
        // why, because 「暂无」 on its own would claim the community has
        // announced nothing.
        return CommunityQuietLine(
          key: const ValueKey<String>('community-announcements-unavailable'),
          text: '暂无公告 · ${communityUnavailableReason(reasonCode)}',
        );
      case CommunityAnnouncementFeedPublished(:final items):
        if (items.isEmpty) {
          return const CommunityQuietLine(
            key: ValueKey<String>('community-announcements-empty'),
            text: '暂无公告',
          );
        }
        return LoopRecordGroup(
          key: const ValueKey<String>('community-announcements'),
          rows: <LoopRecordRow>[
            for (var index = 0; index < items.length; index += 1)
              LoopRecordRow(
                key: ValueKey<String>(
                  'community-announcement-${items[index].announcementId}',
                ),
                leading: LoopIcon(
                  glyphFor(items[index].kind),
                  size: 18,
                  color: LoopColors.text2,
                ),
                title: items[index].title,
                subtitle: items[index].byline == null
                    ? communityObservedAtLabel(items[index].publishedAt)
                    : '${items[index].byline} · '
                          '${communityObservedAtLabel(items[index].publishedAt)}',
                onTap: onOpen,
                position: communityRowPosition(index, items.length),
              ),
          ],
        );
    }
  }
}

/// The official links (`.segs`), or the one quiet line when there are none.
///
/// LOOP has no browser of its own here, so a pill copies the address instead
/// of claiming to open it. The address is what the reader takes away either
/// way, and nothing is opened that LOOP cannot state it opened.
class CommunityOfficialLinkRow extends StatelessWidget {
  const CommunityOfficialLinkRow({required this.links, super.key, this.onCopy});

  final CommunityOfficialLinkList links;
  final ValueChanged<CommunityOfficialLink>? onCopy;

  @override
  Widget build(BuildContext context) {
    switch (links) {
      case CommunityOfficialLinksUnavailable(:final reasonCode):
        return CommunityQuietLine(
          key: const ValueKey<String>('community-links-unavailable'),
          text: '暂无官方链接 · ${communityUnavailableReason(reasonCode)}',
        );
      case CommunityOfficialLinksPublished(:final items):
        if (items.isEmpty) {
          return const CommunityQuietLine(
            key: ValueKey<String>('community-links-empty'),
            text: '暂无官方链接',
          );
        }
        return SingleChildScrollView(
          key: const ValueKey<String>('community-links'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: <Widget>[
              for (var index = 0; index < items.length; index += 1) ...<Widget>[
                if (index > 0) const SizedBox(width: 7),
                LoopSeg(
                  key: ValueKey<String>('community-link-${items[index].label}'),
                  label: items[index].label,
                  selected: false,
                  onSelected: onCopy == null
                      ? null
                      : () => onCopy!(items[index]),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// One line of quiet copy where a card would over-answer.
///
/// 「暂无公告」 is a whole reading; wrapping it in a dashed empty-state box
/// gives an absence more room on the page than the facts around it.
class CommunityQuietLine extends StatelessWidget {
  const CommunityQuietLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Text(
        text,
        style: LoopTypography.caption(12, color: LoopColors.text3),
      ),
    );
  }
}

/// Renders one `miningPower` field. A settled reading prints the server's own
/// number and when it was settled; the version that produced it is a backend
/// identifier and stays inside the 详情. Anything else keeps the unavailable
/// card: this card never turns an absent reading into a zero.
class CommunityMiningPowerCard extends StatelessWidget {
  const CommunityMiningPowerCard({
    required this.label,
    required this.fact,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String label;
  final LoopMiningPowerFact fact;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    switch (fact) {
      case LoopMiningPowerUnavailable(:final reasonCode):
        return CommunityUnavailableCard(
          label: label,
          fact: LoopUnavailableFact(reasonCode),
          margin: margin,
        );
      case LoopMiningPowerSettled(
        :final power,
        :final formulaVersion,
        :final computedAt,
        :final isBaseline,
        :final stale,
      ):
        final identifier = formulaVersion;
        return Padding(
          padding: margin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopRecordGroup(
                key: const ValueKey<String>('community-mining-power'),
                rows: <LoopRecordRow>[
                  LoopRecordRow(
                    key: const ValueKey<String>('community-mining-power-row'),
                    title: label,
                    subtitle: stale
                        ? miningStaleLine(
                            computedAtLabel: communitySettlementLabel(
                              computedAt,
                            ),
                          )
                        : '最近一次算力快照 · ${communitySettlementLabel(computedAt)}',
                    // The stamp ended at 「10:23 U…」, which drops the zone
                    // the time is stated in.
                    subtitleMaxLines: 2,
                    trailing: power,
                    // The version's own declaration is what may label the
                    // number; the version string is never read for meaning.
                    trailingCaption: isBaseline ? miningBaselineLabel : null,
                    semanticLabel: isBaseline
                        ? '$label，$power，$miningBaselineLabel'
                        : '$label，$power',
                    position: fact is LoopCommunityMiningPower
                        ? LoopRowPosition.first
                        : LoopRowPosition.single,
                  ),
                  // A community's number is a sum over one bound asset, so the
                  // two facts that explain it belong beside it. An account's
                  // number is one person across every asset and has neither.
                  if (fact is LoopCommunityMiningPower) ...<LoopRecordRow>[
                    _weightRow(fact as LoopCommunityMiningPower),
                    _participantsRow(fact as LoopCommunityMiningPower),
                  ],
                ],
              ),
              LoopDisclosure(
                key: const ValueKey<String>('community-mining-power-details'),
                summary: '详情',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    '这次算力快照所用的公式版本 $identifier',
                    style: LoopTypography.caption(11, color: LoopColors.text3),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// The reviewed weight behind a community's number. A weight still under
/// review is why the number can be zero, so the row says that instead of the
/// value it does not have.
LoopRecordRow _weightRow(LoopCommunityMiningPower fact) => LoopRecordRow(
  key: const ValueKey<String>('community-mining-power-weight'),
  title: '社区权重',
  subtitle: switch (fact.weight) {
    MiningCommunityWeightApproved() => '已按审核结果授予，算在上面的数里',
    // An unbound community is not waiting for anything: saying 审核中 would
    // promise a review nobody is performing (Decision 0046).
    MiningCommunityWeightPending(
      reviewStatus: MiningWeightReviewStatus.pendingReview,
    ) =>
      '权重还在审核中，这里不显示数值',
    MiningCommunityWeightPending() => '没有绑定代币，没有权重可审',
  },
  subtitleMaxLines: 2,
  trailing: switch (fact.weight) {
    MiningCommunityWeightApproved(:final value) => value,
    MiningCommunityWeightPending() => communityMissingFigure,
  },
  position: LoopRowPosition.middle,
);

/// How many members had a power above zero. A count of zero is a reading: the
/// community is settled and nobody held anything that counted.
LoopRecordRow _participantsRow(LoopCommunityMiningPower fact) => LoopRecordRow(
  key: const ValueKey<String>('community-mining-power-participants'),
  title: '有算力的成员',
  subtitle: switch (fact.participants) {
    MiningParticipantsCount() => '最近一次算力快照里算出了算力的人',
    MiningParticipantsUnavailable() => '这一项暂时读不到',
  },
  subtitleMaxLines: 2,
  trailing: switch (fact.participants) {
    MiningParticipantsCount(:final count) => '$count',
    MiningParticipantsUnavailable() => communityMissingFigure,
  },
  position: LoopRowPosition.last,
);

/// The em dash used wherever a real figure has no source. Never `0`.
///
/// It owns the small slots: a metric cell, a row's trailing value, the end of
/// a sentence. At 11–20px, next to its own label, an em dash reads as
/// "nothing here", which is exactly what it means.
const String communityMissingFigure = '—';

/// The same absence, said in words, where a page heading would carry the
/// figure.
///
/// A hero heading prints at 25–30px, and in the Lime folio it prints in Lime;
/// there the same dash stops reading as a placeholder and reads as a stray
/// green rule floating over the card. The heading therefore says it: never
/// `0`, never blank, and still the plain statement that this page has no
/// number to show yet.
const String communityMissingHeading = '暂无数值';

/// The same placeholder for a heading that was never a number. A community
/// whose record did not load has no name to print, and saying 暂无数值 there
/// would describe the wrong kind of gap.
const String communityMissingName = '暂无名称';

/// The one label for a server-confirmed membership, shared by the community
/// home rows and the profile page's 我的社区 entry.
///
/// A muted or banned membership is reported as that state rather than as its
/// role: the account still holds `member`/`admin`, but saying so here would
/// read as an entitlement the server has suspended.
String communityMembershipLabel(CommunityMembership membership) =>
    switch (membership.status) {
      CommunityMemberStatus.active => membership.role.label,
      CommunityMemberStatus.muted => '已禁言',
      CommunityMemberStatus.banned => '已封禁',
    };

/// Square monogram tile for a community.
///
/// `logoRef` is a `avatar:preset/community-01..12` reference the frozen local
/// atlas does not carry, so the tile shows the community's own initials rather
/// than an unrelated preset image.
class CommunityLogoTile extends StatelessWidget {
  const CommunityLogoTile({
    required this.name,
    super.key,
    this.size = 44,
    this.radius,
    this.bordered = false,
  });

  final String name;
  final double size;

  /// Corner radius. The prototype draws this tile at three sizes with three
  /// radii — 12 in a row, 16 in the identity block, the shell radius on the
  /// folio — so the caller states it rather than the tile guessing from size.
  final double? radius;

  /// `.folio-media-identity{border:1px solid rgba(243,245,239,.2)}`: the edge
  /// the tile draws when it sits on the folio rather than inside a card.
  final bool bordered;

  static String monogramFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'LO';
    final runes = trimmed.runes.take(2).toList(growable: false);
    return String.fromCharCodes(runes).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Same rule as the other monogram tiles: the fill and the letters come
        // from the ground, so the tile survives a move onto a Chalk card.
        color: LoopGround.fillOf(context),
        borderRadius: BorderRadius.circular(radius ?? LoopRadius.innerValue),
        border: bordered ? Border.all(color: LoopGround.edgeOf(context)) : null,
      ),
      child: Text(
        monogramFor(name),
        style: LoopTypography.figure(
          size / 3.4,
          color: LoopGround.inkOf(context),
        ),
      ),
    );
  }
}

/// The server's own verification state for a community, in words.
///
/// It is the community's state, not the reader's membership: a community may
/// be 审核中 while the reader is a full member of it.
String communityVerificationLabel(CommunityVerification status) =>
    switch (status) {
      CommunityVerification.verified => '已验证',
      CommunityVerification.pending => '审核中',
      CommunityVerification.rejected => '未通过',
    };

/// One community row. The subtitle only ever carries server-maintained facts.
///
/// It is a function, not a widget, because [LoopRecordGroup] needs the row
/// instances themselves to draw its dividers.
LoopRecordRow communityDirectoryRow({
  required CommunitySummary community,
  required VoidCallback? onTap,
  LoopRowPosition position = LoopRowPosition.single,
}) {
  final verification = communityVerificationLabel(community.verificationStatus);
  return LoopRecordRow(
    key: ValueKey<String>('community-row-${community.communityId}'),
    leading: CommunityLogoTile(name: community.name),
    title: community.name,
    // The slug is the server's addressing handle; it told a reader browsing
    // the directory nothing 「mock-vol-01」 did not already hide.
    subtitle: verification,
    trailing: '${community.memberCount}',
    trailingCaption: '成员',
    onTap: onTap,
    position: position,
    semanticLabel:
        '${community.name}，$verification，${community.memberCount} 名成员',
  );
}

/// Row position inside a group of [length] rows.
LoopRowPosition communityRowPosition(int index, int length) {
  if (length <= 1) return LoopRowPosition.single;
  if (index == 0) return LoopRowPosition.first;
  if (index == length - 1) return LoopRowPosition.last;
  return LoopRowPosition.middle;
}

/// Server observation time in UTC. The client never restates it as a local
/// wall clock or as a relative "just now".
String communityObservedAtLabel(DateTime observedAt) {
  final value = observedAt.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)} UTC';
}

/// Second confirmation for a governance or relationship action.
///
/// The sheet states exactly what the server will be asked to do. It never
/// promises the outcome: the caller shows a success Toast only after a 2xx.
Future<bool> confirmCommunityAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = '取消',
  String sheetKey = 'community-confirm-sheet',
}) async {
  final confirmed = await showLoopSheet<bool>(
    context,
    barrierLabel: '关闭确认弹层',
    builder: (sheetContext) => Padding(
      key: ValueKey<String>(sheetKey),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(body, style: LoopTypography.body(13, color: LoopColors.muted)),
          const SizedBox(height: 18),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-confirm-accept'),
                label: confirmLabel,
                primary: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              LoopButton(
                key: const ValueKey<String>('community-confirm-cancel'),
                label: cancelLabel,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Owner-only community profile edit sheet.
///
/// `slug` and `verificationStatus` are not editable and are shown read-only,
/// so the sheet can never submit a field the server would reject.
Future<CommunityProfileEdit?> showCommunityProfileEditSheet(
  BuildContext context, {
  required CommunitySummary community,
}) {
  final nameController = TextEditingController(text: community.name);
  final descriptionController = TextEditingController(
    text: community.description ?? '',
  );
  return showLoopSheet<CommunityProfileEdit>(
    context,
    barrierLabel: '关闭社区资料编辑',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('community-edit-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '编辑社区资料',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-edit-name'),
            controller: nameController,
            decoration: const InputDecoration(labelText: '社区名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-edit-description'),
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '简介（可留空）'),
          ),
          const SizedBox(height: 12),
          LoopKeyValue(
            label: '短链接（不可修改）',
            value: community.slug,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-edit-submit'),
                label: '下一步',
                primary: true,
                onPressed: () {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(
                    CommunityProfileEdit(
                      name: name == community.name || name.isEmpty
                          ? null
                          : name,
                      description:
                          description.isEmpty ||
                              description == community.description
                          ? null
                          : description,
                      clearDescription:
                          description.isEmpty && community.description != null,
                    ),
                  );
                },
              ),
              LoopButton(
                key: const ValueKey<String>('community-edit-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    nameController.dispose();
    descriptionController.dispose();
  });
}

/// The community application form.
///
/// It has no route of its own: the frozen 93-page manifest has no application
/// page, so `community-discover` opens this sheet instead of inventing one.
/// Shape is checked locally so an obviously invalid application never leaves
/// the device; acceptance stays the server's decision.
Future<CommunityApplication?> showCommunityApplySheet(BuildContext context) {
  return showLoopSheet<CommunityApplication>(
    context,
    barrierLabel: '关闭社区申请',
    builder: (sheetContext) => const _CommunityApplyForm(),
  );
}

class _CommunityApplyForm extends StatefulWidget {
  const _CommunityApplyForm();

  @override
  State<_CommunityApplyForm> createState() => _CommunityApplyFormState();
}

class _CommunityApplyFormState extends State<_CommunityApplyForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _slug = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _assetKey = TextEditingController();
  CommunityApplicationField? _invalidField;

  /// The closed set the server accepts, plus "no logo".
  static const List<String?> _logoRefs = <String?>[
    null,
    'avatar:preset/community-01',
    'avatar:preset/community-02',
    'avatar:preset/community-03',
    'avatar:preset/community-04',
  ];
  String? _logoRef;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _assetKey.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _submit() {
    final application = CommunityApplication(
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      description: _optional(_description),
      logoRef: _logoRef,
      boundAssetKey: _optional(_assetKey)?.toLowerCase(),
    );
    final invalid = application.invalidField;
    if (invalid != null) {
      setState(() => _invalidField = invalid);
      return;
    }
    Navigator.of(context).pop(application);
  }

  String? _errorFor(CommunityApplicationField field) =>
      _invalidField == field ? communityApplicationFieldReason(field) : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('community-apply-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '申请入驻',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '提交后社区状态为「审核中」，你是所有者。验证标记只能由运维核验后设置，'
            '本表单不会带来任何 Mining 权重结论。',
            style: LoopTypography.caption(12, color: LoopColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('community-apply-name'),
            controller: _name,
            decoration: InputDecoration(
              labelText: '社区名称（1–40）',
              errorText: _errorFor(CommunityApplicationField.name),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-apply-slug'),
            controller: _slug,
            decoration: InputDecoration(
              labelText: '短链接（3–32，小写字母、数字与连字符）',
              errorText: _errorFor(CommunityApplicationField.slug),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-apply-description'),
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '简介（可留空，≤280）',
              errorText: _errorFor(CommunityApplicationField.description),
            ),
          ),
          const SizedBox(height: 12),
          const LoopLabel('社区标识（可留空）'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final reference in _logoRefs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LoopSeg(
                      key: ValueKey<String>(
                        'community-apply-logo-${reference ?? 'none'}',
                      ),
                      label: reference == null
                          ? '不设置'
                          : reference.split('-').last,
                      selected: _logoRef == reference,
                      onSelected: () => setState(() => _logoRef = reference),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-apply-asset-key'),
            controller: _assetKey,
            decoration: InputDecoration(
              labelText: '绑定资产（可留空，eip155:<链>:0x…）',
              errorText: _errorFor(CommunityApplicationField.boundAssetKey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '绑定地址只做登记，暂时不会显示价格、市值或持有人。',
            style: LoopTypography.caption(11, color: LoopColors.muted),
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-apply-submit'),
                label: '提交申请',
                primary: true,
                onPressed: _submit,
              ),
              LoopButton(
                key: const ValueKey<String>('community-apply-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline copy for the field the local shape check rejected.
String communityApplicationFieldReason(CommunityApplicationField field) =>
    switch (field) {
      CommunityApplicationField.name => '名称需要 1–40 个字符，且不能包含控制字符。',
      CommunityApplicationField.slug => '短链接只能是 3–32 位小写字母、数字或连字符。',
      CommunityApplicationField.description => '简介最多 280 个字符，且不能包含控制字符。',
      CommunityApplicationField.boundAssetKey =>
        '绑定资产需要形如 eip155:56:0x… 的 40 位十六进制地址。',
    };
