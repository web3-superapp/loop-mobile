import 'package:flutter/widgets.dart' show BuildContext, TextSpan;
import 'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show
        ChannelModel,
        DraftMessage,
        Message,
        MessageState,
        StreamMessagePreviewFormatter,
        User;

/// Removes untrusted Token Card fields from every compact Stream preview.
final class LoopStreamTokenCardMessagePreviewFormatter
    extends StreamMessagePreviewFormatter {
  const LoopStreamTokenCardMessagePreviewFormatter();

  static const String tokenReferenceLabel = 'Token reference';
  static const String unsupportedTokenCardLabel = 'Unsupported token card';

  @override
  TextSpan formatMessage(
    BuildContext context,
    Message message, {
    bool showCaption = true,
    ChannelModel? channel,
    User? currentUser,
  }) {
    if (!LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      message.attachments,
    )) {
      return super.formatMessage(
        context,
        message,
        showCaption: showCaption,
        channel: channel,
        currentUser: currentUser,
      );
    }
    return super.formatMessage(
      context,
      _sanitizedMessage(message),
      showCaption: showCaption,
      channel: channel,
      currentUser: currentUser,
    );
  }

  @override
  String formatMessageSemanticsLabel(
    BuildContext context,
    Message message, {
    ChannelModel? channel,
    User? currentUser,
    bool showCaption = true,
  }) {
    if (!LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      message.attachments,
    )) {
      return super.formatMessageSemanticsLabel(
        context,
        message,
        showCaption: showCaption,
        channel: channel,
        currentUser: currentUser,
      );
    }
    return super.formatMessageSemanticsLabel(
      context,
      _sanitizedMessage(message),
      showCaption: showCaption,
      channel: channel,
      currentUser: currentUser,
    );
  }

  @override
  TextSpan formatDraftMessage(
    BuildContext context,
    DraftMessage draftMessage, {
    User? currentUser,
    bool showCaption = true,
  }) {
    if (!LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      draftMessage.attachments,
    )) {
      return super.formatDraftMessage(
        context,
        draftMessage,
        currentUser: currentUser,
        showCaption: showCaption,
      );
    }
    return super.formatDraftMessage(
      context,
      _sanitizedDraft(draftMessage),
      currentUser: currentUser,
      showCaption: showCaption,
    );
  }

  @override
  String formatDraftMessageSemanticsLabel(
    BuildContext context,
    DraftMessage draftMessage, {
    User? currentUser,
    bool showCaption = true,
  }) {
    if (!LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      draftMessage.attachments,
    )) {
      return super.formatDraftMessageSemanticsLabel(
        context,
        draftMessage,
        currentUser: currentUser,
        showCaption: showCaption,
      );
    }
    return super.formatDraftMessageSemanticsLabel(
      context,
      _sanitizedDraft(draftMessage),
      currentUser: currentUser,
      showCaption: showCaption,
    );
  }

  static Message _sanitizedMessage(Message message) {
    final reference = LoopStreamTokenCardAttachmentPolicy.tryParse(
      message.attachments,
    );
    return Message(
      id: message.id,
      text: reference == null ? unsupportedTokenCardLabel : tokenReferenceLabel,
      createdAt: message.createdAt,
      user: message.user,
      state: MessageState.sent,
    );
  }

  static DraftMessage _sanitizedDraft(DraftMessage draft) {
    final reference = LoopStreamTokenCardAttachmentPolicy.tryParse(
      draft.attachments,
    );
    return DraftMessage(
      id: draft.id,
      text: reference == null ? unsupportedTokenCardLabel : tokenReferenceLabel,
    );
  }
}
