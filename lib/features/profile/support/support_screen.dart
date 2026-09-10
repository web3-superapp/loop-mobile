import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/support/support_controller.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The five bundled answers. They are product copy, not an indexed FAQ: there
/// is no article resource, so nothing here claims a server source.
const List<(String, String)> _supportAnswers = <(String, String)>[
  (
    '算力是怎么算的',
    '挖矿公式还没有定下来，因此暂时不显示算力。公式确定后，'
        '挖矿页会连同 configVersion 一起显示。',
  ),
  (
    '为什么我的币没有权重',
    '只有已登记的资产才会计入挖矿。是否登记以 LOOP 的登记表为准，'
        '不以钱包里是否出现过为准。',
  ),
  (
    '怎么参与 Launch',
    'Launch 轮次、快照与限额由合约参数决定。参数确认前，Launch 页只展示已有的'
        '轮次状态，不承诺任何额度。',
  ),
  (
    '换手机怎么恢复账户',
    '账号身份由 Privy 保管。恢复密码、Passkey、自动恢复与社交恢复暂时都不可用，'
        '安全中心会显示每一项的具体原因。',
  ),
  (
    '内盘买入为什么被拒绝',
    '未毕业的 Launch 资产只能买入，且只能走它自己的通道；被拒绝时会给出具体的'
        '错误码，交易页会原样显示。',
  ),
];

/// `support` · the ticket form, the ticket list and the bundled answers.
///
/// The prototype's "48,120 成员 · 有人在线" line has no source and is not
/// rendered; attachments are permanently unavailable; ticket status is only
/// ever advanced by a LOOP operator.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({required this.onNavigate, super.key, this.onBack});

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final TextEditingController _body = TextEditingController();
  LoopSupportCategory _category = LoopSupportCategory.account;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(supportControllerProvider.notifier)
        .submit(category: _category, body: _body.text);
    if (!mounted) return;
    if (ok) _body.clear();
    LoopToast.show(
      context,
      message: ok ? '工单已提交' : '工单没有提交',
      kind: ok ? LoopToastKind.ok : LoopToastKind.err,
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.support),
    );
    final mode = ref.watch(supportGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(supportControllerProvider);
    if (!blocked && state.resource.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(supportControllerProvider.notifier).load());
        }
      });
    }
    final page = state.resource.value;
    final policy = page?.policy;
    final length = LoopSupportDraft.lengthOf(_body.text);
    final problem = LoopSupportDraft.problemFor(_body.text);
    final submittable = !state.busy && !blocked && problem == null;

    return LoopDashboardPage(
      key: const ValueKey<String>('support-screen'),
      archetype: LoopPageArchetype.record,
      title: '帮助与客服',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('support-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'LOOP SUPPORT',
        heading: '先查答案，再提交工单',
        caption: policy == null
            ? '官方不会主动私聊你，也不会索要私钥、助记词或验证码。'
            : '${policy.businessDaysOnly ? '工作日' : ''}'
                  '${policy.responseWindowHours} 小时内回复'
                  '（规则 ${policy.configVersion}）；官方不会主动私聊你。',
      ),
      sections: <Widget>[
        const LoopNotice(
          key: ValueKey<String>('support-scam-notice'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '官方不会主动私聊你',
          body: '任何私聊索要私钥、助记词或验证码的都是诈骗，请直接举报。',
        ),
        const LoopLabel('提交工单'),
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('support-capability-block'),
            label: '客服工单当前不可用',
            reasonCode: capability.reasonCode ?? 'SUPPORT_RUNTIME_UNAVAILABLE',
          )
        else ...<Widget>[
          LoopSegBar(
            key: const ValueKey<String>('support-category-bar'),
            labels: <String>[
              for (final category in LoopSupportCategory.values) category.label,
            ],
            selectedIndex: LoopSupportCategory.values.indexOf(_category),
            onSelected: (index) =>
                setState(() => _category = LoopSupportCategory.values[index]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey<String>('support-body-field'),
              controller: _body,
              // The server refuses every control character, a newline
              // included, so one is never typed rather than typed and then
              // rejected.
              maxLines: 1,
              enabled: !state.busy,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '描述你遇到的问题；不要填写私钥、助记词或验证码',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '$length / ${LoopSupportPolicy.maximumBodyLength} 码点',
              style: LoopMono.label,
            ),
          ),
          if (problem != null && length > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                key: const ValueKey<String>('support-body-problem'),
                problem.explanation,
                style: LoopTypography.caption(11, color: LoopColors.text3),
              ),
            ),
          if (state.commandFailureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('support-command-error'),
              title: '工单没有提交',
              reason: loopChainFailureReason(state.commandFailureKind),
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('support-submit'),
              label: state.busy ? '提交中' : '提交工单',
              block: true,
              primary: true,
              onPressed: submittable ? () => unawaited(_submit()) : null,
            ),
          ),
          if (page != null)
            LoopUnavailableCard.fact(
              key: const ValueKey<String>('support-attachments-unavailable'),
              label: '暂不支持附件',
              fact: page.attachments,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
          const LoopLabel('我的工单'),
          if (!state.resource.isReady)
            LoopChainStateBlock(
              keyPrefix: 'support',
              phase: state.resource.phase,
              failureKind: state.resource.failureKind,
              emptyMessage: '还没有提交过工单',
              onRetry: () => unawaited(
                ref.read(supportControllerProvider.notifier).reload(),
              ),
            )
          else if (page!.items.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('support-tickets-empty'),
              message: '还没有提交过工单',
              reason: '提交后，这里会显示状态与客服回复。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final ticket in page.items) _ticketRow(ticket),
              ],
            ),
          if (page?.nextCursor != null)
            const LoopNotice(
              key: ValueKey<String>('support-more-tickets'),
              icon: 'info',
              title: '还有更早的工单',
              body: '目前只显示最新的一页，更早的工单暂时看不到。',
              margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
        ],
        const LoopLabel('常见问题'),
        Column(
          children: <Widget>[
            for (final answer in _supportAnswers)
              LoopDisclosure(
                key: ValueKey<String>('support-answer-${answer.$1}'),
                summary: answer.$1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    answer.$2,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
        const LoopLabel('官方社区'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('support-open-community'),
              title: 'LOOP 官方社区',
              subtitle: '成员数与在线状态暂时读不到，这里不显示数字',
              onTap: () => widget.onNavigate('community-discover'),
            ),
          ],
        ),
        if (policy != null)
          LoopProvenanceFooter(
            key: const ValueKey<String>('support-escalation'),
            text: '紧急问题请在工单正文里写明，目前没有单独的加急通道。',
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  LoopRecordRow _ticketRow(LoopSupportTicket ticket) {
    final note = ticket.latestOperatorNote;
    return LoopRecordRow(
      key: ValueKey<String>('support-ticket-${ticket.ticketId}'),
      title: '${ticket.category.label} · ${ticket.body}',
      subtitle: note == null
          ? '提交于 ${loopRelativeTime(ticket.createdAt)} · 还没有回复'
          : '客服回复：$note',
      trailingBadge: LoopBadge(
        ticket.status.label,
        kind: switch (ticket.status) {
          LoopSupportTicketStatus.answered => LoopBadgeKind.up,
          LoopSupportTicketStatus.open => LoopBadgeKind.mining,
          LoopSupportTicketStatus.closed => LoopBadgeKind.mute,
        },
      ),
      position: LoopRowPosition.middle,
      semanticLabel: '${ticket.category.label} 工单，${ticket.status.label}',
    );
  }
}
