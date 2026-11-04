import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_ai_controller.dart';
import 'package:loop_mobile/features/community/community_ai_gateway.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The eight capability rows the prototype lists, as this build states them
/// while the capability itself is closed.
///
/// They are used only by the unavailable shell: once the surface is open the
/// server publishes its own eight rows, with its own words and its own
/// per-row reasons, and the client prints those instead.
List<(String, String, String)> get _communityAiScopes =>
    <(String, String, String)>[
      (
        'book',
        LoopL10n.current.community_aiText,
        LoopL10n.current.community_aiText2,
      ),
      (
        'chat',
        LoopL10n.current.community_aiText3,
        LoopL10n.current.community_aiText4,
      ),
      (
        'graduate',
        LoopL10n.current.community_aiText5,
        LoopL10n.current.community_aiText6,
      ),
      (
        'news',
        LoopL10n.current.community_aiText7,
        LoopL10n.current.community_aiText8,
      ),
      (
        'chart',
        LoopL10n.current.community_aiText9,
        LoopL10n.current.community_aiText10,
      ),
      (
        'compass',
        LoopL10n.current.community_aiText11,
        LoopL10n.current.community_aiText12,
      ),
      (
        'shield',
        LoopL10n.current.community_aiText13,
        LoopL10n.current.community_aiText14,
      ),
      (
        'smart',
        LoopL10n.current.community_aiText15,
        LoopL10n.current.community_aiText16,
      ),
    ];

/// `#scr-community-ai .segs` — the three questions the prototype offers.
///
/// The closed page prints these; the open page prints the server's own three,
/// which are the same three and are still the server's to change.
List<String> get _communityAiSamples => <String>[
  LoopL10n.current.community_aiText17,
  LoopL10n.current.community_aiText18,
  LoopL10n.current.community_aiText19,
];

/// What the closed page says about itself in one line.
///
/// It is also the heading, so the caption must not repeat it; see
/// [communityAiHeroCaption].
String get communityAiHeadline =>
    LoopL10n.current.community_aiCommunityAiHeadline;

/// The hero's second line: what is left of the server's own sentence, plus
/// what the page will hold once it opens.
String communityAiHeroCaption(String reason) {
  var rest = reason;
  if (rest.startsWith(communityAiHeadline)) {
    rest = rest.substring(communityAiHeadline.length);
    rest = rest.replaceFirst(RegExp('^[，,、。：:]'), '').trim();
  }
  final outlook = LoopL10n.current.community_aiOutlook;
  return rest.isEmpty
      ? outlook
      : '$rest${LoopL10n.current.community_aiSentenceGap}$outlook';
}

/// `community-ai` · the prototype's chat page.
///
/// Two pages share one route, and the capability document decides which. With
/// `communityAi` closed the page is the prototype's shape with nothing behind
/// it — the bar, the hero, the abilities, the sample questions and a composer
/// that takes no text — and every one of those says so where it stands. With
/// it open the same shape is filled by the server: the knowledge snapshot in
/// the bar, today's brief in the hero, the server's own eight abilities, its
/// three example questions, and a conversation in which every reply carries
/// the model that wrote it, the sources it used and a way to report it.
///
/// What is never reproduced, in either state, is the prototype's
/// 「知识库 14 篇文档」: there is no document corpus behind LOOP, and the
/// contract publishes a live-source count instead.
class CommunityAiScreen extends ConsumerStatefulWidget {
  const CommunityAiScreen({super.key, this.communityId, this.onBack});

  final String? communityId;
  final VoidCallback? onBack;

  static const deferredReasonCode = 'COMMUNITY_AI_RUNTIME_DEFERRED';

  @override
  ConsumerState<CommunityAiScreen> createState() => _CommunityAiScreenState();
}

class _CommunityAiScreenState extends ConsumerState<CommunityAiScreen> {
  final TextEditingController _composer = TextEditingController();

  /// The gateway the overview was last asked for.
  ///
  /// The controller starts over whenever the gateway behind it changes — a
  /// session that arrives, a transport that is assembled — and a page that
  /// asked once would then sit on a skeleton nothing was going to fill. The
  /// read is tied to the gateway instead of to the first build.
  CommunityAiGateway? _requestedFrom;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _requestOverview(CommunityAiGateway gateway) {
    if (identical(_requestedFrom, gateway)) return;
    _requestedFrom = gateway;
    final id = widget.communityId!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(communityAiControllerProvider(id).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityAi),
    );
    final communityId = widget.communityId;
    if (communityId == null || !capability.isAvailable) {
      return _CommunityAiClosedPage(
        reason: communicationUnavailableReason(
          capability.reasonCode ?? CommunityAiScreen.deferredReasonCode,
        ),
        onBack: widget.onBack,
      );
    }
    _requestOverview(ref.watch(communityAiGatewayProvider));
    final state = ref.watch(communityAiControllerProvider(communityId));
    final controller = ref.read(
      communityAiControllerProvider(communityId).notifier,
    );
    final overview = state.overview;

    return LoopStreamPage(
      key: const ValueKey<String>('community-ai-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Community AI',
      subtitle: overview == null
          ? null
          : communityAiKnowledgeLine(overview.knowledge),
      onBack: widget.onBack,
      updating: state.refreshing,
      // The summary is written behind the read that missed it, so the page
      // has to be re-readable by hand as well as by its one timer.
      onRefresh: overview == null ? null : controller.reload,
      folio: overview == null ? null : _briefFolio(overview.brief),
      block: overview == null
          ? _CommunityAiStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              reasonCode: state.reasonCode,
              onRetry: controller.reload,
            )
          : null,
      footnote: state.disclaimer == null
          ? null
          : _CommunityAiDisclaimer(text: state.disclaimer!),
      composer: overview == null
          ? null
          : LoopComposer(
              key: const ValueKey<String>('community-ai-composer'),
              controller: _composer,
              hintText: context.l10n.community_aiCommunityAiComposerHintText,
              sendLabel: context.l10n.common_send,
              enabled: !state.asking,
              onSend: state.asking
                  ? null
                  : (String text) {
                      if (text.trim().isEmpty) return;
                      _composer.clear();
                      controller.ask(text);
                    },
            ),
      collection: overview == null
          ? const SizedBox.shrink()
          : ListView(
              key: const ValueKey<String>('community-ai-collection'),
              padding: const EdgeInsets.only(bottom: 20),
              children: <Widget>[
                if (overview.brief case final CommunityAiBriefAvailable brief)
                  _CommunityAiGeneratedMark(
                    key: const ValueKey<String>('community-ai-brief-mark'),
                    model: brief.model,
                    generatedAt: brief.generatedAt,
                  ),
                for (var index = 0; index < state.turns.length; index += 1)
                  _CommunityAiTurnBlock(
                    key: ValueKey<String>('community-ai-turn-$index'),
                    index: index,
                    turn: state.turns[index],
                    onReport: (answerId) =>
                        _report(controller, answerId: answerId),
                  ),
                LoopLabel(context.l10n.community_aiLoopLabel),
                _CommunityAiAbilities(
                  key: const ValueKey<String>('community-ai-capabilities'),
                  capabilities: overview.capabilities,
                ),
                if (overview.exampleQuestions.isNotEmpty) ...<Widget>[
                  LoopLabel(context.l10n.community_aiLoopLabel2),
                  Padding(
                    key: const ValueKey<String>('community-ai-samples'),
                    padding: const EdgeInsets.fromLTRB(
                      LoopSpacing.page,
                      0,
                      LoopSpacing.page,
                      10,
                    ),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        for (final sample in overview.exampleQuestions)
                          // `.seg` shrink-wraps its label in the prototype's
                          // row; a chip handed the whole line reads as a
                          // button.
                          IntrinsicWidth(
                            child: LoopSeg(
                              key: ValueKey<String>(
                                'community-ai-sample-$sample',
                              ),
                              label: sample,
                              selected: false,
                              // A sample fills the composer rather than
                              // sending itself: the question is still the
                              // reader's to change, and to spend.
                              onSelected: state.asking
                                  ? null
                                  : () => _fill(sample),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  void _fill(String sample) {
    _composer
      ..text = sample
      ..selection = TextSelection.collapsed(offset: sample.length);
  }

  LoopFolioPrimary _briefFolio(CommunityAiBrief brief) {
    if (brief case final CommunityAiBriefAvailable summary) {
      return LoopFolioPrimary(
        key: const ValueKey<String>('community-ai-hero'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        ring: false,
        headingTone: LoopFolioHeadingTone.neutral,
        kicker: LoopL10n.current.community_aiCommunityAiHeroKicker,
        heading: communityAiBriefHeading(summary),
        caption: summary.summary,
      );
    }
    // A summary still being written, and a budget spent for today, are states
    // rather than failures: the hero says so plainly and offers no 重试,
    // because nothing here failed that retrying would mend.
    final absence = communityAiBriefAbsence(
      brief as CommunityAiBriefUnavailable,
    );
    return LoopFolioPrimary(
      key: const ValueKey<String>('community-ai-hero'),
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.listing,
      ring: false,
      headingTone: LoopFolioHeadingTone.neutral,
      kicker: LoopL10n.current.community_aiCommunityAiHeroKicker,
      heading: absence.heading,
      caption: absence.caption,
    );
  }

  Future<void> _report(
    CommunityAiController controller, {
    required String answerId,
  }) async {
    final reason = await showCommunityAiReportSheet(context);
    if (reason == null || !mounted) return;
    final failure = await controller.report(answerId: answerId, reason: reason);
    if (!mounted) return;
    LoopToast.show(
      context,
      message: failure == null
          ? LoopL10n.current.community_aiMessage
          : communityAiFailureReason(
              kind: failure.kind,
              reasonCode: failure.reasonCode,
              scope: failure.scope,
            ),
      kind: failure == null ? LoopToastKind.ok : LoopToastKind.warn,
    );
  }
}

/// The five reviewed states of the overview read, each with the server's own
/// reason when the server gave one.
class _CommunityAiStateBlock extends StatelessWidget {
  const _CommunityAiStateBlock({
    required this.phase,
    required this.failureKind,
    required this.reasonCode,
    required this.onRetry,
  });

  final CommunityViewPhase phase;
  final CommunityFailureKind? failureKind;
  final String? reasonCode;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final reason = communityAiFailureReason(
      kind: failureKind,
      reasonCode: reasonCode,
    );
    return switch (phase) {
      CommunityViewPhase.loading => const LoopSkeleton(
        key: ValueKey<String>('community-ai-state-loading'),
        type: LoopSkeletonType.list,
        rows: 3,
      ),
      CommunityViewPhase.empty => LoopEmptyState(
        key: ValueKey<String>('community-ai-state-empty'),
        illustration: LoopIllustration.chat,
        title: context.l10n.community_aiCommunityAiStateEmptyTitle,
        compact: true,
      ),
      CommunityViewPhase.offline => LoopOfflineState(
        key: const ValueKey<String>('community-ai-state-offline'),
        onRetry: onRetry,
        pausedActions: <String>[
          context.l10n.community_aiLoopOfflineState,
          context.l10n.common_report,
        ],
      ),
      CommunityViewPhase.unavailable => LoopInlineUnavailable(
        key: const ValueKey<String>('community-ai-state-unavailable'),
        message: context.l10n.community_aiCommunityAiStateUnavailableMessage,
        detail: reason,
        maxLines: 2,
        detailMaxLines: 4,
      ),
      CommunityViewPhase.permission => LoopPermissionState(
        key: const ValueKey<String>('community-ai-state-permission'),
        icon: 'shield',
        title: context.l10n.community_aiCommunityAiStatePermissionTitle,
        purpose: reason,
      ),
      CommunityViewPhase.error || CommunityViewPhase.ready => LoopErrorState(
        key: const ValueKey<String>('community-ai-state-error'),
        reason: reason,
        onRetry: onRetry,
      ),
    };
  }
}

/// The eight ability rows, exactly as the server published them.
class _CommunityAiAbilities extends StatelessWidget {
  const _CommunityAiAbilities({required this.capabilities, super.key});

  final List<CommunityAiCapability> capabilities;

  @override
  Widget build(BuildContext context) {
    if (capabilities.isEmpty) {
      return LoopEmptyState(
        key: ValueKey<String>('community-ai-capabilities-empty'),
        illustration: LoopIllustration.chat,
        title: context.l10n.community_aiCommunityAiCapabilitiesEmptyTitle,
        compact: true,
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (var index = 0; index < capabilities.length; index += 1)
          LoopRecordRow(
            key: ValueKey<String>(
              'community-ai-capability-${capabilities[index].ability.wireName}',
            ),
            leading: LoopIcon(
              capabilities[index].ability.icon,
              size: 18,
              color: capabilities[index].available
                  ? LoopColors.chalk
                  : LoopColors.text3,
            ),
            title: capabilities[index].title,
            subtitle: capabilities[index].available
                ? capabilities[index].summary
                : '${capabilities[index].summary} · '
                      '${communityAiReason(capabilities[index].reasonCode)}',
            subtitleMaxLines: 2,
            trailingBadge: capabilities[index].available
                ? null
                : LoopBadge(context.l10n.common_notOpenYet),
            chevron: false,
            position: communityRowPosition(index, capabilities.length),
          ),
      ],
    );
  }
}

/// One exchange: what was asked, and the reply or the reason there is none.
class _CommunityAiTurnBlock extends StatelessWidget {
  const _CommunityAiTurnBlock({
    required this.index,
    required this.turn,
    required this.onReport,
    super.key,
  });

  final int index;
  final CommunityAiTurn turn;
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    final answer = turn.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CommunityAiQuestionBubble(
          key: ValueKey<String>('community-ai-turn-$index-question'),
          question: turn.question,
        ),
        if (answer != null)
          _CommunityAiAnswerBubble(
            key: ValueKey<String>('community-ai-turn-$index-answer'),
            answer: answer,
            reported: turn.reported,
            onReport: () => onReport(answer.answerId),
          )
        else if (turn.isPending)
          _CommunityAiReply(
            key: ValueKey<String>('community-ai-turn-$index-pending'),
            body: context.l10n.community_aiBody,
          )
        else
          _CommunityAiReply(
            key: ValueKey<String>('community-ai-turn-$index-failure'),
            body: communityAiFailureReason(
              kind: turn.failureKind,
              reasonCode: turn.reasonCode,
              scope: turn.scope,
            ),
          ),
      ],
    );
  }
}

/// `.msg.me` — the reader's own turn, right-aligned.
class _CommunityAiQuestionBubble extends StatelessWidget {
  const _CommunityAiQuestionBubble({required this.question, super.key});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        12,
        LoopSpacing.page,
        4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LoopColors.purple,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(LoopRadius.bubbleValue),
                  topEnd: LoopRadius.bubbleTail,
                  bottomStart: Radius.circular(LoopRadius.bubbleValue),
                  bottomEnd: Radius.circular(LoopRadius.bubbleValue),
                ),
              ),
              child: Text(
                question,
                style: LoopType.bodySm.copyWith(color: LoopColors.onPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.msg` with `.msg-av` / `.msg-who` / `.msg-txt`: the assistant's turn.
///
/// The bubble is never Lime: Lime marks the reader's own words and this app's
/// success colour, and an answer written by a model is neither.
class _CommunityAiReply extends StatelessWidget {
  const _CommunityAiReply({required this.body, super.key});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `.msg{padding:8px 16px;gap:10px}`.
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        8,
        LoopSpacing.page,
        8,
      ),
      child: _CommunityAiTurn(
        bubble: Text(
          body,
          style: LoopType.bodySm.copyWith(
            color: LoopGround.secondaryOf(context),
          ),
        ),
      ),
    );
  }
}

/// The assistant's one turn shape (decision 0172): the 34 round `ai` mark,
/// 「Community AI」 and the `.msg-txt` bubble
/// (`border-radius:5px 16px 16px 16px`), then whatever the turn adds under
/// the bubble. A pending line, a refusal and an answer all draw this.
class _CommunityAiTurn extends StatelessWidget {
  const _CommunityAiTurn({required this.bubble, this.after = const <Widget>[]});

  final Widget bubble;
  final List<Widget> after;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LoopGround.fillOf(context),
            shape: BoxShape.circle,
          ),
          child: const LoopIcon('ai', size: 16, color: LoopColors.text3),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Community AI',
                style: LoopType.captionSm.copyWith(
                  color: LoopGround.secondaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: LoopGround.fillOf(context),
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: LoopRadius.bubbleTail,
                    topEnd: Radius.circular(LoopRadius.bubbleValue),
                    bottomStart: Radius.circular(LoopRadius.bubbleValue),
                    bottomEnd: Radius.circular(LoopRadius.bubbleValue),
                  ),
                ),
                child: bubble,
              ),
              ...after,
            ],
          ),
        ),
      ],
    );
  }
}

/// One model-written answer: the words, the handles it cited, what it was
/// based on, and the way to report it.
class _CommunityAiAnswerBubble extends StatelessWidget {
  const _CommunityAiAnswerBubble({
    required this.answer,
    required this.reported,
    required this.onReport,
    super.key,
  });

  final CommunityAiAnswer answer;
  final bool reported;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final runs = communityAiAnswerRuns(answer.spoken, answer.citations);
    return Semantics(
      container: true,
      child: GestureDetector(
        // The prototype's own gesture for a message: hold it to act on it.
        // The visible control below is the same action, because a gesture
        // nobody can see is not an entry point.
        onLongPress: reported ? null : onReport,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            8,
            LoopSpacing.page,
            8,
          ),
          child: _CommunityAiTurn(
            bubble: _CommunityAiAnswerText(runs: runs),
            after: <Widget>[
              _CommunityAiGeneratedMark(
                model: answer.model,
                generatedAt: answer.generatedAt,
                padded: false,
              ),
              if (answer.sources.isNotEmpty)
                _CommunityAiSourceList(
                  key: ValueKey<String>(
                    'community-ai-sources-${answer.answerId}',
                  ),
                  summary: context.l10n.community_aiSummary(
                    answer.sources.length,
                  ),
                  sources: answer.sources,
                ),
              if (answer.omittedSources.isNotEmpty)
                _CommunityAiOmittedList(
                  key: ValueKey<String>(
                    'community-ai-omitted-${answer.answerId}',
                  ),
                  omitted: answer.omittedSources,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  button: !reported,
                  label: reported
                      ? context.l10n.community_aiLabel
                      : context.l10n.community_aiLabel2,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: ValueKey<String>(
                        'community-ai-report-${answer.answerId}',
                      ),
                      onTap: reported ? null : onReport,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: LoopTouch.minimum,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            LoopIcon('warn', size: 13, color: LoopColors.text3),
                            const SizedBox(width: 5),
                            Text(
                              reported
                                  ? context.l10n.community_aiLabel
                                  : context.l10n.common_report,
                              style: LoopType.captionSm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The answer's words, with each `[sN]` it cited rendered as a control.
class _CommunityAiAnswerText extends StatelessWidget {
  const _CommunityAiAnswerText({required this.runs});

  final List<CommunityAiAnswerRun> runs;

  @override
  Widget build(BuildContext context) {
    final style = LoopType.bodySm.copyWith(
      color: LoopGround.secondaryOf(context),
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          for (final run in runs)
            switch (run) {
              CommunityAiAnswerText(:final text) => TextSpan(
                text: text,
                style: style,
              ),
              CommunityAiAnswerCitation(:final source) => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _CommunityAiCitationChip(source: source),
              ),
            },
        ],
      ),
      style: style,
    );
  }
}

/// `[s2]` as the reader sees it: a handle that opens the source behind it.
class _CommunityAiCitationChip extends StatelessWidget {
  const _CommunityAiCitationChip({required this.source});

  final CommunityAiSource source;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.community_aiLabel3(source.sourceId),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('community-ai-citation-${source.sourceId}'),
          onTap: () => showCommunityAiSourceSheet(context, source: source),
          borderRadius: LoopRadius.badge,
          // Decision 0172: the handle is the shared `.badge` (LimeSoft,
          // Lime), not a hand-drawn r6 block.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ExcludeSemantics(
              child: LoopBadge(
                '[${source.sourceId}]',
                kind: LoopBadgeKind.launch,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the sources of one answer were.
class _CommunityAiSourceList extends StatelessWidget {
  const _CommunityAiSourceList({
    required this.summary,
    required this.sources,
    super.key,
  });

  final String summary;
  final List<CommunityAiSource> sources;

  @override
  Widget build(BuildContext context) {
    return LoopDisclosure(
      summary: summary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.community_aiBuild(
                    communityAiTimestamp(source.observedAt),
                    source.label,
                  ),
                  style: LoopType.captionSm,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What this answer could *not* be based on, and why.
class _CommunityAiOmittedList extends StatelessWidget {
  const _CommunityAiOmittedList({required this.omitted, super.key});

  final List<CommunityAiOmittedSource> omitted;

  @override
  Widget build(BuildContext context) {
    return LoopDisclosure(
      summary: context.l10n.community_aiSummary2(omitted.length),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final entry in omitted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  communityAiReason(entry.reasonCode),
                  style: LoopType.captionSm,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The AI mark: which model wrote this, and when.
class _CommunityAiGeneratedMark extends StatelessWidget {
  const _CommunityAiGeneratedMark({
    required this.model,
    required this.generatedAt,
    super.key,
    this.padded = true,
  });

  final String model;
  final DateTime generatedAt;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded
          ? const EdgeInsets.fromLTRB(LoopSpacing.page, 8, LoopSpacing.page, 0)
          : const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const LoopIcon('ai', size: 12, color: LoopColors.text3),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              communityAiGeneratedLabel(model: model, generatedAt: generatedAt),
              style: LoopType.captionSm,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one line that never leaves the foot of the conversation.
class _CommunityAiDisclaimer extends StatelessWidget {
  const _CommunityAiDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('community-ai-disclaimer'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        8,
        LoopSpacing.page,
        8,
      ),
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LoopType.captionSm,
      ),
    );
  }
}

/// What one cited source is, and when it was observed.
Future<void> showCommunityAiSourceSheet(
  BuildContext context, {
  required CommunityAiSource source,
}) => showLoopSheet<void>(
  context,
  barrierLabel: context.l10n.community_aiCommunityAiSourceSheetBarrierLabel,
  builder: (sheetContext) => Column(
    key: const ValueKey<String>('community-ai-source-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopSheetHeading(source.label),
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
            Text(
              context.l10n.community_aiBuild2(
                communityAiTimestamp(source.observedAt),
              ),
              // L2 R21 provenance: captionSm 11 (decision 0191).
              style: LoopType.captionSm,
            ),
            const SizedBox(height: 18),
            LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('community-ai-source-close'),
                  label: context.l10n.common_gotIt,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

/// Why this answer is being reported. One choice, and it is submitted as it
/// is chosen: a report is a single fact, not a form.
Future<CommunityAiReportReason?> showCommunityAiReportSheet(
  BuildContext context,
) => showLoopSheet<CommunityAiReportReason>(
  context,
  barrierLabel: context.l10n.community_aiCommunityAiReportSheetBarrierLabel,
  builder: (sheetContext) => Column(
    key: const ValueKey<String>('community-ai-report-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopSheetHeading(context.l10n.community_aiLabel2),
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
            Text(
              context.l10n.community_aiBuild3,
              // R19 sheet support copy in text2 (decision 0191 L1).
              style: LoopType.bodySm,
            ),
            const SizedBox(height: 12),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (
                  var index = 0;
                  index < CommunityAiReportReason.values.length;
                  index += 1
                )
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'community-ai-report-reason-'
                      '${CommunityAiReportReason.values[index].wireName}',
                    ),
                    title: CommunityAiReportReason.values[index].label,
                    onTap: () =>
                        Navigator.of(sheetContext)
                            .pop(CommunityAiReportReason.values[index]),
                    position: communityRowPosition(
                      index,
                      CommunityAiReportReason.values.length,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('community-ai-report-cancel'),
                  label: context.l10n.common_cancel,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

/// The prototype's page with nothing behind it.
///
/// It is what the route renders while `communityAi` is not `available`, and
/// what it renders when there is no community to ask about. Every part of it
/// says so where it stands: the composer takes no text, the sample questions
/// are not controls, and the reply area carries the server's own reason
/// instead of an answer.
class _CommunityAiClosedPage extends ConsumerWidget {
  const _CommunityAiClosedPage({required this.reason, this.onBack});

  final String reason;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(communityGatewayProvider).mode;
    return LoopStreamPage(
      key: const ValueKey<String>('community-ai-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Community AI',
      kicker: communityPreviewKicker(mode),
      onBack: onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('community-ai-hero'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        ring: false,
        // Lime is this app's success colour; a closed capability is not good
        // news, so the heading stays Chalk.
        headingTone: LoopFolioHeadingTone.neutral,
        kicker: context.l10n.community_aiCommunityAiHeroKicker,
        heading: communityAiHeadline,
        caption: communityAiHeroCaption(reason),
      ),
      composer: LoopComposer(
        key: ValueKey<String>('community-ai-composer-unavailable'),
        hintText:
            context.l10n.community_aiCommunityAiComposerUnavailableHintText,
        sendLabel: context.l10n.common_send,
        enabled: false,
      ),
      collection: ListView(
        key: const ValueKey<String>('community-ai-collection'),
        padding: const EdgeInsets.only(bottom: 20),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: 'Community AI'),
          // `.msg` — the room's first message is the assistant's. It has
          // nothing to answer with, so it states why, in the server's words.
          _CommunityAiReply(
            key: const ValueKey<String>('community-ai-unavailable'),
            body: reason,
          ),
          LoopLabel(context.l10n.community_aiLoopLabel3),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (var index = 0; index < _communityAiScopes.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'community-ai-scope-${_communityAiScopes[index].$1}',
                  ),
                  leading: LoopIcon(
                    _communityAiScopes[index].$1,
                    size: 18,
                    color: LoopColors.text3,
                  ),
                  title: _communityAiScopes[index].$2,
                  subtitle: _communityAiScopes[index].$3,
                  trailingBadge: LoopBadge(context.l10n.common_notOpenYet),
                  position: communityRowPosition(
                    index,
                    _communityAiScopes.length,
                  ),
                ),
            ],
          ),
          LoopLabel(context.l10n.community_aiLoopLabel2),
          Padding(
            key: const ValueKey<String>('community-ai-samples'),
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              10,
            ),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                for (final (index, sample) in _communityAiSamples.indexed)
                  IntrinsicWidth(
                    child: LoopSeg(
                      key: ValueKey<String>('community-ai-sample-$index'),
                      label: sample,
                      selected: false,
                      // Not a control: there is nothing to ask, so the chip
                      // carries the question and takes no tap at all.
                      onSelected: null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
