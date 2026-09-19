// How a picture reads once it is in the room.
//
// Stream already draws the thumbnail, the upload overlay and the full-screen
// pager; LOOP keeps all three and changes what they say:
//
//  * a picture that will not load shows a LOOP placeholder with the reason in
//    Chinese, never the CDN address it failed to fetch. A raw URL in a bubble
//    is a leak dressed as an error message, and it is not something a member
//    can act on;
//  * the bubble's picture is bounded by LOOP's own ceiling, so one tall
//    screenshot cannot take the whole conversation;
//  * the full-screen view is LOOP chrome — Ink ground, the sender, a 24-hour
//    clock, `第 n 张 / 共 m 张` in mono — over Stream's own zoom and paging.
//    Stream's default viewer also offers share and save, which download the
//    file through a Dio client LOOP does not own; neither capability has been
//    proven on a device, so neither is offered.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The largest a picture may be drawn inside a bubble.
///
/// The width matches Stream's own bubble ceiling; the height is LOOP's, and is
/// shorter than Stream's 300 so a portrait screenshot still leaves the
/// messages around it on screen.
const BoxConstraints loopChatImageBubbleConstraints = BoxConstraints(
  minWidth: 140,
  maxWidth: 256,
  minHeight: 96,
  maxHeight: 260,
);

/// The grid a message with several pictures is drawn in.
const BoxConstraints loopChatImageGridConstraints = BoxConstraints.tightFor(
  width: 256,
  height: 195,
);

/// What LOOP shows where a picture did not appear.
///
/// The [error] is deliberately unread: it is a transport object whose
/// `toString()` carries the request URL. The member is told the one thing they
/// can act on — it did not load, tap to try again — and nothing else.
Widget loopChatImagePlaceholder(
  BuildContext context,
  Object error,
  VoidCallback? retry,
) => _LoopChatImagePlaceholder(onRetry: retry);

class _LoopChatImagePlaceholder extends StatelessWidget {
  const _LoopChatImagePlaceholder({this.onRetry});

  final VoidCallback? onRetry;

  static const String failureMessage = '图片没有加载出来';
  static const String retryMessage = '点按重试';

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, constraints) {
        // A grid cell is too small for a sentence; the label still reaches a
        // screen reader through the Semantics wrapper below.
        final narrow =
            constraints.maxHeight < 108 || constraints.maxWidth < 132;
        return ColoredBox(
          color: LoopColors.card2,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const LoopIcon('camera', size: 20, color: LoopColors.text3),
                if (!narrow) ...<Widget>[
                  const SizedBox(height: LoopSpacing.x2),
                  Text(
                    failureMessage,
                    style: LoopTypography.caption(11),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null)
                    Text(
                      retryMessage,
                      style: LoopTypography.caption(11, color: LoopColors.lime),
                      textAlign: TextAlign.center,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );

    return Semantics(
      key: const ValueKey<String>('loop-chat-image-unavailable'),
      label: onRetry == null ? failureMessage : '$failureMessage，$retryMessage',
      button: onRetry != null,
      child: onRetry == null
          ? body
          : GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: body,
            ),
    );
  }
}

/// One picture in a bubble.
///
/// Registered on [StreamComponentBuilders.imageAttachment]. It restates
/// Stream's own layout — aspect-ratio box, thumbnail, upload overlay — with
/// LOOP's ceiling and LOOP's failure placeholder. The tap that opens the
/// full-screen view belongs to the builder above it and is untouched.
Widget loopStreamImageAttachmentBuilder(
  BuildContext context,
  StreamImageAttachmentProps props,
) {
  final size = props.image.originalSize;
  final constraints = size == null
      ? loopChatImageBubbleConstraints
      : loopChatImageBubbleConstraints.tightenMaxSize(size);

  return ConstrainedBox(
    constraints: constraints,
    child: AspectRatio(
      aspectRatio: size?.aspectRatio ?? 1,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: <Widget>[
          StreamImageAttachmentThumbnail(
            image: props.image,
            // Stream fills the box when it does not know the original size;
            // with a known size the aspect box above is already exact.
            fit: size == null ? BoxFit.cover : null,
            resize: props.resize,
            errorBuilder: loopChatImagePlaceholder,
          ),
          Positioned.fill(
            child: StreamAttachmentUploadStateBuilder(
              message: props.message,
              attachment: props.image,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Several pictures in one bubble.
///
/// Registered on [StreamComponentBuilders.galleryAttachment]. Stream's grid
/// geometry is kept exactly; only the tile is LOOP's, because the tile is the
/// one place the failure placeholder can be installed — the props Stream hands
/// this builder carry a tile builder with the placeholder already baked in.
/// Replacing the tile means LOOP also has to restate the tap, which is the
/// same route the single-picture path takes.
Widget loopStreamGalleryAttachmentBuilder(
  BuildContext context,
  StreamGalleryAttachmentProps props,
) => DefaultStreamGalleryAttachment(
  props: StreamGalleryAttachmentProps(
    message: props.message,
    attachments: props.attachments,
    constraints: props.constraints ?? loopChatImageGridConstraints,
    spacing: props.spacing,
    runSpacing: props.runSpacing,
    itemBuilder: (context, index) => _LoopChatGalleryTile(
      message: props.message,
      attachment: props.attachments[index],
    ),
  ),
);

class _LoopChatGalleryTile extends StatelessWidget {
  const _LoopChatGalleryTile({required this.message, required this.attachment});

  final Message message;
  final Attachment attachment;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => loopOpenChatImageViewer(context, message, attachment),
    child: Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: <Widget>[
        StreamMediaAttachmentThumbnail(
          media: attachment,
          fit: BoxFit.cover,
          errorBuilder: loopChatImagePlaceholder,
        ),
        Positioned.fill(
          child: StreamAttachmentUploadStateBuilder(
            message: message,
            attachment: attachment,
          ),
        ),
      ],
    ),
  );
}

/// Opens the full-screen view at [attachment], paging over the pictures of the
/// same message.
Future<void> loopOpenChatImageViewer(
  BuildContext context,
  Message message,
  Attachment attachment,
) {
  final attachments = message.toMediaGalleryAttachments(
    filter: (it) =>
        it.type == AttachmentType.image ||
        it.type == AttachmentType.giphy ||
        it.type == AttachmentType.video,
  );
  final initialIndex = attachments.indexWhere(
    (it) => it.attachment.id == attachment.id,
  );
  final channel = StreamChannel.of(context).channel;

  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => StreamChannel.value(
        channel: channel,
        child: StreamMediaGalleryPreview(
          attachments: attachments,
          initialIndex: math.max(0, initialIndex),
        ),
      ),
    ),
  );
}

/// The full-screen picture view.
///
/// Registered on [StreamComponentBuilders.mediaGalleryPreview], so the tap
/// LOOP does not own — the one inside Stream's own single-image builder —
/// lands here too.
Widget loopStreamMediaGalleryPreviewBuilder(
  BuildContext context,
  StreamMediaGalleryPreviewProps props,
) => LoopChatImageViewer(props: props);

/// Ink ground, Stream's zoom, LOOP's chrome.
class LoopChatImageViewer extends StatefulWidget {
  const LoopChatImageViewer({required this.props, super.key});

  final StreamMediaGalleryPreviewProps props;

  @override
  State<LoopChatImageViewer> createState() => _LoopChatImageViewerState();
}

class _LoopChatImageViewerState extends State<LoopChatImageViewer> {
  late final PageController _pageController = PageController(
    initialPage: widget.props.initialIndex,
  );
  late int _page = widget.props.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.props.attachments;
    if (attachments.isEmpty) {
      return const ColoredBox(color: LoopColors.ink, child: SizedBox.expand());
    }
    final index = _page.clamp(0, attachments.length - 1);
    final message = attachments[index].message;

    return Scaffold(
      backgroundColor: LoopColors.ink,
      // The chrome does not hide on a tap. Stream's own viewer toggles it, but
      // the tap has to reach a `PhotoView` that has already claimed the
      // gesture arena for pan and zoom, so the control would work on some
      // pictures and not others. Two thin bars over a veil, always readable,
      // are the honest version: the member always knows who sent this and
      // which one of how many they are looking at.
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey<String>('loop-chat-image-viewer-pages'),
              controller: _pageController,
              itemCount: attachments.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (_, page) => StreamMediaGalleryPreviewItem(
                attachment: attachments[page].attachment,
                pageIndex: page,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _LoopChatImageViewerHeader(message: message),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LoopChatImageViewerFooter(
              page: index,
              total: attachments.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopChatImageViewerHeader extends StatelessWidget {
  const _LoopChatImageViewerHeader({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final sender = message.user?.name.trim();
    final sentAt = message.createdAt.toLocal();
    final stamp =
        '${loopStreamDayLabel(sentAt)} ${loopStreamClockLabel(sentAt)}';

    return SafeArea(
      bottom: false,
      child: Container(
        color: LoopColors.veil,
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.x2),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: const ValueKey<String>('loop-chat-image-viewer-close'),
                onPressed: Navigator.of(context).maybePop,
                tooltip: '返回',
                icon: const LoopIcon('close', size: 20),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (sender != null && sender.isNotEmpty)
                    Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.label(13),
                    ),
                  Text(stamp, style: LoopMono.stamp),
                ],
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

class _LoopChatImageViewerFooter extends StatelessWidget {
  const _LoopChatImageViewerFooter({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    // A single picture has no position to state.
    if (total < 2) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        color: LoopColors.veil,
        padding: const EdgeInsets.symmetric(vertical: LoopSpacing.x3),
        alignment: Alignment.center,
        child: Text(
          key: const ValueKey<String>('loop-chat-image-viewer-counter'),
          '第 ${page + 1} 张 / 共 $total 张',
          style: LoopMono.stamp,
        ),
      ),
    );
  }
}
