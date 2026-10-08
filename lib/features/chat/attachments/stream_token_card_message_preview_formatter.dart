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
///
/// It is also LOOP's one conversation-list preview, so it carries the other
/// LOOP-owned message shape too: a member-buy feed message (S108, decision
/// 0114) previews as `群友买入 · PEPE`, with no sender prefix — the sender is
/// LOOP's feed bot, and the buyer is a fact the card resolves live.
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
    if (_isMemberBuy(message)) {
      return TextSpan(text: memberBuyPreview(message));
    }
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
    if (_isMemberBuy(message)) return memberBuyPreview(message);
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

  // The member-buy rule, restated: `member_buy/member_buy_event.dart` owns
  // it, and this file's imports are a reviewed allowlist. A test compares the
  // two field by field and sample by sample.
  static const String memberBuySchemaField = 'loop_schema';
  static const String memberBuySchema = 'member_buy.v1';
  static const String memberBuySymbolField = 'symbol';
  static const String feedBotUserId = 'loop_feed_bot';
  static const String feedBotFlagField = 'loop_bot';
  static const String memberBuyLabel = '群友买入';
  static const int memberBuySymbolMaxLength = 20;
  static final RegExp _memberBuySymbolCharacters = RegExp(
    r'^[\p{L}\p{N}\p{M}$._-]+$',
    unicode: true,
  );
  static final RegExp _combiningMark = RegExp(r'^\p{M}$', unicode: true);

  /// A member-buy message from LOOP's feed bot, not yet deleted. The same tag
  /// on anybody else's message previews as that message.
  static bool _isMemberBuy(Message message) {
    final user = message.user;
    return message.extraData[memberBuySchemaField] == memberBuySchema &&
        user != null &&
        user.id == feedBotUserId &&
        user.extraData[feedBotFlagField] == true &&
        message.deletedAt == null &&
        message.type != 'deleted';
  }

  /// Letters, digits and marks of any script plus `$ . _ -`, at most twenty
  /// characters; no control, bidi or zero-width character.
  static bool memberBuySymbolIsValid(String symbol) {
    if (symbol.isEmpty || !_memberBuySymbolCharacters.hasMatch(symbol)) {
      return false;
    }
    var characters = 0;
    for (final rune in symbol.runes) {
      final mark = _combiningMark.hasMatch(String.fromCharCode(rune));
      if (mark && characters == 0) return false;
      if (!mark) characters += 1;
    }
    return characters <= memberBuySymbolMaxLength;
  }

  /// `群友买入 · PEPE`, or `群友买入` when the payload carries no symbol LOOP
  /// accepts.
  static String memberBuyPreview(Message message) {
    final raw = message.extraData[memberBuySymbolField];
    final symbol = raw is String ? raw.trim() : '';
    return memberBuySymbolIsValid(symbol)
        ? '$memberBuyLabel · $symbol'
        : memberBuyLabel;
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
