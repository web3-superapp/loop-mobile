import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The eight capability rows the prototype lists, restated as a scope
/// description. None of them has a runtime in this step.
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
/// They are the prototype's own wording and nothing else: a sample question
/// is a question, not an answer, so printing it claims no knowledge base,
/// no digest and no figure. None of them can be asked yet, so none of them
/// is a control.
const List<String> _communityAiSamples = <String>[
  'Tokenomics 怎么分配',
  '怎么参与挖矿',
  '这周有什么动态',
];

/// What the page says about itself in one line.
///
/// It is also the heading, so the caption must not repeat it; see
/// [communityAiHeroCaption].
const communityAiHeadline = 'Community AI 还没有开放';

/// The hero's second line: what is left of the server's own sentence, plus
/// what the page will hold once it opens.
///
/// The server's reason for this capability starts with the same words as the
/// heading, and one screen must not say the same thing twice, so the shared
/// opening is dropped and the rest of the sentence is kept verbatim. A
/// different reason — a code this build has no sentence for — is carried
/// whole.
String communityAiHeroCaption(String reason) {
  var rest = reason;
  if (rest.startsWith(communityAiHeadline)) {
    rest = rest.substring(communityAiHeadline.length);
    rest = rest.replaceFirst(RegExp('^[，,、。：:]'), '').trim();
  }
  const outlook = '开放后，回答会带上来源和观察时间，不替代项目方公告。';
  return rest.isEmpty ? outlook : '$rest$outlook';
}

/// `community-ai` · the prototype's chat page, closed end to end.
///
/// The community record's AI button used to answer with a toast, which took
/// the reason away again and read as a control that does nothing (device
/// report 2026-09-22). The button opens this page instead, and the page is
/// the prototype's: the bar, the hero, the assistant's first message, what it
/// will be able to do, the sample questions and the composer at the bottom.
///
/// Every one of those is unavailable, and each says so where it stands: the
/// composer takes no text and sends nothing, the sample questions are not
/// controls, and the reply area carries the server's own reason instead of an
/// answer. The prototype's knowledge-base count, daily-digest figure and
/// sample answer are deliberately not reproduced: none of them has a source.
class CommunityAiScreen extends ConsumerWidget {
  const CommunityAiScreen({super.key, this.communityId, this.onBack});

  final String? communityId;
  final VoidCallback? onBack;

  static const _deferred = 'COMMUNITY_AI_RUNTIME_DEFERRED';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityAi),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final reason = communicationUnavailableReason(
      capability.reasonCode ?? _deferred,
    );

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
      // The bar the prototype ends the page with, with nothing behind it: the
      // field takes no text and the send control cannot act.
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
            reason: reason,
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
                  position: index == 0
                      ? LoopRowPosition.first
                      : index == _communityAiScopes.length - 1
                      ? LoopRowPosition.last
                      : LoopRowPosition.middle,
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
                  // `.seg` shrink-wraps its label in the prototype's row. A
                  // chip laid out in a wrap is handed the whole line instead,
                  // and a segment that spans the page reads as a button.
                  IntrinsicWidth(
                    child: LoopSeg(
                      key: ValueKey<String>('community-ai-sample-$sample'),
                      label: sample,
                      selected: false,
                      // Not a control: there is nothing to ask, so the chip
                      // carries the question and takes no tap at all. The page
                      // has already said why, in three places.
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

/// `.msg` with `.msg-av` / `.msg-who` / `.msg-txt`: the assistant's turn.
///
/// It keeps the prototype's bubble so the page reads as the conversation it
/// will be, and puts the reason where the answer would go. The bubble is
/// never Lime: Lime marks a reply that arrived.
class _CommunityAiReply extends StatelessWidget {
  const _CommunityAiReply({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `.msg{padding:8px 16px;gap:10px}`.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    reason,
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
