import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The eight capability rows the prototype lists, as this build states them
/// while the capability itself is closed.
///
/// They are used only by the unavailable shell: once the surface is open the
/// server publishes its own eight rows, with its own words and its own
/// per-row reasons, and the client prints those instead.
const List<(String, String, String)> _communityAiScopes =
    <(String, String, String)>[
      ('book', '项目知识', '白皮书、Tokenomics、Roadmap、FAQ'),
      ('chat', '社区客服', 'CA 是什么、怎么买、怎么参与挖矿'),
      ('graduate', '新手教育', '3 分钟了解项目、新手指南、资产安全'),
      ('news', '项目动态', '官方 X、公告、Blog 汇总成日报周报'),
      ('chart', '资产信息', '价格、市值、流动性、权重、社区算力'),
      ('compass', '社区引导', '提醒你还没参与挖矿、权重已生效'),
      ('shield', 'AI 巡查', '检测诈骗链接、假 CA、钓鱼、假管理员'),
      ('smart', '社区分析', '仅管理员可见：DAU、转化、情绪变化'),
    ];

/// `#scr-community-ai .segs` — the three questions the prototype offers.
///
/// The closed page prints these; the open page prints the server's own three,
/// which are the same three and are still the server's to change.
const List<String> _communityAiSamples = <String>[
  'Tokenomics 怎么分配',
  '怎么参与挖矿',
  '这周有什么动态',
];

/// What the closed page says about itself in one line.
///
/// It is also the heading, so the caption must not repeat it; see
/// [communityAiHeroCaption].
const communityAiHeadline = 'Community AI 还没有开放';

/// The hero's second line: what is left of the server's own sentence, plus
/// what the page will hold once it opens.
String communityAiHeroCaption(String reason) {
  var rest = reason;
  if (rest.startsWith(communityAiHeadline)) {
    rest = rest.substring(communityAiHeadline.length);
    rest = rest.replaceFirst(RegExp('^[，,、。：:]'), '').trim();
  }
  const outlook = '开放后，回答会带上来源和观察时间，不替代项目方公告。';
  return rest.isEmpty ? outlook : '$rest$outlook';
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
              hintText: '问这个社区的 AI',
              sendLabel: '发送',
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
                const LoopLabel('我能做什么'),
                _CommunityAiAbilities(
                  key: const ValueKey<String>('community-ai-capabilities'),
                  capabilities: overview.capabilities,
                ),
                const LoopNotice(
                  key: ValueKey<String>('community-ai-scope-note'),
                  icon: 'info',
                  title: '只给数据和事实',
                  body: 'AI 只提供标注出处和时间的客观信息，不输出评级或结论，也不替你做投资决定。',
                  margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
                ),
                if (overview.exampleQuestions.isNotEmpty) ...<Widget>[
                  const LoopLabel('试试这些'),
                  Padding(
                    key: const ValueKey<String>('community-ai-samples'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
        kicker: 'COMMUNITY BRIEF',
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
      kicker: 'COMMUNITY BRIEF',
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
          ? '已提交举报'
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
      CommunityViewPhase.empty => const LoopEmpty(
        key: ValueKey<String>('community-ai-state-empty'),
        message: '这个社区还没有可以问的内容',
      ),
      CommunityViewPhase.offline => LoopOfflineState(
        key: const ValueKey<String>('community-ai-state-offline'),
        onRetry: onRetry,
        pausedActions: const <String>['提问', '举报'],
      ),
      CommunityViewPhase.unavailable => LoopEmpty(
        key: const ValueKey<String>('community-ai-state-unavailable'),
        icon: 'warn',
        message: '这一页暂时不可用',
        reason: reason,
      ),
      CommunityViewPhase.permission => LoopPermissionState(
        key: const ValueKey<String>('community-ai-state-permission'),
        icon: 'shield',
        title: '当前账号还不能用这个助理',
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
      return const LoopEmpty(
        key: ValueKey<String>('community-ai-capabilities-empty'),
        message: '这个社区还没有开放的助理能力',
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
                : const LoopBadge('未开放'),
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
            body: '正在回答…',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LoopColors.limeSoft,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(LoopRadius.controlValue),
                  topEnd: LoopRadius.bubbleTail,
                  bottomStart: Radius.circular(LoopRadius.controlValue),
                  bottomEnd: Radius.circular(LoopRadius.controlValue),
                ),
              ),
              child: Text(question, style: LoopTypography.body(13)),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LoopGround.fillOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: LoopGround.hairlineOf(context)),
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
                  style: LoopTypography.caption(
                    11,
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
                    // `.msg-txt{border-radius:5px 16px 16px 16px}`.
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: LoopRadius.bubbleTail,
                      topEnd: Radius.circular(LoopRadius.controlValue),
                      bottomStart: Radius.circular(LoopRadius.controlValue),
                      bottomEnd: Radius.circular(LoopRadius.controlValue),
                    ),
                  ),
                  child: Text(
                    body,
                    style: LoopTypography.body(
                      13,
                      color: LoopGround.secondaryOf(context),
                    ),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LoopGround.fillOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: LoopGround.hairlineOf(context)),
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
                      style: LoopTypography.caption(
                        11,
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
                          topEnd: Radius.circular(LoopRadius.controlValue),
                          bottomStart: Radius.circular(LoopRadius.controlValue),
                          bottomEnd: Radius.circular(LoopRadius.controlValue),
                        ),
                      ),
                      child: _CommunityAiAnswerText(runs: runs),
                    ),
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
                        summary: '本次使用的来源（${answer.sources.length}）',
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
                        label: reported ? '已举报' : '举报这条回答',
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
                                  LoopIcon(
                                    'warn',
                                    size: 13,
                                    color: LoopColors.text3,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    reported ? '已举报' : '举报',
                                    style: LoopTypography.caption(
                                      11,
                                      color: LoopColors.text3,
                                    ),
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
    final style = LoopTypography.body(
      13,
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
      label: '来源 ${source.sourceId}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('community-ai-citation-${source.sourceId}'),
          onTap: () => showCommunityAiSourceSheet(context, source: source),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: LoopColors.limeSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ExcludeSemantics(
              child: Text(
                '[${source.sourceId}]',
                style: LoopTypography.figure(11, color: LoopColors.lime),
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
                  '${source.label} · 观察于 '
                  '${communityAiTimestamp(source.observedAt)}',
                  style: LoopTypography.caption(11, color: LoopColors.text3),
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
      summary: '本次未使用的来源（${omitted.length}）',
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
                  style: LoopTypography.caption(11, color: LoopColors.text3),
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
          ? const EdgeInsets.fromLTRB(16, 8, 16, 0)
          : const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const LoopIcon('ai', size: 12, color: LoopColors.text3),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              communityAiGeneratedLabel(model: model, generatedAt: generatedAt),
              style: LoopTypography.figure(11, color: LoopColors.text3),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LoopTypography.caption(11, color: LoopColors.text3),
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
  barrierLabel: '关闭来源说明',
  builder: (sheetContext) => Padding(
    key: const ValueKey<String>('community-ai-source-sheet'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          source.label,
          style: LoopTypography.heading(18, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '观察于 ${communityAiTimestamp(source.observedAt)}',
          style: LoopTypography.figure(12, color: LoopColors.text3),
        ),
        const SizedBox(height: 18),
        LoopButtonPair(
          padded: false,
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('community-ai-source-close'),
              label: '知道了',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ],
    ),
  ),
);

/// Why this answer is being reported. One choice, and it is submitted as it
/// is chosen: a report is a single fact, not a form.
Future<CommunityAiReportReason?> showCommunityAiReportSheet(
  BuildContext context,
) => showLoopSheet<CommunityAiReportReason>(
  context,
  barrierLabel: '关闭举报选项',
  builder: (sheetContext) => Padding(
    key: const ValueKey<String>('community-ai-report-sheet'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '举报这条回答',
          style: LoopTypography.heading(18, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '选择一个原因。举报只记录这条回答和你的选择，不会上传你问过的问题。',
          style: LoopTypography.body(13, color: LoopColors.muted),
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
              label: '取消',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ],
    ),
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
        kicker: 'COMMUNITY BRIEF',
        heading: communityAiHeadline,
        caption: communityAiHeroCaption(reason),
      ),
      composer: const LoopComposer(
        key: ValueKey<String>('community-ai-composer-unavailable'),
        hintText: '提问还没有开放',
        sendLabel: '发送',
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
          const LoopLabel('规划中的能力'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (var index = 0; index < _communityAiScopes.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'community-ai-scope-${_communityAiScopes[index].$2}',
                  ),
                  leading: LoopIcon(
                    _communityAiScopes[index].$1,
                    size: 18,
                    color: LoopColors.text3,
                  ),
                  title: _communityAiScopes[index].$2,
                  subtitle: _communityAiScopes[index].$3,
                  trailingBadge: const LoopBadge('未开放'),
                  position: communityRowPosition(
                    index,
                    _communityAiScopes.length,
                  ),
                ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('community-ai-scope-note'),
            icon: 'info',
            title: '只给数据和事实',
            body: '之后的 AI 只提供标注出处和时间的客观信息，不输出评级或结论，也不替你做投资决定。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopLabel('试试这些'),
          Padding(
            key: const ValueKey<String>('community-ai-samples'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                for (final sample in _communityAiSamples)
                  IntrinsicWidth(
                    child: LoopSeg(
                      key: ValueKey<String>('community-ai-sample-$sample'),
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
