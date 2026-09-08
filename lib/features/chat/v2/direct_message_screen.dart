import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The trusted identity an in-app caller hands to `dm`.
///
/// A deep link carries no identity, so the header then stays neutral rather
/// than repeating an unverified alias from a URL.
@immutable
final class DirectMessageTarget {
  const DirectMessageTarget({required this.publicProfileId, this.identity});

  final String publicProfileId;
  final LoopPublicProfile? identity;
}

/// `dm` · one direct conversation.
///
/// A friendship is the only admission. Without one the page explains that a
/// message request has to be sent and accepted first, and offers exactly that
/// action. LOOP never claims end-to-end encryption here or anywhere else.
class DirectMessageScreen extends ConsumerStatefulWidget {
  const DirectMessageScreen({
    super.key,
    this.target,
    this.channelCid,
    this.onBack,
  });

  /// The account this conversation is with. Null for a pure deep link.
  final DirectMessageTarget? target;

  /// A server-issued direct-channel CID from a notification deep link.
  final String? channelCid;
  final VoidCallback? onBack;

  @override
  ConsumerState<DirectMessageScreen> createState() =>
      _DirectMessageScreenState();
}

class _DirectMessageScreenState extends ConsumerState<DirectMessageScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final state = ref.watch(directChannelControllerProvider);
    final controller = ref.read(directChannelControllerProvider.notifier);
    final target = widget.target;
    final blocked = communityCapabilityBlocks(mode, capability);
    if (!blocked &&
        widget.channelCid == null &&
        target != null &&
        state.phase == CommunityViewPhase.loading &&
        !state.isReady) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(target.publicProfileId));
      });
    }

    final identity = target?.identity;
    return Scaffold(
      key: const ValueKey<String>('dm-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopTopbar(
              title: identity?.displayName ?? '私聊',
              kicker: identity?.alias == null
                  ? communityPreviewKicker(mode)
                  : identity!.loopId,
              onBack: widget.onBack,
              minHeight: 72,
            ),
            Expanded(
              child: _body(
                blocked: blocked,
                capabilityReason: capability.reasonCode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required bool blocked, required String? capabilityReason}) {
    final state = ref.watch(directChannelControllerProvider);
    final controller = ref.read(directChannelControllerProvider.notifier);
    final cid = widget.channelCid ?? state.streamCid;

    if (blocked) {
      return _Block(
        blockKey: 'dm-capability-unavailable',
        message: '私聊当前不可用',
        reason: capabilityReason == null
            ? '尚未读取到能力清单，本页不请求任何频道。'
            : communicationUnavailableReason(capabilityReason),
      );
    }
    if (cid == null && widget.target == null) {
      return const _Block(
        blockKey: 'dm-missing-target',
        message: '缺少会话标识',
        reason: '请从关注列表、陌生人请求或公开资料进入，本页不会猜测要打开谁的私聊。',
      );
    }
    if (cid == null) {
      if (state.block == DirectChannelBlock.friendshipRequired) {
        return _FriendshipRequired(
          target: widget.target!,
          requestSent: state.requestSent,
          busy: state.busy,
          onSend: _sendMessageRequest,
        );
      }
      // `operatorRequired` is a terminal *unresolved* outcome: the server
      // accepted the command and a human has to finish it. Offering a retry
      // would start a second logical operation under a new key, so this state
      // gets its own explanation with no retry at all.
      if (state.block == DirectChannelBlock.operatorRequired) {
        return const SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopEmpty(
                key: ValueKey<String>('dm-operator-required'),
                icon: 'clock',
                message: '需要人工处理',
                reason:
                    '服务端已经受理这次请求，但需要人工介入才能完成。'
                    '这里不提供重试：重新提交会开出第二个操作。请联系支持后再回到这个会话。',
              ),
              LoopNotice(
                key: ValueKey<String>('dm-operator-required-notice'),
                icon: 'info',
                tone: LoopNoticeTone.warn,
                title: '不要重复提交',
                body: '这次请求已经记录在服务端，重复发起不会加快处理，反而会产生一条新的待处理操作。',
                margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
              ),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: CommunityStateBlock(
          phase: state.phase,
          failureKind: state.failureKind,
          skeleton: LoopSkeletonType.list,
          emptyMessage: '还没有打开这个私聊',
          emptyReason: '服务端还没有返回可用的会话地址。',
          onRetry: () => unawaited(controller.resolve()),
        ),
      );
    }

    return LoopStreamChannelSurface(
      key: ValueKey<String>('dm-$cid'),
      cid: cid,
      composerHint: '发消息',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '私聊'),
          const LoopNotice(
            key: ValueKey<String>('dm-protection-note'),
            icon: 'info',
            title: '不声明端到端加密',
            body: '私聊由 Stream Chat 承载，保护能力取决于供应商策略，LOOP 不做端到端加密承诺。',
            margin: EdgeInsets.fromLTRB(16, 10, 16, 4),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessageRequest() async {
    final target = widget.target;
    if (target == null) return;
    final controller = ref.read(directChannelControllerProvider.notifier);
    controller.setBusy(true);
    CommunityFailureKind? failure;
    try {
      await ref
          .read(socialGatewayProvider)
          .sendMessageRequest(target.publicProfileId);
    } on CommunityGatewayException catch (error) {
      failure = error.kind;
    } catch (_) {
      failure = CommunityFailureKind.unexpected;
    }
    controller.setBusy(false);
    if (!mounted) return;
    if (failure == null) {
      controller.markRequestSent();
      LoopToast.show(context, message: '消息请求已发送');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.warn,
    );
  }
}

class _FriendshipRequired extends StatelessWidget {
  const _FriendshipRequired({
    required this.target,
    required this.requestSent,
    required this.busy,
    required this.onSend,
  });

  final DirectMessageTarget target;
  final bool requestSent;
  final bool busy;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopEmpty(
          key: const ValueKey<String>('dm-friendship-required'),
          icon: 'shield',
          message: '还不能直接私聊',
          reason: requestSent
              ? '消息请求已经发出。对方接受之前，这里不会出现会话。'
              : '私聊需要双方成为好友。先发送一条消息请求，对方接受后这个会话才会打开。'
                    '服务端对不可达的账号统一返回同一个结果，因此这里不代表对方一定存在。',
        ),
        if (!requestSent)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('dm-send-message-request'),
              label: '发送消息请求',
              block: true,
              primary: true,
              onPressed: busy ? null : () => unawaited(onSend()),
            ),
          ),
        const LoopNotice(
          key: ValueKey<String>('dm-protection-note-blocked'),
          icon: 'info',
          title: '不声明端到端加密',
          body: '私聊由 Stream Chat 承载，保护能力取决于供应商策略，LOOP 不做端到端加密承诺。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
      ],
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({
    required this.blockKey,
    required this.message,
    required this.reason,
  });

  final String blockKey;
  final String message;
  final String reason;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LoopEmpty(
      key: ValueKey<String>(blockKey),
      icon: 'warn',
      message: message,
      reason: reason,
    ),
  );
}
