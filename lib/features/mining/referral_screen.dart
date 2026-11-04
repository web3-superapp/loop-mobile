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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
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
  invitees(),
  boost();

  const ReferralCenterTab();

  String get label => switch (this) {
    ReferralCenterTab.invitees => LoopL10n.current.mining_referralInvitees,

    ReferralCenterTab.boost => LoopL10n.current.mining_secondaryScreensTitle3,
  };
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
          message: context.l10n.mining_referralReferralCapabilityInlineMessage,
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
          emptyMessage: context.l10n.mining_referralEmptyMessage,
          emptyReason: context.l10n.mining_referralEmptyReason,
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
        LoopLabel(context.l10n.mining_referralLoopLabel),
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
              ? LoopL10n.current.mining_referralMessage(code)
              : LoopL10n.current.mining_referralMessage2(code),
          kind: LoopToastKind.warn,
        );
      }
    });
  }

  Future<void> _openClaimSheet({String? initialCode}) async {
    final code = await showLoopSheet<String>(
      context,
      barrierLabel: LoopL10n.current.mining_referralBarrierLabel,
      builder: (sheetContext) => _ClaimForm(initialCode: initialCode),
    );
    if (code == null || !mounted) return;
    await ref.read(referralControllerProvider.notifier).claim(code);
    if (!mounted) return;
    final state = ref.read(referralControllerProvider);
    // A success Toast only after the server confirmed the binding.
    if (state.claimed) {
      LoopToast.show(
        context,
        message: LoopL10n.current.mining_referralMessage3,
        kind: LoopToastKind.ok,
      );
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
  static const double filterHeight = LoopTouch.chipHeight;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: LoopSpacing.segmentGap - (LoopTouch.minimum - filterHeight) / 2,
    ),
    // Decision 0277: the one shared filter chip row (S350 left two copies of
    // the same capsule here and in `WalletAssetTabs`).
    child: LoopFilterChips(
      labels: labels,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
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
    LoopInfoNote(
      key: ValueKey<String>('referral-info-mining-only'),
      title: LoopL10n.current.mining_referralReferralInfoMiningOnlyTitle,
      body: LoopL10n.current.mining_referralReferralInfoMiningOnlyBody,
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-relationship'),
      title: LoopL10n.current.mining_referralReferralInfoRelationshipTitle,
      body: LoopL10n.current.mining_referralReferralInfoRelationshipBody(
        overview == null
            ? ''
            : LoopL10n.current.mining_referralOverviewCounts(
                overview.pendingRelationships,
                overview.validRelationships,
              ),
      ),
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-depth'),
      title: LoopL10n.current.mining_referralReferralInfoDepthTitle,
      body: LoopL10n.current.mining_referralReferralInfoDepthBody(
        rules == null
            ? ''
            : LoopL10n.current.mining_referralDepthMax(rules.maximumDepth),
      ),
    ),
    for (final level in levels)
      LoopInfoNote(
        key: ValueKey<String>('referral-level-${level.level}'),
        title: LoopL10n.current.mining_referralTitle(
          level.boostPercent,
          level.level,
        ),
        body: referralLevelDescription(level.level),
      ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-valid-member'),
      title: LoopL10n.current.mining_referralReferralInfoValidMemberTitle,
      body: LoopL10n.current.mining_referralReferralInfoValidMemberBody(
        stats == null
            ? ''
            : asOf == null
            ? LoopL10n.current.mining_referralValidNoHour
            : LoopL10n.current.mining_referralValidAsOf(
                launchTimestampLabel(asOf),
              ),
      ),
    ),
    LoopInfoNote(
      key: const ValueKey<String>('referral-info-binding'),
      title: LoopL10n.current.mining_referralReferralInfoBindingTitle,
      body: LoopL10n.current.mining_referralReferralInfoBindingBody,
    ),
    if (rules != null)
      LoopInfoNote(
        key: const ValueKey<String>('referral-info-rules'),
        title: LoopL10n.current.mining_referralReferralInfoRulesTitle,
        body: LoopL10n.current.mining_referralReferralInfoRulesBody(
          launchTimestampLabel(rules.effectiveAt),
          rules.maximumDepth,
          rules.appliesTo == 'miningPower'
              ? LoopL10n.current.mining_referralAppliesMiningPower
              : ' ${rules.appliesTo}',
        ),
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
    label: _copied ? context.l10n.common_copied : widget.label,
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
        Text(context.l10n.mining_referralBuild, style: caption),
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                label: context.l10n.mining_referralLabel(code),
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
              label: context.l10n.mining_referralReferralCopyCodeLabel,
              message: context.l10n.mining_referralReferralCopyCodeMessage,
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
          Text(context.l10n.mining_referralBuild2, style: caption),
          Row(
            key: const ValueKey<String>('referral-link-block'),
            children: <Widget>[
              Expanded(
                child: Semantics(
                  label: context.l10n.mining_referralReferralInviteLinkLabel(
                    link,
                  ),
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
                label: context.l10n.mining_referralReferralCopyLinkLabel,
                message: context.l10n.mining_referralReferralCopyLinkMessage,
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
                  label: context.l10n.mining_referralReferralShareLinkLabel,
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
                label: context.l10n.mining_referralReferralPosterLabel,
                onPressed: () => unawaited(
                  showLoopSheet<void>(
                    context,
                    barrierLabel: context.l10n.mining_referralBarrierLabel2,
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
      subject: context.l10n.mining_referralSubject,
    );
    if (!shown && context.mounted) {
      LoopToast.show(
        context,
        message: context.l10n.mining_referralMessage4,
        kind: LoopToastKind.warn,
      );
    }
  }
}

/// The text 「分享邀请链接」 hands to the system sheet.
String referralInviteText(String code, String? link) => link == null
    ? LoopL10n.current.mining_referralIf(code)
    : LoopL10n.current.mining_referralS(code, link);

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
          title: context.l10n.mining_referralReferralBoostTotalTitle,
          trailing: total,
          trailingCaption: value == null ? null : context.l10n.common_power,
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
              context.l10n.mining_referralLoopRecordRow(
                shown[index].effectiveMembers,
              ),
            ].join(' · '),
            subtitle: context.l10n.mining_referralSubtitle(
              loopPowerFigure(shown[index].nftPower),
              loopPowerFigure(shown[index].assetPower),
            ),
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
        emptyMessage: context.l10n.mining_referralEmptyMessage2,
        onRetry: () => unawaited(controller.reload()),
      );
    }
    final items = state.items;
    if (items.isEmpty) {
      return LoopInlineUnavailable(
        key: ValueKey<String>('referral-invitees-empty'),
        icon: 'users',
        message: context.l10n.mining_referralEmptyMessage2,
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
    final name = invitee.alias ?? LoopL10n.current.mining_referralRow;
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
      subtitle: LoopL10n.current.mining_referralSubtitle2(
        launchTimestampLabel(invitee.boundAt),
      ),
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
      semanticLabel: LoopL10n.current.mining_referralSemanticLabel(
        launchTimestampLabel(invitee.boundAt),
        name,
        referralInviteeStatusLabel(invitee.status),
      ),
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
        LoopSheetHeading(context.l10n.mining_referralLoopSheetHeading),
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
                    context.l10n.mining_referralReferralPosterNoLink,
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
                    label: _exporting
                        ? context.l10n.mining_referralReferralPosterShareLabel
                        : context.l10n.mining_referralReferralPosterShareLabel2,
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
      label: context.l10n.mining_referralReferralPosterLabel2(code),
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
              Text(
                context.l10n.mining_referralSubject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.headingLg,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.mining_referralBuild3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                      semanticLabel: context
                          .l10n
                          .mining_referralReferralPosterQrSemanticLabel,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                context.l10n.mining_referralBuild,
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
                symbol == null
                    ? context.l10n.mining_referralBuild4
                    : context.l10n.mining_referralS2,
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
        ? context.l10n.mining_referralBuild5
        : switch (binding.claimWindow) {
            ReferralClaimWindowUnavailable(:final reasonCode) =>
              context.l10n.mining_referralReferralClaimWindowUnavailable(
                launchReasonCodeText(reasonCode),
              ),
            ReferralClaimWindowTimed() =>
              context.l10n.mining_referralReferralClaimWindowTimed,
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
                title: context.l10n.mining_referralReferralBoundRowTitle,
                // Never the inviter's identity: only depth and state.
                subtitle: context.l10n.mining_referralReferralBoundRowSubtitle(
                  inviter.depth,
                  launchTimestampLabel(inviter.lockedAt),
                  referralValidationStatusLabel(inviter.validationStatus),
                ),
              ),
            ],
          ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('referral-claim'),
              label: context.l10n.mining_referralReferralInfoBindingTitle,
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
          LoopNotice(
            key: ValueKey<String>('referral-claim-shape-invalid'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.mining_referralReferralClaimShapeInvalidTitle,
            body: context.l10n.mining_referralReferralClaimShapeInvalidBody,
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
            title: context.l10n.mining_referralReferralClaimFailureTitle,
            body: referralClaimFailureReason(claimFailureKind),
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
        if (claimed)
          LoopNotice(
            key: ValueKey<String>('referral-claim-success'),
            icon: 'check',
            title: context.l10n.mining_referralReferralClaimSuccessTitle,
            body: context.l10n.mining_referralReferralClaimSuccessBody,
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
          LoopSheetHeading(
            context.l10n.mining_referralReferralInfoBindingTitle,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.mining_referralBuild6,
                  style: LoopType.bodySm,
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey<String>('referral-claim-input'),
                  controller: _code,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.l10n.mining_referralLabelText,
                    errorText: _invalid
                        ? context.l10n.mining_referralErrorText
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                LoopButtonPair(
                  padded: false,
                  children: <Widget>[
                    LoopButton(
                      key: const ValueKey<String>('referral-claim-submit'),
                      label:
                          context.l10n.mining_referralReferralClaimSubmitLabel,
                      primary: true,
                      onPressed: _submit,
                    ),
                    LoopButton(
                      key: const ValueKey<String>('referral-claim-cancel'),
                      label: context.l10n.common_cancel,
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
