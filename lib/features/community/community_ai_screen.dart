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

/// `community-ai` · restored layout, entirely unavailable.
///
/// Every functional area is closed with the server's own
/// `COMMUNITY_AI_RUNTIME_DEFERRED`. The prototype's sample answer, knowledge
/// base figure, daily digest count and suggested prompts are deliberately not
/// reproduced: none of them has a source.
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
    final reasonCode = capability.reasonCode ?? _deferred;

    return LoopDashboardPage(
      key: const ValueKey<String>('community-ai-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Community AI',
      kicker: communityPreviewKicker(mode),
      onBack: onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: 'COMMUNITY BRIEF',
        heading: 'Community AI',
        caption:
            '摘要与问答会保留来源与观察时间，不替代项目方公告，也不替你做投资决定。'
            '当前还没有可用的运行时，本页不展示任何示例回答或统计数字。',
      ),
      sections: <Widget>[
        LoopEmpty(
          key: const ValueKey<String>('community-ai-unavailable'),
          icon: 'ai',
          message: 'Community AI 当前不可用',
          reason: communicationUnavailableReason(reasonCode),
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
                trailingBadge: const LoopBadge('未接入'),
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
          body: '未来的 AI 只提供带来源与观察时间的客观信息，不输出评级或综合结论，也不替你做投资决定。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
        LoopEmpty(
          key: const ValueKey<String>('community-ai-composer-unavailable'),
          icon: 'warn',
          message: '提问入口未开放',
          reason: communicationUnavailableReason(reasonCode),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
