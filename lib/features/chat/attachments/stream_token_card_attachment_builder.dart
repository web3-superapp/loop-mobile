import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart';
import 'package:loop_mobile/features/chat/widgets/token_card_view.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show Attachment, Message, StreamAttachmentWidgetBuilder;

/// Renders LOOP's identifier-only token reference inside official Stream UI.
///
/// This builder performs no network request and never mirrors Stream message
/// history. A separately designed bounded facts projection may enrich visible
/// cards later; until then valid references remain explicitly unavailable.
final class LoopStreamTokenCardAttachmentBuilder
    extends StreamAttachmentWidgetBuilder {
  const LoopStreamTokenCardAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    return LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard(
      message.attachments,
    );
  }

  @override
  Widget build(
    BuildContext context,
    Message message,
    Map<String, List<Attachment>> attachments,
  ) {
    final reference = LoopStreamTokenCardAttachmentPolicy.tryParse(
      message.attachments,
    );
    if (reference == null) {
      return const LoopTokenCardView(state: LoopTokenCardViewState.malformed);
    }

    return LoopTokenCardView(
      state: LoopTokenCardViewState.unavailable,
      reference: reference,
    );
  }
}
