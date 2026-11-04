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
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Re-reads the overview and the invitees together (pull-to-refresh).
Future<void> reloadReferralCenter(WidgetRef ref) async {
  await Future.wait(<Future<void>>[
    ref.read(referralControllerProvider.notifier).reload(),
    ref.read(referralInviteesControllerProvider.notifier).reload(),
  ]);
}

/// 邀请中心's content as a run of sections (decision 0272, S348): the invite
/// card, then two side-by-side tabs — 邀请列表 and 邀请加成 — and 我的邀请人
/// at the foot. Drawn by 情报 · 算力's 邀请 tab.
class ReferralCenterSections extends ConsumerStatefulWidget {
  const ReferralCenterSections({
    super.key,
    this.initialInviteCode,
    this.onNavigate,
    this.info,
    this.onOfferedInviteCode,
    this.initialTab = ReferralCenterTab.invitees,
  });

  /// The tab under the invite card the sections open on.
  final ReferralCenterTab initialTab;

  /// A code an invite link (`/i/{code}`) carried in. Once the overview says
  /// the account may still bind, the binding form opens with it filled in;
  /// nothing is submitted without the owner's tap.
  final String? initialInviteCode;

  /// Pushes a location; defaults to the ambient router.
  final ValueChanged<String>? onNavigate;

  /// The (i) beside the first heading, when the host has no bar to carry it.
  final Widget? info;

  /// Called once [initialInviteCode] has been offered, so a host that holds
  /// the code can let it go.
  final VoidCallback? onOfferedInviteCode;

  @override
  ConsumerState<ReferralCenterSections> createState() =>
      _ReferralCenterSectionsState();
}

/// The two tabs under the invite card (S348).
enum ReferralCenterTab {
  invitees('邀请列表'),
  boost('邀请加成');

  const ReferralCenterTab(this.label);

  final String label;
}

class _ReferralCenterSectionsState
    extends ConsumerState<ReferralCenterSections> {
  String? _offeredCode;
  late ReferralCenterTab _tab = widget.initialTab;

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
    final info = widget.info;
    final children = <Widget>[
      if (blocked)
        LoopInlineUnavailable(
          key: const ValueKey<String>('referral-capability-inline'),
          icon: 'users',
          message: '邀请关系当前不可用',
          detail: launchReasonCodeText(
            capability.reasonCode ?? 'CAPABILITY_UNAVAILABLE',
          ),
        )
      else if (overview == null)
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
        // UX-012 (decision 0257): the hero is the one invite card — the
        // code and the link, each with its own copy glyph, and 分享邀请链接 /
        // 生成海报. S348: the five depths moved into 邀请加成.
        LoopLedgerComposite(
          key: const ValueKey<String>('referral-hero'),
          primary: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _InviteCardBody(
              overview: overview,
              codeKey: const ValueKey<String>('referral-invite-code'),
            ),
          ),
          detail: const <Widget>[],
        ),
        Row(
          children: <Widget>[
            Expanded(
              // S350b · decision 0275: the filter step under 代币 / NFT / 邀请
              // — 32 high framed chips, not a second row of 36 capsules.
              child: ReferralSubTabs(
                key: const ValueKey<String>('referral-tabs'),
                labels: <String>[
                  for (final tab in ReferralCenterTab.values) tab.label,
                ],
                selectedIndex: _tab.index,
                onSelected: (index) =>
                    setState(() => _tab = ReferralCenterTab.values[index]),
              ),
            ),
            if (info != null)
              Padding(padding: const EdgeInsets.only(right: 4), child: info),
          ],
        ),
        KeyedSubtree(
          key: ValueKey<String>('referral-tab-${_tab.name}'),
          child: switch (_tab) {
            ReferralCenterTab.invitees => _InviteeList(
              onNavigate: widget.onNavigate,
            ),
            ReferralCenterTab.boost => ReferralBoostPanel(
              boost: overview.boostAvailable,
              levels: overview.levels,
            ),
          },
        ),
        const LoopLabel('我的邀请人'),
        _BindingBlock(
          binding: overview.binding,
          busy: state.busy,
          claimed: state.claimed,
          claimFailureKind: state.claimFailureKind,
          claimShapeInvalid: state.claimShapeInvalid,
          onClaim: () => unawaited(_openClaimSheet()),
        ),
      ],
    ];
    return Column(
      key: const ValueKey<String>('referral-center-sections'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// The code an invite link carried, offered once: the binding form opens
  /// with it filled in while the account may still bind; otherwise the page
  /// says why the code cannot be used, and nothing is sent.
  void _offerLinkCode(ReferralOverview overview) {
    final code = widget.initialInviteCode;
    if (code == null) {
      _offeredCode = null;
      return;
    }
    if (_offeredCode == code) return;
    _offeredCode = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onOfferedInviteCode?.call();
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
}

/// The tabs inside 邀请 (S350b · decision 0275): 邀请列表 / 邀请加成 one level
/// under the page's 代币 / NFT / 邀请 capsules — the App's filter step
/// (S350c): 32 high framed chips with the 14 word, the chosen one solid
/// Purple with its splat, 8 apart, 16 under the block above.
class ReferralSubTabs extends StatelessWidget {
  const ReferralSubTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// The drawn height of a filter chip (S350c's `WalletAssetTabs`).
  static const double filterHeight = 32;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.segmentGap - (LoopSeg.segmentTarget - filterHeight) / 2,
      0,
      0,
    ),
    child: Row(
      children: <Widget>[
        for (var index = 0; index < labels.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: LoopSpacing.tight),
          LoopSeg(
            label: labels[index],
            selected: index == selectedIndex,
            capsuleHeight: filterHeight,
            onSelected: () => onSelected(index),
          ),
        ],
      ],
    ),
  );
}

/// The `referral` route (manifest slug `referral`). Decision 0272: it
/// forwards to 情报 · 算力 · 邀请.
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

/// How long a copy glyph shows its tick before it turns back (UX-012,
/// decision 0257).
const Duration referralCopiedHold = Duration(seconds: 3);

/// A small copy glyph that answers its own tap (UX-012, decision 0257):
/// besides the toast, the glyph turns into a tick for [referralCopiedHold]
/// and then back. The timer dies with the glyph.
class ReferralCopyGlyph extends StatefulWidget {
  const ReferralCopyGlyph({
    required this.text,
    required this.label,
    required this.message,
    super.key,
  });

  final String text;
  final String label;
  final String message;

  @override
  State<ReferralCopyGlyph> createState() => _ReferralCopyGlyphState();
}

class _ReferralCopyGlyphState extends State<ReferralCopyGlyph> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await LoopCopy.text(context, widget.text, message: widget.message);
    if (!mounted) return;
    _reset?.cancel();
    setState(() => _copied = true);
    _reset = Timer(referralCopiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => LoopIconButton(
    icon: _copied ? 'check' : 'copy',
    label: _copied ? '已复制' : widget.label,
    color: _copied ? LoopColors.yellow : null,
    onPressed: () => unawaited(_copy()),
  );
}

/// 我的邀请 as one card (UX-012, decision 0257): the invite code on one line
/// and the invite link on the next, each with its own small copy glyph, and
/// under them 分享邀请链接 (primary) beside 生成海报 (secondary). The
/// separate 复制邀请码 control is gone. Without a link the card says so and
/// the poster still opens (code only).
class _InviteCardBody extends ConsumerWidget {
  const _InviteCardBody({required this.overview, this.codeKey});

  final ReferralOverview overview;

  /// The key on the drawn code (the page's hero test reads it).
  final Key? codeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = overview.inviteCode.code;
    final link = overview.inviteLink;
    final caption = LoopType.caption.copyWith(color: LoopColors.text2);
    return Column(
      key: const ValueKey<String>('referral-invite-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('邀请码', style: caption),
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                label: '我的邀请码 $code',
                excludeSemantics: true,
                child: Text(
                  code,
                  key: codeKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.keyFigure.copyWith(color: LoopColors.yellow),
                ),
              ),
            ),
            ReferralCopyGlyph(
              key: const ValueKey<String>('referral-copy-code'),
              text: code,
              label: '复制邀请码',
              message: '邀请码已复制',
            ),
          ],
        ),
        // S344 review (需求方不要说明性文案): without a link the whole
        // 邀请链接 block is left out; the code, its copy glyph and the poster
        // stay.
        if (link != null) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: LoopColors.line),
          ),
          Text('邀请链接', style: caption),
          Row(
            key: const ValueKey<String>('referral-link-block'),
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
              ReferralCopyGlyph(
                key: const ValueKey<String>('referral-copy-link'),
                text: link,
                label: '复制邀请链接',
                message: '邀请链接已复制',
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        // S350b: the share button takes the larger part, so 「分享邀请链接」
        // holds one line at 360 wide.
        Row(
          children: <Widget>[
            if (link != null) ...<Widget>[
              Expanded(
                flex: 4,
                child: LoopButton(
                  key: const ValueKey<String>('referral-share-link'),
                  label: '分享邀请链接',
                  // S350b: no glyph, so the label holds one line in half the
                  // card at 360 wide.
                  primary: true,
                  onPressed: () => unawaited(_share(context, ref, code, link)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: LoopButton(
                key: const ValueKey<String>('referral-poster'),
                label: '生成海报',
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
            ),
          ],
        ),
      ],
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

/// 邀请加成 (S348): one total, then a row per depth that has something —
/// effective members or power above zero; a depth with nothing is not
/// drawn. Before the server approves the boost the total is the em dash and
/// nothing else. Mining Power, not money; every figure is the server's own
/// string (loop-api decision 0162 §B.2).
@visibleForTesting
class ReferralBoostPanel extends StatelessWidget {
  const ReferralBoostPanel({
    required this.boost,
    required this.levels,
    super.key,
  });

  /// `null` while the server sends the unavailable projection.
  final ReferralBoostAvailable? boost;

  /// The depths' published boost percentages.
  final List<ReferralLevel> levels;

  static bool _positive(String value) => (double.tryParse(value) ?? 0) > 0;

  /// Whether one depth has anything to show.
  static bool hasData(ReferralBoostLevel level) =>
      level.effectiveMembers > 0 ||
      _positive(level.nftPower) ||
      _positive(level.assetPower);

  @override
  Widget build(BuildContext context) {
    final value = boost;
    final shown = <ReferralBoostLevel>[
      if (value != null)
        for (final level in value.levels)
          if (hasData(level)) level,
    ];
    final percents = <int, String>{
      for (final level in levels) level.level: level.boostPercent,
    };
    final total = value == null
        ? launchMissingFigure
        : loopPowerFigure(value.referralPower);
    return LoopRecordGroup(
      key: const ValueKey<String>('referral-boost'),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('referral-boost-total'),
          title: '总加成',
          trailing: total,
          trailingCaption: value == null ? null : '算力',
          trailingStrong: true,
          trailingColor: value == null ? null : LoopColors.yellow,
          chevron: false,
          position: launchRowPosition(0, shown.length + 1),
        ),
        for (var index = 0; index < shown.length; index += 1)
          LoopRecordRow(
            key: ValueKey<String>('referral-boost-level-${shown[index].level}'),
            title: <String>[
              'L${shown[index].level}',
              if (percents[shown[index].level] case final String percent)
                '$percent%',
              '有效成员 ${shown[index].effectiveMembers} 人',
            ].join(' · '),
            subtitle:
                'NFT ${loopPowerFigure(shown[index].nftPower)} · '
                '资产 ${loopPowerFigure(shown[index].assetPower)}',
            chevron: false,
            position: launchRowPosition(index + 1, shown.length + 1),
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
        emptyMessage: '还没有邀请',
        onRetry: () => unawaited(controller.reload()),
      );
    }
    final items = state.items;
    if (items.isEmpty) {
      return const LoopInlineUnavailable(
        key: ValueKey<String>('referral-invitees-empty'),
        icon: 'users',
        message: '还没有邀请',
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
