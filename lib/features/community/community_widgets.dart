import 'package:flutter/material.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
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

/// A server-side time — a snapshot's, an observation's — on the reader's own
/// wall clock. It is never restated as a relative "just now".
String communitySettlementLabel(DateTime computedAt) =>
    loopLocalTimestampLabel(computedAt);

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
          CommunityLogo(
            key: const ValueKey<String>('community-profile-logo'),
            identity: community.communityId,
            name: community.name,
            logoRef: community.logoRef,
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

/// One of the three per-account cells on the community record's mining card.
///
/// A cell is either the server's own figure or the reason there is none. The
/// client computes neither: a holding, a power and a daily estimate are three
/// settled readings, and a card that multiplied them itself would be printing
/// a number nobody settled.
@immutable
final class CommunityMiningCell {
  const CommunityMiningCell.value(this.value) : reason = null;

  const CommunityMiningCell.missing(this.reason) : value = null;

  /// The figure as the server sent it, already grouped for reading.
  final String? value;

  /// Why there is no figure. Null exactly when [value] is not.
  final String? reason;
}

/// The three cells `我的持仓 / 我的算力 / 预估每日` on the community record.
///
/// They are one account's readings on this community's bound asset, and the
/// community projection carries none of them: they are read from the mining
/// module (`GET /v2/mining/communities/{id}` and `GET /v2/mining/assets`).
/// Until 2026-09-23 the card printed three em dashes and a line saying it
/// would not estimate them, which is true of the estimate and was not true of
/// the other two.
@immutable
final class CommunityMiningAccountReading {
  const CommunityMiningAccountReading({
    required this.holding,
    required this.power,
    required this.estimatedDaily,
  });

  /// Nothing has been read yet: the panel and the composition are both still
  /// in flight, or this build never asked for them.
  factory CommunityMiningAccountReading.unread(String reason) =>
      CommunityMiningAccountReading(
        holding: CommunityMiningCell.missing(reason),
        power: CommunityMiningCell.missing(reason),
        estimatedDaily: CommunityMiningCell.missing(reason),
      );

  final CommunityMiningCell holding;
  final CommunityMiningCell power;
  final CommunityMiningCell estimatedDaily;

  /// The reasons behind the cells that have no figure, each said once.
  List<String> get missingReasons {
    final reasons = <String>[];
    for (final cell in <CommunityMiningCell>[holding, power, estimatedDaily]) {
      final reason = cell.reason;
      if (reason != null && !reasons.contains(reason)) reasons.add(reason);
    }
    return reasons;
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
    this.account,
    this.onOpenPanel,
  });

  final LoopMiningPowerFact fact;

  /// The reader's own three cells, when this page read them.
  final CommunityMiningAccountReading? account;

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
    // 531381.12 is read digit by digit; 531,381.12 is read at a glance. The
    // separator never rounds and never abbreviates (walkthrough · a48).
    final power = settled == null
        ? communityMissingFigure
        : loopGroupedFigure(settled.power);
    final reading =
        account ??
        CommunityMiningAccountReading.unread('这三格要在社区挖矿面板里读，这张卡片没有读到。');
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
    final panel = reading.missingReasons.join('');
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
                children: <Widget>[
                  _MiningColumn(
                    slug: 'holding',
                    label: '我的持仓',
                    cell: reading.holding,
                  ),
                  const SizedBox(width: 16),
                  _MiningColumn(
                    slug: 'power',
                    label: '我的算力',
                    cell: reading.power,
                    accent: true,
                  ),
                  const SizedBox(width: 16),
                  _MiningColumn(
                    slug: 'estimated',
                    label: '预估/日',
                    cell: reading.estimatedDaily,
                  ),
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

/// One column of the mining card: the account's own figure, or the em dash
/// that stands for the reason the card's own line carries.
class _MiningColumn extends StatelessWidget {
  const _MiningColumn({
    required this.slug,
    required this.label,
    required this.cell,
    this.accent = false,
  });

  final String slug;
  final String label;
  final CommunityMiningCell cell;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final value = cell.value;
    return Semantics(
      container: true,
      label: '$label，${value ?? cell.reason ?? communityMissingFigure}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value ?? communityMissingFigure,
              key: ValueKey<String>('community-mining-cell-$slug'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.figure(
                13,
                color: accent ? LoopColors.lime : LoopColors.chalk,
              ),
            ),
            Text(
              label,
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ],
        ),
      ),
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

/// The applicant's own reading of the review, in words.
///
/// It is deliberately not [communityVerificationLabel]: that one is what a
/// reader is told about somebody else's community (已验证 / 审核中 / 未通过),
/// and this one is what an applicant is told about a review they are waiting
/// on. 「已通过」 and 「已驳回」 name the decision that was made about their
/// submission; 「已验证」 and 「未通过」 name a property of the community.
String communityApplicationStatusLabel(CommunityVerification status) =>
    switch (status) {
      CommunityVerification.pending => '审核中',
      CommunityVerification.verified => '已通过',
      CommunityVerification.rejected => '已驳回',
    };

/// How many code points of an operator's reason a list row carries before it
/// elides. The whole reason is on the community record; a row states enough of
/// it to be recognised.
const int communityRejectedReasonPreviewRunes = 30;

/// `驳回：名称与已上线社区重复` — the head of the operator's own words.
///
/// A refusal with no reason still says it was refused: the operator is not
/// obliged to give one, and 「驳回：」 followed by nothing would read as a
/// reason this device failed to load.
String communityRejectedReasonPreview(String? reason) {
  final text = reason?.trim();
  if (text == null || text.isEmpty) return '驳回：运维没有给出原因';
  final runes = text.runes.toList(growable: false);
  if (runes.length <= communityRejectedReasonPreviewRunes) return '驳回：$text';
  final head = String.fromCharCodes(
    runes.take(communityRejectedReasonPreviewRunes),
  );
  return '驳回：$head…';
}

/// The second line of a 我创建的 row: when it was submitted, or why it was
/// refused. A refused application says why instead of when, because the reason
/// is the only thing on that row its owner can act on.
String communityApplicationRowLine(OwnedCommunity entry) {
  final review = entry.application;
  if (review == null) {
    // A deployment that carries no review block still has a community with a
    // creation time on it, and that is what the row dates.
    return '创建于 ${loopLocalTimestampLabel(entry.community.createdAt)}';
  }
  if (review.isRejected) {
    return communityRejectedReasonPreview(review.rejectedReason);
  }
  return '提交于 ${loopLocalTimestampLabel(review.submittedAt)}';
}

/// `.badge` for an application's review state.
///
/// [LoopBadge] publishes two pairs — Lime and the neutral ground — and a
/// refusal is neither: 「已驳回」 in the neutral pair reads as one more piece of
/// metadata beside 「审核中」, and in Lime it reads as an achievement. The pill
/// keeps [LoopBadge]'s geometry and type exactly, and only the refusal adds a
/// third pair, from the one non-Lime accent the palette already carries.
///
/// It is a status, never an action: nothing here is tappable.
class CommunityApplicationBadge extends StatelessWidget {
  const CommunityApplicationBadge(this.status, {super.key});

  final CommunityVerification status;

  @override
  Widget build(BuildContext context) {
    final label = communityApplicationStatusLabel(status);
    if (status != CommunityVerification.rejected) {
      return LoopBadge(
        label,
        kind: status == CommunityVerification.verified
            ? LoopBadgeKind.up
            : LoopBadgeKind.mute,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: LoopColors.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: LoopTypography.label(
          12,
          weight: FontWeight.w700,
          color: LoopColors.danger,
        ),
      ),
    );
  }
}

/// The owner's own progress card, directly under the record's hero.
///
/// It exists for exactly two states and for exactly one reader. `pending`
/// says when the version under review was submitted and what verification
/// unlocks, so the wait is a wait for something nameable. `rejected` prints
/// the operator's own words in full — the 我创建的 row elides them, this is
/// where they are read — and offers the one command that changes the state.
/// A `verified` application draws nothing: the community is verified, and the
/// record already says so.
///
/// Every other viewer receives no `application` at all (backend decision
/// 0073), so this card cannot be shown to one. It never derives the state
/// from the community's own `verificationStatus`, which is a fact about the
/// community and not about anybody's application.
class CommunityApplicationStatusCard extends StatelessWidget {
  const CommunityApplicationStatusCard({
    required this.review,
    required this.viewer,
    super.key,
    this.busy = false,
    this.onResubmit,
  });

  final CommunityApplicationReview? review;
  final CommunityViewer viewer;
  final bool busy;

  /// Opens the profile edit and, once it is saved, asks for a new review.
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final state = review;
    if (state == null || !viewer.isOwner) return const SizedBox.shrink();
    if (state.isPending) {
      return LoopNotice(
        key: const ValueKey<String>('community-application-pending'),
        icon: 'clock',
        title: '审核中 · 提交于 ${loopLocalTimestampLabel(state.submittedAt)}',
        body: '通过后开放挖矿权重与官方群。运维核验前，这个社区不带验证标记。',
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      );
    }
    if (!state.isRejected) return const SizedBox.shrink();
    final reason = state.rejectedReason?.trim();
    return LoopNotice(
      key: const ValueKey<String>('community-application-rejected'),
      icon: 'warn',
      tone: LoopNoticeTone.danger,
      title: '已驳回',
      body: reason == null || reason.isEmpty
          ? '运维没有给出原因。修改社区资料后可以重新提交。'
          : '原因：$reason',
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      trailing: LoopButton(
        key: const ValueKey<String>('community-application-resubmit'),
        label: '修改资料后重新提交',
        onPressed: busy ? null : onResubmit,
      ),
    );
  }
}

/// One community row. The subtitle only ever carries server-maintained facts.
///
/// It is a function, not a widget, because [LoopRecordGroup] needs the row
/// instances themselves to draw its dividers.
///
/// Its second line is the prototype's (`app-v2.js` `renderRow('community')`:
/// `<div class="row-s">${d.members} 成员 · …</div>`) and the home page's own
/// joined row — the count on the line, the right-hand side left to the
/// chevron. It used to hold 「已验证」 alone while 「312 / 成员」 stood in a
/// two-line value column, which spent a 70pt row on four words and read as a
/// half-empty list (requester, 2026-09-23; decision 0086).
LoopRecordRow communityDirectoryRow({
  required CommunitySummary community,
  required VoidCallback? onTap,
  LoopRowPosition position = LoopRowPosition.single,
  CommunityDirectorySort sort = CommunityDirectorySort.members,
}) {
  final verification = communityVerificationLabel(community.verificationStatus);
  final members = '${community.memberCount} 名成员';
  final ranked = communityDirectoryRowFigure(community, sort: sort);
  if (ranked == null) {
    return LoopRecordRow(
      key: ValueKey<String>('community-row-${community.communityId}'),
      leading: CommunityLogo(
        identity: community.communityId,
        name: community.name,
        logoRef: community.logoRef,
      ),
      title: community.name,
      // The slug is the server's addressing handle; it told a reader browsing
      // the directory nothing 「mock-vol-01」 did not already hide.
      subtitle: '$members · $verification',
      onTap: onTap,
      position: position,
      semanticLabel: '${community.name}，$verification，$members',
    );
  }
  // The column the list is ranked by is the one the value slot states; the
  // member count moves onto the second line so both stay readable.
  return LoopRecordRow(
    key: ValueKey<String>('community-row-${community.communityId}'),
    leading: CommunityLogo(
      identity: community.communityId,
      name: community.name,
      logoRef: community.logoRef,
    ),
    title: community.name,
    subtitle: '$verification · $members',
    trailing: ranked.value,
    trailingCaption: ranked.caption,
    onTap: onTap,
    position: position,
    semanticLabel:
        '${community.name}，$verification，$members，'
        '${ranked.caption}${ranked.semanticValue}',
  );
}

/// The value slot of a ranked discover row, or null when the sort ranks by a
/// column the row already showed.
@immutable
final class CommunityRowFigure {
  const CommunityRowFigure({
    required this.value,
    required this.caption,
    required this.semanticValue,
  });

  /// The mono figure, or 「—」 when the fact behind the order is not there
  /// for this community. It is never a zero: an observed 0 and an absent
  /// number are two different answers.
  final String value;
  final String caption;

  /// What a screen reader hears instead of the mono form.
  final String semanticValue;
}

CommunityRowFigure? communityDirectoryRowFigure(
  CommunitySummary community, {
  required CommunityDirectorySort sort,
}) {
  switch (sort) {
    case CommunityDirectorySort.members:
    case CommunityDirectorySort.newest:
      return null;
    case CommunityDirectorySort.miningPower:
      final fact = community.miningPower;
      return switch (fact) {
        LoopMiningPowerSettled(:final power) => CommunityRowFigure(
          value: loopGroupedFigure(power),
          caption: '算力',
          semanticValue: loopGroupedFigure(power),
        ),
        LoopMiningPowerUnavailable(:final reasonCode) => CommunityRowFigure(
          value: launchMissingFigure,
          caption: '算力',
          semanticValue: communityUnavailableReason(reasonCode),
        ),
        null => const CommunityRowFigure(
          value: launchMissingFigure,
          caption: '算力',
          semanticValue: '暂时读不到',
        ),
      };
    case CommunityDirectorySort.activity:
      final fact = community.activity;
      return switch (fact) {
        // A full page of messages that still began inside the window means
        // more exist than were counted, so the row prints a floor.
        CommunityActivityCount(:final messageCount, :final bounded) =>
          CommunityRowFigure(
            value: bounded ? '≥$messageCount' : '$messageCount',
            caption: '7 天讨论',
            semanticValue: bounded ? '至少 $messageCount 条' : '$messageCount 条',
          ),
        CommunityActivityUnavailable(:final reasonCode) => CommunityRowFigure(
          value: launchMissingFigure,
          caption: '7 天讨论',
          semanticValue: communityUnavailableReason(reasonCode),
        ),
        null => const CommunityRowFigure(
          value: launchMissingFigure,
          caption: '7 天讨论',
          semanticValue: '暂时读不到',
        ),
      };
  }
}

/// Row position inside a group of [length] rows.
LoopRowPosition communityRowPosition(int index, int length) {
  if (length <= 1) return LoopRowPosition.single;
  if (index == 0) return LoopRowPosition.first;
  if (index == length - 1) return LoopRowPosition.last;
  return LoopRowPosition.middle;
}

/// Server observation time, on the reader's own wall clock.
///
/// It used to print UTC while the chat two taps away printed local time for
/// the same instant (device walkthrough 2026-09-23 · chat-forward, members,
/// snapshots). One app, one clock.
String communityObservedAtLabel(DateTime observedAt) =>
    loopLocalTimestampLabel(observedAt);

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

/// Where an applicant goes to watch their own application.
///
/// One sentence, held in one place, because it is said twice: on the sheet
/// that confirms the submission and nowhere else it could drift from.
const String communityApplicationProgressHint = '可以在「我的 → 我的社区 → 我创建的」查看审核进度。';

/// The confirmation an accepted application gets.
///
/// A Toast said 「社区申请已提交，状态为审核中」 and took it away again, and the
/// applicant was left on the directory with no idea where the answer would
/// arrive. This states the same fact and, with it, the one thing the applicant
/// now has to know: where to look. It is a sheet rather than a Toast because
/// it carries an instruction, and an instruction that disappears on its own is
/// not one (decision 0079 §1).
Future<void> showCommunityApplicationSubmittedSheet(
  BuildContext context, {
  required String communityName,
}) async {
  await showLoopSheet<void>(
    context,
    barrierLabel: '关闭确认弹层',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('community-apply-submitted-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '申请已提交 · 审核中',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '「$communityName」已进入审核队列，你是它的所有者。'
            '$communityApplicationProgressHint'
            '通过后才会显示验证标记，并开放挖矿权重与官方群。',
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          const SizedBox(height: 18),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-apply-submitted-open'),
                label: '查看社区',
                primary: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Owner-only community profile edit sheet.
///
/// `slug` and `verificationStatus` are not editable and are shown read-only,
/// so the sheet can never submit a field the server would reject.
Future<CommunityProfileEdit?> showCommunityProfileEditSheet(
  BuildContext context, {
  required CommunitySummary community,
}) {
  return showLoopSheet<CommunityProfileEdit>(
    context,
    barrierLabel: '关闭社区资料编辑',
    builder: (sheetContext) => _CommunityProfileEditForm(community: community),
  );
}

/// The edit sheet's own state.
///
/// The two controllers used to be created beside the sheet and disposed in
/// the future's `whenComplete`, which fires when the route pops — while its
/// exit animation is still rebuilding the fields it owns. A caller that
/// opened a second sheet straight after (修改资料后重新提交) met
/// 「A TextEditingController was used after being disposed」 and a broken
/// frame. The controllers belong to a [State] whose `dispose` runs when the
/// widget is actually gone, which is the same shape the application form has.
class _CommunityProfileEditForm extends StatefulWidget {
  const _CommunityProfileEditForm({required this.community});

  final CommunitySummary community;

  @override
  State<_CommunityProfileEditForm> createState() =>
      _CommunityProfileEditFormState();
}

class _CommunityProfileEditFormState extends State<_CommunityProfileEditForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.community.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.community.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    return Padding(
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
            controller: _name,
            decoration: const InputDecoration(labelText: '社区名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-edit-description'),
            controller: _description,
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
                  final name = _name.text.trim();
                  final description = _description.text.trim();
                  Navigator.of(context).pop(
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
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

  /// The closed set the server accepts, plus "no logo". All twelve are
  /// offered because all twelve now draw a mark; the four the form used to
  /// stop at were the four the local atlas carried.
  static const List<String?> _logoRefs = <String?>[
    null,
    'avatar:preset/community-01',
    'avatar:preset/community-02',
    'avatar:preset/community-03',
    'avatar:preset/community-04',
    'avatar:preset/community-05',
    'avatar:preset/community-06',
    'avatar:preset/community-07',
    'avatar:preset/community-08',
    'avatar:preset/community-09',
    'avatar:preset/community-10',
    'avatar:preset/community-11',
    'avatar:preset/community-12',
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
          Row(
            children: <Widget>[
              const Expanded(child: LoopLabel('社区标识（可留空）')),
              // The chips are numbered, and a number is not a mark: the form
              // shows the one that is selected so the choice is made by
              // looking at it.
              if (_logoRef != null)
                CommunityLogo(
                  key: ValueKey<String>(
                    'community-apply-logo-preview-$_logoRef',
                  ),
                  identity: 'community-apply-preview',
                  name: _name.text,
                  logoRef: _logoRef,
                  size: 36,
                ),
            ],
          ),
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
