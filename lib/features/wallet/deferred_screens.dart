import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/security/loop_url_review.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';

/// The four D21 surfaces: `pay`, `bridge`, `bridge-status` and `dapp`.
///
/// Each one exists as an entry point and states the server's own deferred
/// reason. None of them holds an amount, a route, a fee, a progress source or
/// an executable action, and none of them is backed by a preview fixture.

String _reasonFor(LoopCapabilityProjection capability, String fallback) =>
    capability.reasonCode ?? fallback;

/// Whether the server named a reason other than the page's own deferral —
/// the only case in which the reason line says more than the heading
/// (S278 · decision 0236, 需求方第 11 条).
bool _reasonAddsToHeading(
  LoopCapabilityProjection capability,
  String deferredReasonCode,
) {
  final reason = capability.reasonCode;
  return reason != null && reason != deferredReasonCode;
}

/// The folio's 「(i) 说明」 (S278 · decision 0236): what the page is and why
/// it is shaped so, one tap away instead of a caption and a card.
Widget _deferredInfo(
  BuildContext context, {
  required String keyName,
  required String title,
  required List<LoopInfoNote> notes,
}) => LoopProvenanceReport(
  // S325 · decision 0255 (UX-009): the page's one (i) in its bar.
  entry: LoopProvenanceEntry(heading: title, notes: notes),
  fallback: LoopInfoTrigger(
    key: ValueKey<String>('$keyName-info'),
    label: context.l10n.common_about,
    semanticsLabel: context.l10n.wallet_deferredScreensSemanticsLabel(title),
    onTap: () => unawaited(
      showLoopInfoSheet(
        context,
        title: title,
        sheetKey: '$keyName-info-sheet',
        notes: notes,
      ),
    ),
  ),
);

/// `pay` · reached from Wallet. `PAY_RUNTIME_DEFERRED`.
class PayScreen extends ConsumerWidget {
  const PayScreen({super.key, this.onBack});

  static const deferredReasonCode = 'PAY_RUNTIME_DEFERRED';

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.pay),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('pay-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Pay',
      onBack: onBack,
      // Chalk primary with the CAMERA stamp, as the prototype has it. A
      // deferred capability is still a page with a shape (audit §A.14).
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('pay-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: context.l10n.common_scan,
        heading: context.l10n.wallet_deferredScreensPayFolioHeading,
        // S278 · decision 0236: the caption and the 「为什么现在不做」 card
        // are this (i).
        kickerTrailing: _deferredInfo(
          context,
          keyName: 'pay',
          title: context.l10n.wallet_deferredScreensPayWhyNoticeTitle,
          notes: <LoopInfoNote>[
            LoopInfoNote(body: context.l10n.wallet_deferredScreensBody),
            LoopInfoNote(
              key: ValueKey<String>('pay-why-notice'),
              title: context.l10n.wallet_deferredScreensPayWhyNoticeTitle2,
              body: context.l10n.wallet_deferredScreensPayWhyNoticeBody,
            ),
          ],
        ),
        stamp: context.l10n.wallet_deferredScreensPayFolioStamp,
      ),
      sections: <Widget>[
        // The prototype keeps the viewfinder's room, with the reason in it.
        LoopPlaceholderStage(
          key: const ValueKey<String>('pay-unavailable'),
          icon: 'camera',
          title: 'Pay',
          badge: 'Coming soon',
          body: loopReasonCodeText(_reasonFor(capability, deferredReasonCode)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// `bridge` · `BRIDGE_RUNTIME_DEFERRED`. No amount input and no route.
class BridgeScreen extends ConsumerWidget {
  const BridgeScreen({super.key, this.onBack, this.onOpenStatus});

  static const deferredReasonCode = 'BRIDGE_RUNTIME_DEFERRED';

  final VoidCallback? onBack;
  final VoidCallback? onOpenStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bridge),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('bridge-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.common_bridge,
      onBack: onBack,
      primary: LoopFolioPrimary(
        ring: false,
        key: const ValueKey<String>('bridge-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.wallet_deferredScreensBridgeFolioKicker,
        heading: context.l10n.wallet_deferredScreensBridgeFolioHeading,
        // S278 · decision 0236 (需求方第 11 条): the caption and the
        // 「这里不会出现预估数字」 card are this (i).
        kickerTrailing: _deferredInfo(
          context,
          keyName: 'bridge',
          title: context.l10n.wallet_deferredScreensBridgeScopeNoticeTitle,
          notes: <LoopInfoNote>[
            LoopInfoNote(body: context.l10n.wallet_deferredScreensBody2),
            LoopInfoNote(
              key: ValueKey<String>('bridge-scope-notice'),
              title: context.l10n.wallet_deferredScreensBridgeScopeNoticeTitle2,
              body: context.l10n.wallet_deferredScreensBridgeScopeNoticeBody,
            ),
          ],
        ),
        stamp: context.l10n.wallet_deferredScreensBridgeFolioStamp,
      ),
      sections: <Widget>[
        // The prototype's 从 / 到 boxes keep their room. Each figure is a
        // dash: a bridge fee, a receive amount and an ETA can only come from a
        // real route, and there is none.
        LoopFigureBox(
          key: ValueKey<String>('bridge-from'),
          caption: context.l10n.wallet_deferredScreensBridgeFromCaption,
          figure: loopFigureDash,
        ),
        LoopFigureBox(
          key: ValueKey<String>('bridge-to'),
          caption: context.l10n.wallet_deferredScreensBridgeToCaption,
          figure: loopFigureDash,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            6,
            LoopSpacing.page,
            14,
          ),
          child: LoopButton(
            key: const ValueKey<String>('bridge-start'),
            label: context.l10n.wallet_deferredScreensBridgeStartLabel,
            primary: true,
            block: true,
            // Disabled, with the shape the prototype gives the action.
            onPressed: null,
          ),
        ),
        // The heading already says 跨链尚未开放; the line stands only when
        // the server names a different reason.
        if (_reasonAddsToHeading(capability, deferredReasonCode))
          LoopUnavailableLine(
            key: const ValueKey<String>('bridge-unavailable'),
            label: context.l10n.wallet_deferredScreensBridgeFolioHeading,
            reasonCode: _reasonFor(capability, deferredReasonCode),
          ),
        if (onOpenStatus != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              0,
            ),
            child: LoopButton(
              key: const ValueKey<String>('bridge-open-status'),
              label: context.l10n.wallet_deferredScreensBridgeOpenStatusLabel,
              block: true,
              onPressed: onOpenStatus,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// `bridge-status` · one whole-page state, because there is no progress.
///
/// The page used to carry a folio heading, an unavailable card, three step
/// rows badged 等待 and a footnote — and then most of a screen of black under
/// them (C-19). None of the three steps is observed by anybody: nothing is
/// transferring, so 等待 was a state the page invented for a run that does not
/// exist, and the heading above it could only repeat the card below it. The
/// whole page is the server's one reason, centred in the space the page owns,
/// with the only next step that leads anywhere.
class BridgeStatusScreen extends ConsumerWidget {
  const BridgeStatusScreen({super.key, this.onBack, this.onOpenWallet});

  static const deferredReasonCode = 'BRIDGE_RUNTIME_DEFERRED';

  final VoidCallback? onBack;
  final VoidCallback? onOpenWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bridge),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('bridge-status-screen'),
      archetype: LoopPageArchetype.state,
      title: context.l10n.wallet_deferredScreensBridgeStatusScreenTitle,
      onBack: onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('bridge-status-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        ring: false,
        archetype: LoopFolioArchetype.state,
        kicker: context.l10n.wallet_deferredScreensBridgeStatusScreenTitle,
        heading: context.l10n.wallet_deferredScreensBridgeStatusFolioHeading,
        // S278 · decision 0236: the caption and the 「可以离开此页」 card.
        kickerTrailing: _deferredInfo(
          context,
          keyName: 'bridge-status',
          title:
              context.l10n.wallet_deferredScreensBridgeStatusLeaveNoticeTitle,
          notes: <LoopInfoNote>[
            LoopInfoNote(body: context.l10n.wallet_deferredScreensBody3),
            LoopInfoNote(
              key: ValueKey<String>('bridge-status-leave-notice'),
              title: context
                  .l10n
                  .wallet_deferredScreensBridgeStatusLeaveNoticeTitle2,
              body: context
                  .l10n
                  .wallet_deferredScreensBridgeStatusLeaveNoticeBody,
            ),
          ],
        ),
        stamp: context.l10n.common_notOpenYet,
      ),
      sections: <Widget>[
        // The prototype's 步骤 group keeps its heading. Its three rows do not
        // appear: nothing is in flight, so 完成 / 进行中 / 等待 would be three
        // states this page invented for a transfer that does not exist. The
        // group states the one fact there is.
        LoopLabel(context.l10n.wallet_deferredScreensLoopLabel),
        LoopInlineUnavailable(
          key: const ValueKey<String>('bridge-status-page-block'),
          // 读不到 would say LOOP tried and failed. Nothing was tried,
          // because bridging has not been built.
          message:
              context.l10n.wallet_deferredScreensBridgeStatusPageBlockMessage,
          // The heading says the progress is not open; the server's reason
          // is printed only when it says something else.
          detail: _reasonAddsToHeading(capability, deferredReasonCode)
              ? loopReasonCodeText(_reasonFor(capability, deferredReasonCode))
              : null,
          detailMaxLines: 3,
          maxLines: 2,
        ),
        if (onOpenWallet != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              6,
              LoopSpacing.page,
              14,
            ),
            child: LoopButton(
              key: const ValueKey<String>('bridge-status-back-to-wallet'),
              label: context
                  .l10n
                  .wallet_deferredScreensBridgeStatusBackToWalletLabel,
              block: true,
              onPressed: onOpenWallet,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// `dapp` · local, offline URL review. Connecting and signing stay disabled.
class DappReviewScreen extends ConsumerStatefulWidget {
  const DappReviewScreen({super.key, this.onBack});

  static const deferredReasonCode = 'DAPP_EXECUTION_RUNTIME_DEFERRED';
  static const reputationReasonCode = 'DAPP_REPUTATION_PROVIDER_NOT_CONFIGURED';

  final VoidCallback? onBack;

  @override
  ConsumerState<DappReviewScreen> createState() => _DappReviewScreenState();
}

class _DappReviewScreenState extends ConsumerState<DappReviewScreen> {
  final TextEditingController _address = TextEditingController();
  LoopUrlReview _review = LoopUrlReview.review('');

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _review = LoopUrlReview.review(value));
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.dappExecution),
    );
    final typed = _address.text.trim();
    final review = _review;

    return LoopDashboardPage(
      key: const ValueKey<String>('dapp-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.wallet_deferredScreensDappScreenTitle,
      onBack: widget.onBack,
      // The prototype puts the address bar at the top of the page, where a
      // browser puts it, and the Chalk review card under it (audit §A.9).
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopOmnibox(
            key: const ValueKey<String>('dapp-omnibox'),
            fieldKey: const ValueKey<String>('dapp-address-field'),
            controller: _address,
            hintText: context.l10n.wallet_deferredScreensDappOmniboxHintText,
            trailingKey: 'GLOBAL',
            onChanged: _onChanged,
          ),
          LoopFolioPrimary(
            key: const ValueKey<String>('dapp-folio'),
            // S241b: flat dark card, Chalk heading (no light slab on Ink).
            variant: LoopFolioVariant.quiet,
            headingTone: LoopFolioHeadingTone.neutral,
            ring: false,
            archetype: LoopFolioArchetype.action,
            kicker: context.l10n.wallet_deferredScreensDappFolioKicker,
            heading: switch (review.verdict) {
              LoopUrlVerdict.normalized => review.host!,
              LoopUrlVerdict.flagged => review.host!,
              LoopUrlVerdict.blocked =>
                typed.isEmpty
                    ? context.l10n.wallet_deferredScreensLoopFolioPrimary
                    : context.l10n.wallet_deferredScreensS,
            },
            // S278 · decision 0236: the caption and the 「这一页不会打开网址」
            // disclosure are this (i).
            kickerTrailing: _deferredInfo(
              context,
              keyName: 'dapp',
              title: context.l10n.wallet_deferredScreensDappNoFetchNoticeTitle,
              notes: <LoopInfoNote>[
                LoopInfoNote(body: context.l10n.wallet_deferredScreensBody4),
                LoopInfoNote(
                  key: ValueKey<String>('dapp-no-fetch-notice'),
                  body:
                      context.l10n.wallet_deferredScreensDappNoFetchNoticeBody,
                ),
              ],
            ),
            stamp: switch (review.verdict) {
              LoopUrlVerdict.normalized =>
                context.l10n.wallet_deferredScreensNormalized,
              LoopUrlVerdict.flagged =>
                context.l10n.wallet_deferredScreensFlagged,
              LoopUrlVerdict.blocked => typed.isEmpty ? null : 'BLOCKED',
            },
          ),
        ],
      ),
      sections: <Widget>[
        // The prototype's chip row. It carries only what this page knows
        // without asking anybody: the origin it normalised and the one chain
        // the product is bound to. Gas price and open-approval counts are two
        // more reads, and this page makes none.
        if (review.canonical != null)
          LoopChipRow(
            key: const ValueKey<String>('dapp-chips'),
            children: <Widget>[
              LoopBadge(review.host!),
              LoopBadge(loopChainName(loopPrimaryChainId)),
              LoopBadge(
                switch (review.verdict) {
                  LoopUrlVerdict.normalized =>
                    context.l10n.wallet_deferredScreensNormalized2,
                  LoopUrlVerdict.flagged =>
                    context.l10n.wallet_deferredScreensFlagged2,
                  LoopUrlVerdict.blocked =>
                    context.l10n.wallet_deferredScreensBlocked,
                },
                kind: switch (review.verdict) {
                  LoopUrlVerdict.normalized => LoopBadgeKind.up,
                  LoopUrlVerdict.flagged => LoopBadgeKind.mining,
                  LoopUrlVerdict.blocked => LoopBadgeKind.mute,
                },
              ),
            ],
          ),
        LoopLabel(context.l10n.wallet_deferredScreensLoopLabel2),
        if (typed.isEmpty)
          LoopEmptyState(
            key: ValueKey<String>('dapp-review-empty'),
            illustration: LoopIllustration.search,
            title: context.l10n.wallet_deferredScreensLoopFolioPrimary,
            message: context.l10n.wallet_deferredScreensDappReviewEmptyMessage,
            compact: true,
          )
        else ...<Widget>[
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('dapp-review-typed'),
                title: context.l10n.wallet_deferredScreensDappReviewTypedTitle,
                subtitle: review.input,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('dapp-review-canonical'),
                title:
                    context.l10n.wallet_deferredScreensDappReviewCanonicalTitle,
                subtitle:
                    review.canonical?.toString() ??
                    context
                        .l10n
                        .wallet_deferredScreensDappReviewCanonicalSubtitle,
                trailingBadge: LoopBadge(
                  switch (review.verdict) {
                    LoopUrlVerdict.normalized =>
                      context.l10n.wallet_deferredScreensNormalized3,
                    LoopUrlVerdict.flagged =>
                      context.l10n.wallet_deferredScreensFlagged2,
                    LoopUrlVerdict.blocked =>
                      context.l10n.wallet_deferredScreensBlocked,
                  },
                  kind: switch (review.verdict) {
                    LoopUrlVerdict.normalized => LoopBadgeKind.up,
                    LoopUrlVerdict.flagged => LoopBadgeKind.mining,
                    LoopUrlVerdict.blocked => LoopBadgeKind.mute,
                  },
                ),
                position: LoopRowPosition.last,
              ),
            ],
          ),
          if (review.confusableReading != null)
            LoopNotice(
              key: const ValueKey<String>('dapp-confusable-notice'),
              icon: 'phishing',
              tone: LoopNoticeTone.danger,
              title:
                  context.l10n.wallet_deferredScreensDappConfusableNoticeTitle,
              body: context.l10n.wallet_deferredScreensDappConfusableNoticeBody(
                review.confusableReading,
              ),
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
            ),
          LoopLabel(context.l10n.wallet_deferredScreensLoopLabel3),
          if (review.findings.isEmpty)
            LoopEmptyState(
              key: ValueKey<String>('dapp-findings-empty'),
              illustration: LoopIllustration.search,
              title: context.l10n.wallet_deferredScreensDappFindingsEmptyTitle,
              message:
                  context.l10n.wallet_deferredScreensDappFindingsEmptyMessage,
              compact: true,
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final finding in review.findings)
                  LoopRecordRow(
                    key: ValueKey<String>('dapp-finding-${finding.name}'),
                    title: finding.explanation,
                    subtitle: finding.isBlocking
                        ? context.l10n.wallet_deferredScreensSubtitle
                        : context.l10n.wallet_deferredScreensSubtitle2,
                    trailingBadge: LoopBadge(
                      finding.isBlocking
                          ? context.l10n.wallet_deferredScreensSubtitle
                          : context.l10n.wallet_deferredScreensSubtitle2,
                      kind: finding.isBlocking
                          ? LoopBadgeKind.mute
                          : LoopBadgeKind.mining,
                    ),
                    position: LoopRowPosition.middle,
                  ),
              ],
            ),
        ],
        // With no address typed there is nothing to look up, and a second
        // empty group saying so was one more placeholder in a page the audit
        // already found full of them (item 5). The reputation group exists
        // once there is a domain to have one.
        if (typed.isNotEmpty) ...<Widget>[
          LoopLabel(context.l10n.wallet_deferredScreensLoopLabel4),
          LoopUnavailableLine(
            key: ValueKey<String>('dapp-reputation-unavailable'),
            label: context
                .l10n
                .wallet_deferredScreensDappReputationUnavailableLabel,
            reasonCode: DappReviewScreen.reputationReasonCode,
          ),
        ],
        LoopLabel(context.l10n.wallet_deferredScreensLoopLabel5),
        LoopUnavailableLine(
          key: const ValueKey<String>('dapp-execution-unavailable'),
          label:
              context.l10n.wallet_deferredScreensDappExecutionUnavailableLabel,
          reasonCode: _reasonFor(
            capability,
            DappReviewScreen.deferredReasonCode,
          ),
        ),
        // 连接钱包 and 签名请求 used to stand here as two dead buttons, and
        // the signing one was painted as the page's primary action. A tap got
        // nothing back, because there is nothing behind either of them: the
        // card above already states that connecting and signing are not open.
        // An action that cannot run is not offered as a button.
        const SizedBox(height: 20),
      ],
    );
  }
}
