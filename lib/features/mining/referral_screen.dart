import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/referral_center_controllers.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart'
    show LoopProfileAvatar;
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart'
    show LoopQrView, loopPosterExportMessage;
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart' show LoopPillAction;
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `referral` · 邀请中心 (S239, decision 0214; formerly Referral Boost).
///
/// archetype `record`, layout `dashboard`. The page reads `GET /v2/referral`
/// and `GET /v2/referral/invitees`, and the referrals board. Top to bottom:
/// the invite code (large, copyable) over the five depths; the invite link
/// with copy / system share and the poster; 我的邀请 counts; the invite
/// boost; the direct invitees; my own inviter. Decision 0243 (需求方
/// 2026-10-23 #01 / #05): how depth is counted, what L1–L5 mean, the
/// mining-power-only rule, the valid-member basis and the binding rules are
/// said once, behind the (i) in the header ([referralInfoNotes]), and the
/// 推广榜 lives on 情报 · 算力榜 only.
/// Everything here is a relationship count or Mining Power — never a
/// commission, a payout or a downline income (user ruling: the only reward is
/// the power boost).
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({
    super.key,
    this.onBack,
    this.initialInviteCode,
    this.onNavigate,
  });

  final VoidCallback? onBack;

  /// A code an invite link (`/i/{code}`) carried in. Once the overview says
  /// the account may still bind, the binding form opens with it filled in;
  /// nothing is submitted without the owner's tap.
  final String? initialInviteCode;

  /// Pushes a location; defaults to the ambient router.
  final ValueChanged<String>? onNavigate;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  bool _offeredLinkCode = false;

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.referral),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(referralControllerProvider);
    final controller = ref.read(referralControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final overview = state.value;
    if (overview != null) _offerLinkCode(overview);

    return LoopDashboardPage(
      key: const ValueKey<String>('referral-screen'),
      onRefresh: _reloadAll,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '邀请中心',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('referral-explain-action'),
          icon: 'info',
          label: '邀请说明',
          onPressed: () => unawaited(_explain(overview)),
        ),
      ],
      // The invite code is the page's one hero: the large code, with the five
      // depths under it in the same card (audit 2026-09-21 §J.11).
      primary: overview == null ? null : _hero(overview),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('referral-capability-unavailable'),
              title: '邀请关系当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (overview == null)
          LaunchStateBlock(
            prefix: 'referral',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到邀请关系',
            emptyReason: '暂时读不到邀请码和邀请人数。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          _InviteActions(overview: overview),
          const LoopLabel('我的邀请'),
          _InviteStats(stats: overview.stats),
          const LoopLabel('邀请加成'),
          if (overview.boostAvailable case final ReferralBoostAvailable boost)
            _BoostCard(boost: boost)
          else if (overview.boost case final LaunchUnavailable boost)
            LaunchUnavailableCard(label: '邀请加成', fact: boost),
          const LoopLabel('邀请列表'),
          _InviteeList(onNavigate: widget.onNavigate),
          const LoopLabel('我的邀请人'),
          _BindingBlock(
            binding: overview.binding,
            busy: state.busy,
            claimed: state.claimed,
            claimFailureKind: state.claimFailureKind,
            claimShapeInvalid: state.claimShapeInvalid,
            onClaim: () => unawaited(_openClaimSheet()),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _hero(ReferralOverview overview) => LoopLedgerComposite(
    key: const ValueKey<String>('referral-hero'),
    primary: LoopFolioPrimary(
      ring: false,
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.record,
      kicker: '我的邀请码',
      heading: overview.inviteCode.code,
      // Decision 0235: the code carries its own copy glyph; 复制邀请码 is no
      // longer a full-width button under it.
      headingBuilder: (heading) => Row(
        children: <Widget>[
          Flexible(
            child: Semantics(
              label: '我的邀请码 ${overview.inviteCode.code}',
              excludeSemantics: true,
              child: KeyedSubtree(
                key: const ValueKey<String>('referral-invite-code'),
                child: heading,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _CopyCodeButton(code: overview.inviteCode.code),
        ],
      ),
      margin: EdgeInsets.zero,
      squareBottom: true,
      // Decision 0243 S293b: with the caption gone the record folio's
      // 178 minimum left a blank band under the code; the card now closes
      // one padding under the code row, as 情报 · 我的邀请码 does.
      minHeight: 0,
    ),
    detail: <Widget>[_LevelBand(levels: overview.levels)],
  );

  Future<void> _reloadAll() async {
    await Future.wait(<Future<void>>[
      ref.read(referralControllerProvider.notifier).reload(),
      ref.read(referralInviteesControllerProvider.notifier).reload(),
    ]);
  }

  /// The code an invite link carried, offered once: the binding form opens
  /// with it filled in while the account may still bind; otherwise the page
  /// says why the code cannot be used, and nothing is sent.
  void _offerLinkCode(ReferralOverview overview) {
    final code = widget.initialInviteCode;
    if (code == null || _offeredLinkCode) return;
    _offeredLinkCode = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (overview.binding.canClaim) {
        unawaited(_openClaimSheet(initialCode: code));
      } else {
        LoopToast.show(
          context,
          message: overview.binding.isBound
              ? '这个账号已经绑定过邀请人，邀请链接里的 $code 不会再绑定'
              : '这个账号现在不能绑定邀请码，邀请链接里的 $code 没有提交',
          kind: LoopToastKind.warn,
        );
      }
    });
  }

  Future<void> _openClaimSheet({String? initialCode}) async {
    final code = await showLoopSheet<String>(
      context,
      barrierLabel: '关闭绑定邀请码',
      builder: (sheetContext) => _ClaimForm(initialCode: initialCode),
    );
    if (code == null || !mounted) return;
    await ref.read(referralControllerProvider.notifier).claim(code);
    if (!mounted) return;
    final state = ref.read(referralControllerProvider);
    // A success Toast only after the server confirmed the binding.
    if (state.claimed) {
      LoopToast.show(context, message: '邀请码已绑定', kind: LoopToastKind.ok);
    }
  }

  Future<void> _explain(ReferralOverview? overview) => showLoopInfoSheet(
    context,
    title: '邀请说明',
    notes: referralInfoNotes(overview),
    sheetKey: 'referral-explain-sheet',
  );
}

/// 情报 · 邀请中心 chip (S239, decision 0214): my invite code, copy / link /
/// poster, 我的邀请 counts, and the way into the full page — drawn over the
/// 推广榜 under the same chips. It reads the same overview as the page.
class ReferralCenterCard extends ConsumerStatefulWidget {
  const ReferralCenterCard({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<ReferralCenterCard> createState() => _ReferralCenterCardState();
}

class _ReferralCenterCardState extends ConsumerState<ReferralCenterCard> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.referral),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(referralControllerProvider);
    final controller = ref.read(referralControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final overview = state.value;
    final Widget body;
    if (blocked) {
      body = LoopInlineUnavailable(
        key: const ValueKey<String>('intel-referral-center-unavailable'),
        icon: 'users',
        message: '邀请关系当前不可用',
        detail: launchReasonCodeText(
          capability.reasonCode ?? 'CAPABILITY_UNAVAILABLE',
        ),
      );
    } else if (overview == null) {
      body = LaunchStateBlock(
        prefix: 'intel-referral-center',
        phase: state.phase,
        failureKind: state.failureKind,
        skeleton: LoopSkeletonType.record,
        rows: 2,
        emptyMessage: '没有读到邀请码',
        emptyReason: '暂时读不到邀请码和邀请人数。',
        onRetry: () => unawaited(controller.reload()),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _InviteCodeBlock(code: overview.inviteCode.code),
          const SizedBox(height: LoopSpacing.rowGap),
          _InviteActions(overview: overview),
          const SizedBox(height: LoopSpacing.rowGap),
          _InviteStats(stats: overview.stats),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('intel-referral-open'),
                leading: const LoopRowIcon(icon: 'users'),
                title: '打开邀请中心',
                subtitle: '邀请列表、邀请加成和我的邀请人',
                onTap: () => widget.onNavigate(referralCenterPath),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey<String>('intel-referral-center'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Decision 0243 (需求方 2026-10-23 #03): the mining-power-only rule
        // and the valid-member basis are behind this (i), not under the code
        // and the counts.
        LoopInfoLabel(
          '我的邀请',
          info: LoopInfoButton(
            key: const ValueKey<String>('intel-referral-info'),
            title: '邀请说明',
            label: '邀请说明',
            notes: referralInfoNotes(overview),
            sheetKey: 'intel-referral-info-sheet',
          ),
        ),
        body,
      ],
    );
  }
}

/// The `referral` route (manifest slug `referral`).
const String referralCenterPath = '/profile/referral';

/// What the (i) on 邀请中心 and on 情报 · 我的邀请 says (decision 0243,
/// 需求方 2026-10-23 #01 / #03 / #05): one heading per fact, read from the
/// same overview the page draws. Without an overview it says the rules in
/// words and leaves the server's figures out rather than guessing them.
List<LoopInfoNote> referralInfoNotes(ReferralOverview? overview) {
  final rules = overview?.rules;
  final stats = overview?.stats;
  final levels = overview?.levels ?? const <ReferralLevel>[];
  final asOf = stats?.validAsOf;
  return <LoopInfoNote>[
    const LoopInfoNote(
      key: ValueKey<String>('referral-info-mining-only'),
      title: '只计入挖矿算力',
      body: '邀请加成只计入挖矿算力，不是收入、佣金或返佣。',
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-relationship'),
      title: '关系怎样成立',
      body:
          '每个账号只有一个邀请码。分享完成不代表关系成立，还需要验证；'
          '「有效」只统计已验证的关系，其余一律显示为待验证，不计入任何加成。'
          '${overview == null ? '' : '\n当前 ${overview.validRelationships} 个有效关系 · '
                    '${overview.pendingRelationships} 个待验证。'}',
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-depth'),
      title: '关系深度如何计算',
      body:
          '你直接邀请并已验证的人是 L1，L1 再邀请的人是 L2，依此类推'
          '${rules == null ? '' : '，最深到 L${rules.maximumDepth}'}。'
          '每一级的加成比例以服务端公布的为准，只按该级的有效关系计入。',
    ),
    for (final level in levels)
      LoopInfoNote(
        key: ValueKey<String>('referral-level-${level.level}'),
        title: 'L${level.level} · 加成 ${level.boostPercent}%',
        body: referralLevelDescription(level.level),
      ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-valid-member'),
      title: '有效成员',
      body:
          '被邀请人本人在最近一个结算小时有算力，才算有效成员。'
          '${stats == null
              ? ''
              : asOf == null
              ? '\n还没有结算过的小时，有效成员暂为 0。'
              : '\n当前数字截至 ${launchTimestampLabel(asOf)}。'}',
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-binding'),
      title: '绑定邀请码',
      body:
          '被邀请人激活 LOOP ID 后随时可以绑定；一个账号只能绑定一次，关系锁定后不可更换。'
          '不能绑定自己的邀请码，也不能绑定自己下级的邀请码。',
    ),
    if (rules != null)
      LoopInfoNote(
        key: const ValueKey<String>('referral-info-rules'),
        title: '规则版本',
        body:
            '生效于 ${launchTimestampLabel(rules.effectiveAt)} · '
            '最大深度 L${rules.maximumDepth} · '
            '作用于${rules.appliesTo == 'miningPower' ? '挖矿算力' : ' ${rules.appliesTo}'}',
      ),
  ];
}

/// One block of 我的邀请 (decision 0235): the raised `card2` ground with a
/// hairline, so the code, the link and the counts read as three separate
/// pieces on the Ink page instead of one dark run.
class _InviteBlock extends StatelessWidget {
  const _InviteBlock({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.card,
      12,
      LoopSpacing.tight,
      12,
    ),
    decoration: BoxDecoration(
      color: LoopColors.card2,
      borderRadius: LoopRadius.card,
      border: Border.all(color: LoopColors.line),
    ),
    child: child,
  );
}

/// The copy glyph beside the invite code (decision 0235).
class _CopyCodeButton extends StatelessWidget {
  const _CopyCodeButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => LoopIconButton(
    key: const ValueKey<String>('referral-copy-code'),
    icon: 'copy',
    label: '复制邀请码',
    onPressed: () => unawaited(LoopCopy.text(context, code, message: '邀请码已复制')),
  );
}

/// 情报 · 我的邀请码: the code large with its copy glyph. The sentence that
/// stood under it is in the (i) beside 我的邀请 (decision 0243).
class _InviteCodeBlock extends StatelessWidget {
  const _InviteCodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => _InviteBlock(
    key: const ValueKey<String>('intel-referral-code'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                label: '我的邀请码 $code',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '我的邀请码',
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.keyFigure.copyWith(
                        color: LoopColors.yellow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _CopyCodeButton(code: code),
          ],
        ),
      ],
    ),
  );
}

/// 邀请链接 (decision 0235): the link on one line, middle-elided, with copy
/// and system share as glyphs; 生成海报 is a small action in the block's
/// heading. Without a link the block says so and the poster still opens
/// (code only).
class _InviteActions extends ConsumerWidget {
  const _InviteActions({required this.overview});

  final ReferralOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = overview.inviteCode.code;
    final link = overview.inviteLink;
    return _InviteBlock(
      key: const ValueKey<String>('referral-link-block'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '邀请链接',
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ),
              LoopPillAction(
                key: const ValueKey<String>('referral-poster'),
                label: '生成海报',
                soft: true,
                onPressed: () => unawaited(
                  showLoopSheet<void>(
                    context,
                    barrierLabel: '关闭邀请海报',
                    useRootNavigator: true,
                    builder: (sheetContext) =>
                        ReferralPosterSheet(code: code, link: link),
                  ),
                ),
              ),
            ],
          ),
          if (link == null)
            Padding(
              key: const ValueKey<String>('referral-link-absent'),
              padding: const EdgeInsets.only(
                right: LoopSpacing.tight,
                bottom: 4,
              ),
              child: Text(
                '邀请链接还没有开放，先把邀请码发给好友；对方激活 LOOP ID 后随时可以填写。',
                style: LoopType.captionSm,
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    label: '邀请链接 $link',
                    excludeSemantics: true,
                    // The scheme is dropped on screen only; copy and share
                    // carry the full link.
                    child: _MiddleEllipsisText(
                      link.replaceFirst(RegExp(r'^https?://'), ''),
                      key: const ValueKey<String>('referral-invite-link'),
                      style: LoopType.code.copyWith(color: LoopColors.chalk),
                    ),
                  ),
                ),
                LoopIconButton(
                  key: const ValueKey<String>('referral-copy-link'),
                  icon: 'copy',
                  label: '复制邀请链接',
                  onPressed: () => unawaited(
                    LoopCopy.text(context, link, message: '邀请链接已复制'),
                  ),
                ),
                LoopIconButton(
                  key: const ValueKey<String>('referral-share-link'),
                  icon: 'share',
                  label: '分享邀请链接',
                  onPressed: () => unawaited(_share(context, ref, code, link)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    String code,
    String link,
  ) async {
    final shown = await ref.read(loopTextShareProvider)(
      referralInviteText(code, link),
      subject: '邀请你加入 LOOP',
    );
    if (!shown && context.mounted) {
      LoopToast.show(
        context,
        message: '系统分享没有打开，可以先复制链接',
        kind: LoopToastKind.warn,
      );
    }
  }
}

/// The text 「分享邀请链接」 hands to the system sheet.
String referralInviteText(String code, String? link) => link == null
    ? '来 LOOP 一起挖矿，注册后填写我的邀请码 $code'
    : '来 LOOP 一起挖矿，注册后填写我的邀请码 $code\n$link';

/// 我的邀请: direct / valid / depth 2–5 — three equal cells on one raised
/// block, the name small above the figure (decision 0235). Without the
/// server's `stats` every figure is the dash and the page says the counts are
/// not open yet. Decision 0243: the valid-member basis and the hour it was
/// read at are in the (i) ([referralInfoNotes]), not under the counts.
class _InviteStats extends StatelessWidget {
  const _InviteStats({required this.stats});

  final ReferralStats? stats;

  @override
  Widget build(BuildContext context) {
    final value = stats;
    return Column(
      key: const ValueKey<String>('referral-stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InviteBlock(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StatCell(
                  valueKey: const ValueKey<String>('referral-stats-direct'),
                  label: '直接邀请',
                  value: value == null
                      ? loopFigureDash
                      : '${value.directCount}',
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: LoopColors.line,
                ),
                _StatCell(
                  valueKey: const ValueKey<String>('referral-stats-valid'),
                  label: '有效成员',
                  value: value == null ? loopFigureDash : '${value.validCount}',
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: LoopColors.line,
                ),
                _StatCell(
                  valueKey: const ValueKey<String>('referral-stats-deep'),
                  label: '二至五级',
                  value: value == null
                      ? loopFigureDash
                      : '${value.level2to5Count}',
                ),
              ],
            ),
          ),
        ),
        // Fail closed: counts that are not open say so on the page.
        if (value == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              LoopSpacing.tight,
              LoopSpacing.page,
              0,
            ),
            child: Text(
              '邀请统计还没有开放，开放后显示在这里。',
              key: const ValueKey<String>('referral-stats-note'),
              style: LoopType.captionSm.copyWith(color: LoopColors.text2),
            ),
          ),
      ],
    );
  }
}

/// One 我的邀请 count: the name above, the figure under it.
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.valueKey,
    required this.label,
    required this.value,
  });

  final Key valueKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.captionSm.copyWith(color: LoopColors.text2),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              key: valueKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.statFigure.copyWith(color: LoopColors.chalk),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One line of text that keeps its start and its end and drops the middle
/// for 「…」 when it does not fit (decision 0235: the invite link keeps the
/// host and the code it ends with). Never wraps.
class _MiddleEllipsisText extends StatelessWidget {
  const _MiddleEllipsisText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  /// The text as drawn: [text] itself when it fits [maxWidth], otherwise
  /// its head, 「…」 and its tail — the tail a little longer than the head.
  static String fit(
    String text,
    TextStyle style,
    double maxWidth,
    TextScaler scaler,
  ) {
    bool fits(String candidate) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width <= maxWidth;
    }

    if (!maxWidth.isFinite || fits(text)) return text;
    String elide(int keep) {
      final head = (keep * 0.4).floor();
      final tail = keep - head;
      return '${text.substring(0, head)}…'
          '${text.substring(text.length - tail)}';
    }

    var low = 0;
    var high = text.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits(elide(mid))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return elide(low);
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        fit(text, style, constraints.maxWidth, scaler),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// The available boost (loop-api decision 0162 §B.2): the newest settled
/// hour's referral power and each depth's effective members. Mining Power,
/// not money; every figure is the server's own string.
class _BoostCard extends StatelessWidget {
  const _BoostCard({required this.boost});

  final ReferralBoostAvailable boost;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('referral-boost-available'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('referral-boost-total'),
              title: '最近结算小时的邀请加成',
              subtitle:
                  'NFT ${loopPowerFigure(boost.nftReferralPower)} · '
                  '资产 ${loopPowerFigure(boost.assetReferralPower)}',
              trailing: loopPowerFigure(boost.referralPower),
              trailingCaption: '算力',
              trailingStrong: true,
              trailingColor: LoopColors.yellow,
              chevron: false,
              position: LoopRowPosition.first,
            ),
            for (var index = 0; index < boost.levels.length; index += 1)
              LoopRecordRow(
                key: ValueKey<String>(
                  'referral-boost-level-${boost.levels[index].level}',
                ),
                title:
                    'L${boost.levels[index].level} · '
                    '有效成员 ${boost.levels[index].effectiveMembers} 人',
                subtitle:
                    'NFT ${loopPowerFigure(boost.levels[index].nftPower)} · '
                    '资产 ${loopPowerFigure(boost.levels[index].assetPower)}',
                chevron: false,
                position: index == boost.levels.length - 1
                    ? LoopRowPosition.last
                    : LoopRowPosition.middle,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '结算小时 ${launchTimestampLabel(boost.hourStart)} – '
            '${launchTimestampLabel(boost.hourEnd)}',
            style: LoopType.captionSm.copyWith(color: LoopColors.text2),
          ),
        ),
      ],
    );
  }
}

/// 邀请列表: direct invitees, newest binding first, read page by page.
class _InviteeList extends ConsumerStatefulWidget {
  const _InviteeList({this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  ConsumerState<_InviteeList> createState() => _InviteeListState();
}

class _InviteeListState extends ConsumerState<_InviteeList> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralInviteesControllerProvider);
    final controller = ref.read(referralInviteesControllerProvider.notifier);
    if (state.phase == LaunchViewPhase.loading && !state.hasRead) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    if (!state.hasRead) {
      return LaunchStateBlock(
        prefix: 'referral-invitees',
        phase: state.phase,
        failureKind: state.failureKind,
        skeleton: LoopSkeletonType.record,
        rows: 3,
        emptyMessage: '还没有邀请到好友',
        emptyReason: '好友用你的邀请码绑定后，会出现在这里。',
        onRetry: () => unawaited(controller.reload()),
      );
    }
    final items = state.items;
    if (items.isEmpty) {
      return const LoopInlineUnavailable(
        key: ValueKey<String>('referral-invitees-empty'),
        icon: 'users',
        message: '还没有邀请到好友',
        detail: '好友用你的邀请码绑定后，会出现在这里。',
      );
    }
    return Column(
      key: const ValueKey<String>('referral-invitees'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 0; index < items.length; index += 1)
              _row(items[index], index, items.length),
          ],
        ),
        LoopLoadMoreFooter(
          key: const ValueKey<String>('referral-invitees-footer'),
          keyPrefix: 'referral-invitees',
          cursor: state.nextCursor,
          canLoadMore: !state.loadingMore && !state.refreshing,
          loading: state.loadingMore,
          onLoadMore: controller.loadMore,
        ),
      ],
    );
  }

  LoopRecordRow _row(ReferralInvitee invitee, int index, int length) {
    final name = invitee.alias ?? '未公开的成员';
    final id = invitee.publicProfileId;
    final location = loopProfileFaceLocation(id);
    void open(String target) {
      final navigate = widget.onNavigate;
      if (navigate != null) {
        navigate(target);
      } else {
        LoopProfileFaceLink.push(context, target);
      }
    }

    return LoopRecordRow(
      key: ValueKey<String>('referral-invitee-$index'),
      leading: LoopProfileFaceLink(
        key: ValueKey<String>('referral-invitee-face-$index'),
        publicProfileId: id,
        name: name,
        onOpen: open,
        child: LoopProfileAvatar(
          avatarRef: invitee.avatarRef,
          alias: invitee.alias,
          size: 36,
        ),
      ),
      title: name,
      subtitle: '加入于 ${launchTimestampLabel(invitee.boundAt)}',
      trailingBadge: LoopBadge(
        referralInviteeStatusLabel(invitee.status),
        kind: switch (invitee.status) {
          ReferralInviteeStatus.valid => LoopBadgeKind.up,
          ReferralInviteeStatus.pending => LoopBadgeKind.mute,
          ReferralInviteeStatus.invalid => LoopBadgeKind.down,
        },
      ),
      chevron: location != null,
      onTap: location == null ? null : () => open(location),
      position: launchRowPosition(index, length),
      semanticLabel:
          '$name，加入于 ${launchTimestampLabel(invitee.boundAt)}，'
          '${referralInviteeStatusLabel(invitee.status)}',
    );
  }
}

/// 生成海报: the invite poster, drawn in the sheet exactly as it is
/// exported (1080 × 1920), then handed to the system share sheet, where the
/// owner may save it to the photo library. Nothing is uploaded or kept.
class ReferralPosterSheet extends ConsumerStatefulWidget {
  const ReferralPosterSheet({required this.code, this.link, super.key});

  final String code;
  final String? link;

  @override
  ConsumerState<ReferralPosterSheet> createState() =>
      _ReferralPosterSheetState();
}

class _ReferralPosterSheetState extends ConsumerState<ReferralPosterSheet> {
  final GlobalKey _posterKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final qr = link == null ? null : LoopQrCode.encode(link);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final posterHeight = (screenHeight * 0.55).clamp(320.0, 520.0);
    return Column(
      key: const ValueKey<String>('referral-poster-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSheetHeading('邀请海报'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: SizedBox(
                  height: posterHeight,
                  width: posterHeight * ReferralPoster.aspectRatio,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: ReferralPoster(code: widget.code, qr: qr),
                    ),
                  ),
                ),
              ),
              if (qr == null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '邀请链接还没有开放，海报上只印邀请码。',
                    key: const ValueKey<String>('referral-poster-no-link'),
                    style: LoopType.captionSm,
                  ),
                ),
              const SizedBox(height: 12),
              LoopButtonPair(
                padded: false,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('referral-poster-share'),
                    label: _exporting ? '正在生成…' : '保存或分享海报',
                    primary: true,
                    onPressed: _exporting ? null : () => unawaited(_export()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final sink = ref.read(chatMergeExportSinkProvider);
    ChatMergeExportOutcome outcome;
    try {
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      final bytes = boundary == null ? null : await _encode(boundary);
      outcome = bytes == null
          ? ChatMergeExportOutcome.failed
          : await sink.shareImage(
              pngBytes: bytes,
              fileName: 'loop-invite-${widget.code}.png',
            );
    } catch (_) {
      outcome = ChatMergeExportOutcome.failed;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    LoopToast.show(
      context,
      message: loopPosterExportMessage(outcome),
      kind: outcome == ChatMergeExportOutcome.shared
          ? LoopToastKind.ok
          : LoopToastKind.warn,
    );
  }

  static Future<Uint8List?> _encode(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(
      pixelRatio: ReferralPoster.exportPixelRatio,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// The invite poster: Ink ground, the LOOP mark, the invite code, and — when
/// the server sent a link — a QR code to it on a Chalk plate. Laid out at
/// 360 × 640 and exported at three times that, 1080 × 1920.
class ReferralPoster extends StatelessWidget {
  const ReferralPoster({required this.code, required this.qr, super.key});

  final String code;
  final LoopQrCode? qr;

  static const double width = 360;
  static const double height = 640;
  static const double aspectRatio = width / height;
  static const double exportPixelRatio = 3;

  @override
  Widget build(BuildContext context) {
    final symbol = qr;
    return Semantics(
      key: const ValueKey<String>('referral-poster'),
      container: true,
      label: 'LOOP 邀请海报，邀请码 $code',
      child: DefaultTextStyle(
        style: LoopType.body,
        child: Container(
          width: width,
          height: height,
          color: LoopColors.ink,
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: LoopBrandMark(
                  key: ValueKey<String>('referral-poster-mark'),
                  kind: LoopBrandMarkKind.wordmark,
                  height: 32,
                ),
              ),
              const SizedBox(height: 36),
              Text('邀请你加入 LOOP', style: LoopType.headingLg),
              const SizedBox(height: 8),
              Text(
                '注册后随时可以填写邀请码，一起挖矿。',
                style: LoopType.bodySm.copyWith(color: LoopColors.text2),
              ),
              const Spacer(),
              if (symbol != null)
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LoopColors.chalk,
                      borderRadius: BorderRadius.circular(LoopRadius.cardValue),
                    ),
                    child: LoopQrView(
                      key: const ValueKey<String>('referral-poster-qr'),
                      code: symbol,
                      semanticLabel: '邀请链接二维码',
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '邀请码',
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
              const SizedBox(height: 6),
              Text(
                code,
                key: const ValueKey<String>('referral-poster-code'),
                style: LoopType.keyFigure.copyWith(color: LoopColors.yellow),
              ),
              const SizedBox(height: 12),
              Text(
                symbol == null ? '在 LOOP 注册后填写邀请码' : '扫码打开邀请页',
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.ledger-card > grid-template-columns:repeat(5,…)`: the five depths side
/// by side inside the hero, each with its boost and its own verified count.
class _LevelBand extends StatelessWidget {
  const _LevelBand({required this.levels});

  final List<ReferralLevel> levels;

  @override
  Widget build(BuildContext context) {
    // The five cells carry the same two lines, so they come out the same
    // height; `stretch` here would ask for a height the strip does not have.
    return Row(
      key: const ValueKey<String>('referral-levels'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < levels.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 5),
          Expanded(child: _LevelCell(level: levels[index])),
        ],
      ],
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.level});

  final ReferralLevel level;

  @override
  Widget build(BuildContext context) {
    // The prototype fills the current depth and tints the rest.
    final current = level.level == 1;
    return Semantics(
      container: true,
      label:
          'L${level.level}，加成 ${level.boostPercent}%，'
          '有效关系 ${level.counts.valid}，待验证 ${level.counts.pending}',
      child: ExcludeSemantics(
        // Decision 0222: the current depth is a solid Purple choice, so it
        // wears the splat.
        child: _splatIf(
          current,
          Container(
            key: ValueKey<String>('referral-level-cell-${level.level}'),
            padding: const EdgeInsets.fromLTRB(7, 9, 7, 9),
            // Decision 0210 / S241b: the current depth is a selected cell —
            // purple 9 % ground behind a purple edge, yellow figures — not a
            // yellow slab; the other depths are flat outlined cells.
            // Decision 0211: filled tiles with a 10 radius, no edge.
            decoration: BoxDecoration(
              color: current ? LoopColors.purpleSelected : LoopColors.card2,
              borderRadius: LoopRadius.tile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // S249: a narrow cell scales the label down rather than
                // clipping 「L1 · 10%」.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'L${level.level} · ${level.boostPercent}%',
                    maxLines: 1,
                    softWrap: false,
                    // R13 / R12, the steps `LoopStatGrid` draws (decision
                    // 0192); the five-across strip is not a two-column grid,
                    // so the cell stays local.
                    style: LoopType.kicker.copyWith(
                      color: current ? LoopColors.onPurple : LoopColors.text2,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${level.counts.valid}',
                  maxLines: 1,
                  style: LoopType.figure.copyWith(
                    color: current ? LoopColors.yellow : LoopColors.chalk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _splatIf(bool chosen, Widget cell) =>
      chosen ? loopSplatted(cell) : cell;
}

class _BindingBlock extends StatelessWidget {
  const _BindingBlock({
    required this.binding,
    required this.busy,
    required this.claimed,
    required this.claimFailureKind,
    required this.claimShapeInvalid,
    required this.onClaim,
  });

  final ReferralBinding binding;
  final bool busy;
  final bool claimed;
  final LaunchFailureKind? claimFailureKind;
  final bool claimShapeInvalid;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final inviter = binding.inviter;
    // Decision 0243 (需求方 2026-10-23 #05): one 绑定邀请码 button. While the
    // window is open it is the only thing here; the window, the one-binding
    // rule and the rule version are in the (i). Whenever it cannot be used it
    // stays, disabled, with one short line under it saying why.
    final String? blockedLine = binding.canClaim
        ? null
        : binding.isBound || inviter != null
        ? '已绑定邀请人，关系锁定后不能更换'
        : switch (binding.claimWindow) {
            ReferralClaimWindowUnavailable(:final reasonCode) =>
              '还不能绑定：${launchReasonCodeText(reasonCode)}',
            ReferralClaimWindowTimed() => '当前不能绑定邀请码，请稍后刷新再试',
          };
    final String blockedKey = binding.isBound || inviter != null
        ? 'referral-claim-bound-note'
        : switch (binding.claimWindow) {
            ReferralClaimWindowUnavailable() => 'referral-claim-unavailable',
            ReferralClaimWindowTimed() => 'referral-claim-closed',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (inviter != null)
          LoopRecordGroup(
            key: const ValueKey<String>('referral-bound'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('referral-bound-row'),
                title: '已绑定邀请人',
                // Never the inviter's identity: only depth and state.
                subtitle:
                    '深度 L${inviter.depth} · '
                    '${referralValidationStatusLabel(inviter.validationStatus)} · '
                    '锁定于 ${launchTimestampLabel(inviter.lockedAt)}',
              ),
            ],
          ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('referral-claim'),
              label: '绑定邀请码',
              primary: true,
              onPressed: blockedLine != null || busy ? null : onClaim,
            ),
          ],
        ),
        if (blockedLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              LoopSpacing.tight,
              LoopSpacing.page,
              0,
            ),
            child: Text(
              blockedLine,
              key: ValueKey<String>(blockedKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LoopType.captionSm.copyWith(color: LoopColors.text2),
            ),
          ),
        if (claimShapeInvalid)
          const LoopNotice(
            key: ValueKey<String>('referral-claim-shape-invalid'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '邀请码格式不对',
            body: '邀请码形如 LOOP- 加 5 位字符。格式明显不对时不会提交，以免浪费唯一的一次绑定机会。',
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
        if (claimFailureKind != null)
          LoopNotice(
            key: const ValueKey<String>('referral-claim-failure'),
            icon: 'warn',
            tone: LoopNoticeTone.danger,
            title: '这次绑定没有完成',
            body: referralClaimFailureReason(claimFailureKind),
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
        if (claimed)
          const LoopNotice(
            key: ValueKey<String>('referral-claim-success'),
            icon: 'check',
            title: '关系已锁定',
            body: '这条关系已确认。绑定后不能更换。',
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
      ],
    );
  }
}

/// The binding form. The shape check runs locally so an obviously malformed
/// code never spends the account's single binding attempt.
class _ClaimForm extends StatefulWidget {
  const _ClaimForm({this.initialCode});

  /// Filled in from an invite link; the owner still taps 绑定.
  final String? initialCode;

  @override
  State<_ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends State<_ClaimForm> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode ?? '',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _code.text;
    if (!isReferralInviteCodeShaped(raw)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(normaliseReferralInviteCode(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('referral-claim-sheet'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const LoopSheetHeading('绑定邀请码'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '一个账号只能绑定一次，关系锁定后不可更换。不能绑定自己的邀请码，也不能绑定自己下级的邀请码。',
                  style: LoopType.bodySm,
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey<String>('referral-claim-input'),
                  controller: _code,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '邀请码（形如 LOOP-XXXXX）',
                    errorText: _invalid ? '邀请码格式不对，请检查后再试。' : null,
                  ),
                ),
                const SizedBox(height: 16),
                LoopButtonPair(
                  padded: false,
                  children: <Widget>[
                    LoopButton(
                      key: const ValueKey<String>('referral-claim-submit'),
                      label: '绑定',
                      primary: true,
                      onPressed: _submit,
                    ),
                    LoopButton(
                      key: const ValueKey<String>('referral-claim-cancel'),
                      label: '取消',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
