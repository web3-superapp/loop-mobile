import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/friends/friend_request_controller.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class FriendRequestsPage extends ConsumerStatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  ConsumerState<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends ConsumerState<FriendRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendRequestsControllerProvider);
    final controller = ref.read(friendRequestsControllerProvider.notifier);
    ref.listen<FriendRequestsState>(friendRequestsControllerProvider, (
      previous,
      next,
    ) {
      final receipt = next.decisionReceipt;
      if (receipt == null || previous?.decisionReceipt == receipt) return;
      final accepted = receipt.decision == FriendRequestDecision.accept;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accepted ? '好友申请已接受' : '好友申请已拒绝')));
      controller.acknowledgeDecision();
    });
    if (state.phase == FriendRequestsPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    return LoopPage(
      eyebrow: 'PEOPLE',
      title: '好友申请',
      subtitle: '只有接受后的关系才会进入好友列表；申请状态不会被当作已建立关系。',
      actions: <Widget>[
        if (state.mode == FriendGatewayMode.production)
          IconButton(
            key: const ValueKey<String>('friend-requests-refresh'),
            tooltip: '刷新申请',
            onPressed: state.isBusy || state.requiresDecisionReconciliation
                ? null
                : () => unawaited(controller.reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
      children: _content(state, controller),
    );
  }

  List<Widget> _content(
    FriendRequestsState state,
    FriendRequestsController controller,
  ) {
    if (state.phase == FriendRequestsPhase.unavailable) {
      return const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('friend-requests-unavailable'),
          title: '好友申请不可用',
          message: '需要已验证的 LOOP 账号和可用的 Social 服务。这里不会显示本地假申请。',
          icon: Icons.mark_email_unread_outlined,
          tone: LoopTone.warning,
        ),
      ];
    }
    if (state.phase == FriendRequestsPhase.loading &&
        state.incoming.isEmpty &&
        state.outgoing.isEmpty) {
      return const <Widget>[_FriendRequestsLoadingCard()];
    }

    final content = <Widget>[];
    if (state.phase == FriendRequestsPhase.failure) {
      final unknown =
          state.failureKind == FriendGatewayFailureKind.outcomeUnknown &&
          state.decidingRequestId != null;
      content.addAll(<Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-requests-failure'),
          title: unknown ? '处理结果待确认' : '好友申请暂时无法更新',
          message: _requestFailureMessage(state.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: unknown
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('friend-decision-reconcile'),
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(
                          controller.reconcileDecision(
                            state.decidingRequestId!,
                          ),
                        ),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('查询结果'),
                )
              : OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(controller.reload()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
        ),
        const SizedBox(height: 14),
      ]);
    }

    content.addAll(<Widget>[
      const LoopSectionLabel('收到的申请'),
      if (state.incoming.isEmpty)
        const LoopStateCard(
          key: ValueKey<String>('friend-requests-incoming-empty'),
          title: '没有待处理申请',
          message: '新的好友申请会显示在这里。',
          icon: Icons.inbox_outlined,
        )
      else
        _FriendRequestList(
          items: state.incoming,
          decidingRequestId: state.decidingRequestId,
          enabled: !state.isBusy && !state.requiresDecisionReconciliation,
          onAccept: (requestId) => unawaited(
            controller.decide(requestId, FriendRequestDecision.accept),
          ),
          onReject: (requestId) => unawaited(
            controller.decide(requestId, FriendRequestDecision.reject),
          ),
        ),
      if (state.incomingCursor != null) ...<Widget>[
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton(
            key: const ValueKey<String>('friend-requests-incoming-more'),
            onPressed: state.canLoadMore(FriendRequestDirection.incoming)
                ? () => unawaited(
                    controller.loadMore(FriendRequestDirection.incoming),
                  )
                : null,
            child: const Text('加载更多收到的申请'),
          ),
        ),
      ],
      const SizedBox(height: 22),
      const LoopSectionLabel('已发送'),
      if (state.outgoing.isEmpty)
        const LoopStateCard(
          key: ValueKey<String>('friend-requests-outgoing-empty'),
          title: '没有等待中的申请',
          message: '你发送且尚未处理的申请会显示在这里。',
          icon: Icons.outbox_outlined,
        )
      else
        _FriendRequestList(
          items: state.outgoing,
          decidingRequestId: null,
          enabled: false,
        ),
      if (state.outgoingCursor != null) ...<Widget>[
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton(
            key: const ValueKey<String>('friend-requests-outgoing-more'),
            onPressed: state.canLoadMore(FriendRequestDirection.outgoing)
                ? () => unawaited(
                    controller.loadMore(FriendRequestDirection.outgoing),
                  )
                : null,
            child: const Text('加载更多已发送申请'),
          ),
        ),
      ],
    ]);
    return content;
  }
}

class _FriendRequestList extends StatelessWidget {
  const _FriendRequestList({
    required this.items,
    required this.decidingRequestId,
    required this.enabled,
    this.onAccept,
    this.onReject,
  });

  final List<FriendRequestRecord> items;
  final String? decidingRequestId;
  final bool enabled;
  final ValueChanged<String>? onAccept;
  final ValueChanged<String>? onReject;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            _FriendRequestRow(
              record: items[index],
              deciding: decidingRequestId == items[index].friendRequestId,
              enabled: enabled,
              onAccept: onAccept,
              onReject: onReject,
            ),
            if (index != items.length - 1) const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  const _FriendRequestRow({
    required this.record,
    required this.deciding,
    required this.enabled,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequestRecord record;
  final bool deciding;
  final bool enabled;
  final ValueChanged<String>? onAccept;
  final ValueChanged<String>? onReject;

  @override
  Widget build(BuildContext context) {
    final identity = record.counterparty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          ChatAvatar(
            label: identity.alias,
            colorSeed: identity.colorSeed,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  identity.alias,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'LOOP #${identity.profileCode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (deciding)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (onAccept != null && onReject != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: ValueKey<String>(
                    'friend-request-reject-${record.friendRequestId}',
                  ),
                  tooltip: '拒绝',
                  onPressed: enabled
                      ? () => onReject!(record.friendRequestId)
                      : null,
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton.filled(
                  key: ValueKey<String>(
                    'friend-request-accept-${record.friendRequestId}',
                  ),
                  tooltip: '接受',
                  onPressed: enabled
                      ? () => onAccept!(record.friendRequestId)
                      : null,
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            )
          else
            const LoopStatusPill(label: '等待中', tone: LoopTone.warning),
        ],
      ),
    );
  }
}

class _FriendRequestsLoadingCard extends StatelessWidget {
  const _FriendRequestsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('正在加载好友申请…')),
        ],
      ),
    );
  }
}

String _requestFailureMessage(FriendGatewayFailureKind? kind) => switch (kind) {
  FriendGatewayFailureKind.unavailable => 'Social 服务当前不可用。',
  FriendGatewayFailureKind.invalidData => '服务返回了无法安全接受的数据。',
  FriendGatewayFailureKind.notFound => '申请不存在、已过期或当前账号不可见。',
  FriendGatewayFailureKind.permissionDenied => '当前账号无权处理这条申请。',
  FriendGatewayFailureKind.conflict => '申请状态已经变化，请刷新后再试。',
  FriendGatewayFailureKind.rateLimited => '操作过于频繁，请稍后再试。',
  FriendGatewayFailureKind.profileRequired => '请先完成 LOOP Profile。',
  FriendGatewayFailureKind.incomingRequestPending ||
  FriendGatewayFailureKind.outgoingRequestPending => '已有一条等待中的好友申请。',
  FriendGatewayFailureKind.alreadyFriends => '你们已经是好友。',
  FriendGatewayFailureKind.cooldown => '申请处于冷却期，请稍后再试。',
  FriendGatewayFailureKind.alreadyDecided => '这条申请已经处理，请刷新列表。',
  FriendGatewayFailureKind.cursorInvalid => '列表分页已过期，需要从第一页重新加载。',
  FriendGatewayFailureKind.operatorRequired => '该操作需要后台核对。',
  FriendGatewayFailureKind.outcomeUnknown => '请求可能已提交，需按原操作编号查询结果。',
  FriendGatewayFailureKind.unexpected => '操作暂时无法完成。',
  null => '操作暂时无法完成。',
};
