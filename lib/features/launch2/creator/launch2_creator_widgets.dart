import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart'
    show launch2BuyFeeSideText, launch2ChineseCopy, launch2CurveCapFigure;
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

// ---------------------------------------------------------------------------
// MEME v2 project side · copy and shared pieces (S135, decision 0138)
// ---------------------------------------------------------------------------

final Decimal _unit = Decimal.fromBigInt(BigInt.from(10).pow(18));

Decimal launch2Units(BigInt raw) =>
    (Decimal.fromBigInt(raw) / _unit).toDecimal(scaleOnInfinitePrecision: 18);

/// 「10 亿」「8 亿」「500 万」 for a whole-token supply.
String launch2SupplyLabel(BigInt raw) {
  final units = launch2Units(raw);
  if (!launch2ChineseCopy) {
    // en: compact K / M / B (glossary §1.7) — 1,000,000,000 → 1B.
    return units >= Decimal.fromInt(10000)
        ? loopFormatCompactFigure(units, usd: false)
        : loopFormatDecimal(units, maxFractionDigits: 2);
  }
  final yi = Decimal.fromInt(100000000);
  final wan = Decimal.fromInt(10000);
  if (units >= yi && (units % yi) == Decimal.zero) {
    return LoopL10n.current.launch2Creator_launch2Launch2SupplyLabel(
      loopFormatDecimal((units / yi).toDecimal()),
    );
  }
  if (units >= wan && (units % wan) == Decimal.zero) {
    return LoopL10n.current.launch2Creator_launch2Launch2SupplyLabel2(
      loopFormatDecimal((units / wan).toDecimal()),
    );
  }
  return loopFormatDecimal(units, maxFractionDigits: 2);
}

String launch2Usd1Label(BigInt raw) =>
    '${loopFormatDecimal(launch2Units(raw), maxFractionDigits: 3)} USD1';

String launch2BpsLabel(int bps) =>
    '${loopFormatDecimal(Decimal.fromInt(bps).shift(-2), maxFractionDigits: 2)}%';

String launch2DurationLabel(int seconds) {
  if (seconds % 86400 == 0) {
    return LoopL10n.current.launch2Creator_launch2Launch2DurationLabel(
      seconds ~/ 86400,
    );
  }
  if (seconds % 3600 == 0) {
    return LoopL10n.current.launch2Creator_launch2CreateLeadLabel(
      seconds ~/ 3600,
    );
  }
  return LoopL10n.current.launch2Creator_launch2CreateLeadLabel2(seconds ~/ 60);
}

/// The BscScan testnet page for one transaction hash on the deployment chain.
String? launch2ExplorerTx(String? hash) =>
    hash == null ? null : 'https://testnet.bscscan.com/tx/$hash';

/// What a refusal of a project-side request means to the owner.
String launch2FailureText(LoopChainException failure) {
  switch (failure.reasonCode) {
    case 'HOOKS_LAUNCH_DISABLED':
      return LoopL10n.current.launch2Creator_launch2S;
    case 'HOOKS_LAUNCH_FACTORY_UNAVAILABLE':
      return LoopL10n.current.launch2Creator_launch2S2;
    case 'HOOKS_CONFIG_NOT_APPROVED':
      return LoopL10n.current.launch2Creator_launch2S3;
    case 'HOOKS_SIGNATURE_EXPIRED':
      return LoopL10n.current.launch2Creator_launch2S4;
    case launch2RecipientFixedCode:
      return LoopL10n.current.launch2Creator_launch2Launch2RecipientFixedCode;
    case launch2ConfigVersionUsedCode:
      return LoopL10n
          .current
          .launch2Creator_launch2Launch2ConfigVersionUsedCode;
    case launch2RecipientUnavailableCode:
      return LoopL10n
          .current
          .launch2Creator_launch2Launch2RecipientUnavailableCode;
  }
  return switch (failure.kind) {
    LoopChainFailureKind.invalidData =>
      LoopL10n.current.launch2Creator_launch2InvalidData,
    LoopChainFailureKind.versionConflict =>
      LoopL10n.current.launch2Creator_launch2VersionConflict,
    LoopChainFailureKind.idempotencyConflict =>
      LoopL10n.current.launch2Creator_launch2IdempotencyConflict,
    LoopChainFailureKind.permissionDenied =>
      LoopL10n.current.launch2Creator_launch2PermissionDenied,
    LoopChainFailureKind.notFound =>
      LoopL10n.current.launch2Creator_launch2NotFound,
    LoopChainFailureKind.bootstrapRequired =>
      LoopL10n.current.launch2Creator_launch2BootstrapRequired,
    _ => loopChainFailureReason(failure.kind),
  };
}

/// §9.2: one sentence per `failure.code`; an unknown code asks the owner to
/// contact the platform.
String launch2JobFailureText(String code) => switch (code) {
  'HOOKS_SIGNATURE_EXPIRED' => LoopL10n.current.launch2Creator_launch2Switch,
  'HOOKS_CONFIG_SUPERSEDED' => LoopL10n.current.launch2Creator_launch2Switch2,
  'HOOKS_CONFIG_NOT_APPROVED' => LoopL10n.current.launch2Creator_launch2Switch3,
  'HOOKS_AUTHORIZATION_INVALID' =>
    LoopL10n.current.launch2Creator_launch2Switch4,
  'HOOKS_OWNER_NONCE_CONSUMED' =>
    LoopL10n.current.launch2Creator_launch2Switch5,
  'HOOKS_LAUNCH_ALREADY_DEPLOYED' =>
    LoopL10n.current.launch2Creator_launch2Switch6,
  'HOOKS_ACTIVATION_WINDOW_CLOSED' =>
    LoopL10n.current.launch2Creator_launch2Switch7,
  // Decision 0206 (backend 0164, contracts 0016 `InvalidName` /
  // `InvalidTicker`): the name or ticker broke the 1–20 rule.
  'HOOKS_LAUNCH_NAME_INVALID' || 'HOOKS_LAUNCH_TICKER_INVALID' =>
    LoopL10n.current.launch2Creator_launch2Switch8,
  'HOOKS_VERIFICATION_MISMATCH' =>
    LoopL10n.current.launch2Creator_launch2Switch9,
  'HOOKS_EXECUTOR_FUNDS_INSUFFICIENT' ||
  'HOOKS_BROADCAST_REJECTED' ||
  'HOOKS_TX_DROPPED' ||
  'HOOKS_DEPLOY_REVERTED' => LoopL10n.current.launch2Creator_launch2Switch10,
  _ => LoopL10n.current.launch2Creator_launch2Switch11,
};

/// The failures the owner answers by signing again (§9.2).
bool launch2JobFailureResignable(String code) => const <String>{
  'HOOKS_SIGNATURE_EXPIRED',
  'HOOKS_CONFIG_SUPERSEDED',
  'HOOKS_AUTHORIZATION_INVALID',
  'HOOKS_OWNER_NONCE_CONSUMED',
}.contains(code);

/// The failures the owner answers by editing the project: the sale time,
/// or (decision 0206) a name or ticker the rule refused.
bool launch2JobFailureNeedsEdit(String code) => const <String>{
  'HOOKS_ACTIVATION_WINDOW_CLOSED',
  'HOOKS_LAUNCH_NAME_INVALID',
  'HOOKS_LAUNCH_TICKER_INVALID',
}.contains(code);

/// The edit button for a [launch2JobFailureNeedsEdit] failure.
String launch2JobFailureEditLabel(String code) => switch (code) {
  'HOOKS_LAUNCH_NAME_INVALID' || 'HOOKS_LAUNCH_TICKER_INVALID' =>
    LoopL10n.current.launch2Creator_launch2Switch12,
  _ => LoopL10n.current.launch2Creator_launch2Switch13,
};

/// §9.1: the job's own status, in the owner's words.
String launch2JobStatusText(Launch2DeploymentJob job) => switch (job.status) {
  Launch2JobStatus.awaitingExecutor =>
    LoopL10n.current.launch2Creator_launch2AwaitingExecutor,
  Launch2JobStatus.claimed => LoopL10n.current.launch2Creator_launch2Claimed,
  Launch2JobStatus.broadcast =>
    job.confirmations == null
        ? LoopL10n.current.launch2Creator_launch2Switch14
        : LoopL10n.current.launch2Creator_launch2S5(job.confirmations),
  Launch2JobStatus.confirmed =>
    LoopL10n.current.launch2Creator_launch2Confirmed,
  Launch2JobStatus.verified =>
    LoopL10n.current.launch2Creator_launch2ModelsVerified,
  Launch2JobStatus.activated =>
    LoopL10n.current.launch2Creator_launch2ModelsActive,
  Launch2JobStatus.failed =>
    job.failure?.retryable == true
        ? LoopL10n.current.launch2Creator_launch2Switch15
        : LoopL10n.current.launch2Creator_launch2ModelsDeployFailed,
  Launch2JobStatus.reorged => LoopL10n.current.launch2Creator_launch2Reorged,
  Launch2JobStatus.cancelled => LoopL10n.current.common_cancelled,
};

/// §9.3: the seven events of a successful run have their own line; every
/// other kind reads generically, and nothing depends on `included`.
String launch2EventTitle(Launch2JobEvent event) => switch (event.kind) {
  'created' => LoopL10n.current.launch2Creator_launch2Switch16,
  'claimed' ||
  'retry_claimed' => LoopL10n.current.launch2Creator_launch2Switch17,
  'broadcast' ||
  'rebroadcast' => LoopL10n.current.launch2Creator_launch2Switch18,
  'included' => LoopL10n.current.launch2Creator_launch2Switch19,
  'confirmed' => LoopL10n.current.launch2Creator_launch2Switch20,
  'verified' => LoopL10n.current.launch2Creator_launch2Switch21,
  'activation_broadcast' => LoopL10n.current.launch2Creator_launch2Switch22,
  'activation_included' => LoopL10n.current.launch2Creator_launch2Switch23,
  'activated' => LoopL10n.current.launch2Creator_launch2ModelsActive,
  'reorg_detected' ||
  'reclaimed_after_reorg' => LoopL10n.current.launch2Creator_launch2Switch24,
  'failed' => LoopL10n.current.launch2Creator_launch2ModelsDeployFailed,
  'cancelled' => LoopL10n.current.common_cancelled,
  _ => LoopL10n.current.launch2Creator_launch2Switch25,
};

/// The fixed template, read-only (S134–S137 §3.1): the page's one large
/// figure is the total supply.
class Launch2TemplateCard extends StatelessWidget {
  const Launch2TemplateCard({
    required this.economics,
    super.key,
    this.fromServer = false,
  });

  final Launch2FixedEconomics economics;

  /// The values are the saved draft's own; otherwise they are the platform
  /// template the server will derive.
  final bool fromServer;

  @override
  Widget build(BuildContext context) {
    final capBps = economics.perAddressCapBps;
    // Decision 0198: the Factory's own cap (loop-api 0152), said the way the
    // instance's 发射规则 says it (decision 0197): 「N 枚（x%）」.
    final capFigure = LoopL10n.current.launch2Creator_launch2CapFigure(
      launch2CurveCapFigure(launch2Units(economics.curveCapRaw)),
    );
    final loopDynamic = economics.loopDynamic;
    final buyFeeToken = loopDynamic?.buyFeeToken;
    final rows = <(String, String)>[
      (
        context.l10n.launch2Creator_launch2Build,
        launch2SupplyLabel(economics.curveSaleSupplyRaw),
      ),
      (
        context.l10n.launch2Creator_launch2Build2,
        launch2Usd1Label(economics.graduationReserveUsd1Raw),
      ),
      (
        context.l10n.launch2Creator_launch2Build3,
        launch2BpsLabel(economics.curveBuyTaxBps),
      ),
      (
        context.l10n.launch2Creator_launch2Build4,
        launch2BpsLabel(economics.officialPoolBuyTaxBps),
      ),
      // Only when the template says which side; never inferred.
      if (loopDynamic != null && buyFeeToken != null)
        (
          context.l10n.launch2Creator_launch2Build5,
          context.l10n.launch2Creator_figureWithNote(
            launch2BpsLabel(loopDynamic.buyFeePpm ~/ 100),
            launch2BuyFeeSideText(
              fromUsd1: buyFeeToken == Launch2BuyFeeToken.usd1,
            ),
          ),
        ),
      (
        context.l10n.launch2Creator_launch2Build6,
        capBps == null
            ? capFigure
            : context.l10n.launch2Creator_figureWithNote(
                capFigure,
                launch2BpsLabel(capBps),
              ),
      ),
      (
        context.l10n.launch2Creator_launch2Build7,
        launch2Usd1Label(economics.nftPriceUsd1Raw),
      ),
      (
        context.l10n.launch2Creator_launch2Build8,
        fromServer
            ? launch2DurationLabel(economics.nftSaleDurationSeconds)
            : context.l10n.launch2Creator_launch2Build9,
      ),
    ];
    return LoopSurfaceCard(
      key: const ValueKey<String>('launch2-template-card'),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.common_totalSupply,
            style: LoopType.caption.copyWith(color: LoopColors.text3),
          ),
          const SizedBox(height: 2),
          Text(
            launch2SupplyLabel(economics.memeTotalSupplyRaw),
            key: const ValueKey<String>('launch2-template-supply'),
            style: LoopType.figureLg,
          ),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            LoopKeyValue(
              label: label,
              value: value,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
        ],
      ),
    );
  }
}

/// A project's state for a row or a header: the `.badge` (decision 0169;
/// was a self-drawn r999 pill with the fall red for a refusal). Lime-soft
/// once active, the quiet pair for every other state — a refusal is said by
/// its word and by the page's notice, not by a colour.
class Launch2StatusPill extends StatelessWidget {
  const Launch2StatusPill({required this.status, super.key});

  final Launch2CreatorStatus status;

  /// The badge kind a state takes.
  static LoopBadgeKind kindOf(Launch2CreatorStatus status) => switch (status) {
    Launch2CreatorStatus.active => LoopBadgeKind.launch,
    Launch2CreatorStatus.rejected ||
    Launch2CreatorStatus.deployFailed => LoopBadgeKind.down,
    _ => LoopBadgeKind.mute,
  };

  @override
  Widget build(BuildContext context) => LoopBadge(
    status.label,
    key: ValueKey<String>('launch2-status-${status.wireName}'),
    kind: kindOf(status),
  );
}

/// A time on the reader's clock, plus how far away it is.
String launch2SaleStartLabel(DateTime start, DateTime now) {
  final local = loopLocalTimestampLabel(start);
  final delta = start.difference(now);
  if (delta.isNegative) return local;
  if (delta.inDays >= 1) {
    return LoopL10n.current.launch2Creator_launch2Launch2SaleStartLabel(
      delta.inDays,
      local,
    );
  }
  if (delta.inHours >= 1) {
    return LoopL10n.current.launch2Creator_launch2Launch2SaleStartLabel2(
      delta.inHours,
      local,
    );
  }
  return LoopL10n.current.launch2Creator_launch2Launch2SaleStartLabel3(
    delta.inMinutes,
    local,
  );
}

/// The platform's fixed buyback recipient, read only (decision 0144,
/// requirer answer 9). The owner never types or changes it.
class Launch2FixedRecipient extends StatelessWidget {
  const Launch2FixedRecipient({required this.address, super.key});

  /// `null` when the platform has not configured it.
  final String? address;

  @override
  Widget build(BuildContext context) {
    final value = address;
    return Padding(
      key: const ValueKey<String>('launch2-fixed-recipient'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        4,
      ),
      child: Semantics(
        label: value == null
            ? context
                  .l10n
                  .launch2Creator_launch2Launch2FixedRecipientAddressLabel
            : context.l10n
                  .launch2Creator_launch2Launch2FixedRecipientAddressLabel2(
                    value,
                  ),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              // S370a · decision 0293: a read-only field at the search
              // field's r12 (docs/58 §9.4, 类推).
              decoration: const BoxDecoration(
                color: LoopColors.card,
                borderRadius: LoopRadius.control,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      value ??
                          context
                              .l10n
                              .launch2Creator_launch2Launch2FixedRecipientAddress,
                      key: const ValueKey<String>(
                        'launch2-fixed-recipient-address',
                      ),
                      style: LoopType.code.copyWith(
                        color: value == null
                            ? LoopColors.text3
                            : LoopColors.chalk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  LoopBadge(context.l10n.launch2Creator_launch2LoopBadge),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value == null
                  ? context.l10n.launch2Creator_launch2Build11
                  : context.l10n.launch2Creator_launch2S6,
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reviewer rejection (decision 0144): the reason in the owner's words,
/// the reviewer's own note verbatim, and when.
class Launch2RejectionNotice extends StatelessWidget {
  const Launch2RejectionNotice({
    required this.rejection,
    super.key,
    this.configuration = false,
  });

  final LaunchRejection rejection;

  /// The launch configuration was rejected rather than the project material.
  final bool configuration;

  @override
  Widget build(BuildContext context) {
    final note = rejection.note;
    return LoopNotice(
      key: ValueKey<String>('launch2-rejection-${rejection.reason.wireName}'),
      icon: 'warn',
      tone: LoopNoticeTone.warn,
      title: launch2RejectionTitle(rejection),
      body: <String>[
        if (note != null) context.l10n.launch2Creator_launch2LoopNotice(note),
        context.l10n.launch2Creator_launch2LoopNotice2(
          configuration
              ? context.l10n.launch2Creator_launch2ProjectLoopLabel
              : context.l10n.launch2Creator_projectDetails,
          loopLocalTimestampLabel(rejection.at),
        ),
      ].join('\n'),
    );
  }
}

/// 「已拒绝 · 材料不完整」: a rejected project's row in 我的项目 (decision 0200).
String launch2RejectedRowText(LaunchRejection rejection) => LoopL10n.current
    .launch2Creator_launch2Launch2RejectedRowText(rejection.reason.label);

/// 「审核未通过：材料不完整」.
String launch2RejectionTitle(LaunchRejection rejection) => LoopL10n.current
    .launch2Creator_launch2Launch2RejectionTitle(rejection.reason.label);

/// Calls [onReturn] when the page it wraps becomes the top route again after
/// another page covered it (decision 0200). 我的项目 and the project page stay
/// mounted under the pages they open, so without this the owner came back to
/// the answer read before the edit, the resubmission or the review.
class Launch2RefreshOnReturn extends StatefulWidget {
  const Launch2RefreshOnReturn({
    required this.onReturn,
    required this.child,
    super.key,
  });

  final VoidCallback onReturn;
  final Widget child;

  @override
  State<Launch2RefreshOnReturn> createState() => _Launch2RefreshOnReturnState();
}

class _Launch2RefreshOnReturnState extends State<Launch2RefreshOnReturn> {
  bool _covered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (!current) {
      _covered = true;
      return;
    }
    if (!_covered) return;
    _covered = false;
    scheduleMicrotask(() {
      if (mounted) widget.onReturn();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What the create page says under the NFT image slot (decision 0233;
/// S326 · decision 0256 shortened it to the design's words).
String get launch2NftImageHelp =>
    LoopL10n.current.launch2Creator_launch2Launch2NftImageHelp;

/// S326 · decision 0256 (UX-006): the create page's step bar — equal
/// segments across the top of the page, every reached step Yellow, the rest
/// the raised grey, the same shape as the sign-in flow's. It replaces the
/// step dots under the title.
class Launch2CreateStepBar extends StatelessWidget {
  const Launch2CreateStepBar({
    required this.labels,
    required this.current,
    super.key,
  });

  final List<String> labels;
  final int current;

  /// The segments' height and the gap between two.
  static const double height = 4;
  static const double gap = 6;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: context.l10n.launch2Creator_launch2Label(
      current + 1,
      labels.length,
      labels[current],
    ),
    excludeSemantics: true,
    child: Row(
      children: <Widget>[
        for (var index = 0; index < labels.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: gap),
          Expanded(
            child: AnimatedContainer(
              key: ValueKey<String>('launch2-create-step-segment-$index'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              height: height,
              decoration: BoxDecoration(
                color: index <= current ? LoopColors.yellow : LoopColors.card2,
                borderRadius: LoopRadius.round,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// S326 · decision 0256 (UX-006): an upload placeholder that is itself the
/// upload control. Empty, a raised square with the add-picture glyph over
/// 「上传」; with a picture, the picture with a small 「换一张」 at its foot;
/// while sending, 「上传中…」. There is no separate upload button beside it.
class Launch2UploadSlot extends StatelessWidget {
  const Launch2UploadSlot({
    required this.size,
    required this.semanticLabel,
    super.key,
    this.imageUrl,
    this.preview,
    this.previewKey,
    this.emptyKey,
    this.missing = false,
    this.uploading = false,
    this.onTap,
  });

  final double size;

  /// What the slot holds, for a screen reader (「头像」, 「NFT 图」).
  final String semanticLabel;
  final String? imageUrl;

  /// Draws the uploaded picture; absent, [imageUrl] is drawn as a square.
  final Widget? preview;
  final Key? previewKey;
  final Key? emptyKey;

  /// The step refused without a picture: the slot's edge turns Chalk.
  final bool missing;
  final bool uploading;

  /// `null` while upload is closed or a picture is on its way.
  final VoidCallback? onTap;

  static const BorderRadius radius = LoopRadius.control;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final words = LoopTypography.withWeight(
      LoopType.captionSm,
      FontWeight.w600,
    );
    final empty = Column(
      key: emptyKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Launch2AddPictureGlyph(
          size: size >= 110 ? 30 : 26,
          color: uploading ? LoopColors.text3 : LoopColors.chalk,
        ),
        const SizedBox(height: 6),
        Text(
          uploading
              ? context.l10n.common_uploading
              : context.l10n.launch2Creator_launch2S7,
          style: words.copyWith(
            color: uploading ? LoopColors.text3 : LoopColors.chalk,
          ),
        ),
      ],
    );
    final Widget face;
    if (url == null) {
      face = empty;
    } else {
      face = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          preview ??
              LoopRemoteAvatar(
                url: url,
                fallback: empty,
                size: size,
                shape: BoxShape.rectangle,
                radius: LoopRadius.controlValue,
                semanticLabel: semanticLabel,
              ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 24,
              alignment: Alignment.center,
              color: LoopColors.veil,
              child: Text(
                uploading
                    ? context.l10n.common_uploading
                    : context.l10n.launch2Creator_launch2S8,
                style: words.copyWith(color: LoopColors.chalk),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: url == null
          ? context.l10n.launch2Creator_launch2Label2(semanticLabel)
          : context.l10n.launch2Creator_launch2Label3(semanticLabel),
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null && !uploading ? 0.5 : 1,
        child: Material(
          color: LoopColors.card2,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: missing ? LoopColors.chalk : LoopColors.line2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              key: previewKey,
              width: size,
              height: size,
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

/// The add-picture glyph of [Launch2UploadSlot]: a picture frame with a hill
/// and a sun, and a plus at its top-right corner, in the sprite's 1.7 pen.
class Launch2AddPictureGlyph extends StatelessWidget {
  const Launch2AddPictureGlyph({
    super.key,
    this.size = 26,
    this.color = LoopColors.chalk,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _AddPicturePainter(color));
}

class _AddPicturePainter extends CustomPainter {
  const _AddPicturePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The frame, open at its top-right corner where the plus stands.
    final frame = Path()
      ..moveTo(13 * k, 4 * k)
      ..lineTo(6 * k, 4 * k)
      ..arcToPoint(
        Offset(3 * k, 7 * k),
        radius: Radius.circular(3 * k),
        clockwise: false,
      )
      ..lineTo(3 * k, 18 * k)
      ..arcToPoint(
        Offset(6 * k, 21 * k),
        radius: Radius.circular(3 * k),
        clockwise: false,
      )
      ..lineTo(17 * k, 21 * k)
      ..arcToPoint(
        Offset(20 * k, 18 * k),
        radius: Radius.circular(3 * k),
        clockwise: false,
      )
      ..lineTo(20 * k, 11 * k);
    canvas.drawPath(frame, pen);
    // The hill.
    canvas.drawPath(
      Path()
        ..moveTo(3.5 * k, 17.5 * k)
        ..lineTo(8.5 * k, 12.5 * k)
        ..lineTo(14 * k, 18 * k)
        ..moveTo(12 * k, 16 * k)
        ..lineTo(14.5 * k, 13.5 * k)
        ..lineTo(19.5 * k, 18.5 * k),
      pen,
    );
    // The sun.
    canvas.drawCircle(Offset(8.5 * k, 8.5 * k), 1.5 * k, pen);
    // The plus.
    canvas.drawLine(Offset(19 * k, 2 * k), Offset(19 * k, 8 * k), pen);
    canvas.drawLine(Offset(16 * k, 5 * k), Offset(22 * k, 5 * k), pen);
  }

  @override
  bool shouldRepaint(_AddPicturePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The project NFT's image in a square card-ground frame (decision 0233):
/// the board's ground and top hairline, the Yellow splat on its top-left
/// corner, the image inset 6. Without an image the slot shows the upload
/// glyph.
class Launch2NftImageFrame extends StatelessWidget {
  const Launch2NftImageFrame({
    super.key,
    this.imageUrl,
    this.size = 120,
    this.missing = false,
  });

  final String? imageUrl;
  final double size;

  /// The step refused without one: the frame's line turns Chalk.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    const inset = 6.0;
    final inner = size - inset * 2;
    final empty = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: LoopRadius.inner,
      ),
      child: LoopIcon(
        'camera',
        key: const ValueKey<String>('launch2-nft-image-empty'),
        size: inner / 4,
        color: LoopColors.text3,
      ),
    );
    final url = imageUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(inset),
          decoration: BoxDecoration(
            color: LoopColors.card,
            borderRadius: LoopRadius.card,
            border: missing
                ? Border.all(color: LoopColors.chalk)
                : const Border(top: BorderSide(color: Color(0x0AFFFFFF))),
          ),
          child: url == null
              ? empty
              : LoopRemoteAvatar(
                  url: url,
                  fallback: empty,
                  size: inner,
                  shape: BoxShape.rectangle,
                  radius: LoopRadius.innerValue,
                  semanticLabel: context
                      .l10n
                      .launch2Creator_launch2CreateLaunch2CreateNftMissing,
                ),
        ),
        const Positioned(
          left: -7,
          top: -8,
          width: 24,
          child: LoopSplatSticker(),
        ),
      ],
    );
  }
}
