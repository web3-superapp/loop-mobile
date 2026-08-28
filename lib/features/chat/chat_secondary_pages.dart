import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/features/chat/preview_conversation_unavailable_page.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class GroupInfoPage extends ConsumerStatefulWidget {
  const GroupInfoPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage> {
  var _notifications = true;
  var _mentionsOnly = false;

  void _setNotifications(bool value) {
    setState(() {
      _notifications = value;
      if (!value) _mentionsOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = PreviewConversationIdentity.resolve(
      conversationId: widget.conversationId,
      kind: ConversationKind.group,
    );
    if (target == null) return const PreviewConversationUnavailablePage();
    final gateway = ref.watch(communicationGatewayProvider);
    final preview = gateway.mode == CommunicationMode.preview;
    return LoopPage(
      eyebrow: 'Group',
      title: target.title,
      subtitle: preview
          ? 'Offline preview · simulated member layout'
          : gateway.isConfigured
          ? 'Static member layout · Stream presence not verified'
          : 'Stream not connected',
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push(target.searchLocation),
          tooltip: 'Search group messages',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
      bottom: const ChatMiniVoiceBar(),
      children: <Widget>[
        LoopCard(
          tone: LoopTone.market,
          accent: true,
          child: Column(
            children: <Widget>[
              const ChatAvatar(
                label: 'Glyph Hunters',
                size: 72,
                colorSeed: 2,
                icon: Icons.groups_rounded,
              ),
              const SizedBox(height: 13),
              Text(
                'Glyph Hunters',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'On-chain research, market structure, and fact-checked small-cap discussion.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(target.searchLocation),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/chat/voice'),
                      icon: const Icon(Icons.graphic_eq_rounded, size: 17),
                      label: const Text('Voice room'),
                      style: FilledButton.styleFrom(
                        backgroundColor: LoopColors.chat,
                        foregroundColor: LoopColors.abyss,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Announcement'),
        const LoopStateCard(
          title: 'Research before reaction',
          message: 'Share sources with contract claims. Flag unlocks, admin controls, and concentrated ownership.',
          icon: Icons.campaign_outlined,
          tone: LoopTone.conversation,
        ),
        const LoopSectionLabel('Preferences · 开发预览'),
        const LoopStateCard(
          title: 'Preview controls only',
          message: 'These switches change only this process-local page state. They do not read or write Stream notification settings.',
          icon: Icons.tune_rounded,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 12),
        LoopCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  key: const ValueKey<String>('preview-group-notifications'),
                  value: _notifications,
                  onChanged: _setNotifications,
                  title: const Text('Notification layout'),
                  subtitle: const Text(
                    'Process-local example; no Stream setting is changed',
                  ),
                  secondary: const Icon(Icons.notifications_outlined),
                ),
              ),
              const Divider(),
              Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  key: const ValueKey<String>('preview-group-mentions-only'),
                  value: _mentionsOnly,
                  onChanged: _notifications
                      ? (value) => setState(() => _mentionsOnly = value)
                      : null,
                  title: const Text('Mentions-only layout'),
                  subtitle: const Text(
                    'Local dependent-state example for this page',
                  ),
                  secondary: const Icon(Icons.alternate_email_rounded),
                ),
              ),
            ],
          ),
        ),
        LoopSectionLabel(
          'Preview members',
          trailing: TextButton(
            onPressed: () => _showMemberList(context),
            child: const Text('See more'),
          ),
        ),
        const LoopCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              _MemberRow(alias: 'NightOwl', role: 'Moderator', colorSeed: 2),
              Divider(),
              _MemberRow(alias: '0xSable', role: 'Member', colorSeed: 4),
              Divider(),
              _MemberRow(alias: 'AtlasLoop', role: 'Member', colorSeed: 3),
              Divider(),
              _MemberRow(alias: 'Nori', role: 'Member', colorSeed: 6),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const LoopStateCard(
          title: 'Membership actions unavailable',
          message: 'No Stream membership mutation is connected. Preview members remain unchanged.',
          icon: Icons.group_off_outlined,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('preview-group-leave-unavailable'),
            onPressed: null,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave unavailable'),
            style: OutlinedButton.styleFrom(foregroundColor: LoopColors.danger),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.alias,
    required this.role,
    required this.colorSeed,
  });

  final String alias;
  final String role;
  final int colorSeed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ChatAvatar(label: alias, size: 40, colorSeed: colorSeed),
      title: Text(alias),
      subtitle: Text('$role · No member actions'),
    );
  }
}

class MessageRequestsPage extends ConsumerStatefulWidget {
  const MessageRequestsPage({super.key});

  @override
  ConsumerState<MessageRequestsPage> createState() =>
      _MessageRequestsPageState();
}

class _MessageRequestsPageState extends ConsumerState<MessageRequestsPage> {
  final Set<String> _resolvingRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(messageRequestsProvider);
    return LoopPage(
      eyebrow: 'Inbox',
      title: 'Message requests',
      subtitle:
          'Process-local simulated requests for this Development Preview.',
      children: <Widget>[
        const LoopStateCard(
          title: 'Development Preview only · 开发预览',
          message: 'These actions only update process-local Preview state. Accept does not create a Stream conversation, Ignore does not notify the sender, and Report does not submit a moderation report.',
          icon: Icons.mark_email_unread_outlined,
          tone: LoopTone.conversation,
        ),
        const LoopSectionLabel('Pending'),
        requests.when(
          data: (items) {
            if (items.isEmpty) {
              return const LoopStateCard(
                key: ValueKey<String>('chat-preview-message-requests-empty'),
                title: 'No simulated requests remain',
                message: 'No simulated requests remain in this Development Preview. Restarting the preview restores the fixtures.',
                icon: Icons.inbox_outlined,
              );
            }
            return Column(
              children: items
                  .map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RequestCard(
                        request: request,
                        resolving: _resolvingRequestIds.contains(request.id),
                        onAccept: () => _resolveRequest(request, accept: true),
                        onIgnore: () => _resolveRequest(request, accept: false),
                        onReport: () => _reportRequest(request),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (error, stackTrace) => LoopStateCard(
            title: 'Requests are unavailable',
            message: 'This Development Preview could not load its process-local request state.',
            icon: Icons.cloud_off_outlined,
            tone: LoopTone.warning,
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(messageRequestsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resolveRequest(
    MessageRequestSummary request, {
    required bool accept,
  }) async {
    if (!_beginResolving(request.id)) return;
    final gateway = ref.read(communicationGatewayProvider);
    try {
      final result = accept
          ? await gateway.acceptMessageRequest(request.id)
          : await gateway.ignoreMessageRequest(request.id);
      if (!mounted) return;
      if (result.isSuccess) {
        ref.invalidate(messageRequestsProvider);
        _showRequestNotice(
          accept
              ? 'Marked accepted in 开发预览 and removed locally. No Stream conversation was created.'
              : 'Removed from 开发预览 only. No sender interaction occurred.',
        );
      } else {
        _showRequestNotice(
          'Preview request was not updated. It may already have been handled.',
        );
      }
    } finally {
      _finishResolving(request.id);
    }
  }

  Future<void> _reportRequest(MessageRequestSummary request) async {
    if (!_beginResolving(request.id)) return;
    try {
      final reason = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        'Report ${request.alias}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Development Preview only. Choosing a reason removes this simulated request locally; no report is submitted.',
                      ),
                    ),
                    for (final reason in <String>[
                      'Spam',
                      'Scam attempt',
                      'Harassment',
                    ])
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(reason),
                        onTap: () => Navigator.of(sheetContext).pop(reason),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (reason == null || !mounted) return;
      final result = await ref
          .read(communicationGatewayProvider)
          .reportMessageRequest(requestId: request.id, reason: reason);
      if (!mounted) return;
      if (result.isSuccess) {
        ref.invalidate(messageRequestsProvider);
        _showRequestNotice('Removed from 开发预览. No report was submitted.');
      } else {
        _showRequestNotice(
          'Preview request was not updated. No report was submitted.',
        );
      }
    } finally {
      _finishResolving(request.id);
    }
  }

  bool _beginResolving(String requestId) {
    if (_resolvingRequestIds.contains(requestId)) return false;
    setState(() => _resolvingRequestIds.add(requestId));
    return true;
  }

  void _finishResolving(String requestId) {
    if (!mounted || !_resolvingRequestIds.contains(requestId)) return;
    setState(() => _resolvingRequestIds.remove(requestId));
  }

  void _showRequestNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.resolving,
    required this.onAccept,
    required this.onIgnore,
    required this.onReport,
  });

  final MessageRequestSummary request;
  final bool resolving;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      key: ValueKey<String>('chat-preview-request-${request.id}'),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ChatAvatar(label: request.alias, colorSeed: request.colorSeed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            request.alias,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          request.timeLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.sharedContext,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: LoopColors.market),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<String>(
                  'chat-preview-request-report-${request.id}',
                ),
                onPressed: resolving ? null : onReport,
                tooltip: 'Report request',
                icon: const Icon(Icons.flag_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.preview, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          if (resolving) ...<Widget>[
            const LinearProgressIndicator(
              key: ValueKey<String>('chat-preview-request-progress'),
              value: 0.5,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: ValueKey<String>(
                    'chat-preview-request-ignore-${request.id}',
                  ),
                  onPressed: resolving ? null : onIgnore,
                  child: const Text('Ignore'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  key: ValueKey<String>(
                    'chat-preview-request-accept-${request.id}',
                  ),
                  onPressed: resolving ? null : onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SearchFilter { all, groups, direct }

class MessageSearchPage extends ConsumerStatefulWidget {
  const MessageSearchPage({this.conversationId, super.key});

  final String? conversationId;

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> {
  final _controller = TextEditingController(text: 'unlock');
  late final PreviewConversationTarget? _scope;
  late List<MessageSearchResult> _results;
  var _loading = false;
  var _filter = _SearchFilter.all;

  @override
  void initState() {
    super.initState();
    final conversationId = widget.conversationId;
    _scope = conversationId == null
        ? null
        : PreviewConversationIdentity.resolveMessage(conversationId);
    final scope = _scope;
    _results = conversationId == null
        ? List<MessageSearchResult>.of(ChatContent.searchResults)
        : scope == null
        ? <MessageSearchResult>[]
        : ChatContent.searchResults
              .where((result) => result.conversationId == scope.id)
              .toList(growable: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (widget.conversationId != null && scope == null) {
      return const PreviewConversationUnavailablePage();
    }
    final filtered = _results
        .where((result) {
          return switch (_filter) {
            _SearchFilter.all => true,
            _SearchFilter.groups => result.kind == ConversationKind.group,
            _SearchFilter.direct => result.kind == ConversationKind.direct,
          };
        })
        .toList(growable: false);
    return LoopPage(
      eyebrow: 'Chats',
      title: scope == null ? 'Search messages' : 'Search ${scope.title}',
      subtitle: scope == null
          ? 'Find a source, ticker, address, or earlier conversation.'
          : 'Results stay inside this exact Preview conversation.',
      children: <Widget>[
        TextField(
          controller: _controller,
          autofocus: false,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Search messages',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      _search();
                    },
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (scope == null)
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == _SearchFilter.all,
                onSelected: (_) => setState(() => _filter = _SearchFilter.all),
              ),
              ChoiceChip(
                label: const Text('Groups'),
                selected: _filter == _SearchFilter.groups,
                onSelected: (_) =>
                    setState(() => _filter = _SearchFilter.groups),
              ),
              ChoiceChip(
                label: const Text('Direct'),
                selected: _filter == _SearchFilter.direct,
                onSelected: (_) =>
                    setState(() => _filter = _SearchFilter.direct),
              ),
            ],
          ),
        LoopSectionLabel('${filtered.length} results'),
        if (!_loading && filtered.isEmpty)
          const LoopStateCard(
            title: 'No messages found',
            message: 'Try a shorter phrase, ticker, or sender name.',
            icon: Icons.search_off_rounded,
          )
        else
          for (final result in filtered) ...<Widget>[
            _SearchResultCard(result: result),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _search() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    final result = await ref
        .read(communicationGatewayProvider)
        .searchMessages(query: _controller.text, conversationId: _scope?.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = result.value ?? const <MessageSearchResult>[];
    });
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Search is unavailable. Try again.')),
        );
    }
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result});

  final MessageSearchResult result;

  @override
  Widget build(BuildContext context) {
    final direct = result.kind == ConversationKind.direct;
    final resolvedTarget = PreviewConversationIdentity.resolveMessage(
      result.conversationId,
    );
    final target = resolvedTarget?.kind == result.kind ? resolvedTarget : null;
    return LoopCard(
      key: ValueKey<String>('chat-preview-search-result-${result.id}'),
      onTap: target == null ? null : () => context.push(target.location),
      semanticLabel: target == null
          ? null
          : 'Open result from ${result.conversationTitle}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChatAvatar(
            label: result.conversationTitle,
            size: 40,
            colorSeed: direct ? 4 : 2,
            icon: direct ? null : Icons.groups_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        result.conversationTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      result.timeLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  result.senderAlias,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: direct ? LoopColors.chat : LoopColors.market,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.snippet,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (target == null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Preview conversation unavailable',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: LoopColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeetingPlaceholderPage extends StatelessWidget {
  const MeetingPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'Coming later',
      title: 'Meet face to face',
      subtitle:
          'Scheduled video meetings will live alongside your conversations.',
      children: <Widget>[
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LoopColors.market.withValues(alpha: 0.08),
              border: Border.all(
                color: LoopColors.market.withValues(alpha: 0.28),
              ),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: LoopColors.market,
                ),
                Positioned(
                  right: 27,
                  bottom: 32,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: LoopColors.elevated,
                    child: Icon(
                      Icons.videocam_rounded,
                      size: 20,
                      color: LoopColors.chat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'One place for planned conversations',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 9),
        Text(
          'Create a meeting from a group, invite members, and return to the discussion when it ends.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 26),
        const LoopCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Scheduled meetings',
                value: 'Coming later',
              ),
              LoopKeyValueRow(label: 'Video calls', value: 'Coming later'),
              LoopKeyValueRow(
                label: 'Calendar reminders',
                value: 'Coming later',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.notifications_none_rounded),
            label: const Text('Not available yet'),
          ),
        ),
      ],
    );
  }
}

Future<void> _showMemberList(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Simulated preview members',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: const <Widget>[
                    _MemberRow(
                      alias: 'NightOwl',
                      role: 'Moderator',
                      colorSeed: 2,
                    ),
                    _MemberRow(alias: '0xSable', role: 'Member', colorSeed: 4),
                    _MemberRow(
                      alias: 'AtlasLoop',
                      role: 'Member',
                      colorSeed: 3,
                    ),
                    _MemberRow(alias: 'Nori', role: 'Member', colorSeed: 6),
                    _MemberRow(alias: 'Mina.Ξ', role: 'Member', colorSeed: 7),
                    _MemberRow(
                      alias: 'OnchainMia',
                      role: 'Member',
                      colorSeed: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
