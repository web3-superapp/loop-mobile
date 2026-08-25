import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show Attachment;

/// Strict receive policy shared by full messages and compact Stream previews.
abstract final class LoopStreamTokenCardAttachmentPolicy {
  static bool containsRawTokenCard(Iterable<Attachment> attachments) {
    return attachments.any(
      (attachment) =>
          attachment.rawType == LoopTokenCardAttachment.attachmentType,
    );
  }

  static LoopTokenCardAttachment? tryParse(Iterable<Attachment> attachments) {
    final materialized = attachments.toList(growable: false);
    if (materialized.length != 1) return null;

    final attachment = materialized.single;
    if (attachment.rawType != LoopTokenCardAttachment.attachmentType ||
        !_hasIdentifierOnlyTopLevelFields(attachment)) {
      return null;
    }
    return LoopTokenCardAttachment.tryParse(
      type: attachment.rawType,
      extraData: attachment.extraData,
    );
  }

  static bool _hasIdentifierOnlyTopLevelFields(Attachment attachment) {
    return attachment.titleLink == null &&
        attachment.title == null &&
        attachment.thumbUrl == null &&
        attachment.text == null &&
        attachment.pretext == null &&
        attachment.ogScrapeUrl == null &&
        attachment.imageUrl == null &&
        attachment.footerIcon == null &&
        attachment.footer == null &&
        attachment.fields == null &&
        attachment.fallback == null &&
        attachment.color == null &&
        attachment.authorName == null &&
        attachment.authorLink == null &&
        attachment.authorIcon == null &&
        attachment.assetUrl == null &&
        (attachment.actions == null || attachment.actions!.isEmpty) &&
        attachment.originalWidth == null &&
        attachment.originalHeight == null &&
        attachment.localUri == null &&
        attachment.file == null;
  }
}
