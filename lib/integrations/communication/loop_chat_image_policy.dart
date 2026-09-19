// What LOOP lets a member put in a chat message, and what it says when it
// refuses.
//
// The rule is deliberately narrower than the one Stream enforces. Stream's own
// validator reads `appSettings.imageUploadConfig` — a server-side ceiling that
// is generous (tens of megabytes, every image format the CDN understands) and
// that LOOP does not control. A chat on a phone, on a Chinese mobile network,
// is not the place to discover that ceiling: a 40 MB photo uploads for a
// minute and then sits in the room as a picture nobody can load.
//
// So LOOP states its own rule, in front of Stream's, and states it in the
// member's words: images only, four formats, 10 MB each, nine per message.
// Everything here is a pure function over `Attachment`, so the rule can be
// read, tested and quoted without a widget tree.
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The largest single image LOOP will hand to the upload.
const int loopChatImageMaxBytes = 10 * 1024 * 1024;

/// The picker types LOOP opens. Images and nothing else.
const List<AttachmentPickerType> loopChatImagePickerTypes =
    <AttachmentPickerType>[AttachmentPickerType.images];

/// The most images one message may carry.
const int loopChatImageMaxCount = 9;

/// The file extensions LOOP accepts, lower-case, without the dot.
const Set<String> loopChatImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
};

/// The MIME types LOOP accepts, lower-case.
const Set<String> loopChatImageMimeTypes = <String>{
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
};

/// Why LOOP did not take something the member picked.
enum LoopChatImageRefusal {
  /// The pick was not an image at all.
  notAnImage,

  /// An image, in a format LOOP does not send.
  unsupportedFormat,

  /// An image over [loopChatImageMaxBytes].
  tooLarge,

  /// One image too many for a single message.
  tooMany,
}

/// The sentence shown when [refusal] happens.
///
/// Each one names the limit and says what LOOP did — which is nothing. A
/// refused pick is not queued, not compressed and not uploaded, so the copy
/// never has to be walked back.
String loopChatImageRefusalMessage(LoopChatImageRefusal refusal) =>
    switch (refusal) {
      LoopChatImageRefusal.notAnImage => '这里只能发图片，刚才选的不是图片，没有加进来。',
      LoopChatImageRefusal.unsupportedFormat =>
        '只支持 JPG、PNG、WebP、GIF 四种图片，其他格式没有加进来。',
      LoopChatImageRefusal.tooLarge => '单张图片不能超过 10 MB，超出的那张没有加进来。',
      LoopChatImageRefusal.tooMany => '一条消息最多 9 张图片，多出来的没有加进来。',
    };

/// What survives LOOP's rule, and the first reason something did not.
class LoopChatImageReview {
  const LoopChatImageReview({required this.kept, this.refusal});

  /// The picks LOOP will send, in the order the member made them.
  final List<Attachment> kept;

  /// The first rule that was broken, or null when nothing was.
  final LoopChatImageRefusal? refusal;

  /// Whether anything was dropped.
  bool get refused => refusal != null;
}

/// Applies LOOP's image rule to one composer's current picks.
///
/// Only a *local* pick is judged. An attachment with no [Attachment.file] was
/// not chosen on this device in this composer — it is the link preview the
/// composer scraped from the typed text, or an attachment already on a message
/// being edited — and re-judging it would delete a fact LOOP did not create.
///
/// The count is over image attachments only, for the same reason: a link
/// preview riding along with nine photos is not a tenth photo.
LoopChatImageReview loopChatReviewImages(List<Attachment> attachments) {
  final kept = <Attachment>[];
  LoopChatImageRefusal? refusal;
  var images = 0;

  for (final attachment in attachments) {
    final file = attachment.file;
    if (file == null) {
      kept.add(attachment);
      continue;
    }
    final localRefusal = loopChatRefuseImage(attachment);
    if (localRefusal != null) {
      refusal ??= localRefusal;
      continue;
    }
    if (images >= loopChatImageMaxCount) {
      refusal ??= LoopChatImageRefusal.tooMany;
      continue;
    }
    images += 1;
    kept.add(attachment);
  }

  return LoopChatImageReview(kept: kept, refusal: refusal);
}

/// Why LOOP will not send this one pick, or null when it will.
///
/// The format is read from both the file name and the MIME type the picker
/// reported. Either one naming a format LOOP does not send is enough: an
/// extension can be renamed and a MIME type can be absent, and LOOP would
/// rather refuse a picture it could have sent than upload a file it cannot
/// describe.
LoopChatImageRefusal? loopChatRefuseImage(Attachment attachment) {
  final file = attachment.file;
  if (file == null) return null;
  if (attachment.type != AttachmentType.image) {
    return LoopChatImageRefusal.notAnImage;
  }

  final extension = file.extension?.toLowerCase();
  if (extension == null || !loopChatImageExtensions.contains(extension)) {
    return LoopChatImageRefusal.unsupportedFormat;
  }
  final mimeType = (attachment.mimeType ?? file.mediaType?.mimeType)
      ?.toLowerCase();
  if (mimeType != null && !loopChatImageMimeTypes.contains(mimeType)) {
    return LoopChatImageRefusal.unsupportedFormat;
  }

  final size = attachment.fileSize ?? file.size;
  if (size != null && size > loopChatImageMaxBytes) {
    return LoopChatImageRefusal.tooLarge;
  }
  return null;
}
