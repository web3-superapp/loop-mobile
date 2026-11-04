import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_identity_scope.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
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

/// `#scr-dm`'s `.folio-primary.chalk-card`.
///
/// The heading names the conversation — `和 NightOwl 的私聊` — so the page's
/// one primary narrative is what this thread *is*, not the word for every
/// private thread. Without a trusted identity the page has no name to use and
/// says only what kind of conversation it is.
LoopFolioPrimary directMessageFolio(LoopPublicProfile? identity) =>
    LoopFolioPrimary(
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.listing,
      // A Chalk hero carries no `::after` ring in the prototype.
      ring: false,
      compact: true,
      kicker: LoopL10n.current.common_directMessage,
      heading: identity == null
          ? LoopL10n.current.chatV2_directMessageHeading
          : LoopL10n.current.chatV2_directMessageHeading2(identity.displayName),
      caption: LoopL10n.current.chatV2_directMessageCaption,
      stamp: LoopL10n.current.chatV2_directMessageStamp,
    );

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
    // S108: a direct conversation multi-selects and forwards like a group.
    return LoopMessageSelectionHost(
      child: Scaffold(
        key: const ValueKey<String>('dm-screen'),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopSelectionAwareTopbar(
                child: LoopTopbar(
                  title:
                      identity?.displayName ??
                      context.l10n.common_directMessage,
                  // `#scr-dm .topbar` prints `NightOwl` at 15px and
                  // `LOOP-4D5E6F · 在线` at 11px *under* it. LOOP had the LOOP ID
                  // in the mono eyebrow above the name, which reads as a section
                  // marker and put the identifier before the person (audit
                  // 2026-09-20 · B.3).
                  kicker: communityPreviewKicker(mode),
                  // An account with no alias is already named by its LOOP ID on
                  // the title line; printing it twice says nothing the second
                  // time.
                  subtitle: identity == null || identity.alias == null
                      ? null
                      : identity.loopId,
                  onBack: widget.onBack,
                  minHeight: 72,
                  framedTools: true,
                ),
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
      ),
    );
  }

  Widget _body({required bool blocked, required String? capabilityReason}) {
    final identity = widget.target?.identity;
    final state = ref.watch(directChannelControllerProvider);
    final controller = ref.read(directChannelControllerProvider.notifier);
    final cid = widget.channelCid ?? state.streamCid;

    if (blocked) {
      return _Block(
        blockKey: 'dm-capability-unavailable',
        message: LoopL10n.current.chatV2_directMessageMessage,
        reason: capabilityReason == null
            ? LoopL10n.current.chatV2_communityReason2
            : communicationUnavailableReason(capabilityReason),
      );
    }
    if (cid == null && widget.target == null) {
      return _Block(
        blockKey: 'dm-missing-target',
        message: LoopL10n.current.chatV2_directMessageMessage2,
        reason: LoopL10n.current.chatV2_directMessageReason,
      );
    }
    if (cid == null) {
      if (state.block == DirectChannelBlock.friendshipRequired) {
        return _FriendshipRequired(
          identity: identity,
          requestSent: state.requestSent,
          busy: state.busy,
          failure: state.requestFailure,
          onSend: _sendMessageRequest,
        );
      }
      // `operatorRequired` is a terminal *unresolved* outcome: the server
      // accepted the command and a human has to finish it. Offering a retry
      // would start a second logical operation under a new key, so this state
      // gets its own explanation with no retry at all.
      if (state.block == DirectChannelBlock.operatorRequired) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopInlineUnavailable(
                key: ValueKey<String>('dm-operator-required'),
                icon: 'clock',
                message: LoopL10n
                    .current
                    .chatV2_directMessageDmOperatorRequiredMessage,
                detail: LoopL10n
                    .current
                    .chatV2_directMessageDmOperatorRequiredDetail,
                maxLines: 2,
                detailMaxLines: 4,
              ),
              LoopNotice(
                key: ValueKey<String>('dm-operator-required-notice'),
                icon: 'info',
                tone: LoopNoticeTone.warn,
                title: LoopL10n
                    .current
                    .chatV2_directMessageDmOperatorRequiredNoticeTitle,
                body: LoopL10n
                    .current
                    .chatV2_directMessageDmOperatorRequiredNoticeBody,
                margin: EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  14,
                  LoopSpacing.page,
                  0,
                ),
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
          emptyMessage: LoopL10n.current.chatV2_directMessageEmptyMessage,
          emptyReason: LoopL10n.current.chatV2_directMessageEmptyReason,
          onRetry: () => unawaited(controller.resolve()),
        ),
      );
    }

    final surface = LoopStreamChannelSurface(
      key: ValueKey<String>('dm-$cid'),
      cid: cid,
      keyPrefix: 'dm-channel',
      // S99c: nobody pins in a direct conversation (loop-api 0091).
      mayPinMessages: false,
      // The placeholder stays the one every conversation shares (decision
      // 0075): a pasted contract address is read in a private thread too —
      // `_withTokenCards` draws the card under any bubble in any channel —
      // so this composer promises exactly what it does. The walkthrough note
      // about 「贴合约地址识别代币」 in `dm` is left for the main agent, with
      // that evidence.
      composerHint: loopChatComposerHint,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommunityPreviewNotice(
            mode: state.mode,
            resource: LoopL10n.current.common_directMessage,
          ),
        ],
      ),
    );

    // The peer's public identity travels down with the conversation, so the
    // Stream widgets under it name the same person the header does instead of
    // the provider's account id. Without a trusted identity — a deep link
    // carries none — nothing is published and they fail closed.
    final peer = widget.target?.identity?.displayName;
    if (peer == null) return surface;
    return LoopDirectPeerScope(
      displayName: peer,
      publicProfileId: widget.target?.publicProfileId,
      child: surface,
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
    if (failure == null) {
      controller.markRequestSent();
      if (!mounted) return;
      LoopToast.show(
        context,
        message: LoopL10n.current.chatV2_directMessageMessage3,
      );
      return;
    }
    // The refusal is state, not an announcement: it stays under the control
    // until the next attempt. The toast is the same sentence, said once.
    controller.markRequestFailed(failure);
    if (!mounted) return;
    LoopToast.show(
      context,
      message: directMessageRequestFailureReason(failure),
      kind: LoopToastKind.warn,
    );
  }
}

/// zh-CN copy for a message request the server refused.
///
/// Reachability is not enumerable (decision 0070): a closed 私聊 switch, a
/// missing friendship and an account that does not exist all answer the same
/// not-found kind, so the sentence names the switch without claiming which of
/// the three it was. Every other kind keeps the shared refusal copy.
String directMessageRequestFailureReason(CommunityFailureKind kind) =>
    switch (kind) {
      CommunityFailureKind.notFound =>
        LoopL10n.current.chatV2_directMessageNotFound,
      _ => communityFailureReason(kind),
    };

class _FriendshipRequired extends StatelessWidget {
  const _FriendshipRequired({
    required this.identity,
    required this.requestSent,
    required this.busy,
    required this.failure,
    required this.onSend,
  });

  /// The peer this card names, when the caller carried one.
  final LoopPublicProfile? identity;
  final bool requestSent;
  final bool busy;

  /// Why the last send did not go through, or null when none was refused.
  final CommunityFailureKind? failure;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // With no thread to read, the page has the room for its own primary:
        // `#scr-dm` opens on the Chalk hero, and this is the state where it
        // is the only thing on screen. A conversation that did open keeps the
        // one-line strip instead, so the messages get the height.
        directMessageFolio(identity),
        LoopEmptyState(
          key: const ValueKey<String>('dm-friendship-required'),
          illustration: LoopIllustration.friends,
          title: context.l10n.chatV2_directMessageDmFriendshipRequiredTitle,
          message: requestSent
              ? context.l10n.chatV2_directMessageDmFriendshipRequiredMessage
              // The refusal does not enumerate: a missing friendship, a
              // closed 私聊 switch in the other account's privacy centre and
              // an account that does not exist all answer the same way
              // (decision 0070).
              : context.l10n.chatV2_directMessageDmFriendshipRequiredMessage2,
          compact: true,
        ),
        // A refused send is the page's own outcome and outlives the toast
        // that announced it. It never replaces the control: the same request
        // may be sent again, under a new idempotency key, once the other
        // account opens 「允许陌生人发好友申请」.
        if (failure != null)
          LoopNotice(
            key: const ValueKey<String>('dm-message-request-failed'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.chatV2_directMessageDmMessageRequestFailedTitle,
            body: directMessageRequestFailureReason(failure!),
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
        if (!requestSent)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
            child: LoopButton(
              key: const ValueKey<String>('dm-send-message-request'),
              label: failure == null
                  ? context.l10n.chatV2_directMessageDmSendMessageRequestLabel
                  : context.l10n.chatV2_directMessageDmSendMessageRequestLabel2,
              block: true,
              primary: true,
              onPressed: busy ? null : () => unawaited(onSend()),
            ),
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
    child: LoopInlineUnavailable(
      key: ValueKey<String>(blockKey),
      message: message,
      detail: reason,
      maxLines: 2,
      detailMaxLines: 4,
    ),
  );
}
