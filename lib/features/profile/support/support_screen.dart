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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The five bundled answers. They are product copy, not an indexed FAQ: there
/// is no article resource, so nothing here claims a server source.
/// Each answer carries a stable id for its key (decision 0281: keys never
/// spell copy).
List<(String, String, String)>
get _supportAnswers => <(String, String, String)>[
  // Bundled copy outlives the state it was written in: this answer used to say
  // the formula was undecided and that no power was shown, and it kept saying
  // it after the mining pages started showing settled figures. It now describes
  // where a figure comes from, which does not change with the version in
  // effect; the version itself is on the mining page, which is the one place
  // that reads it.
  (
    'power',
    LoopL10n.current.profileSupport_screenText,
    LoopL10n.current.profileSupport_screenText2,
  ),
  (
    'weight',
    LoopL10n.current.profileSupport_screenText3,
    LoopL10n.current.profileSupport_screenText4,
  ),
  (
    'launch',
    LoopL10n.current.profileSupport_screenText5,
    LoopL10n.current.profileSupport_screenText6,
  ),
  (
    'recovery',
    LoopL10n.current.profileSupport_screenText7,
    // Decision 0158: the same facts as the security center (decision 0156).
    LoopL10n.current.profileSupport_screenText8,
  ),
  (
    'bonding-buy',
    LoopL10n.current.profileSupport_screenText9,
    LoopL10n.current.profileSupport_screenText10,
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
      message: ok
          ? LoopL10n.current.profileSupport_screenMessage
          : LoopL10n.current.profileSupport_screenMessage2,
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

    // Decision 0126: flat sections; the policy card and its English
    // eyebrow are gone, the reply window is one footnote line.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('support-screen'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.profileSupport_screenSupportScreenTitle,
        onBack: widget.onBack,
        // The prototype has no hero here: it opens on 联系我们, and its
        // 「先查答案，再提交工单」 card is the body of the closing disclosure.
        // A hero carrying that line over a page with no answers on it was the
        // page denying itself (audit 2026-09-21 §D+ #13, §D+ #14).
        sections: <Widget>[
          LoopLabel(context.l10n.profileSupport_screenLoopLabel),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('support-open-community'),
                leading: const LoopRowIcon(icon: 'community'),
                title:
                    context.l10n.profileSupport_screenSupportOpenCommunityTitle,
                position: LoopRowPosition.single,
                onTap: () => widget.onNavigate('community-discover'),
              ),
            ],
          ),
          // Five bundled answers, so the page has a first path that is not a
          // ticket. They are product copy, not an indexed article resource.
          LoopLabel(context.l10n.profileSupport_screenLoopLabel2),
          Column(
            children: <Widget>[
              for (final answer in _supportAnswers)
                LoopDisclosure(
                  key: ValueKey<String>('support-answer-${answer.$1}'),
                  summary: answer.$2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      answer.$3,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
          LoopLabel(context.l10n.profileSupport_screenLoopLabel3),
          if (blocked)
            LoopUnavailableLine(
              key: const ValueKey<String>('support-capability-block'),
              label:
                  context.l10n.profileSupport_screenSupportCapabilityBlockLabel,
              reasonCode:
                  capability.reasonCode ?? 'SUPPORT_RUNTIME_UNAVAILABLE',
            )
          else ...<Widget>[
            LoopSegBar(
              key: const ValueKey<String>('support-category-bar'),
              labels: <String>[
                for (final category in LoopSupportCategory.values)
                  category.label,
              ],
              selectedIndex: LoopSupportCategory.values.indexOf(_category),
              onSelected: (index) =>
                  setState(() => _category = LoopSupportCategory.values[index]),
            ),
            const SizedBox(height: 12),
            LoopFlatField(
              key: const ValueKey<String>('support-body'),
              label: context.l10n.profileSupport_screenSupportBodyLabel,
              footnote: context.l10n.profileSupport_screenSupportBodyFootnote(
                length,
                LoopSupportPolicy.maximumBodyLength,
                problem != null && length > 0
                    ? ' · ${problem.explanation}'
                    : '',
              ),
              error: problem != null && length > 0,
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
                style: LoopType.bodyLg,
                // S353c: the hint wraps to a second line rather than cut
                // 「Never enter a private key…」 short at 360.
                decoration: loopFormFieldDecoration(
                  hint: context.l10n.profileSupport_screenHint,
                ).copyWith(hintMaxLines: 2),
              ),
            ),
            if (problem != null && length > 0)
              const SizedBox.shrink(
                key: ValueKey<String>('support-body-problem'),
              ),
            if (state.commandFailureKind != null)
              LoopErrorState(
                key: const ValueKey<String>('support-command-error'),
                title: context.l10n.profileSupport_screenMessage2,
                reason: loopChainFailureReason(state.commandFailureKind),
                margin: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  12,
                  LoopSpacing.page,
                  0,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
              child: LoopButton(
                key: const ValueKey<String>('support-submit'),
                label: state.busy
                    ? context.l10n.common_submitting
                    : context.l10n.profileSupport_screenLoopLabel3,
                block: true,
                primary: true,
                onPressed: submittable ? () => unawaited(_submit()) : null,
              ),
            ),
            if (page != null)
              LoopUnavailableLine.fact(
                key: const ValueKey<String>('support-attachments-unavailable'),
                label: context
                    .l10n
                    .profileSupport_screenSupportAttachmentsUnavailableLabel,
                fact: page.attachments,
                margin: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  12,
                  LoopSpacing.page,
                  0,
                ),
              ),
            LoopLabel(context.l10n.profileSupport_screenLoopLabel4),
            if (!state.resource.isReady)
              LoopChainStateBlock(
                keyPrefix: 'support',
                phase: state.resource.phase,
                failureKind: state.resource.failureKind,
                emptyMessage: context.l10n.profileSupport_screenEmptyMessage,
                onRetry: () => unawaited(
                  ref.read(supportControllerProvider.notifier).reload(),
                ),
              )
            else if (page!.items.isEmpty)
              LoopEmptyState(
                key: ValueKey<String>('support-tickets-empty'),
                illustration: LoopIllustration.history,
                title: context.l10n.profileSupport_screenEmptyMessage,
                message: context
                    .l10n
                    .profileSupport_screenSupportTicketsEmptyMessage,
                compact: true,
              )
            else
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  for (final ticket in page.items) _ticketRow(ticket),
                ],
              ),
            if (page?.nextCursor != null)
              LoopNotice(
                key: ValueKey<String>('support-more-tickets'),
                icon: 'info',
                title:
                    context.l10n.profileSupport_screenSupportMoreTicketsTitle,
                body: context.l10n.profileSupport_screenSupportMoreTicketsBody,
                margin: EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  12,
                  LoopSpacing.page,
                  0,
                ),
              ),
          ],
          if (policy != null)
            LoopProvenanceFooter(
              key: const ValueKey<String>('support-escalation'),
              label: context.l10n.common_about,
              title: context.l10n.profileSupport_screenSupportEscalationTitle,
              text: policy.businessDaysOnly
                  ? LoopL10n.current
                        .profileSupport_screenSupportEscalationTextBusinessDays(
                          policy.responseWindowHours,
                        )
                  : LoopL10n.current.profileSupport_screenSupportEscalationText(
                      policy.responseWindowHours,
                    ),
            ),
          // The prototype closes on the warning, not opens on it.
          LoopNotice(
            key: ValueKey<String>('support-scam-notice'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.profileSupport_screenSupportScamNoticeTitle,
            body: context.l10n.profileSupport_screenSupportScamNoticeBody,
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  LoopRecordRow _ticketRow(LoopSupportTicket ticket) {
    final note = ticket.latestOperatorNote;
    return LoopRecordRow(
      key: ValueKey<String>('support-ticket-${ticket.ticketId}'),
      title: '${ticket.category.label} · ${ticket.body}',
      subtitle: note == null
          ? LoopL10n.current.profileSupport_screenSubtitle(
              loopRelativeTime(ticket.createdAt),
            )
          : LoopL10n.current.profileSupport_screenSubtitle2(note),
      // A ticket row carries two full sentences — the question you typed and
      // the operator's answer — and on a phone both used to end in an
      // ellipsis with nowhere to go. The row now opens the whole exchange.
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        ticket.status.label,
        kind: switch (ticket.status) {
          LoopSupportTicketStatus.answered => LoopBadgeKind.up,
          LoopSupportTicketStatus.open => LoopBadgeKind.mining,
          LoopSupportTicketStatus.closed => LoopBadgeKind.mute,
        },
      ),
      position: LoopRowPosition.middle,
      semanticLabel: LoopL10n.current.profileSupport_screenSemanticLabel(
        ticket.category.label,
        ticket.status.label,
      ),
      onTap: () => unawaited(_openTicket(ticket)),
    );
  }

  Future<void> _openTicket(LoopSupportTicket ticket) => showLoopSheet<void>(
    context,
    barrierLabel: LoopL10n.current.profileSupport_screenBarrierLabel,
    builder: (context) => _SupportTicketDetail(ticket: ticket),
  );
}

/// The whole of one ticket: the question as it was typed, the status, and
/// every event in the order it happened. The list row is a summary and
/// ellipses; this is where the operator's reply is read in full.
class _SupportTicketDetail extends StatelessWidget {
  const _SupportTicketDetail({required this.ticket});

  final LoopSupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ticket.events.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return Column(
      key: const ValueKey<String>('support-ticket-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(ticket.category.label, style: LoopType.eyebrow),
              ),
              LoopBadge(
                ticket.status.label,
                kind: switch (ticket.status) {
                  LoopSupportTicketStatus.answered => LoopBadgeKind.up,
                  LoopSupportTicketStatus.open => LoopBadgeKind.mining,
                  LoopSupportTicketStatus.closed => LoopBadgeKind.mute,
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            6,
            LoopSpacing.page,
            12,
          ),
          child: Text(
            key: const ValueKey<String>('support-ticket-detail-body'),
            ticket.body,
            style: theme.textTheme.titleMedium,
          ),
        ),
        LoopLabel(context.l10n.profileSupport_screenLoopLabel5),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final event in events)
                LoopSurfaceCard(
                  key: ValueKey<String>(
                    'support-ticket-event-${event.eventVersion}',
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '${event.actor.label} · ${event.eventType.label} · '
                        '${loopRelativeTime(event.occurredAt)}',
                        style: LoopType.eyebrow,
                      ),
                      if (event.note case final String note) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(note, style: theme.textTheme.bodyMedium),
                      ] else if (event.eventType ==
                          LoopSupportEventType.created) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(ticket.body, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (ticket.status == LoopSupportTicketStatus.open)
          LoopFootnote(
            key: ValueKey<String>('support-ticket-detail-open'),
            text: context.l10n.profileSupport_screenSupportTicketDetailOpenText,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
